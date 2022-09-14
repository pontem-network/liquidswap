module 0x2::aptos_coin {
    struct AptosCoin {}
}

module 0x2::coins_a {
    struct BTC {}
}

module 0x2::coins_b {
    struct BTC {}
}

#[test_only]
module liquidswap::compare_tests {
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_std::comparator;

    use liquidswap::coin_helper;
    use test_coin_admin::test_coins::{BTC, USDC, USDT};

    #[test]
    fun test_coins_equal() {
        assert!(comparator::is_equal(&coin_helper::compare<BTC, BTC>()), 1);
        assert!(comparator::is_equal(&coin_helper::compare<USDC, USDC>()), 2);
        assert!(comparator::is_equal(&coin_helper::compare<USDT, USDT>()), 3);
        assert!(comparator::is_equal(&coin_helper::compare<AptosCoin, AptosCoin>()), 4);
    }

    #[test]
    fun test_coins_compared_with_struct_name_first() {
        assert!(comparator::is_smaller_than(&coin_helper::compare<BTC, USDC>()), 1);
        assert!(comparator::is_smaller_than(&coin_helper::compare<USDC, USDT>()), 2);
        assert!(comparator::is_smaller_than(&coin_helper::compare<BTC, AptosCoin>()), 3);

        assert!(comparator::is_greater_than(&coin_helper::compare<USDC, BTC>()), 4);
        assert!(comparator::is_greater_than(&coin_helper::compare<USDT, USDC>()), 5);
        assert!(comparator::is_greater_than(&coin_helper::compare<AptosCoin, USDT>()), 6);
    }

    #[test]
    fun test_coins_compared_with_module_name_if_struct_name_is_equal() {
        assert!(comparator::is_smaller_than(&coin_helper::compare<0x2::coins_a::BTC, 0x2::coins_b::BTC>()), 1);
        assert!(comparator::is_greater_than(&coin_helper::compare<0x2::coins_b::BTC, 0x2::coins_a::BTC>()), 2);
    }

    #[test]
    fun test_coins_compared_with_address_if_all_others_are_equal() {
        assert!(comparator::is_smaller_than(&coin_helper::compare<AptosCoin, 0x2::aptos_coin::AptosCoin>()), 1);
        assert!(comparator::is_greater_than(&coin_helper::compare<0x2::aptos_coin::AptosCoin, AptosCoin>()), 1);
    }

    #[test]
    fun test_is_sorted() {
        assert!(coin_helper::is_sorted<BTC, AptosCoin>(), 1);
        assert!(coin_helper::is_sorted<USDC, USDT>(), 2);
        assert!(coin_helper::is_sorted<AptosCoin, 0x2::aptos_coin::AptosCoin>(), 3);

        assert!(!coin_helper::is_sorted<AptosCoin, BTC>(), 4);
        assert!(!coin_helper::is_sorted<USDT, USDC>(), 5);
    }

    #[test]
    #[expected_failure(abort_code = 3000)]
    fun test_is_sorted_cannot_be_equal() {
        assert!(coin_helper::is_sorted<AptosCoin, AptosCoin>(), 1);
    }
}
