module CoinAdmin::CoinHelperTests {
    use Std::ASCII;

    use AptosFramework::Genesis;
    use AptosFramework::Coin;

    use AptosSwap::CoinHelper;

    struct USDT has store {}
    struct BTC has store {}

    struct Capabilities<phantom CoinType> has key, store {
        mint_cap: Coin::MintCapability<CoinType>,
        burn_cap: Coin::BurnCapability<CoinType>,
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin)]
    fun test_end_to_end(core: signer, coin_admin: signer) {
        Genesis::setup(&core);

        let (usdt_mint_cap, usdt_burn_cap) = Coin::initialize<USDT>(
            &coin_admin,
            ASCII::string(b"USDT"),
            ASCII::string(b"USDT"),
            6,
            true,
        );
        let (btc_mint_cap, btc_burn_cap) = Coin::initialize<BTC>(
            &coin_admin,
            ASCII::string(b"BTC"),
            ASCII::string(b"BTC"),
            8,
            true,
        );
        CoinHelper::assert_is_coin<USDT>();
        CoinHelper::assert_is_coin<BTC>();

        let coins_minted = Coin::mint(1000000000, &usdt_mint_cap);
        CoinHelper::assert_has_supply<USDT>();
        CoinHelper::assert_has_supply<BTC>();

        let usdt_supply = CoinHelper::supply<USDT>();
        let btc_supply = CoinHelper::supply<BTC>();
        assert!(usdt_supply == 1000000000, 0);
        assert!(btc_supply == 0, 1);

        Coin::burn(coins_minted, &usdt_burn_cap);
        usdt_supply = CoinHelper::supply<USDT>();
        assert!(usdt_supply == 0, 2);

        assert!(CoinHelper::is_sorted<BTC, USDT>(), 3);
        assert!(!CoinHelper::is_sorted<USDT, BTC>(), 4);

        let cmp = CoinHelper::compare<BTC, USDT>();
        assert!(cmp == 1, 5);
        cmp = CoinHelper::compare<BTC, BTC>();
        assert!(cmp == 0, 6);
        cmp = CoinHelper::compare<USDT, BTC>();
        assert!(cmp == 2, 7);

        move_to(&coin_admin, Capabilities<USDT> {
            mint_cap: usdt_mint_cap,
            burn_cap: usdt_burn_cap,
        });
        move_to(&coin_admin, Capabilities<BTC> {
            mint_cap: btc_mint_cap,
            burn_cap: btc_burn_cap,
        });
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin)]
    #[expected_failure(abort_code = 102)]
    fun test_assert_has_supply_failuer(core: signer, coin_admin: signer) {
        Genesis::setup(&core);

        let (mint_cap, burn_cap) = Coin::initialize<USDT>(
            &coin_admin,
            ASCII::string(b"USDT"),
            ASCII::string(b"USDT"),
            6,
            false,
        );

        CoinHelper::assert_has_supply<USDT>();
        move_to(&coin_admin, Capabilities<USDT> {
            mint_cap,
            burn_cap,
        });
    }

    #[test]
    #[expected_failure(abort_code = 100)]
    fun test_assert_is_coin_failure() {
        CoinHelper::assert_is_coin<USDT>();
    }
}