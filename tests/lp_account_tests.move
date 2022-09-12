#[test_only]
module liquidswap::lp_account_tests {
    use test_pool_owner::test_lp;
    use liquidswap::lp_account;
    use test_coin_admin::test_coins::{BTC, USDT};
    use liquidswap::liquidity_pool;
    use std::string::utf8;
    use aptos_framework::coin;

    #[test]
    #[expected_failure(abort_code = 101)]
    fun test_register_pool_fails_if_corresponding_lp_coin_already_exists() {
        let (_, pool_owner) = test_lp::setup_coins_and_pool_owner();

        let (mint_cap, burn_cap) =
            lp_account::register_lp_coin_test<BTC, USDT>();
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);

        liquidity_pool::register<BTC, USDT>(
            &pool_owner,
            utf8(b"Liquidswap LP"),
            utf8(b"LP-BTC-USDT"),
            2
        );
    }
}
