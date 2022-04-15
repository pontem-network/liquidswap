/// Router for Liquidity Pool.
/// Similar to Uniswap.
module AptosSwap::Router {
    use Std::U256::U256;
    
    use AptosSwap::Token::{Token, Self};
    use AptosSwap::SafeMath;
    use AptosSwap::TokenSymbols;
    use AptosSwap::LiquidityPool;

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
    /// Needed amount in great than maximum.
    const ERR_TOKEN_VAL_MAX_LESS_THAN_NEEDED: u64 = 109;

    /// Check liquidity pool exists at owner address.
    /// * pool_addr - pool owner address.
    public fun pool_exists_at<X: store, Y: store, LP>(pool_addr: address): bool {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::pool_exists_at<X, Y, LP>(pool_addr)
        } else {
            LiquidityPool::pool_exists_at<Y, X, LP>(pool_addr)
        }
    }

    /// Register new liquidity pool on signer address.
    /// * lp_token_mint_cap - LP token mint capability.
    /// * lp_token_burn_cap - LP token burn capability.
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
    /// * pool_addr - pool owner address.
    /// * token_x - tokens X used to add liquidity.
    /// * token_y - tokens Y used to add liquidity.
    public fun add_liquidity_inner<X: store, Y: store, LP>(pool_addr: address, token_x: Token<X>, token_y: Token<Y>): Token<LP> {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::add_liquidity<X, Y, LP>(pool_addr, token_x, token_y)
        } else {
            LiquidityPool::add_liquidity<Y, X, LP>(pool_addr, token_y, token_x)
        }
    }

    /// Add liquidity to pool with rationality checks.
    /// * pool_addr - pool owner address.
    /// * token_x - token X to add as liquidity.
    /// * min_token_x_val - minimum amount of token X to add as liquidity (slippage).
    /// * token_y - token Y to add as liquidity.
    /// * min_token_y_val - minimum amount of token Y to add as liquidity (slippage).
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

    // TODO: we should check amount_min_x and amount_min_y for remove liquidity too (otherwise it could be attacked imho with frontrun).

    /// Burn liquidity and get token X and Y back.
    /// * pool_addr - pool owner address.
    /// * lp_tokens - LP tokens to burn.
    public fun remove_liquidity<X: store, Y: store, LP>(pool_addr: address, lp_tokens: Token<LP>): (Token<X>, Token<Y>) {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::burn_liquidity<X, Y, LP>(pool_addr, lp_tokens)
        } else {
            let (y, x) = LiquidityPool::burn_liquidity<Y, X, LP>(pool_addr, lp_tokens);
            (x, y)
        }
    }

    /// Swap token X for token Y.
    /// * pool_addr - pool owner address.
    /// * token_in - token X to swap.
    /// * token_out_min_val - minimum amount of token Y to get out.
    public fun swap_exact_token_for_token<X: store, Y: store, LP>(
        pool_addr: address,
        token_in: Token<X>,
        token_out_min_val: u128
    ): Token<Y> {
        let (x_reserve_size, y_reserve_size) = get_reserves_size<X, Y, LP>(pool_addr);

        let token_in_val = Token::value(&token_in);
        let token_out_val = get_token_out_with_fees(token_in_val, x_reserve_size, y_reserve_size);
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

    /// Swap max token amount X for exact token Y.
    /// * pool_addr - pool owner address.
    /// * token_max_in - maximum amount of token X to swap to get `token_out_val` of tokens Y.
    /// * token_out_val - exact amount of tokens Y to get.
    public fun swap_token_for_exact_token<X: store, Y: store, LP>(
        pool_addr: address,
        token_max_in: Token<X>,
        token_out_val: u128,
    ): (Token<X>, Token<Y>) {
        let (x_reserve_size, y_reserve_size) = get_reserves_size<X, Y, LP>(pool_addr);

        let token_x_val_needed = get_token_in_with_fees(token_out_val, y_reserve_size, x_reserve_size);

        let token_val_max = Token::value(&token_max_in);
        assert!(token_x_val_needed <= token_val_max, ERR_TOKEN_VAL_MAX_LESS_THAN_NEEDED);

        let (remainder, token_in) = Token::split(token_max_in, token_x_val_needed);
        

        let (zero, token_out);
        if (TokenSymbols::is_sorted<X, Y>()) {
            (zero, token_out) = LiquidityPool::swap<X, Y, LP>(pool_addr, token_in, 0, Token::zero(), token_out_val);
        } else {
            (token_out, zero) = LiquidityPool::swap<Y, X, LP>(pool_addr, Token::zero(), token_out_val, token_in, 0);
        };
        Token::destroy_zero(zero);

        (remainder, token_out)
    }

    /// Calculate amounts needed for adding new liquidity for both X and Y.
    /// * pool_addr - pool owner address.
    /// * x_desired - desired value of tokens X.
    /// * y_desired - desired value of tokens Y.
    /// * x_min - minimum of tokens X expected.
    /// * y_min - minimum of tokens Y expected.
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

    /// Get reserves of liquidity pool (X and Y).
    /// * pool_addr - pool owner address.
    public fun get_reserves_size<X: store, Y: store, LP>(pool_addr: address): (u128, u128) {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::get_reserves_size<X, Y, LP>(pool_addr)
        } else {
            let (y_res, x_res) = LiquidityPool::get_reserves_size<Y, X, LP>(pool_addr);
            (x_res, y_res)
        }
    }

    /// Get current cumulative prices in liquidity pool.
    /// * pool_addr - pool owner address.
    public fun get_cumulative_prices<X: store, Y: store, LP>(pool_addr: address): (U256, U256, u64) {
        if (TokenSymbols::is_sorted<X, Y>()) {
            LiquidityPool::get_cumulative_prices<X, Y, LP>(pool_addr)
        } else {
            let (y, x, t) = LiquidityPool::get_cumulative_prices<Y, X, LP>(pool_addr);
            (x, y, t)
        }
    }

    /// Get token amount out by passing amount in (include fees).
    /// * token_in_val - exactly amount of tokens to swap.
    /// * reserve_in_size - reserves of token we are going to swap.
    /// * reserve_out_size - reserves of token we are going to get.
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

    /// Get token amount in by amount out.
    /// * token_out_val - exactly amount of tokens to get.
    /// * reserve_in_size - reserves of token we are going to swap.
    /// * reserve_out_size - reserves of token we are going to get.
    public fun get_token_in_with_fees(token_out_val: u128, reserve_out_size: u128, reserve_in_size: u128): u128 {
        let (fee_pct, fee_scale) = LiquidityPool::get_fees_config();

        // 0.997 for 0.3% fee
        let fee_multiplier = fee_scale - fee_pct;
        // reserves_out - token_out * 0.997
        let new_reserves_out_size = (reserve_out_size - token_out_val) * fee_multiplier;
        // token_out * fee scale * reserve_in / new reserves out
        SafeMath::safe_mul_div_u128(token_out_val * fee_scale, reserve_in_size, new_reserves_out_size) + 1
    }

    /// Return amount of liquidity need to for `amount_in`.
    /// * amount_in - amount to swap.
    /// * reserve_in - reserves of token to swap. 
    /// * reserve_out - reserves of token to get.
    public fun convert_with_current_price(token_in_val: u128, reserve_in_size: u128, reserve_out_size: u128): u128 {
        assert!(token_in_val > 0, ERR_WRONG_AMOUNT);
        assert!(reserve_in_size > 0 && reserve_out_size > 0, ERR_WRONG_RESERVE);

        // exchange_price = reserve_out / reserve_in_size
        // amount_returned = token_in_val * exchange_price
        SafeMath::safe_mul_div_u128(token_in_val, reserve_out_size, reserve_in_size)
    }

    #[test_only]
    public fun current_price<X: store, Y: store, LP>(pool_addr: address): u128 {
        let (x_reserve, y_reserve) = get_reserves_size<X, Y, LP>(pool_addr);
        SafeMath::safe_mul_div_u128(1, x_reserve, y_reserve)
    }
}
