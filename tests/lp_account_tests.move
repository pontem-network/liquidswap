#[test_only]
module liquidswap::lp_account_tests {
    use std::string::utf8;

    use liquidswap::liquidity_pool;
    use test_coin_admin::test_coins::{BTC, USDT};
    use test_pool_owner::test_lp;

    #[test]
    #[expected_failure(abort_code = 101)]
    fun test_register_pool_fails_if_corresponding_lp_coin_already_exists() {
        let (_, pool_owner) = test_lp::setup_coins_and_pool_owner();

        test_lp::register_lp_coin_drop_caps<BTC, USDT>();

        liquidity_pool::register<BTC, USDT>(
            &pool_owner,
            utf8(b"Liquidswap LP"),
            utf8(b"LP-BTC-USDT"),
            2
        );
    }
}
