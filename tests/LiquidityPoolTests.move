module AptosSwap::LiquidityPoolTests {
    use Std::ASCII::string;
    use Std::Signer;
    use Std::U256;
    use AptosFramework::Genesis;
    use AptosSwap::Token;
    use AptosSwap::LiquidityPool;

    struct USDT has store {}

    struct BTC has store {}

    struct LP has store {}

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
            Token::register_token<LP>(&token_admin, 10, string(b"TestLPToken"));
        LiquidityPool::register_liquidity_pool<BTC, USDT, LP>(&pool_owner, mint_cap, burn_cap);

        let (x_res_val, y_res_val) =
            LiquidityPool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res_val == 0, 3);
        assert!(y_res_val == 0, 4);

        let (x_price, y_price, _) =
            LiquidityPool::get_price_info<BTC, USDT, LP>(pool_owner_addr, false);
        assert!(U256::as_u128(x_price) == 0, 1);
        assert!(U256::as_u128(y_price) == 0, 2);
    }

    #[test(token_admin = @TokenAdmin, pool_owner = @0x42)]
    #[expected_failure(abort_code = 101)]
    fun test_fail_if_token_generics_provided_in_the_wrong_order(token_admin: signer, pool_owner: signer) {
        register_tokens(&token_admin);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        let (mint_cap, burn_cap) =
            Token::register_token<LP>(&token_admin, 10, string(b"TestLPToken"));
        LiquidityPool::register_liquidity_pool<BTC, USDT, LP>(&pool_owner, mint_cap, burn_cap);

        // here generics are provided as USDT-BTC, but pool is BTC-USDT. `reverse` parameter is irrelevant
        let (_x_price, _y_price, _) =
            LiquidityPool::get_price_info<USDT, BTC, LP>(pool_owner_addr, false);
    }

    #[test(core = @CoreResources, token_admin = @TokenAdmin, pool_owner = @0x42)]
    fun test_add_liquidity_and_then_burn_it(core: signer, token_admin: signer, pool_owner: signer)
    acquires Caps {
        Genesis::setup(&core);
        register_tokens(&token_admin);

        let token_admin_addr = Signer::address_of(&token_admin);
        let caps = borrow_global<Caps>(token_admin_addr);

        let (mint_cap, burn_cap) =
            Token::register_token<LP>(&token_admin, 10, string(b"TestLPToken"));
        LiquidityPool::register_liquidity_pool<BTC, USDT, LP>(&pool_owner, mint_cap, burn_cap);

        let btc_tokens = Token::mint(100100, &caps.btc_mint_cap);
        let usdt_tokens = Token::mint(100100, &caps.usdt_mint_cap);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let lp_tokens =
            LiquidityPool::mint_liquidity<BTC, USDT, LP>(pool_owner_addr, btc_tokens, usdt_tokens);
        assert!(Token::value(&lp_tokens) == 99100, 1);

        let (x_res, y_res) = LiquidityPool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 100100, 2);
        assert!(y_res == 100100, 3);

        let (btc_return, usdt_return) =
            LiquidityPool::burn_liquidity<BTC, USDT, LP>(pool_owner_addr, lp_tokens);
        assert!(Token::value(&btc_return) == 100100, 1);
        assert!(Token::value(&usdt_return) == 100100, 1);

        let (x_res, y_res) = LiquidityPool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 0, 2);
        assert!(y_res == 0, 3);

        Token::burn(btc_return, &caps.btc_burn_cap);
        Token::burn(usdt_return, &caps.usdt_burn_cap);
    }
}
