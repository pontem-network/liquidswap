#[test_only]
module liquidswap::coin_helper_tests {
    use std::string::utf8;

    use aptos_framework::genesis;

    use liquidswap::coin_helper;

    use test_helpers::test_account::create_account;
    use test_coin_admin::test_coins::{Self, BTC, USDT};

    #[test(core = @core_resources, coin_admin = @test_coin_admin)]
    fun test_end_to_end(core: signer, coin_admin: signer) {
        genesis::setup(&core);
        create_account(&coin_admin);

        test_coins::register_coins(&coin_admin);

        coin_helper::assert_is_coin<USDT>();
        coin_helper::assert_is_coin<BTC>();

        let coins_minted = test_coins::mint<USDT>(&coin_admin, 1000000000);

        let usdt_supply = coin_helper::supply<USDT>();
        let btc_supply = coin_helper::supply<BTC>();
        assert!(usdt_supply == 1000000000, 0);
        assert!(btc_supply == 0, 1);

        test_coins::burn(&coin_admin, coins_minted);
        usdt_supply = coin_helper::supply<USDT>();
        assert!(usdt_supply == 0, 2);

        assert!(coin_helper::is_sorted<BTC, USDT>(), 3);
        assert!(!coin_helper::is_sorted<USDT, BTC>(), 4);

        let cmp = coin_helper::compare<BTC, USDT>();
        assert!(cmp == 1, 5);
        cmp = coin_helper::compare<BTC, BTC>();
        assert!(cmp == 0, 6);
        cmp = coin_helper::compare<USDT, BTC>();
        assert!(cmp == 2, 7);
    }

    #[test]
    #[expected_failure(abort_code = 101)]
    fun test_assert_is_coin_failure() {
        coin_helper::assert_is_coin<USDT>();
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin)]
    #[expected_failure(abort_code = 100)]
    fun test_cant_be_same_coin_failure(core: signer, coin_admin: signer) {
        genesis::setup(&core);
        create_account(&coin_admin);

        test_coins::register_coins(&coin_admin);

        coin_helper::assert_is_coin<USDT>();
        let _ = coin_helper::is_sorted<USDT, USDT>();
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin)]
    fun generate_lp_name(core: signer, coin_admin: signer) {
        genesis::setup(&core);
        create_account(&coin_admin);

        test_coins::register_coins(&coin_admin);

        let (lp_name, lp_symbol) = coin_helper::generate_lp_name<BTC, USDT>();
        assert!(lp_name == utf8(b"LiquidSwap LP"), 0);
        assert!(lp_symbol == utf8(b"LP-BTC-USDT"), 1);
    }
}
