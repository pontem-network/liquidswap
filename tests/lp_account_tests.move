#[test_only]
module liquidswap::lp_account_tests {
    use std::string::utf8;

    use liquidswap::liquidity_pool;
    use test_coin_admin::test_coins::{BTC, USDT};
    use test_helpers::test_pool;

    #[test]
    #[expected_failure(abort_code = 101)]
    fun test_register_pool_fails_if_corresponding_lp_coin_already_exists() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        test_pool::register_lp_coin_drop_caps<BTC, USDT>();

        liquidity_pool::register<BTC, USDT>(
            &lp_owner,
            utf8(b"Liquidswap LP"),
            utf8(b"LP-BTC-USDT"),
            2
        );
    }
}
