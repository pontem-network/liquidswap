#[test_only]
module liquidswap::gauge_tests {
    use aptos_framework::genesis;
    use test_helpers::test_account::create_account;
    use test_coin_admin::test_coins;
    use liquidswap::liquidity_pool;
    use test_coin_admin::test_coins::{BTC, USDT};
    use test_pool_owner::test_lp::LP;
    use std::string::utf8;
    use liquidswap::gauge;
    use std::signer;

    #[test(
        core = @core_resources,
        coin_admin = @test_coin_admin,
        pool_owner = @test_pool_owner,
        gauge_admin = @gauge_admin
    )]
    fun test_vote_for_liquidity_pool(core: signer, coin_admin: signer, pool_owner: signer, gauge_admin: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-BTC-USDT"),
            2
        );
        gauge::initialize(&gauge_admin);

        gauge::vote_for_liquidity_pool<BTC, USDT, LP>(
            signer::address_of(&pool_owner),
            ve_nft,
            10
        );
    }
}
