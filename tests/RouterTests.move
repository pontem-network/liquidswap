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
                                                         x_num: u128, y_num: u128) acquires Caps {
        let token_admin_addr = Signer::address_of(token_admin);
        let caps = borrow_global<Caps>(token_admin_addr);

        let (lp_mint_cap, lp_burn_cap) =
            Token::register_token<LP>(token_admin, 10, string(b"LP"));
        LiquidityPool::register<BTC, USDT, LP>(pool_owner, lp_mint_cap, lp_burn_cap);

        let pool_owner_addr = Signer::address_of(pool_owner);
        let btc_tokens = Token::mint(x_num, &caps.btc_mint_cap);
        let usdt_tokens = Token::mint(y_num, &caps.usdt_mint_cap);

        let lp_tokens =
            LiquidityPool::add_liquidity<BTC, USDT, LP>(pool_owner_addr, btc_tokens, usdt_tokens);
        move_to(pool_owner, Balance<LP>{ tokens: lp_tokens });
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
        assert!(Token::num(&usdt_tokens) == 98, 1);

        Token::burn(usdt_tokens, &caps.usdt_burn_cap);
    }
}
