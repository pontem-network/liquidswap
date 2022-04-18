/// Liquidity pool.
module AptosSwap::LiquidityPool {
    use Std::Signer;
    use Std::U256::{U256, Self};

    use CoreFramework::Timestamp;

    use AptosSwap::Token::{Self, Token};
    use AptosSwap::Math;
    use AptosSwap::FixedPoint128;
    use AptosSwap::TokenSymbols;

    // Constants.
    /// LP token default decimals.
    const LP_TOKEN_DECIMALS: u8 = 9;

    /// Minimal liquidity.
    const MINIMAL_LIQUIDITY: u128 = 1000;

    /// Current fee is 0.3%
    const FEE_MULTIPLIER: u128 = 3;
    /// It's fee denumenator.
    const FEE_SCALE: u128 = 1000;

    // Error codes.
    /// When tokens used to create pair have wrong ordering.
    const ERR_WRONG_PAIR_ORDERING: u64 = 101;

    /// When provided LP token already has minted supply.
    const ERR_LP_TOKEN_NON_ZERO_TOTAL: u64 = 102;

    /// When pair already exists on account.
    const ERR_POOL_EXISTS_FOR_PAIR: u64 = 103;

    /// When not enough liquidity minted.
    const ERR_NOT_ENOUGH_INITIAL_LIQUIDITY: u64 = 1035;

    /// When not enough liquidity minted.
    const ERR_NOT_ENOUGH_LIQUIDITY: u64 = 104;

    /// When both X and Y provided for swap are equal zero.
    const ERR_EMPTY_TOKEN_IN: u64 = 105;

    /// When incorrect INs/OUTs arguments passed during swap and math doesn't work.
    const ERR_INCORRECT_SWAP: u64 = 106;

    /// Incorrect lp token burn values
    const ERR_INCORRECT_BURN_VALUES: u64 = 107;

    const ERR_POOL_DOES_NOT_EXIST: u64 = 108;

    // TODO: events.

    /// Liquidity pool with reserves.
    /// LP token should go outside of this module.
    /// Probably we only need mint capability?
    struct LiquidityPool<phantom X, phantom Y, phantom LP> has key, store {
        token_x_reserve: Token<X>,
        token_y_reserve: Token<Y>,
        last_block_timestamp: u64,
        last_price_x_cumulative: U256,
        last_price_y_cumulative: U256,
        lp_mint_cap: Token::MintCapability<LP>,
        lp_burn_cap: Token::BurnCapability<LP>,
    }

    /// Register liquidity pool (by pairs).
    public fun register<X: store, Y: store, LP>(
        owner: &signer,
        lp_mint_cap: Token::MintCapability<LP>,
        lp_burn_cap: Token::BurnCapability<LP>
    ) {
        Token::assert_is_token<X>();
        Token::assert_is_token<Y>();
        assert!(TokenSymbols::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);

        Token::assert_is_token<LP>();

        // TODO: check LP decimals.
        assert!(Token::total_supply<LP>() == 0, ERR_LP_TOKEN_NON_ZERO_TOTAL);

        let owner_addr = Signer::address_of(owner);
        assert!(!exists<LiquidityPool<X, Y, LP>>(owner_addr), ERR_POOL_EXISTS_FOR_PAIR);

        let pool = LiquidityPool<X, Y, LP>{
            token_x_reserve: Token::zero<X>(),
            token_y_reserve: Token::zero<Y>(),
            last_block_timestamp: 0,
            last_price_x_cumulative: U256::zero(),
            last_price_y_cumulative: U256::zero(),
            lp_mint_cap,
            lp_burn_cap,
        };
        move_to(owner, pool);
    }

    /// Mint new liquidity.
    /// * pool_addr - pool owner address.
    /// * token_x - token X to add to liquidity reserves.
    /// * token_x - token Y to add to liquidity reserves.
    public fun add_liquidity<X: store, Y: store, LP>(
        pool_addr: address,
        token_x: Token<X>,
        token_y: Token<Y>
    ): Token<LP> acquires LiquidityPool {
        assert!(exists<LiquidityPool<X, Y, LP>>(pool_addr), ERR_POOL_DOES_NOT_EXIST);

        let lp_tokens_total: u128 = Token::total_supply<LP>();

        let (x_reserve_size, y_reserve_size) = get_reserves_size<X, Y, LP>(pool_addr);

        let x_provided_val = Token::value<X>(&token_x);
        let y_provided_val = Token::value<Y>(&token_y);

        let provided_liquidity = if (lp_tokens_total == 0) {
            let initial_liquidity = Math::sqrt_u256(Math::mul_u128(x_provided_val, y_provided_val));
            assert!(initial_liquidity > MINIMAL_LIQUIDITY, ERR_NOT_ENOUGH_INITIAL_LIQUIDITY);
            initial_liquidity - MINIMAL_LIQUIDITY
        } else {
            // (x_provided / x_reserve) * lp_tokens_total
            let x_liquidity = Math::safe_mul_div_u128(x_provided_val, lp_tokens_total, x_reserve_size);
            let y_liquidity = Math::safe_mul_div_u128(y_provided_val, lp_tokens_total, y_reserve_size);

            if (x_liquidity < y_liquidity) {
                x_liquidity
            } else {
                y_liquidity
            }
        };
        assert!(provided_liquidity > 0, ERR_NOT_ENOUGH_LIQUIDITY);

        let pool = borrow_global_mut<LiquidityPool<X, Y, LP>>(pool_addr);
        Token::deposit(&mut pool.token_x_reserve, token_x);
        Token::deposit(&mut pool.token_y_reserve, token_y);

        let lp_tokens = Token::mint<LP>(provided_liquidity, &pool.lp_mint_cap);

        update_oracle<X, Y, LP>(pool, x_reserve_size, y_reserve_size);

        lp_tokens
    }

    /// Burn liquidity tokens (LP) and get back X and Y tokens from reserves.
    /// * pool_addr - pool owner address.
    /// * lp_tokens - LP tokens to burn.
    /// Return both `Token<X>` and `Token<Y>`.
    public fun burn_liquidity<X: store, Y: store, LP>(pool_addr: address, lp_tokens: Token<LP>): (Token<X>, Token<Y>)
    acquires LiquidityPool {
        assert!(exists<LiquidityPool<X, Y, LP>>(pool_addr), ERR_POOL_DOES_NOT_EXIST);

        let burned_lp_tokens_val = Token::value(&lp_tokens);
        let pool = borrow_global_mut<LiquidityPool<X, Y, LP>>(pool_addr);

        let lp_tokens_total = Token::total_supply<LP>();
        let x_reserve_val = Token::value(&pool.token_x_reserve);
        let y_reserve_val = Token::value(&pool.token_y_reserve);

        // Compute x, y token values for provided lp_tokens value
        let x_to_return_val = Math::safe_mul_div_u128(burned_lp_tokens_val, x_reserve_val, lp_tokens_total);
        let y_to_return_val = Math::safe_mul_div_u128(burned_lp_tokens_val, y_reserve_val, lp_tokens_total);
        assert!(x_to_return_val > 0 && y_to_return_val > 0, ERR_INCORRECT_BURN_VALUES);

        // Withdraw those values from reserves
        let x_token_to_return = Token::withdraw(&mut pool.token_x_reserve, x_to_return_val);
        let y_token_to_return = Token::withdraw(&mut pool.token_y_reserve, y_to_return_val);

        // Update price and burn provided lp tokens
        update_oracle<X, Y, LP>(pool, x_reserve_val - x_to_return_val, y_reserve_val - y_to_return_val);
        Token::burn(lp_tokens, &pool.lp_burn_cap);

        (x_token_to_return, y_token_to_return)
    }

    /// Swap tokens (can swap both x and y in the same time).
    /// In the most of situation only X or Y tokens argument has value (similar with *_out, only one _out will be non-zero).
    /// Because an user usually exchanges only one token, yet function allow to exchange both tokens.
    /// * x_in - X tokens to swap.
    /// * x_out - expected amount of X tokens to get out.
    /// * y_in - Y tokens to swap.
    /// * y_out - expected amount of Y tokens to get out.
    /// Returns - both exchanged X and Y token.
    public fun swap<X: store, Y: store, LP>(
        pool_addr: address,
        x_in: Token<X>,
        x_out: u128,
        y_in: Token<Y>,
        y_out: u128
    ): (Token<X>, Token<Y>) acquires LiquidityPool {
        assert!(exists<LiquidityPool<X, Y, LP>>(pool_addr), ERR_POOL_DOES_NOT_EXIST);

        let x_in_val = Token::value(&x_in);
        let y_in_val = Token::value(&y_in);

        assert!(x_in_val > 0 || y_in_val > 0, ERR_EMPTY_TOKEN_IN);

        let (x_reserve_size, y_reserve_size) = get_reserves_size<X, Y, LP>(pool_addr);
        let pool = borrow_global_mut<LiquidityPool<X, Y, LP>>(pool_addr);

        // Deposit new tokens to liquidity pool.
        Token::deposit(&mut pool.token_x_reserve, x_in);
        Token::deposit(&mut pool.token_y_reserve, y_in);

        // Withdraw expected amount from reserves.
        let x_swapped = Token::withdraw(&mut pool.token_x_reserve, x_out);
        let y_swapped = Token::withdraw(&mut pool.token_y_reserve, y_out);

        // Get new reserves.
        let x_reserve_size_new = Token::value(&pool.token_x_reserve);
        let y_reserve_size_new = Token::value(&pool.token_y_reserve);

        // Confirm that lp_value for the pool hasn't been reduced.
        // For that, we compute lp_value with old reserves and lp_value with reserves after swap is done,
        // and make sure lp_value doesn't decrease.

        // x_res_after_fee = x_reserve_new - x_in_value * 0.003
        // (all of it scaled to 1000 to be able to achieve this math in integers)
        let x_res_new_after_fee = x_reserve_size_new * FEE_SCALE - x_in_val * FEE_MULTIPLIER;
        let y_res_new_after_fee = y_reserve_size_new * FEE_SCALE - y_in_val * FEE_MULTIPLIER;

        let lp_value_before_swap = U256::mul(
            U256::from_u128(x_reserve_size),
            U256::from_u128(y_reserve_size * FEE_SCALE * FEE_SCALE)  // FEE_SCALE squared here to get to the same dim
        );
        let lp_value_after_swap_and_fee =
            U256::mul(U256::from_u128(x_res_new_after_fee), U256::from_u128(y_res_new_after_fee));
        // invariant: lp_value_after_swap_and_fee >= lp_value_before_swap
        let order = U256::compare(&lp_value_after_swap_and_fee, &lp_value_before_swap);
        assert!(order != Math::CONST_LESS_THAN(), ERR_INCORRECT_SWAP);

        update_oracle<X, Y, LP>(pool, x_reserve_size, y_reserve_size);

        // Return swapped amount.
        (x_swapped, y_swapped)
    }

    /// Update current cumulative prices.
    /// * pool - Liquidity pool to update prices.
    /// * x_reserve - token X reserves.
    /// * y_reserve - token Y reserves.
    fun update_oracle<X: store, Y: store, LP>(pool: &mut LiquidityPool<X, Y, LP>, x_reserve: u128, y_reserve: u128) {
        let last_block_timestamp = pool.last_block_timestamp;

        let block_timestamp = Timestamp::now_seconds() % (1u64 << 32);

        let time_elapsed: u64 = block_timestamp - last_block_timestamp;

        if (time_elapsed > 0 && x_reserve != 0 && y_reserve != 0) {
            // If we are not in the same block.
            // TODO: see if possible rewrite without FixedPoint128 and U256 (yet i'm really not sure, too big numbers).
            // Uniswap is using the following library https://github.com/Uniswap/v2-core/blob/master/contracts/libraries/UQ112x112.sol
            // And doing it so - https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol#L77.
            let last_price_x_cumulative = U256::mul(FixedPoint128::to_u256(FixedPoint128::div(FixedPoint128::encode(y_reserve), x_reserve)), U256::from_u64(time_elapsed));
            let last_price_y_cumulative = U256::mul(FixedPoint128::to_u256(FixedPoint128::div(FixedPoint128::encode(x_reserve), y_reserve)), U256::from_u64(time_elapsed));
            pool.last_price_x_cumulative = U256::add(*&pool.last_price_x_cumulative, last_price_x_cumulative);
            pool.last_price_y_cumulative = U256::add(*&pool.last_price_y_cumulative, last_price_y_cumulative);
        };

        pool.last_block_timestamp = block_timestamp;
    }

    /// Get reserves of a pool.
    /// * pool_addr - pool owner address.
    /// Returns both (X, Y) reserves.
    public fun get_reserves_size<X: store, Y: store, LP>(pool_addr: address): (u128, u128)
    acquires LiquidityPool {
        assert!(TokenSymbols::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, LP>>(pool_addr), ERR_POOL_DOES_NOT_EXIST);

        let liquidity_pool = borrow_global<LiquidityPool<X, Y, LP>>(pool_addr);
        let x_reserve = Token::value(&liquidity_pool.token_x_reserve);
        let y_reserve = Token::value(&liquidity_pool.token_y_reserve);

        (x_reserve, y_reserve)
    }

    /// Get current cumilative prices.
    /// * pool_addr - pool owner address.
    /// Returns (X price, Y price, block_timestamp).
    public fun get_cumulative_prices<X: store, Y: store, LP>(pool_addr: address): (U256, U256, u64)
    acquires LiquidityPool {
        assert!(TokenSymbols::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, LP>>(pool_addr), ERR_POOL_DOES_NOT_EXIST);

        let liquidity_pool = borrow_global<LiquidityPool<X, Y, LP>>(pool_addr);
        let last_price_x_cumulative = *&liquidity_pool.last_price_x_cumulative;
        let last_price_y_cumulative = *&liquidity_pool.last_price_y_cumulative;
        let last_block_timestamp = liquidity_pool.last_block_timestamp;

        (last_price_x_cumulative, last_price_y_cumulative, last_block_timestamp)
    }

    /// Check if lp exists at address
    /// * pool_addr - pool owner address.
    public fun pool_exists_at<X: store, Y: store, LP>(pool_addr: address): bool {
        exists<LiquidityPool<X, Y, LP>>(pool_addr)
    }

    /// Get fees numerator, denumerator.
    /// Returns (numerator, denumerator).
    public fun get_fees_config(): (u128, u128) {
        (FEE_MULTIPLIER, FEE_SCALE)
    }
}
