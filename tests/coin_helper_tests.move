#[test_only]
module liquidswap::coin_helper_tests {
    use std::string::utf8;

    use aptos_std::comparator;
    use aptos_framework::genesis;

    use liquidswap::coin_helper;

    use test_helpers::test_account::create_account;
    use test_coin_admin::test_coins::{Self, BTC, USDT};

    #[test(coin_admin = @test_coin_admin)]
    fun test_end_to_end(coin_admin: signer) {
        genesis::setup();
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
        assert!(comparator::is_smaller_than(&cmp), 5);
        cmp = coin_helper::compare<BTC, BTC>();
        assert!(comparator::is_equal(&cmp), 6);
        cmp = coin_helper::compare<USDT, BTC>();
        assert!(comparator::is_greater_than(&cmp), 7);
    }

    #[test]
    #[expected_failure(abort_code = 3001)]
    fun test_assert_is_coin_failure() {
        coin_helper::assert_is_coin<USDT>();
    }

    #[test(coin_admin = @test_coin_admin)]
    #[expected_failure(abort_code = 3000)]
    fun test_cant_be_same_coin_failure(coin_admin: signer) {
        genesis::setup();
        create_account(&coin_admin);

        test_coins::register_coins(&coin_admin);

        coin_helper::assert_is_coin<USDT>();
        let _ = coin_helper::is_sorted<USDT, USDT>();
    }

    #[test(coin_admin = @test_coin_admin)]
    fun generate_lp_name(coin_admin: signer) {
        genesis::setup();
        create_account(&coin_admin);

        test_coins::register_coins(&coin_admin);

        let (lp_name, lp_symbol) = coin_helper::generate_lp_name<BTC, USDT>();
        assert!(lp_name == utf8(b"LiquidSwap LP"), 0);
        assert!(lp_symbol == utf8(b"LP-BTC-USDT"), 1);
    }
}
