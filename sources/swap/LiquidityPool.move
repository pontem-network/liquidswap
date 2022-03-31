/// Liquidity pool.
module SwapAdmin::LiquidityPool {
    use Std::Signer;
    use Std::Vector;
    use Std::ASCII::{String, Self};
    use Std::BCS;
    use Std::Compare;
    use SwapAdmin::Token::{Self, Token};
    use SwapAdmin::SafeMath;

    /// LP token default decimals.
    const LP_TOKEN_DECIMALS: u8 = 9;

    /// Minimal liquidity.
    const MINIMAL_LIQUIDITY: u64 = 1000;

    /// Liquidity pool with reserves
    /// LP token should go outside of this module.
    /// Probably we only need mint capability?
    struct LiquidityPool<X: store, Y: store, phantom LP> has key {
        token_x_reserve: Token<X>,
        token_y_reserve: Token<Y>,
        lp_mint_cap: Token::MintCapability<LP>,
        lp_burn_cap: Token::BurnCapability<LP>,
    }

    /// Register liquidity pool (by pairs).
    public fun register_liquidity_pool<X: store, Y: store, LP>(account: &signer, lp_mint_cap: Token::MintCapability<LP>, lp_burn_cap: Token::BurnCapability<LP>) {
        Token::assert_is_token<X>();
        Token::assert_is_token<Y>();

        let cmp = compare_token<X, Y>();

        // TODO: Error code.
        assert!(cmp != 0, 101);

        // TODO: Error code.
        assert!(Token::total_value<LP>() == 0, 102);

        // TODO: check that token pair is valid (order of terms).
        let token_pair = LiquidityPool<X, Y, LP>{
            token_x_reserve: Token::zero<X>(),
            token_y_reserve: Token::zero<Y>(),
            lp_mint_cap: lp_mint_cap,
            lp_burn_cap: lp_burn_cap,
        };

        move_to(account, token_pair);
    }

    /// Caller should call this function to determine the order of A, B
    public fun compare_token<X, Y>(): u8 {
        let x_bytes = BCS::to_bytes<String>(&Token::symbol<X>());
        let y_bytes = BCS::to_bytes<String>(&Token::symbol<Y>());
        let ret: u8 = Compare::cmp_bcs_bytes(&x_bytes, &y_bytes);
        ret
    }

    // TODO: common method to add liquidity and for register_liquidity_pool and add_liquidity.

    // public fun mint_liquidity<X: store, Y: store>(token_x: Token<X>, token_y: Token<Y>): Token<LPToken<X, Y>>
    // acquires LiquidityPool, LPTokenCapabilities {
    //     let lp_tokens_total = Token::total_value<LPToken<X, Y>>();
    //     let x_value = Token::value(&token_x);
    //     let y_value = Token::value(&token_y);

    //     let pool = borrow_global<LiquidityPool<X, Y>>(@SwapAdmin);
    //     let x_reserve = Token::value(&pool.token_x_reserve);
    //     let y_reserve = Token::value(&pool.token_y_reserve);

    //     let lp_tokens_generated = if (lp_tokens_total == 0) {
    //         // empty pool: liquidity tokens num is sqrt(x * y)
    //         let lp_tokens = SafeMath::sqrt_u256(SafeMath::mul_u128(x_value, y_value));
    //         lp_tokens
    //     } else {
    //         // lp_tokens_received = (num_tokens_provided / num_tokens_in_pool) * lp_tokens_total
    //         let x_liquidity = SafeMath::safe_mul_div_u128(x_value, lp_tokens_total, x_reserve);
    //         let y_liquidity = SafeMath::safe_mul_div_u128(x_value, lp_tokens_total, y_reserve);
    //         // take minimum of two, so it's incentivised to provide tokens with the same value
    //         if (x_liquidity < y_liquidity) x_liquidity else y_liquidity
    //     };
    //     assert!(lp_tokens_generated > 0, 2);

    //     Token::deposit(&mut pool.token_x_reserve, token_x);
    //     Token::deposit(&mut pool.token_y_reserve, token_y);

    //     let caps = borrow_global<LPTokenCapabilities<X, Y>>(@SwapAdmin);
    //     let lp_tokens = Token::mint(lp_tokens_generated, &caps.mint_cap);
    //     lp_tokens
    // }

    //public fun burn_liquidity<X, Y>(lp_token: Token<LPToken<X, Y>>): (Token<X>, Token<Y>) {}

    //public fun swap<In, Out>(in: Token<In>): Token<Out> {}

    //public fun claim_fees<X, Y>(acc: &signer): Token<LPToken<X, Y>> {}

    // fun collect_fee<In: store, Out: store>(token: Token<In>): Token<In>
    // acquires LiquidityPool {
    //     // extract 0.3% fee from `token`
    //     // TODO: correct fee computation
    //     let (token, fee) = Token::split(token, Token::value(&token) * 3 / 100);
    //     // find right LiquidityPool: order In/Out, extract it's pool
    //     // TODO: ordering
    //     let pool = borrow_global<LiquidityPool<In, Out>>(@SwapAdmin);
    //     // record how many lp tokens were there at the moment of the swap
    //     // it will be used in claiming fee lp tokens later

    //     // deposit fee to the pool
    // }

    // fun register_lp_token<X, Y>(admin_acc: &signer) {
    //     let (mint_cap, burn_cap) =
    //         Token::register_token<LPToken<X, Y>>(admin_acc, LP_TOKEN_DECIMALS, ASCII::string(b"LP"));
    //     let caps = LPTokenCapabilities<X, Y>{ mint_cap, burn_cap };
    //     move_to(admin_acc, caps);
    // }
}
