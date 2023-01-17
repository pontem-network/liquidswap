/// Liquidswap liquidity pool module.
/// Implements mint/burn liquidity, swap of coins.
module liquidswap::liquidity_pool {
    use std::signer;

    use aptos_std::event;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;

    use liquidswap_lp::lp_coin::LP;
    use u256::u256;
    use uq64x64::uq64x64;

    use liquidswap::coin_helper;
    use liquidswap::curves;
    use liquidswap::dao_storage;
    use liquidswap::emergency::{Self, assert_no_emergency};
    use liquidswap::global_config;
    use liquidswap::lp_account;
    use liquidswap::math;
    use liquidswap::stable_curve;

    // Error codes.

    /// When coins used to create pair have wrong ordering.
    const ERR_WRONG_PAIR_ORDERING: u64 = 100;

    /// When pair already exists on account.
    const ERR_POOL_EXISTS_FOR_PAIR: u64 = 101;

    /// When not enough liquidity minted.
    const ERR_NOT_ENOUGH_INITIAL_LIQUIDITY: u64 = 102;

    /// When not enough liquidity minted.
    const ERR_NOT_ENOUGH_LIQUIDITY: u64 = 103;

    /// When both X and Y provided for swap are equal zero.
    const ERR_EMPTY_COIN_IN: u64 = 104;

    /// When incorrect INs/OUTs arguments passed during swap and math doesn't work.
    const ERR_INCORRECT_SWAP: u64 = 105;

    /// Incorrect lp coin burn values
    const ERR_INCORRECT_BURN_VALUES: u64 = 106;

    /// When pool doesn't exists for pair.
    const ERR_POOL_DOES_NOT_EXIST: u64 = 107;

    /// Should never occur.
    const ERR_UNREACHABLE: u64 = 108;

    /// When `initialize()` transaction is signed with any account other than @liquidswap.
    const ERR_NOT_ENOUGH_PERMISSIONS_TO_INITIALIZE: u64 = 109;

    /// When both X and Y provided for flashloan are equal zero.
    const ERR_EMPTY_COIN_LOAN: u64 = 110;

    /// When pool is locked.
    const ERR_POOL_IS_LOCKED: u64 = 111;

    /// When user is not admin
    const ERR_NOT_ADMIN: u64 = 112;

    // Constants.

    /// Minimal liquidity.
    const MINIMAL_LIQUIDITY: u64 = 1000;

    /// Denominator to handle decimal points for fees.
    const FEE_SCALE: u64 = 10000;

    /// Denominator to handle decimal points for dao fee.
    const DAO_FEE_SCALE: u64 = 100;

    // Public functions.

    /// Liquidity pool with reserves.
    struct LiquidityPool<phantom X, phantom Y, phantom Curve> has key {
        coin_x_reserve: Coin<X>,
        coin_y_reserve: Coin<Y>,
        last_block_timestamp: u64,
        last_price_x_cumulative: u128,
        last_price_y_cumulative: u128,
        lp_mint_cap: coin::MintCapability<LP<X, Y, Curve>>,
        lp_burn_cap: coin::BurnCapability<LP<X, Y, Curve>>,
        // Scales are pow(10, token_decimals).
        x_scale: u64,
        y_scale: u64,
        locked: bool,
        fee: u64,           // 1 - 100 (0.01% - 1%)
        dao_fee: u64,       // 0 - 100 (0% - 100%)
    }

    /// Flash loan resource.
    /// There is no way in Move to pass calldata and make dynamic calls, but a resource can be used for this purpose.
    /// To make the execution into a single transaction, the flash loan function must return a resource
    /// that cannot be copied, cannot be saved, cannot be dropped, or cloned.
    struct Flashloan<phantom X, phantom Y, phantom Curve> {
        x_loan: u64,
        y_loan: u64
    }

    /// Stores resource account signer capability under Liquidswap account.
    struct PoolAccountCapability has key { signer_cap: SignerCapability }

    /// Initializes Liquidswap contracts.
    public entry fun initialize(liquidswap_admin: &signer) {
        assert!(signer::address_of(liquidswap_admin) == @liquidswap, ERR_NOT_ENOUGH_PERMISSIONS_TO_INITIALIZE);

        let signer_cap = lp_account::retrieve_signer_cap(liquidswap_admin);
        move_to(liquidswap_admin, PoolAccountCapability { signer_cap });

        global_config::initialize(liquidswap_admin);
        emergency::initialize(liquidswap_admin);
    }

    /// Register liquidity pool `X`/`Y`.
    public fun register<X, Y, Curve>(acc: &signer) acquires PoolAccountCapability {
        assert_no_emergency();

        coin_helper::assert_is_coin<X>();
        coin_helper::assert_is_coin<Y>();
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);

        curves::assert_valid_curve<Curve>();
        assert!(!exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_EXISTS_FOR_PAIR);

        let pool_cap = borrow_global<PoolAccountCapability>(@liquidswap);
        let pool_account = account::create_signer_with_capability(&pool_cap.signer_cap);

        let (lp_name, lp_symbol) = coin_helper::generate_lp_name_and_symbol<X, Y, Curve>();
        let (lp_burn_cap, lp_freeze_cap, lp_mint_cap) =
            coin::initialize<LP<X, Y, Curve>>(
                &pool_account,
                lp_name,
                lp_symbol,
                6,
                true
            );
        coin::destroy_freeze_cap(lp_freeze_cap);

        let x_scale = 0;
        let y_scale = 0;

        if (curves::is_stable<Curve>()) {
            x_scale = math::pow_10(coin::decimals<X>());
            y_scale = math::pow_10(coin::decimals<Y>());
        };

        let pool = LiquidityPool<X, Y, Curve> {
            coin_x_reserve: coin::zero<X>(),
            coin_y_reserve: coin::zero<Y>(),
            last_block_timestamp: 0,
            last_price_x_cumulative: 0,
            last_price_y_cumulative: 0,
            lp_mint_cap,
            lp_burn_cap,
            x_scale,
            y_scale,
            locked: false,
            fee: global_config::get_default_fee<Curve>(),
            dao_fee: global_config::get_default_dao_fee(),
        };
        move_to(&pool_account, pool);

        dao_storage::register<X, Y, Curve>(&pool_account);

        let events_store = EventsStore<X, Y, Curve> {
            pool_created_handle: account::new_event_handle(&pool_account),
            liquidity_added_handle: account::new_event_handle(&pool_account),
            liquidity_removed_handle: account::new_event_handle(&pool_account),
            swap_handle: account::new_event_handle(&pool_account),
            flashloan_handle: account::new_event_handle(&pool_account),
            oracle_updated_handle: account::new_event_handle(&pool_account),
            update_fee_handle: account::new_event_handle(&pool_account),
            update_dao_fee_handle: account::new_event_handle(&pool_account),
        };
        event::emit_event(
            &mut events_store.pool_created_handle,
            PoolCreatedEvent<X, Y, Curve> {
                creator: signer::address_of(acc)
            },
        );
        move_to(&pool_account, events_store);
    }

    /// Mint new liquidity coins.
    /// * `coin_x` - coin X to add to liquidity reserves.
    /// * `coin_y` - coin Y to add to liquidity reserves.
    /// Returns LP coins: `Coin<LP<X, Y, Curve>>`.
    public fun mint<X, Y, Curve>(coin_x: Coin<X>, coin_y: Coin<Y>): Coin<LP<X, Y, Curve>>
    acquires LiquidityPool, EventsStore {
        assert_no_emergency();

        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        assert_pool_unlocked<X, Y, Curve>();

        let lp_coins_total = coin_helper::supply<LP<X, Y, Curve>>();

        let pool = borrow_global_mut<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        let x_reserve_size = coin::value(&pool.coin_x_reserve);
        let y_reserve_size = coin::value(&pool.coin_y_reserve);

        let x_provided_val = coin::value<X>(&coin_x);
        let y_provided_val = coin::value<Y>(&coin_y);

        let provided_liq = if (lp_coins_total == 0) {
            let initial_liq = math::sqrt(math::mul_to_u128(x_provided_val, y_provided_val));
            assert!(initial_liq > MINIMAL_LIQUIDITY, ERR_NOT_ENOUGH_INITIAL_LIQUIDITY);
            initial_liq - MINIMAL_LIQUIDITY
        } else {
            let x_liq = math::mul_div_u128((x_provided_val as u128), lp_coins_total, (x_reserve_size as u128));
            let y_liq = math::mul_div_u128((y_provided_val as u128), lp_coins_total, (y_reserve_size as u128));
            if (x_liq < y_liq) {
                x_liq
            } else {
                y_liq
            }
        };
        assert!(provided_liq > 0, ERR_NOT_ENOUGH_LIQUIDITY);

        coin::merge(&mut pool.coin_x_reserve, coin_x);
        coin::merge(&mut pool.coin_y_reserve, coin_y);

        let lp_coins = coin::mint<LP<X, Y, Curve>>(provided_liq, &pool.lp_mint_cap);

        update_oracle<X, Y, Curve>(pool, x_reserve_size, y_reserve_size);

        let events_store = borrow_global_mut<EventsStore<X, Y, Curve>>(@liquidswap_pool_account);
        event::emit_event(
            &mut events_store.liquidity_added_handle,
            LiquidityAddedEvent<X, Y, Curve> {
                added_x_val: x_provided_val,
                added_y_val: y_provided_val,
                lp_tokens_received: provided_liq
            });

        lp_coins
    }

    /// Burn liquidity coins (LP) and get back X and Y coins from reserves.
    /// * `lp_coins` - LP coins to burn.
    /// Returns both X and Y coins - `(Coin<X>, Coin<Y>)`.
    public fun burn<X, Y, Curve>(lp_coins: Coin<LP<X, Y, Curve>>): (Coin<X>, Coin<Y>)
    acquires LiquidityPool, EventsStore {
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        assert_pool_unlocked<X, Y, Curve>();

        let burned_lp_coins_val = coin::value(&lp_coins);

        let pool = borrow_global_mut<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);

        let lp_coins_total = coin_helper::supply<LP<X, Y, Curve>>();
        let x_reserve_val = coin::value(&pool.coin_x_reserve);
        let y_reserve_val = coin::value(&pool.coin_y_reserve);

        // Compute x, y coin values for provided lp_coins value
        let x_to_return_val = math::mul_div_u128((burned_lp_coins_val as u128), (x_reserve_val as u128), lp_coins_total);
        let y_to_return_val = math::mul_div_u128((burned_lp_coins_val as u128), (y_reserve_val as u128), lp_coins_total);
        assert!(x_to_return_val > 0 && y_to_return_val > 0, ERR_INCORRECT_BURN_VALUES);

        // Withdraw those values from reserves
        let x_coin_to_return = coin::extract(&mut pool.coin_x_reserve, x_to_return_val);
        let y_coin_to_return = coin::extract(&mut pool.coin_y_reserve, y_to_return_val);

        update_oracle<X, Y, Curve>(pool, x_reserve_val, y_reserve_val);
        coin::burn(lp_coins, &pool.lp_burn_cap);

        let events_store = borrow_global_mut<EventsStore<X, Y, Curve>>(@liquidswap_pool_account);
        event::emit_event(
            &mut events_store.liquidity_removed_handle,
            LiquidityRemovedEvent<X, Y, Curve> {
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
    /// Returns both exchanged X and Y coins: `(Coin<X>, Coin<Y>)`.
    public fun swap<X, Y, Curve>(
        x_in: Coin<X>,
        x_out: u64,
        y_in: Coin<Y>,
        y_out: u64
    ): (Coin<X>, Coin<Y>) acquires LiquidityPool, EventsStore {
        assert_no_emergency();

        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        assert_pool_unlocked<X, Y, Curve>();

        let x_in_val = coin::value(&x_in);
        let y_in_val = coin::value(&y_in);

        assert!(x_in_val > 0 || y_in_val > 0, ERR_EMPTY_COIN_IN);

        let pool = borrow_global_mut<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        let x_reserve_size = coin::value(&pool.coin_x_reserve);
        let y_reserve_size = coin::value(&pool.coin_y_reserve);

        // Deposit new coins to liquidity pool.
        coin::merge(&mut pool.coin_x_reserve, x_in);
        coin::merge(&mut pool.coin_y_reserve, y_in);

        // Withdraw expected amount from reserves.
        let x_swapped = coin::extract(&mut pool.coin_x_reserve, x_out);
        let y_swapped = coin::extract(&mut pool.coin_y_reserve, y_out);

        // Confirm that lp_value for the pool hasn't been reduced.
        // For that, we compute lp_value with old reserves and lp_value with reserves after swap is done,
        // and make sure lp_value doesn't decrease
        let (x_res_new_after_fee, y_res_new_after_fee) =
            new_reserves_after_fees_scaled<Curve>(
                coin::value(&pool.coin_x_reserve),
                coin::value(&pool.coin_y_reserve),
                x_in_val,
                y_in_val,
                pool.fee
            );
        assert_lp_value_is_increased<Curve>(
            pool.x_scale,
            pool.y_scale,
            (x_reserve_size as u128),
            (y_reserve_size as u128),
            (x_res_new_after_fee as u128),
            (y_res_new_after_fee as u128),
        );

        split_fee_to_dao(pool, x_in_val, y_in_val);

        update_oracle<X, Y, Curve>(pool, x_reserve_size, y_reserve_size);

        let events_store = borrow_global_mut<EventsStore<X, Y, Curve>>(@liquidswap_pool_account);
        event::emit_event(
            &mut events_store.swap_handle,
            SwapEvent<X, Y, Curve> {
                x_in: x_in_val,
                y_in: y_in_val,
                x_out,
                y_out,
            });

        // Return swapped amount.
        (x_swapped, y_swapped)
    }

    /// Get flash loan coins.
    /// In the most of situation only X or Y coin argument has value.
    /// Because an user usually loans only one coin, yet function allow to loans both coin.
    /// * `x_loan` - expected amount of X coins to loan.
    /// * `y_loan` - expected amount of Y coins to loan.
    /// Returns both loaned X and Y coins: `(Coin<X>, Coin<Y>, Flashloan<X, Y>)`.
    public fun flashloan<X, Y, Curve>(x_loan: u64, y_loan: u64): (Coin<X>, Coin<Y>, Flashloan<X, Y, Curve>)
    acquires LiquidityPool, EventsStore {
        assert_no_emergency();

        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        assert_pool_unlocked<X, Y, Curve>();

        assert!(x_loan > 0 || y_loan > 0, ERR_EMPTY_COIN_LOAN);

        let pool = borrow_global_mut<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);

        let reserve_x = coin::value(&pool.coin_x_reserve);
        let reserve_y = coin::value(&pool.coin_y_reserve);

        // Withdraw expected amount from reserves.
        let x_loaned = coin::extract(&mut pool.coin_x_reserve, x_loan);
        let y_loaned = coin::extract(&mut pool.coin_y_reserve, y_loan);

        // The pool will be locked after the loan until payment.
        pool.locked = true;

        update_oracle(pool, reserve_x, reserve_y);

        // Return loaned amount.
        (x_loaned, y_loaned, Flashloan<X, Y, Curve> { x_loan, y_loan })
    }

    /// Pay flash loan coins.
    /// In the most of situation only X or Y coin argument has value.
    /// Because an user usually loans only one coin, yet function allow to loans both coin.
    /// * `x_in` - X coins to pay.
    /// * `y_in` - Y coins to pay.
    /// * `loan` - data about flashloan.
    public fun pay_flashloan<X, Y, Curve>(
        x_in: Coin<X>,
        y_in: Coin<Y>,
        loan: Flashloan<X, Y, Curve>
    ) acquires LiquidityPool, EventsStore {
        assert_no_emergency();

        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        let Flashloan { x_loan, y_loan } = loan;

        let x_in_val = coin::value(&x_in);
        let y_in_val = coin::value(&y_in);

        assert!(x_in_val > 0 || y_in_val > 0, ERR_EMPTY_COIN_IN);

        let pool = borrow_global_mut<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);

        let x_reserve_size = coin::value(&pool.coin_x_reserve);
        let y_reserve_size = coin::value(&pool.coin_y_reserve);

        // Reserve sizes before loan out
        x_reserve_size = x_reserve_size + x_loan;
        y_reserve_size = y_reserve_size + y_loan;

        // Deposit new coins to liquidity pool.
        coin::merge(&mut pool.coin_x_reserve, x_in);
        coin::merge(&mut pool.coin_y_reserve, y_in);

        // Confirm that lp_value for the pool hasn't been reduced.
        // For that, we compute lp_value with old reserves and lp_value with reserves after swap is done,
        // and make sure lp_value doesn't decrease
        let (x_res_new_after_fee, y_res_new_after_fee) =
            new_reserves_after_fees_scaled<Curve>(
                coin::value(&pool.coin_x_reserve),
                coin::value(&pool.coin_y_reserve),
                x_in_val,
                y_in_val,
                pool.fee,
            );
        assert_lp_value_is_increased<Curve>(
            pool.x_scale,
            pool.y_scale,
            (x_reserve_size as u128),
            (y_reserve_size as u128),
            x_res_new_after_fee,
            y_res_new_after_fee,
        );
        // third of all fees goes into DAO
        split_fee_to_dao(pool, x_in_val, y_in_val);

        // As we are in same block, don't need to update oracle, it's already updated during flashloan initalization.

        // The pool will be unlocked after payment.
        pool.locked = false;

        let events_store = borrow_global_mut<EventsStore<X, Y, Curve>>(@liquidswap_pool_account);
        event::emit_event(
            &mut events_store.flashloan_handle,
            FlashloanEvent<X, Y, Curve> {
                x_in: x_in_val,
                x_out: x_loan,
                y_in: y_in_val,
                y_out: y_loan,
            });
    }

    // Private functions.

    /// Get reserves after fees.
    /// * `x_reserve` - reserve X.
    /// * `y_reserve` - reserve Y.
    /// * `x_in_val` - amount of X coins added to reserves.
    /// * `y_in_val` - amount of Y coins added to reserves.
    /// * `fee` - amount of fee.
    /// Returns both X and Y reserves after fees.
    fun new_reserves_after_fees_scaled<Curve>(
        x_reserve: u64,
        y_reserve: u64,
        x_in_val: u64,
        y_in_val: u64,
        fee: u64,
    ): (u128, u128) {
        let x_res_new_after_fee = if (curves::is_uncorrelated<Curve>()) {
            math::mul_to_u128(x_reserve, FEE_SCALE) - math::mul_to_u128(x_in_val, fee)
        } else if (curves::is_stable<Curve>()) {
            ((x_reserve - math::mul_div(x_in_val, fee, FEE_SCALE)) as u128)
        } else {
            abort ERR_UNREACHABLE
        };

        let y_res_new_after_fee = if (curves::is_uncorrelated<Curve>()) {
            math::mul_to_u128(y_reserve, FEE_SCALE) - math::mul_to_u128(y_in_val, fee)
        } else if (curves::is_stable<Curve>()) {
            ((y_reserve - math::mul_div(y_in_val, fee, FEE_SCALE)) as u128)
        } else {
            abort ERR_UNREACHABLE
        };

        (x_res_new_after_fee, y_res_new_after_fee)
    }

    /// Depositing part of fees to DAO Storage.
    /// * `pool` - pool to extract coins.
    /// * `x_in_val` - how much X coins was deposited to pool.
    /// * `y_in_val` - how much Y coins was deposited to pool.
    fun split_fee_to_dao<X, Y, Curve>(
        pool: &mut LiquidityPool<X, Y, Curve>,
        x_in_val: u64,
        y_in_val: u64
    ) {
        let fee_multiplier = pool.fee;
        let dao_fee = pool.dao_fee;
        // Split dao_fee_multiplier% of fee multiplier of provided coins to the DAOStorage
        let dao_fee_multiplier = if (fee_multiplier * dao_fee % DAO_FEE_SCALE != 0) {
            (fee_multiplier * dao_fee / DAO_FEE_SCALE) + 1
        } else {
            fee_multiplier * dao_fee / DAO_FEE_SCALE
        };
        let dao_x_fee_val = math::mul_div(x_in_val, dao_fee_multiplier, FEE_SCALE);
        let dao_y_fee_val = math::mul_div(y_in_val, dao_fee_multiplier, FEE_SCALE);

        let dao_x_in = coin::extract(&mut pool.coin_x_reserve, dao_x_fee_val);
        let dao_y_in = coin::extract(&mut pool.coin_y_reserve, dao_y_fee_val);
        dao_storage::deposit<X, Y, Curve>(@liquidswap_pool_account, dao_x_in, dao_y_in);
    }

    /// Compute and verify LP value after and before swap, in nutshell, _k function.
    /// * `x_scale` - 10 pow by X coin decimals.
    /// * `y_scale` - 10 pow by Y coin decimals.
    /// * `x_res` - X reserves before swap.
    /// * `y_res` - Y reserves before swap.
    /// * `x_res_with_fees` - X reserves after swap.
    /// * `y_res_with_fees` - Y reserves after swap.
    /// Aborts if swap can't be done.
    fun assert_lp_value_is_increased<Curve>(
        x_scale: u64,
        y_scale: u64,
        x_res: u128,
        y_res: u128,
        x_res_with_fees: u128,
        y_res_with_fees: u128,
    ) {
        if (curves::is_stable<Curve>()) {
            let lp_value_before_swap = stable_curve::lp_value(x_res, x_scale, y_res, y_scale);
            let lp_value_after_swap_and_fee = stable_curve::lp_value(x_res_with_fees, x_scale, y_res_with_fees, y_scale);

            let cmp = u256::compare(&lp_value_after_swap_and_fee, &lp_value_before_swap);
            assert!(cmp == 2, ERR_INCORRECT_SWAP);
        } else if (curves::is_uncorrelated<Curve>()) {
            let lp_value_before_swap = x_res * y_res;
            let lp_value_before_swap_u256 = u256::mul(
                u256::from_u128(lp_value_before_swap),
                u256::from_u64(FEE_SCALE * FEE_SCALE)
            );
            let lp_value_after_swap_and_fee = u256::mul(
                u256::from_u128(x_res_with_fees),
                u256::from_u128(y_res_with_fees),
            );

            let cmp = u256::compare(&lp_value_after_swap_and_fee, &lp_value_before_swap_u256);
            assert!(cmp == 2, ERR_INCORRECT_SWAP);
        } else {
            abort ERR_UNREACHABLE
        };
    }

    /// Update current cumulative prices.
    /// Important: If you want to use the following function take into account prices can be overflowed.
    /// So it's important to use same logic in your math/algo (as Move doesn't allow overflow). See math::overflow_add.
    /// * `pool` - Liquidity pool to update prices.
    /// * `x_reserve` - coin X reserves.
    /// * `y_reserve` - coin Y reserves.
    fun update_oracle<X, Y, Curve>(
        pool: &mut LiquidityPool<X, Y, Curve>,
        x_reserve: u64,
        y_reserve: u64
    ) acquires EventsStore {
        let last_block_timestamp = pool.last_block_timestamp;

        let block_timestamp = timestamp::now_seconds();

        let time_elapsed = ((block_timestamp - last_block_timestamp) as u128);

        if (time_elapsed > 0 && x_reserve != 0 && y_reserve != 0) {
            let last_price_x_cumulative = uq64x64::to_u128(uq64x64::fraction(y_reserve, x_reserve)) * time_elapsed;
            let last_price_y_cumulative = uq64x64::to_u128(uq64x64::fraction(x_reserve, y_reserve)) * time_elapsed;

            pool.last_price_x_cumulative = math::overflow_add(pool.last_price_x_cumulative, last_price_x_cumulative);
            pool.last_price_y_cumulative = math::overflow_add(pool.last_price_y_cumulative, last_price_y_cumulative);

            let events_store = borrow_global_mut<EventsStore<X, Y, Curve>>(@liquidswap_pool_account);
            event::emit_event(
                &mut events_store.oracle_updated_handle,
                OracleUpdatedEvent<X, Y, Curve> {
                    last_price_x_cumulative: pool.last_price_x_cumulative,
                    last_price_y_cumulative: pool.last_price_y_cumulative,
                });
        };

        pool.last_block_timestamp = block_timestamp;
    }

    /// Aborts if pool is locked.
    fun assert_pool_unlocked<X, Y, Curve>() acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        assert!(pool.locked == false, ERR_POOL_IS_LOCKED);
    }

    // Getters.

    /// Check if pool is locked.
    public fun is_pool_locked<X, Y, Curve>(): bool acquires LiquidityPool {
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        let pool = borrow_global<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        pool.locked
    }

    /// Get reserves of a pool.
    /// Returns both (X, Y) reserves.
    public fun get_reserves_size<X, Y, Curve>(): (u64, u64)
    acquires LiquidityPool {
        assert_no_emergency();

        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        assert_pool_unlocked<X, Y, Curve>();

        let liquidity_pool = borrow_global<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        let x_reserve = coin::value(&liquidity_pool.coin_x_reserve);
        let y_reserve = coin::value(&liquidity_pool.coin_y_reserve);

        (x_reserve, y_reserve)
    }

    /// Get current cumulative prices.
    /// Cumulative prices can be overflowed, so take it into account before work with the following function.
    /// It's important to use same logic in your math/algo (as Move doesn't allow overflow).
    /// Returns (X price, Y price, block_timestamp).
    public fun get_cumulative_prices<X, Y, Curve>(): (u128, u128, u64)
    acquires LiquidityPool {
        assert_no_emergency();

        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        assert_pool_unlocked<X, Y, Curve>();

        let liquidity_pool = borrow_global<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        let last_price_x_cumulative = *&liquidity_pool.last_price_x_cumulative;
        let last_price_y_cumulative = *&liquidity_pool.last_price_y_cumulative;
        let last_block_timestamp = liquidity_pool.last_block_timestamp;

        (last_price_x_cumulative, last_price_y_cumulative, last_block_timestamp)
    }

    /// Get decimals scales (10^X decimals, 10^Y decimals) for stable curve.
    /// For uncorrelated curve would return just zeros.
    public fun get_decimals_scales<X, Y, Curve>(): (u64, u64) acquires LiquidityPool {
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        let pool = borrow_global<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        (pool.x_scale, pool.y_scale)
    }

    /// Check if liquidity pool exists.
    public fun is_pool_exists<X, Y, Curve>(): bool {
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account)
    }

    /// Get fee for specific pool together with denominator (numerator, denominator).
    public fun get_fees_config<X, Y, Curve>(): (u64, u64) acquires LiquidityPool {
        (get_fee<X, Y, Curve>(), FEE_SCALE)
    }

    /// Get fee for specific pool.
    public fun get_fee<X, Y, Curve>(): u64 acquires LiquidityPool {
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        let pool = borrow_global<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        pool.fee
    }

    /// Set fee for specific pool.
    public entry fun set_fee<X, Y, Curve>(fee_admin: &signer, fee: u64) acquires LiquidityPool, EventsStore {
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);
        assert_pool_unlocked<X, Y, Curve>();
        assert!(signer::address_of(fee_admin) == global_config::get_fee_admin(), ERR_NOT_ADMIN);

        global_config::assert_valid_fee(fee);

        let pool = borrow_global_mut<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        pool.fee = fee;

        let events_store = borrow_global_mut<EventsStore<X, Y, Curve>>(@liquidswap_pool_account);
        event::emit_event(
            &mut events_store.update_fee_handle,
            UpdateFeeEvent<X, Y, Curve> { new_fee: fee }
        );
    }

    /// Get DAO fee for specific pool together with denominator (numerator, denominator).
    public fun get_dao_fees_config<X, Y, Curve>(): (u64, u64) acquires LiquidityPool {
        (get_dao_fee<X, Y, Curve>(), DAO_FEE_SCALE)
    }

    /// Get DAO fee for specific pool.
    public fun get_dao_fee<X, Y, Curve>(): u64 acquires LiquidityPool {
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        let pool = borrow_global<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        pool.dao_fee
    }

    /// Set DAO fee for specific pool.
    public entry fun set_dao_fee<X, Y, Curve>(fee_admin: &signer, dao_fee: u64) acquires LiquidityPool, EventsStore {
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);
        assert_pool_unlocked<X, Y, Curve>();
        assert!(signer::address_of(fee_admin) == global_config::get_fee_admin(), ERR_NOT_ADMIN);

        global_config::assert_valid_dao_fee(dao_fee);

        let pool = borrow_global_mut<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        pool.dao_fee = dao_fee;

        let events_store = borrow_global_mut<EventsStore<X, Y, Curve>>(@liquidswap_pool_account);
        event::emit_event(
            &mut events_store.update_dao_fee_handle,
            UpdateDAOFeeEvent<X, Y, Curve> { new_fee: dao_fee }
        );
    }

    // Events
    struct EventsStore<phantom X, phantom Y, phantom Curve> has key {
        pool_created_handle: event::EventHandle<PoolCreatedEvent<X, Y, Curve>>,
        liquidity_added_handle: event::EventHandle<LiquidityAddedEvent<X, Y, Curve>>,
        liquidity_removed_handle: event::EventHandle<LiquidityRemovedEvent<X, Y, Curve>>,
        swap_handle: event::EventHandle<SwapEvent<X, Y, Curve>>,
        flashloan_handle: event::EventHandle<FlashloanEvent<X, Y, Curve>>,
        oracle_updated_handle: event::EventHandle<OracleUpdatedEvent<X, Y, Curve>>,
        update_fee_handle: event::EventHandle<UpdateFeeEvent<X, Y, Curve>>,
        update_dao_fee_handle: event::EventHandle<UpdateDAOFeeEvent<X, Y, Curve>>,
    }

    struct PoolCreatedEvent<phantom X, phantom Y, phantom Curve> has drop, store {
        creator: address,
    }

    struct LiquidityAddedEvent<phantom X, phantom Y, phantom Curve> has drop, store {
        added_x_val: u64,
        added_y_val: u64,
        lp_tokens_received: u64,
    }

    struct LiquidityRemovedEvent<phantom X, phantom Y, phantom Curve> has drop, store {
        returned_x_val: u64,
        returned_y_val: u64,
        lp_tokens_burned: u64,
    }

    struct SwapEvent<phantom X, phantom Y, phantom Curve> has drop, store {
        x_in: u64,
        x_out: u64,
        y_in: u64,
        y_out: u64,
    }

    struct FlashloanEvent<phantom X, phantom Y, phantom Curve> has drop, store {
        x_in: u64,
        x_out: u64,
        y_in: u64,
        y_out: u64,
    }

    struct OracleUpdatedEvent<phantom X, phantom Y, phantom Curve> has drop, store {
        last_price_x_cumulative: u128,
        last_price_y_cumulative: u128,
    }

    struct UpdateFeeEvent<phantom X, phantom Y, phantom Curve> has drop, store {
        new_fee: u64,
    }

    struct UpdateDAOFeeEvent<phantom X, phantom Y, phantom Curve> has drop, store {
        new_fee: u64,
    }

    #[test_only]
    public fun compute_and_verify_lp_value_for_test<Curve>(
        x_scale: u64,
        y_scale: u64,
        x_res: u128,
        y_res: u128,
        x_res_new: u128,
        y_res_new: u128,
    ) {
        assert_lp_value_is_increased<Curve>(
            x_scale,
            y_scale,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        )
    }

    #[test_only]
    public fun update_cumulative_price_for_test<X, Y>(
        test_account: &signer,
        prev_last_block_timestamp: u64,
        prev_last_price_x_cumulative: u128,
        prev_last_price_y_cumulative: u128,
        x_reserve: u64,
        y_reserve: u64,
    ): (u128, u128, u64) acquires EventsStore, LiquidityPool, PoolAccountCapability {
        register<X, Y, curves::Uncorrelated>(test_account);

        let pool =
            borrow_global_mut<LiquidityPool<X, Y, curves::Uncorrelated>>(@liquidswap_pool_account);
        pool.last_block_timestamp = prev_last_block_timestamp;
        pool.last_price_x_cumulative = prev_last_price_x_cumulative;
        pool.last_price_y_cumulative = prev_last_price_y_cumulative;

        update_oracle(pool, x_reserve, y_reserve);

        (pool.last_price_x_cumulative, pool.last_price_y_cumulative, pool.last_block_timestamp)
    }
}
