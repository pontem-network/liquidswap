/// Multi Swap liquidity pool.
/// Stores liquidity pool pairs, implements mint/burn liquidity, swap of coins.
module MultiSwap::LiquidityPool {
    use Std::Signer;
    use Std::Errors;
    use Std::Event;

    use AptosFramework::Timestamp;
    use AptosFramework::Coin::{Coin, Self};

    use MultiSwap::Math;
    use MultiSwap::UQ64x64;
    use MultiSwap::CoinHelper::{Self, assert_has_supply, assert_is_coin, supply};

    // Error codes.

    /// When coins used to create pair have wrong ordering.
    const ERR_WRONG_PAIR_ORDERING: u64 = 100;

    /// When provided LP coin already has minted supply.
    const ERR_LP_COIN_NON_ZERO_TOTAL: u64 = 101;

    /// When pair already exists on account.
    const ERR_POOL_EXISTS_FOR_PAIR: u64 = 102;

    /// When not enough liquidity minted.
    const ERR_NOT_ENOUGH_INITIAL_LIQUIDITY: u64 = 103;

    /// When not enough liquidity minted.
    const ERR_NOT_ENOUGH_LIQUIDITY: u64 = 104;

    /// When both X and Y provided for swap are equal zero.
    const ERR_EMPTY_COIN_IN: u64 = 105;

    /// When incorrect INs/OUTs arguments passed during swap and math doesn't work.
    const ERR_INCORRECT_SWAP: u64 = 106;

    /// Incorrect lp coin burn values
    const ERR_INCORRECT_BURN_VALUES: u64 = 107;

    /// When pool doesn't exists for pair.
    const ERR_POOL_DOES_NOT_EXIST: u64 = 108;

    // Constants.

    /// Minimal liquidity.
    const MINIMAL_LIQUIDITY: u64 = 1000;

    /// Current fee is 0.3%
    const FEE_MULTIPLIER: u64 = 3;
    /// It's fee denumenator.
    const FEE_SCALE: u64 = 1000;

    // Public functions.

    /// Liquidity pool with reserves.
    /// LP coin should go outside of this module.
    /// Probably we only need mint capability?
    struct LiquidityPool<phantom X, phantom Y, phantom LP> has key {
        coin_x_reserve: Coin<X>,
        coin_y_reserve: Coin<Y>,
        last_block_timestamp: u64,
        last_price_x_cumulative: u128,
        last_price_y_cumulative: u128,
        lp_mint_cap: Coin::MintCapability<LP>,
        lp_burn_cap: Coin::BurnCapability<LP>,
    }

    /// Register liquidity pool (by pairs), requires LP `burn` and `mint` capabilities.
    /// * `lp_mint_cap` - minting capability for LP coin.
    /// * `lp_burn_cap` - burning capability for LP coin.
    public fun register<X, Y, LP>(
        owner: &signer,
        lp_mint_cap: Coin::MintCapability<LP>,
        lp_burn_cap: Coin::BurnCapability<LP>
    ) acquires EventsStore {
        assert_is_coin<X>();
        assert_is_coin<Y>();
        assert!(CoinHelper::is_sorted<X, Y>(), Errors::invalid_argument(ERR_WRONG_PAIR_ORDERING));

        assert_is_coin<LP>();

        // TODO: check LP decimals.
        assert_has_supply<LP>();
        assert!(supply<LP>() == 0, Errors::invalid_state(ERR_LP_COIN_NON_ZERO_TOTAL));

        let owner_addr = Signer::address_of(owner);
        assert!(!exists<LiquidityPool<X, Y, LP>>(owner_addr), Errors::already_published(ERR_POOL_EXISTS_FOR_PAIR));

        let pool = LiquidityPool<X, Y, LP>{
            coin_x_reserve: Coin::zero<X>(),
            coin_y_reserve: Coin::zero<Y>(),
            last_block_timestamp: 0,
            last_price_x_cumulative: 0,
            last_price_y_cumulative: 0,
            lp_mint_cap,
            lp_burn_cap,
        };
        move_to(owner, pool);

        let events_store = EventsStore<X, Y, LP>{
            pool_created_handle: Event::new_event_handle<PoolCreatedEvent<X, Y, LP>>(owner),
            liquidity_added_handle: Event::new_event_handle<LiquidityAddedEvent<X, Y, LP>>(owner),
            liquidity_removed_handle: Event::new_event_handle<LiquidityRemovedEvent<X, Y, LP>>(owner),
            swap_handle: Event::new_event_handle<SwapEvent<X, Y, LP>>(owner),
            oracle_updated_handle: Event::new_event_handle<OracleUpdatedEvent<X, Y, LP>>(owner),
        };
        move_to(owner, events_store);

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(owner_addr);
        Event::emit_event(
            &mut events_store.pool_created_handle,
            PoolCreatedEvent<X, Y, LP>{});
    }

    /// Mint new liquidity.
    /// * `pool_addr` - pool owner address.
    /// * `coin_x` - coin X to add to liquidity reserves.
    /// * `coin_y` - coin Y to add to liquidity reserves.
    public fun add_liquidity<X, Y, LP>(
        pool_addr: address,
        coin_x: Coin<X>,
        coin_y: Coin<Y>
    ): Coin<LP> acquires LiquidityPool, EventsStore {
        assert!(exists<LiquidityPool<X, Y, LP>>(pool_addr), Errors::not_published(ERR_POOL_DOES_NOT_EXIST));

        let lp_coins_total = supply<LP>();

        let (x_reserve_size, y_reserve_size) = get_reserves_size<X, Y, LP>(pool_addr);

        let x_provided_val = Coin::value<X>(&coin_x);
        let y_provided_val = Coin::value<Y>(&coin_y);

        let provided_liq = if (lp_coins_total == 0) {
            let initial_liq = Math::sqrt(Math::mul_to_u128(x_provided_val, y_provided_val));
            assert!(initial_liq > MINIMAL_LIQUIDITY, Errors::invalid_state(ERR_NOT_ENOUGH_INITIAL_LIQUIDITY));
            initial_liq - MINIMAL_LIQUIDITY
        } else {
            // (x_provided / x_reserve) * lp_tokens_total
            let x_liq = Math::mul_div(x_provided_val, lp_coins_total, x_reserve_size);
            let y_liq = Math::mul_div(y_provided_val, lp_coins_total, y_reserve_size);
            if (x_liq < y_liq) {
                x_liq
            } else {
                y_liq
            }
        };
        assert!(provided_liq > 0, Errors::invalid_argument(ERR_NOT_ENOUGH_LIQUIDITY));

        let pool = borrow_global_mut<LiquidityPool<X, Y, LP>>(pool_addr);
        Coin::merge(&mut pool.coin_x_reserve, coin_x);
        Coin::merge(&mut pool.coin_y_reserve, coin_y);

        let lp_coins = Coin::mint<LP>(provided_liq, &pool.lp_mint_cap);

        update_oracle<X, Y, LP>(pool, pool_addr, x_reserve_size, y_reserve_size);

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        Event::emit_event(
            &mut events_store.liquidity_added_handle,
            LiquidityAddedEvent<X, Y, LP>{
                added_x_val: x_provided_val,
                added_y_val: y_provided_val,
                lp_tokens_received: provided_liq
            });

        lp_coins
    }

    /// Burn liquidity coins (LP) and get back X and Y coins from reserves.
    /// * `pool_addr` - pool owner address.
    /// * `lp_coins` - LP coins to burn.
    /// Return both `Coin<X>` and `Coin<Y>`.
    public fun burn_liquidity<X, Y, LP>(pool_addr: address, lp_coins: Coin<LP>): (Coin<X>, Coin<Y>)
    acquires LiquidityPool, EventsStore {
        assert!(exists<LiquidityPool<X, Y, LP>>(pool_addr), Errors::not_published(ERR_POOL_DOES_NOT_EXIST));

        let burned_lp_coins_val = Coin::value(&lp_coins);
        let pool = borrow_global_mut<LiquidityPool<X, Y, LP>>(pool_addr);

        let lp_coins_total = supply<LP>();
        let x_reserve_val = Coin::value(&pool.coin_x_reserve);
        let y_reserve_val = Coin::value(&pool.coin_y_reserve);

        // Compute x, y coin values for provided lp_coins value
        let x_to_return_val = Math::mul_div(burned_lp_coins_val, x_reserve_val, lp_coins_total);
        let y_to_return_val = Math::mul_div(burned_lp_coins_val, y_reserve_val, lp_coins_total);
        assert!(x_to_return_val > 0 && y_to_return_val > 0, Errors::invalid_argument(ERR_INCORRECT_BURN_VALUES));

        // Withdraw those values from reserves
        let x_coin_to_return = Coin::extract(&mut pool.coin_x_reserve, x_to_return_val);
        let y_coin_to_return = Coin::extract(&mut pool.coin_y_reserve, y_to_return_val);

        // Update price and burn provided lp coins
        update_oracle<X, Y, LP>(pool, pool_addr, x_reserve_val - x_to_return_val, y_reserve_val - y_to_return_val);
        Coin::burn(lp_coins, &pool.lp_burn_cap);

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        Event::emit_event(
            &mut events_store.liquidity_removed_handle,
            LiquidityRemovedEvent<X, Y, LP>{
                returned_x_val: x_to_return_val,
                returned_y_val: y_to_return_val,
                lp_tokens_burned: burned_lp_coins_val
            });

        (x_coin_to_return, y_coin_to_return)
    }

    /// Swap coins (can swap both x and y in the same time).
    /// In the most of situation only X or Y coin argument has value (similar with *_out, only one _out will be non-zero).
    /// Because an user usually exchanges only one coin, yet function allow to exchange both coin.
    /// * `x_in` - X coins to swap.
    /// * `x_out` - expected amount of X coins to get out.
    /// * `y_in` - Y coins to swap.
    /// * `y_out` - expected amount of Y coins to get out.
    /// Returns - both exchanged X and Y coins.
    public fun swap<X, Y, LP>(
        pool_addr: address,
        x_in: Coin<X>,
        x_out: u64,
        y_in: Coin<Y>,
        y_out: u64
    ): (Coin<X>, Coin<Y>) acquires LiquidityPool, EventsStore {
        assert!(exists<LiquidityPool<X, Y, LP>>(pool_addr), Errors::not_published(ERR_POOL_DOES_NOT_EXIST));

        let x_in_val = Coin::value(&x_in);
        let y_in_val = Coin::value(&y_in);

        assert!(x_in_val > 0 || y_in_val > 0, Errors::invalid_argument(ERR_EMPTY_COIN_IN));

        let (x_reserve_size, y_reserve_size) = get_reserves_size<X, Y, LP>(pool_addr);
        let pool = borrow_global_mut<LiquidityPool<X, Y, LP>>(pool_addr);

        // Deposit new coins to liquidity pool.
        Coin::merge(&mut pool.coin_x_reserve, x_in);
        Coin::merge(&mut pool.coin_y_reserve, y_in);

        // Withdraw expected amount from reserves.
        let x_swapped = Coin::extract(&mut pool.coin_x_reserve, x_out);
        let y_swapped = Coin::extract(&mut pool.coin_y_reserve, y_out);

        // Get new reserves.
        let x_reserve_size_new = Coin::value(&pool.coin_x_reserve);
        let y_reserve_size_new = Coin::value(&pool.coin_y_reserve);

        // Confirm that lp_value for the pool hasn't been reduced.
        // For that, we compute lp_value with old reserves and lp_value with reserves after swap is done,
        // and make sure lp_value doesn't decrease.

        // x_res_after_fee = x_reserve_new - x_in_value * 0.003
        // (all of it scaled to 1000 to be able to achieve this math in integers)
        let x_res_new_after_fee = Math::mul_to_u128(x_reserve_size_new, FEE_SCALE)
                                  - Math::mul_to_u128(x_in_val, FEE_MULTIPLIER);

        let y_res_new_after_fee = Math::mul_to_u128(y_reserve_size_new, FEE_SCALE)
                                  - Math::mul_to_u128(y_in_val, FEE_MULTIPLIER);

        let lp_value_before_swap = Math::mul_to_u128(x_reserve_size, y_reserve_size);
        lp_value_before_swap = lp_value_before_swap * 1000000;
        let lp_value_after_swap_and_fee = x_res_new_after_fee * y_res_new_after_fee;
        assert!(
            lp_value_after_swap_and_fee >= (lp_value_before_swap as u128),
            Errors::invalid_state(ERR_INCORRECT_SWAP),
        );

        update_oracle<X, Y, LP>(pool, pool_addr, x_reserve_size, y_reserve_size);

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        Event::emit_event(
            &mut events_store.swap_handle,
            SwapEvent<X, Y, LP>{
                x_in: x_in_val,
                y_in: y_in_val,
                x_out,
                y_out,
            });

        // Return swapped amount.
        (x_swapped, y_swapped)
    }

    /// Update current cumulative prices.
    /// * `pool` - Liquidity pool to update prices.
    /// * `x_reserve` - coin X reserves.
    /// * `y_reserve` - coin Y reserves.
    fun update_oracle<X, Y, LP>(
        pool: &mut LiquidityPool<X, Y, LP>,
        pool_addr: address,
        x_reserve: u64,
        y_reserve: u64
    ) acquires EventsStore {
        let last_block_timestamp = pool.last_block_timestamp;

        let block_timestamp = Timestamp::now_seconds() % (1u64 << 32);

        let time_elapsed = ((block_timestamp - last_block_timestamp) as u128);

        if (time_elapsed > 0 && x_reserve != 0 && y_reserve != 0) {
            // If we are not in the same block.
            // Uniswap is using the following library https://github.com/Uniswap/v2-core/blob/master/contracts/libraries/UQ112x112.sol
            // And doing it so - https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol#L77.
            let last_price_x_cumulative = UQ64x64::to_u128(UQ64x64::div(UQ64x64::encode(y_reserve), x_reserve)) * time_elapsed;
            let last_price_y_cumulative = UQ64x64::to_u128(UQ64x64::div(UQ64x64::encode(x_reserve), y_reserve)) * time_elapsed;

            pool.last_price_x_cumulative = *&pool.last_price_x_cumulative + last_price_x_cumulative;
            pool.last_price_y_cumulative = *&pool.last_price_y_cumulative + last_price_y_cumulative;
        };

        pool.last_block_timestamp = block_timestamp;

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        Event::emit_event(
            &mut events_store.oracle_updated_handle,
            OracleUpdatedEvent<X, Y, LP>{
                last_price_x_cumulative: pool.last_price_x_cumulative,
                last_price_y_cumulative: pool.last_price_y_cumulative,
            });
    }

    /// Get reserves of a pool.
    /// * `pool_addr` - pool owner address.
    /// Returns both (X, Y) reserves.
    public fun get_reserves_size<X, Y, LP>(pool_addr: address): (u64, u64)
    acquires LiquidityPool {
        assert!(CoinHelper::is_sorted<X, Y>(), Errors::invalid_argument(ERR_WRONG_PAIR_ORDERING));
        assert!(exists<LiquidityPool<X, Y, LP>>(pool_addr), Errors::not_published(ERR_POOL_DOES_NOT_EXIST));

        let liquidity_pool = borrow_global<LiquidityPool<X, Y, LP>>(pool_addr);
        let x_reserve = Coin::value(&liquidity_pool.coin_x_reserve);
        let y_reserve = Coin::value(&liquidity_pool.coin_y_reserve);

        (x_reserve, y_reserve)
    }

    /// Get current cumilative prices.
    /// * pool_addr - pool owner address.
    /// Returns (X price, Y price, block_timestamp).
    public fun get_cumulative_prices<X, Y, LP>(pool_addr: address): (u128, u128, u64)
    acquires LiquidityPool {
        assert!(CoinHelper::is_sorted<X, Y>(), Errors::invalid_argument(ERR_WRONG_PAIR_ORDERING));
        assert!(exists<LiquidityPool<X, Y, LP>>(pool_addr), Errors::not_published(ERR_POOL_DOES_NOT_EXIST));

        let liquidity_pool = borrow_global<LiquidityPool<X, Y, LP>>(pool_addr);
        let last_price_x_cumulative = *&liquidity_pool.last_price_x_cumulative;
        let last_price_y_cumulative = *&liquidity_pool.last_price_y_cumulative;
        let last_block_timestamp = liquidity_pool.last_block_timestamp;

        (last_price_x_cumulative, last_price_y_cumulative, last_block_timestamp)
    }

    /// Check if lp exists at address
    /// * pool_addr - pool owner address.
    public fun pool_exists_at<X, Y, LP>(pool_addr: address): bool {
        exists<LiquidityPool<X, Y, LP>>(pool_addr)
    }

    /// Get fees numerator, denumerator.
    /// Returns (numerator, denumerator).
    public fun get_fees_config(): (u64, u64) {
        (FEE_MULTIPLIER, FEE_SCALE)
    }

    // Events
    struct EventsStore<phantom X, phantom Y, phantom LP> has key {
        pool_created_handle: Event::EventHandle<PoolCreatedEvent<X, Y, LP>>,
        liquidity_added_handle: Event::EventHandle<LiquidityAddedEvent<X, Y, LP>>,
        liquidity_removed_handle: Event::EventHandle<LiquidityRemovedEvent<X, Y, LP>>,
        swap_handle: Event::EventHandle<SwapEvent<X, Y, LP>>,
        oracle_updated_handle: Event::EventHandle<OracleUpdatedEvent<X, Y, LP>>
    }

    struct PoolCreatedEvent<phantom X, phantom Y, phantom LP> has drop, store {}

    struct LiquidityAddedEvent<phantom X, phantom Y, phantom LP> has drop, store {
        added_x_val: u64,
        added_y_val: u64,
        lp_tokens_received: u64,
    }

    struct LiquidityRemovedEvent<phantom X, phantom Y, phantom LP> has drop, store {
        returned_x_val: u64,
        returned_y_val: u64,
        lp_tokens_burned: u64,
    }

    struct SwapEvent<phantom X, phantom Y, phantom LP> has drop, store {
        x_in: u64,
        x_out: u64,
        y_in: u64,
        y_out: u64,
    }

    struct OracleUpdatedEvent<phantom X, phantom Y, phantom LP> has drop, store {
        last_price_x_cumulative: u128,
        last_price_y_cumulative: u128,
    }
}
