#[test_only]
module MultiSwap::ScriptsTests {
    use Std::Signer;

    use AptosFramework::Coin;
    use AptosFramework::Genesis;
    use TestCoinAdmin::TestCoins::{Self, USDT, BTC};
    use TestPoolOwner::TestLP::LP;

    use MultiSwap::LiquidityPool;
    use MultiSwap::Router;
    use MultiSwap::Scripts;

    fun register_pool_with_existing_liquidity(
        coin_admin: &signer,
        pool_owner: &signer,
        x_val: u64,
        y_val: u64
    ) {
        Router::register_liquidity_pool<BTC, USDT, LP>(pool_owner);

        let pool_owner_addr = Signer::address_of(pool_owner);
        if (x_val != 0 && y_val != 0) {
            let btc_coins = TestCoins::mint<BTC>(coin_admin, x_val);
            let usdt_coins = TestCoins::mint<USDT>(coin_admin, y_val);
            let lp_coins =
                LiquidityPool::add_liquidity<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
            Coin::register_internal<LP>(pool_owner);
            Coin::deposit<LP>(pool_owner_addr, lp_coins);
        };
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    public(script) fun test_register_pool_with_script(
        core: signer,
        coin_admin: signer,
        pool_owner: signer
    ) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);

        let pool_owner_addr = Signer::address_of(&pool_owner);

        Scripts::register_pool<BTC, USDT, LP>(pool_owner);

        assert!(LiquidityPool::pool_exists_at<BTC, USDT, LP>(pool_owner_addr), 1);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    public(script) fun test_register_and_add_liquidity_in_one_script(
        core: signer,
        coin_admin: signer,
        pool_owner: signer
    ) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);

        let btc_coins = TestCoins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = TestCoins::mint<USDT>(&coin_admin, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, btc_coins);
        Coin::deposit(pool_owner_addr, usdt_coins);

        Scripts::register_pool_with_liquidity<BTC, USDT, LP>(
            pool_owner,
            101,
            101,
            10100,
            10100
        );

        assert!(LiquidityPool::pool_exists_at<BTC, USDT, LP>(pool_owner_addr), 1);

        assert!(Coin::balance<BTC>(pool_owner_addr) == 0, 2);
        assert!(Coin::balance<USDT>(pool_owner_addr) == 0, 3);
        assert!(Coin::balance<LP>(pool_owner_addr) == 10, 4);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    public(script) fun test_add_liquidity(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);
        register_pool_with_existing_liquidity(&coin_admin, &pool_owner, 0, 0);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        let btc_coins = TestCoins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = TestCoins::mint<USDT>(&coin_admin, 10100);

        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, btc_coins);
        Coin::deposit(pool_owner_addr, usdt_coins);

        Coin::register_internal<LP>(&pool_owner);

        Scripts::add_liquidity<BTC, USDT, LP>(
            pool_owner,
            pool_owner_addr,
            101,
            10100,
            101,
            10100
        );

        assert!(Coin::balance<BTC>(pool_owner_addr) == 0, 1);
        assert!(Coin::balance<USDT>(pool_owner_addr) == 0, 2);
        assert!(Coin::balance<LP>(pool_owner_addr) == 10, 3);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    public(script) fun test_remove_liquidity(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);
        register_pool_with_existing_liquidity(&coin_admin, &pool_owner, 0, 0);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        let btc_coins = TestCoins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = TestCoins::mint<USDT>(&coin_admin, 10100);

        let (btc, usdt, lp) =
            Router::add_liquidity<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins, 101, 10100);
        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);
        Coin::register_internal<LP>(&pool_owner);
        Coin::deposit(pool_owner_addr, btc);
        Coin::deposit(pool_owner_addr, usdt);
        Coin::deposit(pool_owner_addr, lp);

        Scripts::remove_liquidity<BTC, USDT, LP>(pool_owner, pool_owner_addr, 10, 98, 10000);

        assert!(Coin::balance<LP>(pool_owner_addr) == 0, 1);
        assert!(Coin::balance<BTC>(pool_owner_addr) == 101, 2);
        assert!(Coin::balance<USDT>(pool_owner_addr) == 10100, 3);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    public(script) fun test_swap_exact_btc_for_usdt(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);
        register_pool_with_existing_liquidity(&coin_admin, &pool_owner, 101, 10100);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        let btc_coins_to_swap = TestCoins::mint<BTC>(&coin_admin, 10);
        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, btc_coins_to_swap);

        Scripts::swap<BTC, USDT, LP>(pool_owner, pool_owner_addr, 10, 900);

        assert!(Coin::balance<BTC>(pool_owner_addr) == 0, 1);
        assert!(Coin::balance<USDT>(pool_owner_addr) == 907, 2);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    public(script) fun test_swap_btc_for_exact_usdt(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);
        register_pool_with_existing_liquidity(&coin_admin, &pool_owner, 101, 10100);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        let btc_coins_to_swap = TestCoins::mint<BTC>(&coin_admin, 10);
        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, btc_coins_to_swap);

        Scripts::swap_into<BTC, USDT, LP>(pool_owner, pool_owner_addr, 10, 700);

        assert!(Coin::balance<BTC>(pool_owner_addr) == 2, 1);
        assert!(Coin::balance<USDT>(pool_owner_addr) == 700, 2);
    }
}
