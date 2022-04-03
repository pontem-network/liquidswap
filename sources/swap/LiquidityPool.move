/// Liquidity pool.
module SwapAdmin::LiquidityPool {
    use Std::Signer;
    use Std::Vector;
    use Std::ASCII::{String, Self};
    use Std::BCS;
    use Std::Compare;
    use SwapAdmin::Token::{Self, Token};
    use SwapAdmin::SafeMath;

    // Constants.

    /// LP token default decimals.
    const LP_TOKEN_DECIMALS: u8 = 9;

    /// Minimal liquidity.
    const MINIMAL_LIQUIDITY: u128 = 1000;

    // TODO: events.

    /// Liquidity pool with reserves.
    /// LP token should go outside of this module.
    /// Probably we only need mint capability?
    struct LiquidityPool<X: store, Y: store, phantom LP> has key, store {
        token_x_reserve: Token<X>,
        token_y_reserve: Token<Y>,
        lp_mint_cap: Token::MintCapability<LP>,
        lp_burn_cap: Token::BurnCapability<LP>,
    }

    /// Register liquidity pool (by pairs).
    public fun register_liquidity_pool<X: store, Y: store, LP>(account: &signer, lp_mint_cap: Token::MintCapability<LP>, lp_burn_cap: Token::BurnCapability<LP>) {
        Token::assert_is_token<X>();
        Token::assert_is_token<Y>();
        Token::assert_is_token<LP>();

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

    /// Mint new liquidity.
    public fun mint_liquidity<X: store, Y: store, LP>(owner: address, token_x: Token<X>, token_y: Token<Y>): Token<LP> acquires LiquidityPool {
        let total_supply: u128 = Token::total_value<LP>();

        let (x_reserve, y_reserve) = get_reserves<X, Y, LP>(owner);

        let x_value = Token::value<X>(&token_x);
        let y_value = Token::value<Y>(&token_y);

        let liquidity = if (total_supply == 0) {
            SafeMath::sqrt_u256(SafeMath::mul_u128(x_value, y_value)) - MINIMAL_LIQUIDITY
        } else {
            let x_liquidity = SafeMath::safe_mul_div_u128(x_value, total_supply, x_reserve);
            let y_liquidity = SafeMath::safe_mul_div_u128(y_value, total_supply, y_reserve);

            if (x_liquidity < y_liquidity) {
                x_liquidity
            } else {
                y_liquidity
            }
        };

        // TODO: error here.
        assert!(liquidity > 0, 103);

        let liquidity_pool = borrow_global_mut<LiquidityPool<X, Y, LP>>(owner);
        Token::deposit(&mut liquidity_pool.token_x_reserve, token_x);
        Token::deposit(&mut liquidity_pool.token_y_reserve, token_y);

        let lp_tokens = Token::mint<LP>(liquidity, &liquidity_pool.lp_mint_cap);

        // TODO: We should update oracle?

        lp_tokens
    }

    /// Swap tokens (can swap both x and y in the same time).
    /// In the most of situation only X or Y tokens argument has value (similar with *_out, only one _out will be non-zero).
    /// Because an user usually exchanges only one token, yet function allow to exchange both tokens.
    /// * x_in - X tokens to swap.
    /// * x_out - exptected amount of X tokens to get out.
    /// * y_in - Y tokens to swap.
    /// * y_out - exptected amount of Y tokens to get out.
    /// Returns - both exchanged X and Y token.
    public fun swap<X: store, Y: store, LP>(owner: address, x_in: Token<X>, x_out: u128, y_in: Token<Y>, y_out: u128): (Token<X>, Token<Y>)  acquires LiquidityPool {
        let x_in_value = Token::value(&x_in);
        let y_in_value = Token::value(&y_in);

        // TODO: error here.
        assert!(x_in_value > 0 || y_in_value > 0, 104);

        let (x_reserve, y_reserve) = get_reserves<X, Y, LP>(owner);
        let liquidity_pool = borrow_global_mut<LiquidityPool<X, Y, LP>>(owner);

        // Deposit new tokens to liquidity pool.
        Token::deposit(&mut liquidity_pool.token_x_reserve, x_in);
        Token::deposit(&mut liquidity_pool.token_y_reserve, y_in);

        // Withdraw expected amount from reserves.
        let x_swapped = Token::withdraw(&mut liquidity_pool.token_x_reserve, x_out);
        let y_swapped = Token::withdraw(&mut liquidity_pool.token_y_reserve, y_out);

        // Get new reserves.
        let x_reserve_new = Token::value(&liquidity_pool.token_x_reserve);
        let y_reserve_new = Token::value(&liquidity_pool.token_y_reserve);        

        // Check we can do swap with provided info.
        let x_adjusted = x_reserve_new * 3 - x_in_value * 1000;
        let y_adjusted = y_reserve_new * 3 - y_in_value * 1000;
        let cmp_order = SafeMath::safe_compare_mul_u128(x_adjusted, y_adjusted, x_reserve, y_reserve * 1000000);

        // TODO: error and compare (equal, greater than) from safe math.
        assert!((0 == cmp_order || 2 == cmp_order), 105);

        // Return swapped amount.
        (x_swapped, y_swapped)
    }

    /// Caller should call this function to determine the order of A, B
    public fun compare_token<X, Y>(): u8 {
        let x_bytes = BCS::to_bytes<String>(&Token::symbol<X>());
        let y_bytes = BCS::to_bytes<String>(&Token::symbol<Y>());
        let ret: u8 = Compare::cmp_bcs_bytes(&x_bytes, &y_bytes);
        ret
    }

    /// Get reserves of a token pair.
    /// The order of type args should be sorted.
    public fun get_reserves<X: store, Y: store, LP>(owner: address): (u128, u128) acquires LiquidityPool {
        let liquidity_pool = borrow_global<LiquidityPool<X, Y, LP>>(owner);
        let x_reserve = Token::value(&liquidity_pool.token_x_reserve);
        let y_reserve = Token::value(&liquidity_pool.token_y_reserve);

        (x_reserve, y_reserve)
    }

    

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
