#[test_only]
module MultiSwap::RouterTests {
    use Std::Signer;

    use AptosFramework::Coin;
    use AptosFramework::Genesis;
    use AptosFramework::Timestamp;

    use MultiSwap::LiquidityPool;
    use MultiSwap::Router;
    use TestCoinAdmin::TestCoins::{Self, USDT, BTC, USDC};
    use TestPoolOwner::TestLP::LP;

    const U64_MAX: u64 = 18446744073709551615;

    fun register_pool_with_liquidity(coin_admin: &signer,
                                     pool_owner: &signer,
                                     x_val: u64, y_val: u64) {
        Router::register<BTC, USDT, LP>(pool_owner, 2);

        let pool_owner_addr = Signer::address_of(pool_owner);
        if (x_val != 0 && y_val != 0) {
            let btc_coins = TestCoins::mint<BTC>(coin_admin, x_val);
            let usdt_coins = TestCoins::mint<USDT>(coin_admin, y_val);
            let lp_coins =
                LiquidityPool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
            Coin::register_internal<LP>(pool_owner);
            Coin::deposit<LP>(pool_owner_addr, lp_coins);
        };
    }

    fun register_stable_pool_with_liquidity(coin_admin: &signer, pool_owner: &signer, x_val: u64, y_val: u64) {
        Router::register<USDC, USDT, LP>(pool_owner, 1);

        let pool_owner_addr = Signer::address_of(pool_owner);
        if (x_val != 0 && y_val != 0) {
            let usdc_coins = TestCoins::mint<USDC>(coin_admin, x_val);
            let usdt_coins = TestCoins::mint<USDT>(coin_admin, y_val);
            let lp_coins =
                LiquidityPool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
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
            Router::mint<BTC, USDT, LP>(
                pool_addr,
                btc_coins,
                101,
                usdt_coins,
                10100
            );

        assert!(Coin::value(&coin_x) == 0, 0);
        assert!(Coin::value(&coin_y) == 0, 1);
        // 1010 - 1000 = 10
        assert!(Coin::value(&lp_coins) == 10, 2);

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
            Router::mint<BTC, USDT, LP>(pool_addr, btc_coins, 10, usdt_coins, 9000);
        // 101 - 90 = 11
        assert!(Coin::value(&coin_x) == 11, 0);
        assert!(Coin::value(&coin_y) == 0, 1);
        // 8.91 ~ 8
        assert!(Coin::value(&lp_coins) == 8, 2);

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
            Router::mint<USDT, BTC, LP>(pool_addr, usdt_coins, 9000, btc_coins, 10);
        // 101 - 90 = 11
        assert!(Coin::value(&coin_x) == 11, 0);
        assert!(Coin::value(&coin_y) == 0, 1);
        // 8.91 ~ 8
        assert!(Coin::value(&lp_coins) == 8, 2);

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
            Router::burn<BTC, USDT, LP>(pool_addr, lp_coins_to_burn, x_out, y_out);

        let (usdt_reserve, btc_reserve) = Router::get_reserves_size<USDT, BTC, LP>(pool_addr);
        assert!(usdt_reserve == 8080, 0);
        assert!(btc_reserve == 81, 1);

        assert!(Coin::value(&coin_x) == x_out, 2);
        assert!(Coin::value(&coin_y) == y_out, 3);

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

        let usdt_coins = Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_owner_addr, btc_coins_to_swap, 90);
        assert!(Coin::value(&usdt_coins) == 98, 0);

        TestCoins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_swap_exact_coin_for_coin_reverse(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let usdt_coins_to_swap = TestCoins::mint<USDT>(&coin_admin, 110);

        let btc_coins = Router::swap_exact_coin_for_coin<USDT, BTC, LP>(pool_owner_addr, usdt_coins_to_swap, 1);
        assert!(Coin::value(&btc_coins) == 1, 0);

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

        assert!(Coin::value(&usdt_coins) == 98, 0);
        assert!(Coin::value(&remainder) == 0, 1);

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

        assert!(Coin::value(&btc_coins) == 10, 0);
        assert!(Coin::value(&remainder) == 0, 1);

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
        assert!(Coin::value(&usdt_coins) == 6704, 0);

        let (btc_reserve, usdt_reserve) = Router::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(btc_reserve == 301, 1);
        assert!(usdt_reserve == 3396, 2);
        assert!(Router::current_price<USDT, BTC, LP>(pool_owner_addr) == 11, 3);

        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, usdt_coins);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_pool_exists(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        Router::register<BTC, USDT, LP>(&pool_owner, 2);

        assert!(Router::pool_exists_at<BTC, USDT, LP>(Signer::address_of(&pool_owner)), 0);
        assert!(Router::pool_exists_at<USDT, BTC, LP>(Signer::address_of(&pool_owner)), 1);
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
        assert!(btc_price == 0, 0);
        assert!(usdt_price == 0, 1);
        assert!(ts == 0, 2);

        // 2 seconds
        Timestamp::update_global_time_for_test(2000000);

        let btc_to_swap = TestCoins::mint<BTC>(&coin_admin, 1);
        let usdts =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_addr, btc_to_swap, 95);
        Coin::deposit(pool_addr, usdts);

        let (btc_cum_price, usdt_cum_price, last_timestamp) =
            Router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_cum_price == 3689348814741910323000, 3);
        assert!(usdt_cum_price == 368934881474191032, 4);
        assert!(last_timestamp == 2, 5);

        // 4 seconds
        Timestamp::update_global_time_for_test(4000000);

        let btc_to_swap = TestCoins::mint<BTC>(&coin_admin, 2);
        let usdts =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_addr, btc_to_swap, 190);
        Coin::deposit(pool_addr, usdts);

        let (btc_cum_price, usdt_cum_price, last_timestamp) =
            Router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_cum_price == 7307080858374124739730, 6);
        assert!(usdt_cum_price == 745173212911578406, 7);
        assert!(last_timestamp == 4, 8);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_stable_curve_swap_exact(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = Signer::address_of(&pool_owner);

        assert!(Router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        // Let's exact amount of USDC to USDT.
        let usdc_to_swap_val = 1258044;

        let usdc_to_swap = TestCoins::mint<USDC>(&coin_admin, usdc_to_swap_val);

        let usdt_swapped = Router::swap_exact_coin_for_coin<USDC, USDT, LP>(
            pool_owner_addr,
            usdc_to_swap,
            125426899,
        );
        // Value 125426899 checked with coin_out func, yet can't run it, as getting timeout on test.
        assert!(Coin::value(&usdt_swapped) == 125426900, 1);

        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, usdt_swapped);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_stable_curve_swap_exact_vise_vera(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = Signer::address_of(&pool_owner);

        assert!(Router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        // Let's swap USDT -> USDC.
        let usdt_to_swap_val = 125804412;
        let usdt_to_swap = TestCoins::mint<USDT>(&coin_admin, usdt_to_swap_val);

        let usdc_swapped = Router::swap_exact_coin_for_coin<USDT, USDC, LP>(
            pool_owner_addr,
            usdt_to_swap,
            1254269,
        );
        assert!(Coin::value(&usdc_swapped) == 1254269, 1);
        Coin::register_internal<USDC>(&pool_owner);
        Coin::deposit(pool_owner_addr, usdc_swapped);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_stable_curve_exact_swap(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = Signer::address_of(&pool_owner);

        assert!(Router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        // I want to swap USDT to get at least 1258044 USDC.
        let usdc_to_get_val = 1258044;

        // I will need 125804400 USDT coins, verified with Router::get_amount_in.
        let usdt_to_swap = TestCoins::mint<USDT>(&coin_admin, 125804400);
        let (usdt_reminder, usdc_swapped) = Router::swap_coin_for_exact_coin<USDT, USDC, LP>(
            pool_owner_addr,
            usdt_to_swap,
            usdc_to_get_val,
        );

        assert!(Coin::value(&usdt_reminder) == 0, 1);
        assert!(Coin::value(&usdc_swapped) == usdc_to_get_val, 2);

        Coin::register_internal<USDC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);

        Coin::deposit(pool_owner_addr, usdt_reminder);
        Coin::deposit(pool_owner_addr, usdc_swapped);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_stable_curve_exact_swap_vise_vera(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);
        TestCoins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = Signer::address_of(&pool_owner);

        assert!(Router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        // I want to swap USDC to get 125804401 USDT.
        let usdt_to_get_val = 125804401;

        // I need at least 1258044 USDC coins, verified with Router::get_amount_in.
        let usdc_to_swap = TestCoins::mint<USDC>(&coin_admin, 1258044);
        let (usdc_reminder, usdt_swapped) = Router::swap_coin_for_exact_coin<USDC, USDT, LP>(
            pool_owner_addr,
            usdc_to_swap,
            usdt_to_get_val,
        );

        assert!(Coin::value(&usdc_reminder) == 0, 1);
        assert!(Coin::value(&usdt_swapped) == usdt_to_get_val, 2);

        Coin::register_internal<USDC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);

        Coin::deposit(pool_owner_addr, usdc_reminder);
        Coin::deposit(pool_owner_addr, usdt_swapped);
    }

    #[test]
    fun test_convert_with_current_price() {
        let a = Router::convert_with_current_price_for_test(U64_MAX, U64_MAX, U64_MAX);
        assert!(a == U64_MAX, 0);

        a = Router::convert_with_current_price_for_test(100, 100, 20);
        assert!(a == 20, 1);

        a = Router::convert_with_current_price_for_test(256, 8, 2);
        assert!(a == 64, 1);
    }

    #[test]
    #[expected_failure(abort_code = 25607)]
    fun test_fail_convert_with_current_price_coin_in_val() {
        Router::convert_with_current_price_for_test(0, 1, 1);
    }

    #[test]
    #[expected_failure(abort_code = 25863)]
    fun test_fail_convert_with_current_price_reserve_in_size() {
        Router::convert_with_current_price_for_test(1, 0, 1);
    }

    #[test]
    #[expected_failure(abort_code = 25863)]
    fun test_fail_convert_with_current_price_reserve_out_size() {
        Router::convert_with_current_price_for_test(1, 1, 0);
    }
}
