module AptosSwap::LiquidityPoolTests {
    use Std::ASCII::string;
    use Std::Signer;
    use Std::U256;
    use AptosSwap::Token;
    use AptosSwap::LiquidityPool;

    struct USDT has store {}

    struct BTC has store {}

    struct TestLPToken {}

    struct Caps has key {
        btc_mint_cap: Token::MintCapability<BTC>,
        btc_burn_cap: Token::BurnCapability<BTC>,
        usdt_mint_cap: Token::MintCapability<USDT>,
        usdt_burn_cap: Token::BurnCapability<USDT>,
    }

    fun register_tokens(owner: &signer) {
        let (usdt_mint_cap, usdt_burn_cap) =
            Token::register_token<USDT>(owner, 10, string(b"USDT"));
        let (btc_mint_cap, btc_burn_cap) =
            Token::register_token<BTC>(owner, 10, string(b"BTC"));
        let caps = Caps{ usdt_mint_cap, usdt_burn_cap, btc_mint_cap, btc_burn_cap };
        move_to(owner, caps);
    }

    #[test(pool_owner = @0x42)]
    fun test_create_empty_pool_without_any_liquidity(pool_owner: signer) {
        register_tokens(&pool_owner);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        let (mint_cap, burn_cap) =
            Token::register_token<TestLPToken>(&pool_owner, 10, string(b"TestLPToken"));
        LiquidityPool::register_liquidity_pool<BTC, USDT, TestLPToken>(&pool_owner, mint_cap, burn_cap);

        let (x_price, y_price, _) =
            LiquidityPool::get_price_info<BTC, USDT, TestLPToken>(pool_owner_addr, false);
        assert!(U256::as_u128(x_price) == 0, 1);
        assert!(U256::as_u128(y_price) == 0, 2);
    }

    #[test(pool_owner = @0x42)]
    #[expected_failure(abort_code = 101)]
    fun test_fail_if_token_generics_provided_in_the_wrong_order(pool_owner: signer) {
        register_tokens(&pool_owner);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        let (mint_cap, burn_cap) =
            Token::register_token<TestLPToken>(&pool_owner, 10, string(b"TestLPToken"));
        LiquidityPool::register_liquidity_pool<BTC, USDT, TestLPToken>(&pool_owner, mint_cap, burn_cap);

        // here generics are provided as USDT-BTC, but pool is BTC-USDT. `reverse` parameter is irrelevant
        let (_x_price, _y_price, _) =
            LiquidityPool::get_price_info<USDT, BTC, TestLPToken>(pool_owner_addr, false);
    }

//    #[test(pool_owner = @0x42)]
//    fun test_add_some_liquidity_to_existing_pool(pool_owner: signer) acquires Caps {
//        register_tokens(&pool_owner);
//        let pool_owner_addr = Signer::address_of(&pool_owner);
//        let _caps = borrow_global<Caps>(pool_owner_addr);
//
//        let (mint_cap, burn_cap) =
//            Token::register_token<TestLPToken>(&pool_owner, 10, string(b"TestLPToken"));
//        LiquidityPool::register_liquidity_pool<BTC, USDT, TestLPToken>(&pool_owner, mint_cap, burn_cap);
//
//        LiquidityPool::mint_liquidity<BTC, USDT>()
//    }
}
