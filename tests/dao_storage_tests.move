#[test_only]
module liquidswap::dao_storage_tests {
    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::coins;
    use aptos_framework::genesis;

    use liquidswap::dao_storage;
    use liquidswap::liquidity_pool;
    use liquidswap::router;

    use test_coin_admin::test_coins;
    use test_coin_admin::test_coins::{BTC, USDT};
    use test_pool_owner::test_lp::LP;
    use test_helpers::test_account::create_account;

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner, dao_admin_acc = @dao_admin)]
    fun test_split_third_of_fees_into_dao_storage_account(
        core: signer,
        coin_admin: signer,
        pool_owner: signer,
        dao_admin_acc: signer,
    ) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);
        create_account(&dao_admin_acc);

        test_coins::register_coins(&coin_admin);

        // 0.3% fee
        router::register_pool<BTC, USDT, LP>(&pool_owner, 2);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 1000);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 960
            );

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 100999, 2);
        assert!(y_res == 99040, 3);

        let (dao_x, dao_y) = dao_storage::get_storage_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(dao_x == 1, 4);
        assert!(dao_y == 0, 5);

        let (x, y) =
            dao_storage::withdraw<BTC, USDT, LP>(&dao_admin_acc, pool_owner_addr, 1, 0);
        assert!(coin::value(&x) == 1, 6);
        assert!(coin::value(&y) == 0, 7);

        test_coins::burn(&coin_admin, x);
        test_coins::burn(&coin_admin, y);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }
}
