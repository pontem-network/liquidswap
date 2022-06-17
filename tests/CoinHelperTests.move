#[test_only]
module MultiSwap::CoinHelperTests {
    use Std::ASCII::string;

    use AptosFramework::Genesis;

    use MultiSwap::CoinHelper;

    use TestCoinAdmin::TestCoins::{Self, BTC, USDT};

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin)]
    fun test_end_to_end(core: signer, coin_admin: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        CoinHelper::assert_is_coin<USDT>();
        CoinHelper::assert_is_coin<BTC>();

        let coins_minted = TestCoins::mint<USDT>(&coin_admin, 1000000000);

        let usdt_supply = CoinHelper::supply<USDT>();
        let btc_supply = CoinHelper::supply<BTC>();
        assert!(usdt_supply == 1000000000, 0);
        assert!(btc_supply == 0, 1);

        TestCoins::burn(&coin_admin, coins_minted);
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
    }

    #[test]
    #[expected_failure(abort_code = 25861)]
    fun test_assert_is_coin_failure() {
        CoinHelper::assert_is_coin<USDT>();
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin)]
    fun generate_lp_name(core: signer, coin_admin: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        let (lp_name, lp_symbol) = CoinHelper::generate_lp_name<BTC, USDT>();
        assert!(lp_name == string(b"LiquidSwap LP"), 0);
        assert!(lp_symbol == string(b"LP-BTC-USDT"), 1);
    }
}