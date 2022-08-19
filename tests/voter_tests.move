#[test_only]
module liquidswap::voter_tests {
    use std::string::utf8;

    use aptos_framework::genesis;

    use liquidswap::voter;
    use liquidswap::liquidity_pool;

    use test_coin_admin::test_coins::{Self, BTC, USDT};
    use test_helpers::test_account::create_account;
    use test_pool_owner::test_lp::LP;

    #[test(
        coin_admin = @test_coin_admin,
        pool_owner = @test_pool_owner,
        gov_admin = @gov_admin
    )]
    fun test_vote_for_liquidity_pool(coin_admin: signer, pool_owner: signer, gov_admin: signer) {
        genesis::setup();

        create_account(&coin_admin);
        create_account(&pool_owner);
        create_account(&gov_admin);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-BTC-USDT"),
            2
        );
        voter::initialize(&gov_admin);
    }
}
