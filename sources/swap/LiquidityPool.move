module SwapAdmin::LiquidityPool {
    use Std::Signer;
    use Std::Vector;
    use Std::ASCII::{String, Self};
    use SwapAdmin::Token::{Self, Token};
    use SwapAdmin::SafeMath;

    const LP_TOKEN_DECIMALS: u8 = 9;

    const MINIMAL_LIQUIDITY: u64 = 1000;

    struct LiquidityPool<X: store, Y: store> has key {
        token_x_reserve: Token<X>,
        token_y_reserve: Token<Y>,
        lp_providers: vector<address>,
    }

    struct LPToken<phantom X, phantom Y> {}

    struct LPTokenCapabilities<X, Y> has key {
        mint_cap: Token::MintCapability<LPToken<X, Y>>,
        burn_cap: Token::BurnCapability<LPToken<X, Y>>,
    }

    public fun register_liquidity_pool<X: store, Y: store>(admin_acc: &signer) {
        Token::assert_is_admin(admin_acc);
        Token::assert_is_token<X>();
        Token::assert_is_token<Y>();

        // TODO: check that token pair is valid (order of terms)

        let token_pair = LiquidityPool<X, Y>{
            token_x_reserve: Token::zero<X>(),
            token_y_reserve: Token::zero<Y>(),
            lp_providers: Vector::empty<address>(),
        };
        move_to(admin_acc, token_pair);

        register_lp_token<X, Y>(admin_acc);
    }

    public fun mint_liquidity<X: store, Y: store>(token_x: Token<X>, token_y: Token<Y>): Token<LPToken<X, Y>>
    acquires LiquidityPool, LPTokenCapabilities {
        let lp_tokens_total = Token::total_value<LPToken<X, Y>>();
        let x_value = Token::value(&token_x);
        let y_value = Token::value(&token_y);

        let pool = borrow_global<LiquidityPool<X, Y>>(@SwapAdmin);
        let x_reserve = Token::value(&pool.token_x_reserve);
        let y_reserve = Token::value(&pool.token_y_reserve);

        let lp_tokens_generated = if (lp_tokens_total == 0) {
            // empty pool: liquidity tokens num is sqrt(x * y)
            let lp_tokens = SafeMath::sqrt_u256(SafeMath::mul_u128(x_value, y_value));
            lp_tokens
        } else {
            // lp_tokens_received = (num_tokens_provided / num_tokens_in_pool) * lp_tokens_total
            let x_liquidity = SafeMath::safe_mul_div_u128(x_value, lp_tokens_total, x_reserve);
            let y_liquidity = SafeMath::safe_mul_div_u128(x_value, lp_tokens_total, y_reserve);
            // take minimum of two, so it's incentivised to provide tokens with the same value
            if (x_liquidity < y_liquidity) x_liquidity else y_liquidity
        };
        assert!(lp_tokens_generated > 0, 2);

        Token::deposit(&mut pool.token_x_reserve, token_x);
        Token::deposit(&mut pool.token_y_reserve, token_y);

        let caps = borrow_global<LPTokenCapabilities<X, Y>>(@SwapAdmin);
        let lp_tokens = Token::mint(lp_tokens_generated, &caps.mint_cap);
        lp_tokens
    }

    public fun burn_liquidity<X, Y>(lp_token: Token<LPToken<X, Y>>): (Token<X>, Token<Y>) {}

    public fun swap<In, Out>(in: Token<In>): Token<Out> {}

    fun collect_fee<In: store, phantom Out: store>(token: Token<In>): Token<In>
    acquires LiquidityPool {
        // extract 0.3% fee from `token`
        // TODO: correct fee computation
        let (token, fee) = Token::split(token, Token::value(&token) * 3 / 100);
        // find right LiquidityPool: order In/Out, extract it's pool
        // TODO: ordering
        let pool = borrow_global<LiquidityPool<In, Out>>(@SwapAdmin);
        // record how many lp tokens were there at the moment of the swap
        // it will be used in claiming fee lp tokens later

        // deposit fee to the pool
    }

    fun register_lp_token<X, Y>(admin_acc: &signer) {
        let (mint_cap, burn_cap) =
            Token::register_token<LPToken<X, Y>>(admin_acc, LP_TOKEN_DECIMALS, ASCII::string(b"LP"));
        let caps = LPTokenCapabilities<X, Y>{ mint_cap, burn_cap };
        move_to(admin_acc, caps);
    }
}
