module AptosSwap::LiquidityPoolTests {
    use Std::ASCII::string;
    use Std::Signer;
    use Std::U256;
    use AptosSwap::Token;
    use AptosSwap::LiquidityPool;

    struct USDT has store {}

    struct BTC has store {}

    struct LPToken has store {}

    struct Balance<phantom TokenType> has key { tokens: Token::Token<TokenType> }

    struct Caps has key {
        btc_mint_cap: Token::MintCapability<BTC>,
        btc_burn_cap: Token::BurnCapability<BTC>,
        usdt_mint_cap: Token::MintCapability<USDT>,
        usdt_burn_cap: Token::BurnCapability<USDT>,
    }

    fun register_tokens(token_admin: &signer) {
        let (usdt_mint_cap, usdt_burn_cap) =
            Token::register_token<USDT>(token_admin, 10, string(b"USDT"));
        let (btc_mint_cap, btc_burn_cap) =
            Token::register_token<BTC>(token_admin, 10, string(b"BTC"));
        let caps = Caps{ usdt_mint_cap, usdt_burn_cap, btc_mint_cap, btc_burn_cap };
        move_to(token_admin, caps);
    }

    #[test(token_admin = @TokenAdmin, pool_owner = @0x42)]
    fun test_create_empty_pool_without_any_liquidity(token_admin: signer, pool_owner: signer) {
        register_tokens(&token_admin);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        let (mint_cap, burn_cap) =
            Token::register_token<LPToken>(&token_admin, 10, string(b"TestLPToken"));
        LiquidityPool::register_liquidity_pool<BTC, USDT, LPToken>(&pool_owner, mint_cap, burn_cap);

        let (x_res_val, y_res_val) =
            LiquidityPool::get_reserves_size<BTC, USDT, LPToken>(pool_owner_addr);
        assert!(x_res_val == 0, 3);
        assert!(y_res_val == 0, 4);

        let (x_price, y_price, _) =
            LiquidityPool::get_price_info<BTC, USDT, LPToken>(pool_owner_addr, false);
        assert!(U256::as_u128(x_price) == 0, 1);
        assert!(U256::as_u128(y_price) == 0, 2);
    }

    #[test(token_admin = @TokenAdmin, pool_owner = @0x42)]
    #[expected_failure(abort_code = 101)]
    fun test_fail_if_token_generics_provided_in_the_wrong_order(token_admin: signer, pool_owner: signer) {
        register_tokens(&token_admin);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        let (mint_cap, burn_cap) =
            Token::register_token<LPToken>(&token_admin, 10, string(b"TestLPToken"));
        LiquidityPool::register_liquidity_pool<BTC, USDT, LPToken>(&pool_owner, mint_cap, burn_cap);

        // here generics are provided as USDT-BTC, but pool is BTC-USDT. `reverse` parameter is irrelevant
        let (_x_price, _y_price, _) =
            LiquidityPool::get_price_info<USDT, BTC, LPToken>(pool_owner_addr, false);
    }

//    #[test(token_admin = @TokenAdmin, pool_owner = @0x42)]
//    fun test_add_some_liquidity_to_existing_pool(token_admin: signer, pool_owner: signer) acquires Caps {
//        register_tokens(&pool_owner);
//        let pool_owner_addr = Signer::address_of(&pool_owner);
//        let caps = borrow_global<Caps>(pool_owner_addr);
//
//        let (mint_cap, burn_cap) =
//            Token::register_token<LPToken>(&pool_owner, 10, string(b"TestLPToken"));
//        LiquidityPool::register_liquidity_pool<BTC, USDT, LPToken>(&pool_owner, mint_cap, burn_cap);
//
//        let btc_tokens = Token::mint(pool_owner_addr, 100100, &caps.btc_mint_cap);
//        let usdt_tokens = Token::mint(pool_owner_addr, 100100, &caps.usdt_mint_cap);
//
//        let lp_tokens =
//            LiquidityPool::mint_liquidity<BTC, USDT, LPToken>(pool_owner_addr, btc_tokens, usdt_tokens);
//
//        move_to(&pool_owner, Balance<LPToken> { tokens: lp_tokens });
//    }
}
