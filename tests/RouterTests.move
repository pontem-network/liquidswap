#[test_only]
module MultiSwap::RouterTests {
    use Std::Signer;

    use AptosFramework::Genesis;
    use AptosFramework::Coin;

    use MultiSwap::LiquidityPool;
    use MultiSwap::Router;
    use AptosFramework::Timestamp;

    use TestCoinAdmin::TestCoins::{Self, USDT, BTC};
    use TestPoolOwner::TestLP::LP;

    fun register_pool_with_liquidity(coin_admin: &signer,
                                     pool_owner: &signer,
                                     x_val: u64, y_val: u64)  {

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
    fun test_add_initial_liquidity(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 0, 0);

        let btc_coins = TestCoins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = TestCoins::mint(&coin_admin, 10100);
        let pool_addr = Signer::address_of(&pool_owner);

        let (coin_x, coin_y, lp_coins) =
            Router::add_liquidity<BTC, USDT, LP>(
                pool_addr,
                btc_coins,
                101,
                usdt_coins,
                10100
            );

        assert!(Coin::value(&coin_x) == 0, 1);
        assert!(Coin::value(&coin_y) == 0, 2);
        // 1010 - 1000 = 10
        assert!(Coin::value(&lp_coins) == 10, 3);

        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);
        Coin::register_internal<LP>(&pool_owner);

        Coin::deposit(pool_addr, coin_x);
        Coin::deposit(pool_addr, coin_y);
        Coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_add_liquidity_to_pool(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let btc_coins = TestCoins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = TestCoins::mint<USDT>(&coin_admin, 9000);
        let pool_addr = Signer::address_of(&pool_owner);

        let (coin_x, coin_y, lp_coins) =
            Router::add_liquidity<BTC, USDT, LP>(pool_addr, btc_coins, 10, usdt_coins, 9000);
        // 101 - 90 = 11
        assert!(Coin::value(&coin_x) == 11, 1);
        assert!(Coin::value(&coin_y) == 0, 2);
        // 8.91 ~ 8
        assert!(Coin::value(&lp_coins) == 8, 3);

        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);

        Coin::deposit(pool_addr, coin_x);
        Coin::deposit(pool_addr, coin_y);
        Coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_add_liquidity_to_pool_reverse(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let btc_coins = TestCoins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = TestCoins::mint<USDT>(&coin_admin, 9000);
        let pool_addr = Signer::address_of(&pool_owner);

        let (coin_y, coin_x, lp_coins) =
            Router::add_liquidity<USDT, BTC, LP>(pool_addr, usdt_coins, 9000, btc_coins, 10);
        // 101 - 90 = 11
        assert!(Coin::value(&coin_x) == 11, 1);
        assert!(Coin::value(&coin_y) == 0, 2);
        // 8.91 ~ 8
        assert!(Coin::value(&lp_coins) == 8, 3);

        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);

        Coin::deposit(pool_addr, coin_x);
        Coin::deposit(pool_addr, coin_y);
        Coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_remove_liquidity(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let lp_coins_val = 2u64;
        let pool_addr = Signer::address_of(&pool_owner);
        let lp_coins_to_burn = Coin::withdraw<LP>(&pool_owner, lp_coins_val);

        let (x_out, y_out) = Router::get_reserves_for_lp_coins<BTC, USDT, LP>(
            pool_addr,
            lp_coins_val
        );
        let (coin_x, coin_y) =
            Router::remove_liquidity<BTC, USDT, LP>(pool_addr, lp_coins_to_burn, x_out, y_out);

        let (usdt_reserve, btc_reserve) = Router::get_reserves_size<USDT, BTC, LP>(pool_addr);
        assert!(usdt_reserve == 8080, 3);
        assert!(btc_reserve == 81, 4);

        assert!(Coin::value(&coin_x) == x_out, 1);
        assert!(Coin::value(&coin_y) == y_out, 2);

        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);

        Coin::deposit(pool_addr, coin_x);
        Coin::deposit(pool_addr, coin_y);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_swap_exact_coin_for_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let btc_coins_to_swap = TestCoins::mint<BTC>(&coin_admin, 1);

        let usdt_coins =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_owner_addr, btc_coins_to_swap, 90);
        assert!(Coin::value(&usdt_coins) == 98, 1);

        TestCoins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_swap_exact_coin_for_coin_reverse(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let usdt_coins_to_swap = TestCoins::mint<USDT>(&coin_admin, 110);

        let btc_coins =
            Router::swap_exact_coin_for_coin<USDT, BTC, LP>(pool_owner_addr, usdt_coins_to_swap, 1);
        assert!(Coin::value(&btc_coins) == 1, 1);

        TestCoins::burn(&coin_admin, btc_coins);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_swap_coin_for_exact_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let btc_coins_to_swap = TestCoins::mint<BTC>(&coin_admin, 1);

        let (remainder, usdt_coins) =
            Router::swap_coin_for_exact_coin<BTC, USDT, LP>(pool_owner_addr, btc_coins_to_swap, 98);

        assert!(Coin::value(&usdt_coins) == 98, 1);
        assert!(Coin::value(&remainder) == 0, 2);

        TestCoins::burn(&coin_admin, usdt_coins);
        Coin::destroy_zero(remainder);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_swap_coin_for_exact_coin_reverse(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let usdt_coins_to_swap = TestCoins::mint<USDT>(&coin_admin, 1114);

        let (remainder, btc_coins) =
            Router::swap_coin_for_exact_coin<USDT, BTC, LP>(pool_owner_addr, usdt_coins_to_swap, 10);

        assert!(Coin::value(&btc_coins) == 10, 1);
        assert!(Coin::value(&remainder) == 0, 2);

        TestCoins::burn(&coin_admin, btc_coins);
        Coin::destroy_zero(remainder);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    #[expected_failure(abort_code = 26887)]
    fun test_fail_if_price_fell_behind_threshold(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let btc_coin_to_swap = TestCoins::mint<BTC>(&coin_admin, 1);

        let usdt_coins =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_owner_addr, btc_coin_to_swap, 102);

        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, usdt_coins);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    #[expected_failure(abort_code = 26631)]
    fun test_fail_if_swap_zero_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let btc_coins_to_swap = TestCoins::mint<BTC>(&coin_admin, 0);

        let usdt_coins =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_owner_addr, btc_coins_to_swap, 0);

        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, usdt_coins);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_returned_usdt_proportially_decrease_for_big_swaps(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let btc_coins_to_swap = TestCoins::mint<BTC>(&coin_admin, 200);

        let usdt_coins =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_owner_addr, btc_coins_to_swap, 1);
        assert!(Coin::value(&usdt_coins) == 6704, 1);

        let (btc_reserve, usdt_reserve) = Router::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(btc_reserve == 301, 2);
        assert!(usdt_reserve == 3396, 3);
        assert!(Router::current_price<USDT, BTC, LP>(pool_owner_addr) == 11, 4);

        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, usdt_coins);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_pool_exists(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        Router::register_liquidity_pool<BTC, USDT, LP>(&pool_owner);

        assert!(Router::pool_exists_at<BTC, USDT, LP>(Signer::address_of(&pool_owner)), 1);
        assert!(Router::pool_exists_at<USDT, BTC, LP>(Signer::address_of(&pool_owner)), 2);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_cumulative_prices_after_swaps(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);
        Coin::register_internal<USDT>(&pool_owner);

        let pool_addr = Signer::address_of(&pool_owner);
        let (btc_price, usdt_price, ts) =
            Router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_price == 0, 1);
        assert!(usdt_price == 0, 2);
        assert!(ts == 0, 3);

        // 2 seconds
        Timestamp::update_global_time_for_test(2000000);

        let btc_to_swap = TestCoins::mint<BTC>(&coin_admin, 1);
        let usdts =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_addr, btc_to_swap, 95);
        Coin::deposit(pool_addr, usdts);

        let (btc_cum_price, usdt_cum_price, last_timestamp) =
            Router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_cum_price == 3689348814741910323000, 4);
        assert!(usdt_cum_price == 368934881474191032, 5);
        assert!(last_timestamp == 2, 6);

        // 4 seconds
        Timestamp::update_global_time_for_test(4000000);

        let btc_to_swap = TestCoins::mint<BTC>(&coin_admin, 2);
        let usdts =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_addr, btc_to_swap, 190);
        Coin::deposit(pool_addr, usdts);

        let (btc_cum_price, usdt_cum_price, last_timestamp) =
            Router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_cum_price == 7307080858374124739730, 7);
        assert!(usdt_cum_price == 745173212911578406, 8);
        assert!(last_timestamp == 4, 9);
    }
}
