#[test_only]
module liquidswap::lp_account_tests {
    use std::string::utf8;

    use liquidswap::liquidity_pool;
    use test_coin_admin::test_coins::{BTC, USDT};
    use test_helpers::test_pool;
    use liquidswap::lp_account;
    use liquidswap::coin_helper;
    use liquidswap::liquidity_pool::Uncorrelated;
    use aptos_framework::coin;

    #[test]
    #[expected_failure(abort_code = 101)]
    fun test_register_pool_fails_if_corresponding_lp_coin_already_exists() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        let (lp_name, lp_symbol) = coin_helper::generate_lp_name_and_symbol<BTC, USDT, Uncorrelated>();
        let (mint_cap, burn_cap) =
            lp_account::register_lp_coin_test<BTC, USDT, Uncorrelated>(lp_name, lp_symbol);
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);

        liquidity_pool::register<BTC, USDT, Uncorrelated>(
            &lp_owner,
            utf8(b"Liquidswap LP"),
            utf8(b"LP-BTC-USDT")
        );
    }
}
