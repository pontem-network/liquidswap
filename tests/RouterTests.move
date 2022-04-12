#[test_only]
module AptosSwap::RouterTests {
    use Std::ASCII::string;
    use Std::Signer;

    use AptosFramework::Genesis;

    use AptosSwap::Token;
    use AptosSwap::LiquidityPool;
    use AptosSwap::Router;

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

    fun register_pool_with_liquidity(token_admin: &signer,
                                     pool_owner: &signer,
                                     x_val: u128, y_val: u128) acquires Caps {
        let token_admin_addr = Signer::address_of(token_admin);
        let caps = borrow_global<Caps>(token_admin_addr);

        let (lp_mint_cap, lp_burn_cap) =
            Token::register_token<LP>(token_admin, 10, string(b"LP"));
        Router::register_liquidity_pool<BTC, USDT, LP>(pool_owner, lp_mint_cap, lp_burn_cap);

        let pool_owner_addr = Signer::address_of(pool_owner);
        if (x_val != 0 && y_val != 0) {
            let btc_tokens = Token::mint(x_val, &caps.btc_mint_cap);
            let usdt_tokens = Token::mint(y_val, &caps.usdt_mint_cap);
            let lp_tokens =
                LiquidityPool::add_liquidity<BTC, USDT, LP>(pool_owner_addr, btc_tokens, usdt_tokens);
            move_to(pool_owner, Balance<LP>{ tokens: lp_tokens });
        };
    }

    fun add_tokens_to_balance<Type: store>(acc: &signer, tokens: Token::Token<Type>) acquires Balance {
        let acc_addr = Signer::address_of(acc);
        if (!exists<Balance<Type>>(acc_addr)) {
            move_to(acc, Balance { tokens });
            return
        };
        let balance = borrow_global_mut<Balance<Type>>(acc_addr);
        Token::deposit(&mut balance.tokens, tokens);
    }

    #[test(core = @CoreResources, token_admin = @TokenAdmin, pool_owner = @0x42)]
    fun test_add_initial_liquidity(core: signer, token_admin: signer, pool_owner: signer) acquires Caps, Balance {
        Genesis::setup(&core);
        register_tokens(&token_admin);

        register_pool_with_liquidity(&token_admin, &pool_owner, 0, 0);

        let caps = borrow_global<Caps>(Signer::address_of(&token_admin));
        let btc_tokens = Token::mint(101, &caps.btc_mint_cap);
        let usdt_tokens = Token::mint(10100, &caps.usdt_mint_cap);
        let pool_addr = Signer::address_of(&pool_owner);

        let (token_x, token_y, lp_tokens) =
            Router::add_liquidity<BTC, USDT, LP>(pool_addr, btc_tokens, 101, usdt_tokens, 10100);
        assert!(Token::value(&token_x) == 0, 1);
        assert!(Token::value(&token_y) == 0, 2);
        // 1010 - 1000 = 10
        assert!(Token::value(&lp_tokens) == 10, 3);

        add_tokens_to_balance(&pool_owner, token_x);
        add_tokens_to_balance(&pool_owner, token_y);
        add_tokens_to_balance(&pool_owner, lp_tokens);
    }

    #[test(core = @CoreResources, token_admin = @TokenAdmin, pool_owner = @0x42)]
    fun test_add_liquidity_to_pool(core: signer, token_admin: signer, pool_owner: signer) acquires Caps, Balance {
        Genesis::setup(&core);
        register_tokens(&token_admin);

        register_pool_with_liquidity(&token_admin, &pool_owner, 101, 10100);

        let caps = borrow_global<Caps>(Signer::address_of(&token_admin));
        let btc_tokens = Token::mint(101, &caps.btc_mint_cap);
        let usdt_tokens = Token::mint(9000, &caps.usdt_mint_cap);
        let pool_addr = Signer::address_of(&pool_owner);

        let (token_x, token_y, lp_tokens) =
            Router::add_liquidity<BTC, USDT, LP>(pool_addr, btc_tokens, 10, usdt_tokens, 9000);
        // 101 - 90 = 11
        assert!(Token::value(&token_x) == 11, 1);
        assert!(Token::value(&token_y) == 0, 2);
        // 8.91 ~ 8
        assert!(Token::value(&lp_tokens) == 8, 3);

        add_tokens_to_balance(&pool_owner, token_x);
        add_tokens_to_balance(&pool_owner, token_y);
        add_tokens_to_balance(&pool_owner, lp_tokens);
    }

    #[test(core = @CoreResources, token_admin = @TokenAdmin, pool_owner = @0x42)]
    fun test_add_liquidity_to_pool_reverse(core: signer, token_admin: signer, pool_owner: signer) acquires Caps, Balance {
        Genesis::setup(&core);
        register_tokens(&token_admin);

        register_pool_with_liquidity(&token_admin, &pool_owner, 101, 10100);

        let caps = borrow_global<Caps>(Signer::address_of(&token_admin));
        let btc_tokens = Token::mint(101, &caps.btc_mint_cap);
        let usdt_tokens = Token::mint(9000, &caps.usdt_mint_cap);
        let pool_addr = Signer::address_of(&pool_owner);

        let (token_y, token_x, lp_tokens) =
            Router::add_liquidity<USDT, BTC, LP>(pool_addr, usdt_tokens, 9000, btc_tokens, 10);
        // 101 - 90 = 11
        assert!(Token::value(&token_x) == 11, 1);
        assert!(Token::value(&token_y) == 0, 2);
        // 8.91 ~ 8
        assert!(Token::value(&lp_tokens) == 8, 3);

        add_tokens_to_balance(&pool_owner, token_x);
        add_tokens_to_balance(&pool_owner, token_y);
        add_tokens_to_balance(&pool_owner, lp_tokens);
    }

    #[test(core = @CoreResources, token_admin = @TokenAdmin, pool_owner = @0x42)]
    fun test_remove_liquidity(core: signer, token_admin: signer, pool_owner: signer) acquires Caps, Balance {
        Genesis::setup(&core);
        register_tokens(&token_admin);

        register_pool_with_liquidity(&token_admin, &pool_owner, 101, 10100);

        let pool_addr = Signer::address_of(&pool_owner);
        let lp_balance = borrow_global_mut<Balance<LP>>(pool_addr);
        let lp_tokens_to_burn = Token::withdraw(&mut lp_balance.tokens, 2);
        let (token_x, token_y) =
            Router::remove_liquidity<BTC, USDT, LP>(pool_addr, lp_tokens_to_burn);
        let (usdt_reserve, btc_reserve) = Router::get_reserves_size<USDT, BTC, LP>(pool_addr);
        assert!(usdt_reserve == 8080, 3);
        assert!(btc_reserve == 81, 4);

        assert!(Token::value(&token_x) == 20, 1);
        assert!(Token::value(&token_y) == 2020, 2);

        add_tokens_to_balance(&pool_owner, token_x);
        add_tokens_to_balance(&pool_owner, token_y);
    }

    #[test(core = @CoreResources, token_admin = @TokenAdmin, pool_owner = @0x42)]
    fun test_swap_exact_token_for_token(core: signer, token_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);
        register_tokens(&token_admin);

        register_pool_with_liquidity(&token_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let caps = borrow_global<Caps>(Signer::address_of(&token_admin));
        let btc_tokens_to_swap = Token::mint(1, &caps.btc_mint_cap);

        let usdt_tokens =
            Router::swap_exact_token_for_token<BTC, USDT, LP>(pool_owner_addr, btc_tokens_to_swap, 90);
        assert!(Token::value(&usdt_tokens) == 98, 1);

        Token::burn(usdt_tokens, &caps.usdt_burn_cap);
    }
}
