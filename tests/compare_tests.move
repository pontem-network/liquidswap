#[test_only]
module 0x1::coins_a { struct BTC {} }

#[test_only]
module 0x1::coins_b { struct BTC {} }

#[test_only]
module liquidswap::compare_tests {
    use liquidswap::coin_helper;
    use aptos_std::comparator;
    use test_coin_admin::test_coins::USDT;
    use test_coin_admin::test_coins;
    use liquidswap::lp_coin;
    use liquidswap_lp::lp_coin;

    struct BTC {}
    struct USDC {}
    struct Usdt {}

    #[test]
    fun test_coins_equal() {
        assert!(comparator::is_equal(&coin_helper::compare<BTC, BTC>()), 1);
        assert!(comparator::is_equal(&coin_helper::compare<USDC, USDC>()), 2);
        assert!(comparator::is_equal(&coin_helper::compare<Usdt, Usdt>()), 3);
    }

    #[test]
    fun test_coins_compared_with_struct_name_first_if_not_equals_then_returns() {
        assert!(comparator::is_smaller_than(&coin_helper::compare<BTC, USDC>()), 1);
        assert!(comparator::is_smaller_than(&coin_helper::compare<BTC, Usdt>()), 2);
        assert!(comparator::is_smaller_than(&coin_helper::compare<USDC, USDT>()), 3);

        assert!(comparator::is_greater_than(&coin_helper::compare<USDC, BTC>()), 4);
        assert!(comparator::is_greater_than(&coin_helper::compare<USDT, USDC>()), 5);
        assert!(comparator::is_greater_than(&coin_helper::compare<Usdt, USDC>()), 6);
    }

    #[test]
    fun test_coins_compared_with_module_name_if_struct_name_is_equal() {
        assert!(comparator::is_smaller_than(&coin_helper::compare<0x1::coins_a::BTC, 0x1::coins_b::BTC>()), 1);
        assert!(comparator::is_greater_than(&coin_helper::compare<0x1::coins_b::BTC, 0x1::coins_a::BTC>()), 2);
    }

    #[test]
    fun test_coins_compared_with_address_if_all_others_are_equal() {
    }
}
