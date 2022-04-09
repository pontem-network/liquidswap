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
    const ERR_AMOUNT_OUT_LESS_THAN_MIN: u64 = 108;

    /// Check liquidity pool exists at owner address.
    public fun pool_exists_at<X: store, Y: store, LP>(owner_addr: address) {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::pool_exists_at<X, Y, LP>(owner_addr);
        } else {
            LiquidityPool::pool_exists_at<Y, X, LP>(owner_addr);
        }
    }

    /// Register new liquidity pool.
    public fun register_liquidity_pool<X: store, Y: store, LP>(
        account: &signer,
        lp_token_mint_cap: Token::MintCapability<LP>,
        lp_token_burn_cap: Token::BurnCapability<LP>
    ) {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::register<X, Y, LP>(account, lp_token_mint_cap, lp_token_burn_cap);
        } else {
            LiquidityPool::register<Y, X, LP>(account, lp_token_mint_cap, lp_token_burn_cap);
        }
    }

    /// Add liquidity to pool using without rationality checks.
    /// Call `calc_required_liquidity` to get optimal amounts first, and only use returned amount for `token_x` and `token_y`.
    public fun add_liquidity_raw<X: store, Y: store, LP>(owner: address, token_x: Token<X>, token_y: Token<Y>): Token<LP> {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::add_liquidity<X, Y, LP>(owner, token_x, token_y)
        } else {
            LiquidityPool::add_liquidity<Y, X, LP>(owner, token_y, token_x)
        }
    }

    /// Add liquidity to pool with rationality checks.
    public fun add_liquidity<X: store, Y: store, LP>(
        owner_addr: address,
        token_x: Token<X>,
        amount_x_min: u128,
        token_y: Token<Y>,
        amount_y_min: u128
    ): Token<LP> {
        let value_x = Token::num(&token_x);
        let value_y = Token::num(&token_y);

        let (exp_amount_x, exp_amount_y) = calc_required_liquidity<X, Y, LP>(owner_addr, value_x, value_y, amount_x_min, amount_y_min);

        assert!(exp_amount_x == value_x && value_y == exp_amount_y, ERR_IRRATIONALLY);
        add_liquidity_raw<X, Y, LP>(owner_addr, token_x, token_y)
    }

    /// Burn liquidity and get token X and Y back.
    public fun remove_liquidity<X: store, Y: store, LP>(owner: address, lp_tokens: Token<LP>): (Token<X>, Token<Y>) {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::burn_liquidity<X, Y, LP>(owner, lp_tokens)
        } else {
            let (y, x) = LiquidityPool::burn_liquidity<Y, X, LP>(owner, lp_tokens);
            (x, y)
        }
    }

    /// Swap token X for token Y.
    /// * owner - pool owner address.
    /// * token_in - token X to swap.
    /// * amount_out_min - minimum amount of token Y to get out.
    public fun swap_exact_token_for_token<X: store, Y: store, LP>(
        owner_addr: address,
        token_in: Token<X>,
        minimum_token_out: u128
    ): Token<Y> {
        let (x_reserve_num, y_reserve_num) = get_reserves_size<X, Y, LP>(owner_addr);
        let (fee_mult, fee_scale) = LiquidityPool::get_fees_config();

        let token_in_num = Token::num(&token_in);
        let token_out_num = get_token_out_num(token_in_num, x_reserve_num, y_reserve_num);

        assert!(token_out_num >= minimum_token_out, ERR_AMOUNT_OUT_LESS_THAN_MIN);

        let (zero, token_out);
        if (TokenSymbols::is_sorted<X, Y>()) {
            (zero, token_out) = LiquidityPool::swap<X, Y, LP>(owner_addr, token_in, 0, Token::zero(), token_out_num);
        } else {
            (token_out, zero) = LiquidityPool::swap<Y, X, LP>(owner_addr, Token::zero(), token_out_num, token_in, 0);
        };
        Token::destroy_zero(zero);

        token_out
    }

    /// TODO: swap_token_for_exact_token? yet probably just script can solve it.

    /// Calculate amounts needed for adding new liquidity for both X and Y.
    public fun calc_required_liquidity<X: store, Y: store, LP>(
        owner: address,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128
    ): (u128, u128) {
        let (reserves_x, reserves_y) = get_reserves_size<X, Y, LP>(owner);

        if (reserves_x == 0 && reserves_y == 0) {
            return (amount_x_desired, amount_y_desired)
        } else {
            let amount_y_optimal = quote(amount_x_desired, reserves_x, reserves_y);
            if (amount_y_optimal <= amount_y_desired) {
                assert!(amount_y_optimal >= amount_y_min, ERR_INSUFFICIENT_Y_AMOUNT);
                return (amount_x_desired, amount_y_optimal)
            } else {
                let amount_x_optimal = quote(amount_y_desired, reserves_y, reserves_x);
                assert!(amount_x_optimal <= amount_x_desired, ERR_OVERLIMIT_X);
                assert!(amount_x_optimal >= amount_x_min, ERR_INSUFFICIENT_X_AMOUNT);
                return (amount_x_optimal, amount_y_desired)
            }
        }
    }

    /// Get reserves of liquidity pool.
    public fun get_reserves_size<X: store, Y: store, LP>(owner_addr: address): (u128, u128) {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::get_reserves_size<X, Y, LP>(owner_addr)
        } else {
            let (y_res, x_res) = LiquidityPool::get_reserves_size<Y, X, LP>(owner_addr)
            (x_res, y_res)
        }
    }

    /// Get current cumulative prices in liquidity pool.
    public fun get_cumulative_prices<X: store, Y: store, LP>(owner_addr: address): (U256, U256, u64) {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::get_cumulative_prices<X, Y, LP>(owner_addr)
        } else {
            let (y, x, t) = LiquidityPool::get_cumulative_prices<Y, X, LP>(owner_addr);
            (x, y, t)
        }
    }

    /// Get amount out by passing amount in. (include fees)
    /// * amount_in - exactly amount of tokens to swap.
    /// * reserve_in - reserves of token we are going to swap.
    /// * reserve_out - reserves of token we are going to get.
    public fun get_token_out_num(token_in_num: u128, reserve_in_num: u128, reserve_out_num: u128): u128 {
        let (fee_num, fee_scale) = LiquidityPool::get_fees_config();
        // 0.997 for 0.3% fee
        let fee_multiplier = fee_scale -fee_num;
        // x_in * 0.997 (scaled to 1000)
        let token_in_num_after_fees = token_in_num * fee_multiplier;
        // x_reserve size after adding amount_in (scaled to 1000)
        let new_reserves_in_num = reserve_in_num * fee_scale + token_in_num_after_fees; // Get new reserve in.
        // Multiply token_in by the current exchange rate
        // current_exchange_rate = reserve_out / reserve_in
        // amount_in * current_echange_rate -> amount_out
        SafeMath::safe_mul_div_u128(
            token_in_num,
            reserve_out_num, new_reserves_in_num)
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

    /// Return amount of liquidity need to for `amount_x`.
    public fun quote(amount_x: u128, reserves_x: u128, reserve_y: u128): u128 {
        assert!(amount_x > 0, ERR_WRONG_AMOUNT);
        assert!(reserves_x > 0 && reserve_y > 0, ERR_WRONG_RESERVE);

        SafeMath::safe_mul_div_u128(amount_x, reserve_y, reserves_x)
    }
}
