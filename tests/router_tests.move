#[test_only]
module liquidswap::router_tests {
    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use liquidswap_lp::lp_coin::LP;

    use liquidswap::curves::{Uncorrelated, Stable};
    use liquidswap::liquidity_pool;
    use liquidswap::router;
    use test_coin_admin::test_coins::{Self, USDT, BTC, USDC};
    use test_helpers::test_pool;

    const MAX_U64: u64 = 18446744073709551615;

    fun register_pool_with_liquidity(x_val: u64, y_val: u64): (signer, signer) {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();
        
        router::register_pool<BTC, USDT, Uncorrelated>(&lp_owner);

        let lp_owner_addr = signer::address_of(&lp_owner);
        if (x_val != 0 && y_val != 0) {
            let btc_coins = test_coins::mint<BTC>(&coin_admin, x_val);
            let usdt_coins = test_coins::mint<USDT>(&coin_admin, y_val);
            let lp_coins =
                liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
            coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
            coin::deposit<LP<BTC, USDT, Uncorrelated>>(lp_owner_addr, lp_coins);
        };

        (coin_admin, lp_owner)
    }

    fun register_stable_pool_with_liquidity(x_val: u64, y_val: u64): (signer, signer) {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();

        router::register_pool<USDC, USDT, Stable>(&lp_owner);

        let lp_owner_addr = signer::address_of(&lp_owner);
        if (x_val != 0 && y_val != 0) {
            let usdc_coins = test_coins::mint<USDC>(&coin_admin, x_val);
            let usdt_coins = test_coins::mint<USDT>(&coin_admin, y_val);
            let lp_coins =
                liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
            coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
            coin::deposit<LP<USDC, USDT, Stable>>(lp_owner_addr, lp_coins);
        };

        (coin_admin, lp_owner)
    }

    #[test]
    fun test_add_initial_liquidity() {
        let (coin_admin, lp_owner) = register_pool_with_liquidity(0, 0);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint(&coin_admin, 10100);
        

        let (coin_x, coin_y, lp_coins) =
            router::add_liquidity<BTC, USDT, Uncorrelated>(
                btc_coins,
                101,
                usdt_coins,
                10100,
            );

        assert!(coin::value(&coin_x) == 0, 0);
        assert!(coin::value(&coin_y) == 0, 1);
        // 1010 - 1000 = 10
        assert!(coin::value(&lp_coins) == 10, 2);

        coin::register<BTC>(&lp_owner);
        coin::register<USDT>(&lp_owner);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);

        coin::deposit(signer::address_of(&lp_owner), coin_x);
        coin::deposit(signer::address_of(&lp_owner), coin_y);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);
    }

    #[test]
    fun test_add_liquidity_to_pool() {
        let (coin_admin, lp_owner) = register_pool_with_liquidity(101, 10100);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 9000);
        

        let (coin_x, coin_y, lp_coins) =
            router::add_liquidity<BTC, USDT, Uncorrelated>(
                btc_coins,
                10,
                usdt_coins,
                9000,
            );
        // 101 - 90 = 11
        assert!(coin::value(&coin_x) == 11, 0);
        assert!(coin::value(&coin_y) == 0, 1);
        // 8.91 ~ 8
        assert!(coin::value(&lp_coins) == 8, 2);

        coin::register<BTC>(&lp_owner);
        coin::register<USDT>(&lp_owner);

        coin::deposit(signer::address_of(&lp_owner), coin_x);
        coin::deposit(signer::address_of(&lp_owner), coin_y);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);
    }

    #[test]
    #[expected_failure(abort_code = 208)]
    fun test_cannot_add_liquidity_to_pool_in_reverse_order() {
        let (coin_admin, lp_owner) = register_pool_with_liquidity(101, 10100);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 9000);

        let (coin_y, coin_x, lp_coins) =
            router::add_liquidity<USDT, BTC, Uncorrelated>(
                usdt_coins,
                9000,
                btc_coins,
                10,
            );
        coin::register<BTC>(&lp_owner);
        coin::register<USDT>(&lp_owner);

        coin::deposit(signer::address_of(&lp_owner), coin_x);
        coin::deposit(signer::address_of(&lp_owner), coin_y);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);
    }

    #[test]
    #[expected_failure(abort_code = 203)]
    fun test_add_liquidity_to_fail_with_insufficient_x_coins() {
        let (coin_admin, lp_owner) = register_pool_with_liquidity(0, 0);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 9000);

        let (coin_y, coin_x, lp_coins) = router::add_liquidity<BTC, USDT, Uncorrelated>(
            btc_coins,
            102,
            usdt_coins,
            9000,
        );

        coin::deposit(signer::address_of(&lp_owner), coin_x);
        coin::deposit(signer::address_of(&lp_owner), coin_y);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);
    }

    #[test]
    #[expected_failure(abort_code = 202)]
    fun test_add_liquidity_to_fail_with_insufficient_y_coins() {
        let (coin_admin, lp_owner) = register_pool_with_liquidity(0, 0);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 9000);

        let (coin_y, coin_x, lp_coins) = router::add_liquidity<BTC, USDT, Uncorrelated>(
            btc_coins,
            101,
            usdt_coins,
            10000,
        );

        coin::deposit(signer::address_of(&lp_owner), coin_x);
        coin::deposit(signer::address_of(&lp_owner), coin_y);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);
    }

    #[test]
    fun test_remove_liquidity() {
        let (_, lp_owner) = register_pool_with_liquidity(101, 10100);

        let lp_coins_val = 2u64;
        
        let lp_coins_to_burn = coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&lp_owner, lp_coins_val);

        let (x_out, y_out) = router::get_reserves_for_lp_coins<BTC, USDT, Uncorrelated>(
            lp_coins_val
        );
        let (coin_x, coin_y) =
            router::remove_liquidity<BTC, USDT, Uncorrelated>(lp_coins_to_burn, x_out, y_out);

        let (usdt_reserve, btc_reserve) = router::get_reserves_size<USDT, BTC, Uncorrelated>();
        assert!(usdt_reserve == 8080, 0);
        assert!(btc_reserve == 81, 1);

        assert!(coin::value(&coin_x) == x_out, 2);
        assert!(coin::value(&coin_y) == y_out, 3);

        coin::register<BTC>(&lp_owner);
        coin::register<USDT>(&lp_owner);

        coin::deposit(signer::address_of(&lp_owner), coin_x);
        coin::deposit(signer::address_of(&lp_owner), coin_y);
    }

    // TODO: test that one can't remove liquidity with reverse coin order
    //  (it's checked with generic params, so I don't know)

    #[test]
    #[expected_failure(abort_code = 205)]
    fun test_remove_liquidity_to_fail_if_less_than_minimum_x() {
        let (_, lp_owner) = register_pool_with_liquidity(101, 10100);

        let lp_coins_val = 2u64;
        
        let lp_coins_to_burn = coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&lp_owner, lp_coins_val);

        let (x_out, y_out) = router::get_reserves_for_lp_coins<BTC, USDT, Uncorrelated>(
            lp_coins_val
        );
        let (coin_x, coin_y) =
            router::remove_liquidity<BTC, USDT, Uncorrelated>(lp_coins_to_burn, x_out * 2, y_out);

        coin::deposit(signer::address_of(&lp_owner), coin_x);
        coin::deposit(signer::address_of(&lp_owner), coin_y);
    }

    #[test]
    #[expected_failure(abort_code = 205)]
    fun test_remove_liquidity_to_fail_if_less_than_minimum_y() {
        let (_, lp_owner) = register_pool_with_liquidity(101, 10100);

        let lp_coins_val = 2u64;
        
        let lp_coins_to_burn = coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&lp_owner, lp_coins_val);

        let (x_out, y_out) = router::get_reserves_for_lp_coins<BTC, USDT, Uncorrelated>(
            lp_coins_val
        );
        let (coin_x, coin_y) =
            router::remove_liquidity<BTC, USDT, Uncorrelated>(lp_coins_to_burn, x_out, y_out * 2);

        coin::deposit(signer::address_of(&lp_owner), coin_x);
        coin::deposit(signer::address_of(&lp_owner), coin_y);
    }

    #[test]
    fun test_swap_exact_coin_for_coin() {
        let (coin_admin, _) = register_pool_with_liquidity(101, 10100);

        let btc_coins_swap_val = 1;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<BTC, USDT, Uncorrelated>(btc_coins_swap_val);

        let usdt_coins = router::swap_exact_coin_for_coin<BTC, USDT, Uncorrelated>(
            btc_coins_to_swap,
            usdt_amount_out,
        );
        assert!(coin::value(&usdt_coins) == usdt_amount_out, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_exact_coin_for_coin_1() {
        let (coin_admin, _) = register_pool_with_liquidity(1230000000, 147600000000);

        let btc_to_swap_val = 572123800;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_to_swap_val);

        let usdt_to_get_val = router::get_amount_out<BTC, USDT, Uncorrelated>(btc_to_swap_val);

        let usdt_coins = router::swap_exact_coin_for_coin<BTC, USDT, Uncorrelated>(
            btc_coins_to_swap,
            usdt_to_get_val,
        );
        assert!(coin::value(&usdt_coins) == usdt_to_get_val, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_exact_coin_for_coin_2() {
        let (coin_admin, _) = register_pool_with_liquidity(10000000000, 2800000000000);

        let usdt_to_swap_val = 257817560;
        let usdt_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_to_swap_val);

        let btc_to_get_val = router::get_amount_out<USDT, BTC, Uncorrelated>(usdt_to_swap_val);

        let usdt_coins = router::swap_exact_coin_for_coin<USDT, BTC, Uncorrelated>(
            usdt_to_swap,
            btc_to_get_val,
        );
        assert!(coin::value(&usdt_coins) == btc_to_get_val, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_exact_coin_for_coin_reverse() {
        let (coin_admin, _) = register_pool_with_liquidity(101, 10100);

        let usdt_coins_to_swap = test_coins::mint<USDT>(&coin_admin, 110);

        let btc_coins = router::swap_exact_coin_for_coin<USDT, BTC, Uncorrelated>(
            usdt_coins_to_swap,
            1,
        );
        assert!(coin::value(&btc_coins) == 1, 0);

        test_coins::burn(&coin_admin, btc_coins);
    }

    #[test]
    #[expected_failure(abort_code = 205)]
    fun test_swap_exact_coin_for_coin_to_fail_if_less_than_minimum_out() {
        let (coin_admin, _) = register_pool_with_liquidity(101, 10100);

        let btc_coins_swap_val = 1;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<BTC, USDT, Uncorrelated>(btc_coins_swap_val);

        let usdt_coins = router::swap_exact_coin_for_coin<BTC, USDT, Uncorrelated>(
            btc_coins_to_swap,
            usdt_amount_out * 2,
        );

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_coin_for_exact_coin() {
        let (coin_admin, _) = register_pool_with_liquidity(101, 10100);

        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 1);

        let (remainder, usdt_coins) =
            router::swap_coin_for_exact_coin<BTC, USDT, Uncorrelated>(
                btc_coins_to_swap,
                98,
            );

        assert!(coin::value(&usdt_coins) == 98, 0);
        assert!(coin::value(&remainder) == 0, 1);

        test_coins::burn(&coin_admin, usdt_coins);
        coin::destroy_zero(remainder);
    }

    #[test]
    fun test_swap_coin_for_exact_coin_1() {
        let (coin_admin, _) = register_pool_with_liquidity(50000000000, 13500000000000);

        let usdt_coins_to_get = 5292719411;
        let btc_coins_to_swap_val = router::get_amount_in<BTC, USDT, Uncorrelated>(usdt_coins_to_get);
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_coins_to_swap_val);

        let (remainder, usdt_coins) =
            router::swap_coin_for_exact_coin<BTC, USDT, Uncorrelated>(
                btc_coins_to_swap,
                usdt_coins_to_get,
            );

        assert!(coin::value(&usdt_coins) == usdt_coins_to_get, 0);
        assert!(coin::value(&remainder) == 0, 1);

        test_coins::burn(&coin_admin, usdt_coins);
        coin::destroy_zero(remainder);
    }

    #[test]
    fun test_swap_coin_for_exact_coin_2() {
        let (coin_admin, _) = register_pool_with_liquidity(10000000000, 2800000000000);

        let btc_coins_to_get = 185200481;
        let usdt_coins_to_swap_val = router::get_amount_in<USDT, BTC, Uncorrelated>(btc_coins_to_get);

        let usdc_coins_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_coins_to_swap_val);

        let (remainder, btc_coins) =
            router::swap_coin_for_exact_coin<USDT, BTC, Uncorrelated>(
                usdc_coins_to_swap,
                btc_coins_to_get,
            );

        assert!(coin::value(&btc_coins) == btc_coins_to_get, 1);
        assert!(coin::value(&remainder) == 0, 2);

        test_coins::burn(&coin_admin, btc_coins);
        coin::destroy_zero(remainder);
    }

    #[test]
    #[expected_failure(abort_code = 206)]
    fun test_swap_coin_for_exact_coin_router_check_fails() {
        let (coin_admin, _) = register_pool_with_liquidity(10000000000, 2800000000000);

        let btc_coins_to_swap_val = 100000000;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_coins_to_swap_val);
        let usdt_to_get = router::get_amount_out<BTC, USDT, Uncorrelated>(btc_coins_to_swap_val) + 1;

        let (remainder, usdt_coins) =
            router::swap_coin_for_exact_coin<BTC, USDT, Uncorrelated>(
                btc_coins_to_swap,
                usdt_to_get,
            );

        assert!(coin::value(&usdt_coins) == usdt_to_get, 1);
        assert!(coin::value(&remainder) == 0, 2);

        test_coins::burn(&coin_admin, usdt_coins);
        coin::destroy_zero(remainder);
    }

    #[test]
    fun test_swap_coin_for_exact_coin_reverse() {
        let (coin_admin, _) = register_pool_with_liquidity(101, 10100);

        let usdt_coins_to_swap = test_coins::mint<USDT>(&coin_admin, 1114);

        let (remainder, btc_coins) =
            router::swap_coin_for_exact_coin<USDT, BTC, Uncorrelated>(
                usdt_coins_to_swap,
                10,
            );

        assert!(coin::value(&btc_coins) == 10, 0);
        assert!(coin::value(&remainder) == 0, 1);

        test_coins::burn(&coin_admin, btc_coins);
        coin::destroy_zero(remainder);
    }

    #[test]
    #[expected_failure(abort_code = 205)]
    fun test_fail_if_price_fell_behind_threshold() {
        let (coin_admin, lp_owner) = register_pool_with_liquidity(101, 10100);

        
        let btc_coin_to_swap = test_coins::mint<BTC>(&coin_admin, 1);

        let usdt_coins =
            router::swap_exact_coin_for_coin<BTC, USDT, Uncorrelated>(
                btc_coin_to_swap,
                102,
            );

        coin::register<USDT>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 104)]
    fun test_fail_if_swap_zero_coin() {
        let (coin_admin, lp_owner) = register_pool_with_liquidity(101, 10100);

        
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 0);

        let usdt_coins =
            router::swap_exact_coin_for_coin<BTC, USDT, Uncorrelated>(
                btc_coins_to_swap,
                0,
            );

        coin::register<USDT>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), usdt_coins);
    }

    #[test]
    fun test_returned_usdt_proportially_decrease_for_big_swaps() {
        let (coin_admin, lp_owner) = register_pool_with_liquidity(101, 10100);

        
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 200);

        let usdt_coins =
            router::swap_exact_coin_for_coin<BTC, USDT, Uncorrelated>(
                btc_coins_to_swap,
                1,
            );
        assert!(coin::value(&usdt_coins) == 6704, 0);

        let (btc_reserve, usdt_reserve) = router::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(btc_reserve == 301, 1);
        assert!(usdt_reserve == 3396, 2);
        assert!(router::current_price<USDT, BTC, Uncorrelated>() == 11, 3);

        coin::register<USDT>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), usdt_coins);
    }

    #[test]
    fun test_pool_exists() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        router::register_pool<BTC, USDT, Uncorrelated>(&lp_owner);

        assert!(router::is_swap_exists<BTC, USDT, Uncorrelated>(), 0);
        assert!(router::is_swap_exists<USDT, BTC, Uncorrelated>(), 1);
    }

    #[test]
    fun test_cumulative_prices_after_swaps() {
        let (coin_admin, lp_owner) = register_pool_with_liquidity(101, 10100);
        coin::register<USDT>(&lp_owner);

        
        let (btc_price, usdt_price, ts) =
            router::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(btc_price == 0, 0);
        assert!(usdt_price == 0, 1);
        assert!(ts == 0, 2);

        // 2 seconds
        timestamp::update_global_time_for_test(2000000);

        let btc_to_swap = test_coins::mint<BTC>(&coin_admin, 1);
        let usdts =
            router::swap_exact_coin_for_coin<BTC, USDT, Uncorrelated>(
                btc_to_swap,
                95,
            );
        coin::deposit(signer::address_of(&lp_owner), usdts);

        let (btc_cum_price, usdt_cum_price, last_timestamp) =
            router::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(btc_cum_price == 3689348814741910323000, 3);
        assert!(usdt_cum_price == 368934881474191032, 4);
        assert!(last_timestamp == 2, 5);

        // 4 seconds
        timestamp::update_global_time_for_test(4000000);

        let btc_to_swap = test_coins::mint<BTC>(&coin_admin, 2);
        let usdts =
            router::swap_exact_coin_for_coin<BTC, USDT, Uncorrelated>(
                btc_to_swap,
                190,
            );
        coin::deposit(signer::address_of(&lp_owner), usdts);

        let (btc_cum_price, usdt_cum_price, last_timestamp) =
            router::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(btc_cum_price == 7307080858374124739730, 6);
        assert!(usdt_cum_price == 745173212911578406, 7);
        assert!(last_timestamp == 4, 8);
    }

    #[test]
    fun test_stable_curve_swap_exact() {
        let (coin_admin, lp_owner) =
            register_stable_pool_with_liquidity(15000000000, 1500000000000);

        let usdc_to_swap_val = 1258044;

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);
        let usdt_to_get = router::get_amount_out<USDC, USDT, Stable>(usdc_to_swap_val);

        let usdt_swapped = router::swap_exact_coin_for_coin<USDC, USDT, Stable>(
            usdc_to_swap,
            usdt_to_get,
        );

        assert!(coin::value(&usdt_swapped) == usdt_to_get, 1);

        coin::register<USDT>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), usdt_swapped);
    }

    #[test]
    fun test_stable_curve_swap_exact_1() {
        let (coin_admin, lp_owner) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        let usdc_to_swap_val = 67482132;

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);
        let usdt_to_get = router::get_amount_out<USDC, USDT, Stable>(usdc_to_swap_val);

        let usdt_swapped = router::swap_exact_coin_for_coin<USDC, USDT, Stable>(
            usdc_to_swap,
            usdt_to_get,
        );
        assert!(coin::value(&usdt_swapped) == usdt_to_get, 1);

        coin::register<USDT>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), usdt_swapped);
    }

    #[test]
    fun test_stable_curve_swap_exact_2() {
        let (coin_admin, lp_owner) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        let usdc_to_swap_val = 1207482132;

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);
        let usdt_to_get = router::get_amount_out<USDC, USDT, Stable>(usdc_to_swap_val);

        let usdt_swapped = router::swap_exact_coin_for_coin<USDC, USDT, Stable>(
            usdc_to_swap,
            usdt_to_get,
        );
        assert!(coin::value(&usdt_swapped) == usdt_to_get, 1);

        coin::register<USDT>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), usdt_swapped);
    }

    #[test]
    fun test_stable_curve_swap_exact_3() {
        let (coin_admin, lp_owner) = register_stable_pool_with_liquidity(2930000000000, 293000000000000);

        

        

        let usdc_to_swap_val = 32207482132;

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);
        let usdt_to_get = router::get_amount_out<USDC, USDT, Stable>(usdc_to_swap_val);

        let usdt_swapped = router::swap_exact_coin_for_coin<USDC, USDT, Stable>(
            usdc_to_swap,
            usdt_to_get,
        );
        assert!(coin::value(&usdt_swapped) == usdt_to_get, 1);

        coin::register<USDT>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), usdt_swapped);
    }

    #[test]
    fun test_stable_curve_swap_exact_vice_versa() {
        let (coin_admin, lp_owner) = 
            register_stable_pool_with_liquidity(15000000000, 1500000000000);

        

        // Let's swap USDT -> USDC.
        let usdt_to_swap_val = 1254269;
        let usdc_to_get_val = router::get_amount_out<USDT, USDC, Stable>(usdt_to_swap_val);
        let usdt_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_to_swap_val);

        let usdc_swapped = router::swap_exact_coin_for_coin<USDT, USDC, Stable>(
            usdt_to_swap,
            usdc_to_get_val,
        );

        assert!(coin::value(&usdc_swapped) == usdc_to_get_val, 1);
        coin::register<USDC>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), usdc_swapped);
    }

    #[test]
    fun test_stable_curve_swap_exact_vice_versa_1() {
        let (coin_admin, lp_owner) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        

        

        let usdt_to_swap_val = 125426939;
        let usdc_to_get_val = router::get_amount_out<USDT, USDC, Stable>(usdt_to_swap_val);
        let usdt_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_to_swap_val);

        let usdc_swapped = router::swap_exact_coin_for_coin<USDT, USDC, Stable>(
            usdt_to_swap,
            usdc_to_get_val,
        );

        assert!(coin::value(&usdc_swapped) == usdc_to_get_val, 1);
        coin::register<USDC>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), usdc_swapped);
    }

    #[test]
    fun test_stable_curve_exact_swap() {
        let (coin_admin, lp_owner) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        

        let usdc_to_get_val = 1254269;
        let usdt_to_swap_val = router::get_amount_in<USDT, USDC, Stable>(usdc_to_get_val);

        let usdt_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_to_swap_val);
        let (usdt_reminder, usdc_swapped) = router::swap_coin_for_exact_coin<USDT, USDC, Stable>(
            usdt_to_swap,
            usdc_to_get_val,
        );

        assert!(coin::value(&usdt_reminder) == 0, 1);
        assert!(coin::value(&usdc_swapped) == usdc_to_get_val, 2);

        coin::register<USDC>(&lp_owner);
        coin::register<USDT>(&lp_owner);

        coin::deposit(signer::address_of(&lp_owner), usdt_reminder);
        coin::deposit(signer::address_of(&lp_owner), usdc_swapped);
    }

    #[test]
    fun test_stable_curve_exact_swap_vice_versa() {
        let (coin_admin, lp_owner) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        

        

        let usdt_to_get_val = 125804401;
        let usdc_to_swap_val = router::get_amount_in<USDC, USDT, Stable>(usdt_to_get_val);

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);
        let (usdc_reminder, usdt_swapped) = router::swap_coin_for_exact_coin<USDC, USDT, Stable>(
            usdc_to_swap,
            usdt_to_get_val,
        );

        assert!(coin::value(&usdc_reminder) == 0, 1);
        assert!(coin::value(&usdt_swapped) == usdt_to_get_val, 2);

        coin::register<USDC>(&lp_owner);
        coin::register<USDT>(&lp_owner);

        coin::deposit(signer::address_of(&lp_owner), usdc_reminder);
        coin::deposit(signer::address_of(&lp_owner), usdt_swapped);
    }

    #[test]
    fun test_stable_get_amount_in() {
        let (_, _) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        let amount_in = router::get_amount_in<USDC, USDT, Stable>(67279092);
        assert!(amount_in == 673061, 0);
    }

    #[test]
    fun test_get_amount_in() {
        let (_, _) = register_pool_with_liquidity(10828583259, 2764800200409);

        let amount_in = router::get_amount_in<USDT, BTC, Uncorrelated>(158202011);
        assert!(amount_in == 41115034299, 0);
    }

    #[test]
    fun test_get_amount_in_1() {
        let (_, _) = register_pool_with_liquidity(10828583259, 2764800200409);

        let amount_in = router::get_amount_in<BTC, USDT, Uncorrelated>(28253021000);
        assert!(amount_in == 112134290, 0);
    }

    #[test]
    fun test_get_amount_in_2() {
        let (_, _) = register_pool_with_liquidity(10828583259, 2764800200409);

        let amount_in = router::get_amount_in<USDT, BTC, Uncorrelated>(1);
        assert!(amount_in == 257, 0);
    }

    #[test]
    fun test_stable_get_amount_in_1() {
        let (_, _) = register_stable_pool_with_liquidity(20000000000, 1000000000000);

        let amount_in = router::get_amount_in<USDC, USDT, Stable>(67279092);
        assert!(amount_in == 724846, 0);
    }

    #[test]
    fun test_stable_get_amount_in_2() {
        let (_, _) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        let amount_in = router::get_amount_in<USDC, USDT, Stable>(15000);
        assert!(amount_in == 152, 0);
    }

    #[test]
    fun test_stable_get_amount_in_3() {
        let (_, _) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        let amount_in = router::get_amount_in<USDT, USDC, Stable>(158282982);
        assert!(amount_in == 15834641356, 0);
    }

    #[test]
    fun test_stable_get_amount_in_4() {
        let (_, _) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        let amount_in = router::get_amount_in<USDT, USDC, Stable>(1);
        assert!(amount_in == 102, 0);
    }

    #[test]
    fun test_stable_get_amount_in_5() {
        let (_, _) = register_stable_pool_with_liquidity(2930000000000, 293000000000000);

        let amount_in = router::get_amount_in<USDT, USDC, Stable>(57212828231);
        assert!(amount_in == 5723593558779, 0);
    }

    #[test]
    fun test_stable_get_amount_out() {
        let (_, _) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        let amount_out = router::get_amount_out<USDC, USDT, Stable>(674816);
        assert!(amount_out == 67454699, 0);
    }

    #[test]
    fun test_get_amount_out() {
        let (_, _) = register_pool_with_liquidity(18000000000, 4680000000000);

        let amount_out = router::get_amount_out<USDT, BTC, Uncorrelated>(1500000000);
        assert!(amount_out == 5750085, 0);
    }

    #[test]
    fun test_get_amount_out_1() {
        let (_, _) = register_pool_with_liquidity(18000000000, 4680000000000);

        let amount_out = router::get_amount_out<BTC, USDT, Uncorrelated>(100000000);
        assert!(amount_out == 25779211810, 0);
    }

    #[test]
    fun test_get_amount_out_2() {
        let (_, _) = register_pool_with_liquidity(18000000000, 4680000000000);

        let amount_out = router::get_amount_out<BTC, USDT, Uncorrelated>(1);
        assert!(amount_out == 259, 0);
    }

    #[test]
    fun test_stable_get_amount_out_1() {
        let (_, _) = register_stable_pool_with_liquidity(25000000000, 1500000000000);

        let amount_out = router::get_amount_out<USDC, USDT, Stable>(323859);
        assert!(amount_out == 31376814, 0);
    }

    #[test]
    fun test_stable_get_amount_out_2() {
        let (_, _) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        let amount_out = router::get_amount_out<USDC, USDT, Stable>(58201);
        assert!(amount_out == 5817799, 0);
    }

    #[test]
    fun test_stable_get_amount_out_3() {
        let (_, _) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        let amount_out = router::get_amount_out<USDT, USDC, Stable>(15000);
        assert!(amount_out == 149, 0);
    }

    #[test]
    fun test_stable_get_amount_out_4() {
        let (_, _) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        let amount_out = router::get_amount_out<USDT, USDC, Stable>(1);
        assert!(amount_out == 0, 0);
    }

    #[test]
    fun test_stable_get_amount_out_5() {
        let (_, _) = register_stable_pool_with_liquidity(2930000000000, 293000000000000);

        let amount_out = router::get_amount_out<USDT, USDC, Stable>(572123482812);
        assert!(amount_out == 5718946312, 0);
    }

    #[test]
    fun test_stable_curve_exact_swap_vice_vera_1() {
        let (coin_admin, lp_owner) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        

        

        let usdt_to_get_val = 672790928312;
        let usdc_to_swap_val = router::get_amount_in<USDC, USDT, Stable>(usdt_to_get_val);

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);
        let (usdc_reminder, usdt_swapped) = router::swap_coin_for_exact_coin<USDC, USDT, Stable>(
            usdc_to_swap,
            usdt_to_get_val,
        );

        assert!(coin::value(&usdc_reminder) == 0, 1);
        assert!(coin::value(&usdt_swapped) == usdt_to_get_val, 2);

        coin::register<USDC>(&lp_owner);
        coin::register<USDT>(&lp_owner);

        coin::deposit(signer::address_of(&lp_owner), usdc_reminder);
        coin::deposit(signer::address_of(&lp_owner), usdt_swapped);
    }

    #[test]
    fun test_stable_curve_exact_swap_vice_versa_2() {
        let (coin_admin, lp_owner) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        

        

        let usdt_to_get_val = 672790928;
        let usdc_to_swap_val = router::get_amount_in<USDC, USDT, Stable>(usdt_to_get_val);

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);
        let (usdc_reminder, usdt_swapped) = router::swap_coin_for_exact_coin<USDC, USDT, Stable>(
            usdc_to_swap,
            usdt_to_get_val,
        );

        assert!(coin::value(&usdc_reminder) == 0, 1);
        assert!(coin::value(&usdt_swapped) == usdt_to_get_val, 2);

        coin::register<USDC>(&lp_owner);
        coin::register<USDT>(&lp_owner);

        coin::deposit(signer::address_of(&lp_owner), usdc_reminder);
        coin::deposit(signer::address_of(&lp_owner), usdt_swapped);
    }

    #[test]
    fun test_convert_with_current_price() {
        let a = router::convert_with_current_price(MAX_U64, MAX_U64, MAX_U64);
        assert!(a == MAX_U64, 0);

        a = router::convert_with_current_price(100, 100, 20);
        assert!(a == 20, 1);

        a = router::convert_with_current_price(256, 8, 2);
        assert!(a == 64, 1);
    }

    #[test]
    #[expected_failure(abort_code = 200)]
    fun test_fail_convert_with_current_price_coin_in_val() {
        router::convert_with_current_price(0, 1, 1);
    }

    #[test]
    #[expected_failure(abort_code = 201)]
    fun test_fail_convert_with_current_price_reserve_in_size() {
        router::convert_with_current_price(1, 0, 1);
    }

    #[test]
    #[expected_failure(abort_code = 201)]
    fun test_fail_convert_with_current_price_reserve_out_size() {
        router::convert_with_current_price(1, 1, 0);
    }

    #[test]
    fun test_get_decimals_scales_stables() {
        let (_, _) = register_stable_pool_with_liquidity(15000000000, 1500000000000);

        let (x, y) = router::get_decimals_scales<USDC, USDT, Stable>();

        // USDC 4 decimals
        assert!(x == 10000, 0);
        // USDT 6 decimals
        assert!(y == 1000000, 1);
    }

    #[test]
    fun test_get_decimals_scales_uncorrelated() {
        let (_, _) = register_pool_with_liquidity(101, 10100);

        let (x, y) = router::get_decimals_scales<BTC, USDT, Uncorrelated>();

        assert!(x == 0, 0);
        assert!(y == 0, 1);
    }


    #[test]
    fun test_swap_coin_for_coin_unchecked() {
        let (coin_admin, _) = register_pool_with_liquidity(101, 10100);

        let btc_coins_swap_val = 1;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<BTC, USDT, Uncorrelated>(btc_coins_swap_val);

        let usdt_coins = router::swap_coin_for_coin_unchecked<BTC, USDT, Uncorrelated>(
            btc_coins_to_swap,
            usdt_amount_out,
        );
        assert!(coin::value(&usdt_coins) == usdt_amount_out, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_stable_swap_coin_for_coin_unchecked() {
        let (coin_admin, _) = register_stable_pool_with_liquidity(150000000, 15000000000);

        let usdc_coins_swap_val = 100;
        let usdc_coins_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<USDC, USDT, Stable>(usdc_coins_swap_val);

        let usdt_coins = router::swap_coin_for_coin_unchecked<USDC, USDT, Stable>(
            usdc_coins_to_swap,
            usdt_amount_out,
        );
        assert!(coin::value(&usdt_coins) == usdt_amount_out, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_stable_swap_coin_for_coin_unchecked_reverse() {
        let (coin_admin, _) = register_stable_pool_with_liquidity(150000000, 15000000000);

        let usdt_to_swap_val = 10000;
        let usdt_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_to_swap_val);
        let usdt_amount_out = router::get_amount_out<USDT, USDC, Stable>(usdt_to_swap_val);

        let usdt_coins = router::swap_coin_for_coin_unchecked<USDT, USDC, Stable>(
            usdt_to_swap,
            usdt_amount_out,
        );
        assert!(coin::value(&usdt_coins) == usdt_amount_out, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_reverse() {
        let (coin_admin, _) = register_pool_with_liquidity(101, 10100);

        let usdt_coins_to_swap = test_coins::mint<USDT>(&coin_admin, 110);

        let btc_coins = router::swap_coin_for_coin_unchecked<USDT, BTC, Uncorrelated>(
            usdt_coins_to_swap,
            1,
        );
        assert!(coin::value(&btc_coins) == 1, 0);

        test_coins::burn(&coin_admin, btc_coins);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_1() {
        let (coin_admin, _) = register_pool_with_liquidity(1230000000, 147600000000);

        let btc_to_swap_val = 572123800;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_to_swap_val);

        let usdt_to_get_val = router::get_amount_out<BTC, USDT, Uncorrelated>(btc_to_swap_val) - 1;

        let usdt_coins = router::swap_coin_for_coin_unchecked<BTC, USDT, Uncorrelated>(
            btc_coins_to_swap,
            usdt_to_get_val,
        );
        assert!(coin::value(&usdt_coins) == usdt_to_get_val, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_2() {
        let (coin_admin, _) = register_pool_with_liquidity(10000000000, 2800000000000);

        let usdt_to_swap_val = 257817560;
        let usdt_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_to_swap_val);

        let btc_to_get_val = router::get_amount_out<USDT, BTC, Uncorrelated>(usdt_to_swap_val) - 134567;

        let usdt_coins = router::swap_coin_for_coin_unchecked<USDT, BTC, Uncorrelated>(
            usdt_to_swap,
            btc_to_get_val,
        );
        assert!(coin::value(&usdt_coins) == btc_to_get_val, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_fail_if_price_fell_behind_threshold_unchecked() {
        let (coin_admin, lp_owner) = register_pool_with_liquidity(101, 10100);

        
        let btc_coin_to_swap = test_coins::mint<BTC>(&coin_admin, 1);

        let usdt_coins =
            router::swap_coin_for_coin_unchecked<BTC, USDT, Uncorrelated>(
                btc_coin_to_swap,
                102,
            );

        coin::register<USDT>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_stable_fail_if_price_fell_behind_threshold_unchecked() {
        let (coin_admin, _) = register_stable_pool_with_liquidity(150000000, 15000000000);

        let usdc_coins_swap_val = 100;
        let usdc_coins_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<USDC, USDT, Stable>(usdc_coins_swap_val);

        let usdt_coins = router::swap_coin_for_coin_unchecked<USDC, USDT, Stable>(
            usdc_coins_to_swap,
            usdt_amount_out + 1,
        );
        assert!(coin::value(&usdt_coins) == usdt_amount_out, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_stable_fail_if_price_fell_behind_threshold_unchecked_1() {
        let (coin_admin, _) = register_stable_pool_with_liquidity(150000000, 15000000000);

        let usdc_coins_swap_val = 999999;
        let usdc_coins_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<USDC, USDT, Stable>(usdc_coins_swap_val);

        let usdt_coins = router::swap_coin_for_coin_unchecked<USDC, USDT, Stable>(
            usdc_coins_to_swap,
            usdt_amount_out + 1,
        );
        assert!(coin::value(&usdt_coins) == usdt_amount_out, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_stable_fail_if_price_fell_behind_threshold_unchecked_2() {
        let (coin_admin, _) = register_stable_pool_with_liquidity(150000000, 15000000000);

        let usdc_coins_to_get = 999999;
        let usdt_coins_to_swap_val = router::get_amount_in<USDT, USDC, Stable>(usdc_coins_to_get);
        let usdt_coins_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_coins_to_swap_val);

        let usdc_coins = router::swap_coin_for_coin_unchecked<USDT, USDC, Stable>(
            usdt_coins_to_swap,
            usdc_coins_to_get + 1,
        );
        assert!(coin::value(&usdc_coins) == usdc_coins_to_get, 0);

        test_coins::burn(&coin_admin, usdc_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_swap_coin_for_coin_unchecked_fails() {
        let (coin_admin, _) = register_pool_with_liquidity(10000000000, 2800000000000);

        let usdt_to_swap_val = 257817560;
        let usdt_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_to_swap_val);

        let btc_to_get_val = router::get_amount_out<USDT, BTC, Uncorrelated>(usdt_to_swap_val) + 1;

        let usdt_coins = router::swap_coin_for_coin_unchecked<USDT, BTC, Uncorrelated>(
            usdt_to_swap,
            btc_to_get_val,
        );
        assert!(coin::value(&usdt_coins) == btc_to_get_val, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_calc_optimal_coin_values() {
        // 100 BTC, 2,800,000 USDT
        let (_, _) = register_pool_with_liquidity(10000000000, 2800000000000);


        // 1 BTC, 10000 USDT
        let x_desired = 100000000;
        let y_desired = 10000000000;

        let (x_value, y_value) = router::calc_optimal_coin_values<BTC, USDT, Uncorrelated>(x_desired, y_desired, 0, 0);

        // 1e8 x 1e10 / (2.8 x 1e11) = 35714285
        assert!(x_value == 35714285, 0);
        assert!(y_value == y_desired, 1);
    }

    #[test]
    #[expected_failure(abort_code = 203)]
    fun test_calc_optimal_coin_values_1() {
        // 100 BTC, 2,800,000 USDT
        let (_, _) = register_pool_with_liquidity(10000000000, 2800000000000);

        // 1 BTC, 10000 USDT
        let x_desired = 100000000;
        let y_desired = 10000000000;

        let (_x_value, _y_value) = router::calc_optimal_coin_values<BTC, USDT, Uncorrelated>(x_desired, y_desired, 5000000000, 0);
    }

    #[test]
    fun test_calc_optimal_coin_values_3() {
        // 100 BTC, 28000 USDT
        let (_, _) = register_pool_with_liquidity(10000000000, 28000000000);

        // 1 BTC, 10000 USDT
        let x_desired = 100000000;
        let y_desired = 10000000000;

        let (x_res, y_res) = router::get_reserves_size<BTC, USDT, Uncorrelated>();

        let (x_value, y_value) = router::calc_optimal_coin_values<BTC, USDT, Uncorrelated>(x_desired, y_desired, 0, 0);

        assert!(x_value == x_desired, 0);
        assert!(y_value == x_desired * y_res / x_res, 1);
    }

    #[test]
    #[expected_failure(abort_code = 202)]
    fun test_calc_optimal_coin_values_4() {
        // 100 BTC, 28000 USDT
        let (_, _) = register_pool_with_liquidity(10000000000, 28000000000);

        // 1 BTC, 10000 USDT
        let x_desired = 100000000;
        let y_desired = 10000000000;

        let (_x_value, _y_value) = router::calc_optimal_coin_values<BTC, USDT, Uncorrelated>(x_desired, y_desired, 0, 2800000000);
    }

    #[test]
    fun test_fee_config_for_uncorrelated_curve() {
        let (_, _) = register_pool_with_liquidity(10000, 10000);

        let (fee, d) = router::get_fees_config<BTC, USDT, Uncorrelated>();
        assert!(fee == 30, 1);
        assert!(d == 10000, 2);
        let (fee, d) = router::get_fees_config<USDT, BTC, Uncorrelated>();
        assert!(fee == 30, 3);
        assert!(d == 10000, 4);

        let fee = router::get_fee<BTC, USDT, Uncorrelated>();
        assert!(fee == 30, 5);
        let fee = router::get_fee<USDT, BTC, Uncorrelated>();
        assert!(fee == 30, 6);

        let (dao_fee, d) = router::get_dao_fees_config<BTC, USDT, Uncorrelated>();
        assert!(dao_fee == 33, 7);
        assert!(d == 100, 8);
        let (dao_fee, d) = router::get_dao_fees_config<USDT, BTC, Uncorrelated>();
        assert!(dao_fee == 33, 9);
        assert!(d == 100, 10);

        let dao_fee = router::get_dao_fee<BTC, USDT, Uncorrelated>();
        assert!(dao_fee == 33, 11);
        let dao_fee = router::get_dao_fee<USDT, BTC, Uncorrelated>();
        assert!(dao_fee == 33, 12);
    }

    #[test]
    fun test_fee_config_for_stable_curve() {
        let (_, _) = register_stable_pool_with_liquidity(10000, 10000);

        let (fee, d) = router::get_fees_config<USDC, USDT, Stable>();
        assert!(fee == 4, 1);
        assert!(d == 10000, 2);
        let (fee, d) = router::get_fees_config<USDT, USDC, Stable>();
        assert!(fee == 4, 3);
        assert!(d == 10000, 4);

        let fee = router::get_fee<USDC, USDT, Stable>();
        assert!(fee == 4, 5);
        let fee = router::get_fee<USDT, USDC, Stable>();
        assert!(fee == 4, 6);

        let (dao_fee, d) = router::get_dao_fees_config<USDC, USDT, Stable>();
        assert!(dao_fee == 33, 7);
        assert!(d == 100, 8);
        let (dao_fee, d) = router::get_dao_fees_config<USDT, USDC, Stable>();
        assert!(dao_fee == 33, 9);
        assert!(d == 100, 10);

        let dao_fee = router::get_dao_fee<USDC, USDT, Stable>();
        assert!(dao_fee == 33, 11);
        let dao_fee = router::get_dao_fee<USDT, USDC, Stable>();
        assert!(dao_fee == 33, 12);
    }

    #[test]
    #[expected_failure(abort_code = 107)]
    fun test_get_fees_config_fail_if_pool_does_not_exists() {
        router::get_fees_config<BTC, USDT, Uncorrelated>();
    }

    #[test]
    #[expected_failure(abort_code = 107)]
    fun test_get_fee_fail_if_pool_does_not_exists() {
        router::get_fee<BTC, USDT, Uncorrelated>();
    }

    #[test]
    #[expected_failure(abort_code = 107)]
    fun test_get_dao_fees_config_fail_if_pool_does_not_exists() {
        router::get_dao_fees_config<BTC, USDT, Uncorrelated>();
    }

    #[test]
    #[expected_failure(abort_code = 107)]
    fun test_get_dao_fee_fail_if_pool_does_not_exists() {
        router::get_dao_fee<BTC, USDT, Uncorrelated>();
    }
}
