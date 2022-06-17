#[test_only]
module MultiSwap::DAOStorageTests {
    use Std::Signer;

    use AptosFramework::Coin;
    use AptosFramework::Genesis;

    use MultiSwap::DAOStorage;
    use MultiSwap::LiquidityPool;
    use MultiSwap::Router;
    use TestCoinAdmin::TestCoins;
    use TestCoinAdmin::TestCoins::{BTC, USDT};
    use TestPoolOwner::TestLP::LP;

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner, dao_admin_acc = @DAOAdmin)]
    fun test_split_third_of_fees_into_dao_storage_account(
        core: signer,
        coin_admin: signer,
        pool_owner: signer,
        dao_admin_acc: signer,
    ) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        // 3% fee
        Router::register_liquidity_pool<BTC, USDT, LP>(&pool_owner, 300);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let btc_coins = TestCoins::mint<BTC>(&coin_admin, 100000);
        let usdt_coins = TestCoins::mint<USDT>(&coin_admin, 100000);

        let lp_coins =
            LiquidityPool::add_liquidity<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        Coin::register_internal<LP>(&pool_owner);
        Coin::deposit(pool_owner_addr, lp_coins);

        let btc_coins_to_exchange = TestCoins::mint<BTC>(&coin_admin, 100);
        let (zero, usdt_coins) =
            LiquidityPool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                Coin::zero<USDT>(), 96
            );

        let (x_res, y_res) = LiquidityPool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 100099, 2);
        assert!(y_res == 99904, 3);

        let (dao_x, dao_y) = DAOStorage::get_storage_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(dao_x == 1, 4);
        assert!(dao_y == 0, 5);

        let (x, y) =
            DAOStorage::withdraw<BTC, USDT, LP>(&dao_admin_acc, pool_owner_addr, 1, 0);
        assert!(Coin::value(&x) == 1, 6);
        assert!(Coin::value(&y) == 0, 7);

        TestCoins::burn(&coin_admin, x);
        TestCoins::burn(&coin_admin, y);

        Coin::destroy_zero(zero);
        TestCoins::burn(&coin_admin, usdt_coins);
    }
}
