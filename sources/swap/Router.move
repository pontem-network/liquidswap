/// Router for Liquidity Pool.
/// Similar to Uniswap.
module AptosSwap::Router {
    use AptosSwap::Token::{Token, Self};
    use AptosSwap::SafeMath;
    use AptosSwap::TokenSymbols;
    use AptosSwap::LiquidityPool;
    use Std::U256::U256;

    // Errors.
    /// Wrong amount used.
    const ERR_WRONG_AMOUNT: u64 = 102;
    /// Wrong reserve used.
    const ERR_WRONG_RESERVE: u64 = 103;
    /// Insuficient amount in Y reserves.
    const ERR_INSUFFICIENT_Y_AMOUNT: u64 = 104;
    /// Insuficient amount in X reserves.
    const ERR_INSUFFICIENT_X_AMOUNT: u64 = 105;
    /// Overlimit of X tokens to swap.
    const ERR_OVERLIMIT_X: u64 = 106;
    /// Irrationally swap.
    const ERR_IRRATIONALLY: u64 = 107;
    /// Amount out less than minimum.
    const ERR_TOKEN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM: u64 = 108;

    /// Check liquidity pool exists at owner address.
    public fun pool_exists_at<X: store, Y: store, LP>(pool_addr: address) {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::pool_exists_at<X, Y, LP>(pool_addr);
        } else {
            LiquidityPool::pool_exists_at<Y, X, LP>(pool_addr);
        }
    }

    /// Register new liquidity pool.
    public fun register_liquidity_pool<X: store, Y: store, LP>(
        owner: &signer,
        lp_token_mint_cap: Token::MintCapability<LP>,
        lp_token_burn_cap: Token::BurnCapability<LP>
    ) {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::register<X, Y, LP>(owner, lp_token_mint_cap, lp_token_burn_cap);
        } else {
            LiquidityPool::register<Y, X, LP>(owner, lp_token_mint_cap, lp_token_burn_cap);
        }
    }

    /// Add liquidity to pool using without rationality checks.
    /// Call `calc_required_liquidity` to get optimal amounts first, and only use returned amount for `token_x` and `token_y`.
    public fun add_liquidity_inner<X: store, Y: store, LP>(pool_addr: address, token_x: Token<X>, token_y: Token<Y>): Token<LP> {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::add_liquidity<X, Y, LP>(pool_addr, token_x, token_y)
        } else {
            LiquidityPool::add_liquidity<Y, X, LP>(pool_addr, token_y, token_x)
        }
    }

    /// Add liquidity to pool with rationality checks.
    public fun add_liquidity<X: store, Y: store, LP>(
        pool_addr: address,
        token_x: Token<X>,
        min_token_x_val: u128,
        token_y: Token<Y>,
        min_token_y_val: u128
    ): (Token<X>, Token<Y>, Token<LP>) {
        let token_x_val = Token::value(&token_x);
        let token_y_val = Token::value(&token_y);

        let (optimal_x, optimal_y) =
            calc_optimal_token_values<X, Y, LP>(pool_addr, token_x_val, token_y_val, min_token_x_val, min_token_y_val);

        let (x_remainder, token_x_opt) = Token::split(token_x, optimal_x);
        let (y_remainder, token_y_opt) = Token::split(token_y, optimal_y);
        let lp_tokens = add_liquidity_inner<X, Y, LP>(pool_addr, token_x_opt, token_y_opt);

        (x_remainder, y_remainder, lp_tokens)
    }

    /// Burn liquidity and get token X and Y back.
    public fun remove_liquidity<X: store, Y: store, LP>(pool_addr: address, lp_tokens: Token<LP>): (Token<X>, Token<Y>) {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::burn_liquidity<X, Y, LP>(pool_addr, lp_tokens)
        } else {
            let (y, x) = LiquidityPool::burn_liquidity<Y, X, LP>(pool_addr, lp_tokens);
            (x, y)
        }
    }

    /// Swap token X for token Y.
    /// * owner - pool owner address.
    /// * token_in - token X to swap.
    /// * amount_out_min - minimum amount of token Y to get out.
    public fun swap_exact_token_for_token<X: store, Y: store, LP>(
        pool_addr: address,
        token_in: Token<X>,
        token_out_min_val: u128
    ): Token<Y> {
        let (x_reserve, y_reserve) = get_reserves_size<X, Y, LP>(pool_addr);

        let token_in_val = Token::value(&token_in);
        let token_out_val = get_token_out_with_fees(token_in_val, x_reserve, y_reserve);
        assert!(
            token_out_val >= token_out_min_val,
            ERR_TOKEN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM
        );

        let (zero, token_out);
        if (TokenSymbols::is_sorted<X, Y>()) {
            (zero, token_out) = LiquidityPool::swap<X, Y, LP>(pool_addr, token_in, 0, Token::zero(), token_out_val);
        } else {
            (token_out, zero) = LiquidityPool::swap<Y, X, LP>(pool_addr, Token::zero(), token_out_val, token_in, 0);
        };
        Token::destroy_zero(zero);

        token_out
    }

    /// TODO: swap_token_for_exact_token? yet probably just script can solve it.

    /// Calculate amounts needed for adding new liquidity for both X and Y.
    public fun calc_optimal_token_values<X: store, Y: store, LP>(
        pool_addr: address,
        x_desired: u128,
        y_desired: u128,
        x_min: u128,
        y_min: u128
    ): (u128, u128) {
        let (reserves_x, reserves_y) = get_reserves_size<X, Y, LP>(pool_addr);

        if (reserves_x == 0 && reserves_y == 0) {
            return (x_desired, y_desired)
        } else {
            let y_returned = convert_with_current_price(x_desired, reserves_x, reserves_y);
            if (y_returned <= y_desired) {
                assert!(y_returned >= y_min, ERR_INSUFFICIENT_Y_AMOUNT);
                return (x_desired, y_returned)
            } else {
                let x_returned = convert_with_current_price(y_desired, reserves_y, reserves_x);
                assert!(x_returned <= x_desired, ERR_OVERLIMIT_X);
                assert!(x_returned >= x_min, ERR_INSUFFICIENT_X_AMOUNT);
                return (x_returned, y_desired)
            }
        }
    }

    /// Get reserves of liquidity pool.
    public fun get_reserves_size<X: store, Y: store, LP>(pool_addr: address): (u128, u128) {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::get_reserves_size<X, Y, LP>(pool_addr)
        } else {
            let (y_res, x_res) = LiquidityPool::get_reserves_size<Y, X, LP>(pool_addr);
            (x_res, y_res)
        }
    }

    /// Get current cumulative prices in liquidity pool.
    public fun get_cumulative_prices<X: store, Y: store, LP>(pool_addr: address): (U256, U256, u64) {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::get_cumulative_prices<X, Y, LP>(pool_addr)
        } else {
            let (y, x, t) = LiquidityPool::get_cumulative_prices<Y, X, LP>(pool_addr);
            (x, y, t)
        }
    }

    /// Get amount out by passing amount in. (include fees)
    /// * amount_in - exactly amount of tokens to swap.
    /// * reserve_in - reserves of token we are going to swap.
    /// * reserve_out - reserves of token we are going to get.
    public fun get_token_out_with_fees(token_in_val: u128, reserve_in_size: u128, reserve_out_size: u128): u128 {
        let (fee_pct, fee_scale) = LiquidityPool::get_fees_config();
        // 0.997 for 0.3% fee
        let fee_multiplier = fee_scale - fee_pct;
        // x_in * 0.997 (scaled to 1000)
        let token_in_val_after_fees = token_in_val * fee_multiplier;
        // x_reserve size after adding amount_in (scaled to 1000)
        let new_reserves_in_size = reserve_in_size * fee_scale + token_in_val_after_fees; // Get new reserve in.
        // Multiply token_in by the current exchange rate:
        // current_exchange_rate = reserve_out / reserve_in
        // amount_in_after_fees * current_exchange_rate -> amount_out
        SafeMath::safe_mul_div_u128(
            token_in_val_after_fees,  // scaled to 1000
            reserve_out_size,
            new_reserves_in_size)  // scaled to 1000
    }

    /// Get amount in by amount out.
    /// * amount_out - exactly amount of tokens to get.
    /// * reserve_in - reserves of token we are going to swap.
    /// * reserve_out - reserves of token we are going to get.
    /// * fee_n - fee numerator.
    /// * fee_d - fee denumerator.
    public fun get_amount_in(amount_out: u128, reserve_out: u128, reserve_in: u128, fee_n: u128, fee_d: u128): u128 {
        // TODO: maybe check values for error codes in case?
        let amount = (reserve_out - amount_out) * (fee_d - fee_n);
        let new_reserves_out = reserve_out - amount;
        SafeMath::safe_mul_div_u128(amount_out * fee_d, reserve_in, new_reserves_out)
    }

    public fun current_price<X: store, Y: store, LP>(pool_addr: address): u128 {
        let (x_reserve, y_reserve) = get_reserves_size<X, Y, LP>(pool_addr);
        SafeMath::safe_mul_div_u128(1, x_reserve, y_reserve)
    }

    /// Return amount of liquidity need to for `amount_x`.
    public fun convert_with_current_price(amount_x: u128, reserves_x: u128, reserve_y: u128): u128 {
        assert!(amount_x > 0, ERR_WRONG_AMOUNT);
        assert!(reserves_x > 0 && reserve_y > 0, ERR_WRONG_RESERVE);

        // exchange_price = reserve_y / reserve_x
        // amount_y_returned = amount_x * exchange_price
        SafeMath::safe_mul_div_u128(amount_x, reserve_y, reserves_x)
    }
}
