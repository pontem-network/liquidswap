#[test_only]
module liquidswap::router_tests {
    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_framework::timestamp;

    use liquidswap::liquidity_pool;
    use liquidswap::router;
    use test_coin_admin::test_coins::{Self, USDT, BTC, USDC};
    use test_pool_owner::test_lp::LP;

    const MAX_U64: u64 = 18446744073709551615;

    fun register_pool_with_liquidity(coin_admin: &signer,
                                     pool_owner: &signer,
                                     x_val: u64, y_val: u64) {
        router::register_pool<BTC, USDT, LP>(pool_owner, 2);

        let pool_owner_addr = signer::address_of(pool_owner);
        if (x_val != 0 && y_val != 0) {
            let btc_coins = test_coins::mint<BTC>(coin_admin, x_val);
            let usdt_coins = test_coins::mint<USDT>(coin_admin, y_val);
            let lp_coins =
                liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
            coin::register_internal<LP>(pool_owner);
            coin::deposit<LP>(pool_owner_addr, lp_coins);
        };
    }

    fun register_stable_pool_with_liquidity(coin_admin: &signer, pool_owner: &signer, x_val: u64, y_val: u64) {
        router::register_pool<USDC, USDT, LP>(pool_owner, 1);

        let pool_owner_addr = signer::address_of(pool_owner);
        if (x_val != 0 && y_val != 0) {
            let usdc_coins = test_coins::mint<USDC>(coin_admin, x_val);
            let usdt_coins = test_coins::mint<USDT>(coin_admin, y_val);
            let lp_coins =
                liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
            coin::register_internal<LP>(pool_owner);
            coin::deposit<LP>(pool_owner_addr, lp_coins);
        };
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_add_initial_liquidity(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 0, 0);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint(&coin_admin, 10100);
        let pool_addr = signer::address_of(&pool_owner);

        let (coin_x, coin_y, lp_coins) =
            router::add_liquidity<BTC, USDT, LP>(
                pool_addr,
                btc_coins,
                101,
                usdt_coins,
                10100,
            );

        assert!(coin::value(&coin_x) == 0, 0);
        assert!(coin::value(&coin_y) == 0, 1);
        // 1010 - 1000 = 10
        assert!(coin::value(&lp_coins) == 10, 2);

        coin::register_internal<BTC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);
        coin::register_internal<LP>(&pool_owner);

        coin::deposit(pool_addr, coin_x);
        coin::deposit(pool_addr, coin_y);
        coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_add_liquidity_to_pool(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 9000);
        let pool_addr = signer::address_of(&pool_owner);

        let (coin_x, coin_y, lp_coins) =
            router::add_liquidity<BTC, USDT, LP>(
                pool_addr,
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

        coin::register_internal<BTC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);

        coin::deposit(pool_addr, coin_x);
        coin::deposit(pool_addr, coin_y);
        coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_add_liquidity_to_pool_reverse(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 9000);
        let pool_addr = signer::address_of(&pool_owner);

        let (coin_y, coin_x, lp_coins) =
            router::add_liquidity<USDT, BTC, LP>(
                pool_addr,
                usdt_coins,
                9000,
                btc_coins,
                10,
            );
        // 101 - 90 = 11
        assert!(coin::value(&coin_x) == 11, 0);
        assert!(coin::value(&coin_y) == 0, 1);
        // 8.91 ~ 8
        assert!(coin::value(&lp_coins) == 8, 2);

        coin::register_internal<BTC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);

        coin::deposit(pool_addr, coin_x);
        coin::deposit(pool_addr, coin_y);
        coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 102)]
    fun test_add_liquidity_to_fail_with_insufficient_y_coins(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 0, 0);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 9000);
        let pool_addr = signer::address_of(&pool_owner);

        let (coin_y, coin_x, lp_coins) = router::add_liquidity<USDT, BTC, LP>(
                pool_addr,
                usdt_coins,
                9000,
                btc_coins,
                102,
            );

        coin::deposit(pool_addr, coin_x);
        coin::deposit(pool_addr, coin_y);
        coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 103)]
    fun test_add_liquidity_to_fail_with_insufficient_x_coins(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 0, 0);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 9000);
        let pool_addr = signer::address_of(&pool_owner);

        let (coin_y, coin_x, lp_coins) = router::add_liquidity<USDT, BTC, LP>(
                pool_addr,
                usdt_coins,
                10000,
                btc_coins,
                101,
            );

        coin::deposit(pool_addr, coin_x);
        coin::deposit(pool_addr, coin_y);
        coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_remove_liquidity(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let lp_coins_val = 2u64;
        let pool_addr = signer::address_of(&pool_owner);
        let lp_coins_to_burn = coin::withdraw<LP>(&pool_owner, lp_coins_val);

        let (x_out, y_out) = router::get_reserves_for_lp_coins<BTC, USDT, LP>(
            pool_addr,
            lp_coins_val
        );
        let (coin_x, coin_y) =
            router::remove_liquidity<BTC, USDT, LP>(pool_addr, lp_coins_to_burn, x_out, y_out);

        let (usdt_reserve, btc_reserve) = router::get_reserves_size<USDT, BTC, LP>(pool_addr);
        assert!(usdt_reserve == 8080, 0);
        assert!(btc_reserve == 81, 1);

        assert!(coin::value(&coin_x) == x_out, 2);
        assert!(coin::value(&coin_y) == y_out, 3);

        coin::register_internal<BTC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);

        coin::deposit(pool_addr, coin_x);
        coin::deposit(pool_addr, coin_y);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 105)]
    fun test_remove_liquidity_to_fail_if_less_than_minimum_x(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let lp_coins_val = 2u64;
        let pool_addr = signer::address_of(&pool_owner);
        let lp_coins_to_burn = coin::withdraw<LP>(&pool_owner, lp_coins_val);

        let (x_out, y_out) = router::get_reserves_for_lp_coins<BTC, USDT, LP>(
            pool_addr,
            lp_coins_val
        );
        let (coin_x, coin_y) =
            router::remove_liquidity<BTC, USDT, LP>(pool_addr, lp_coins_to_burn, x_out * 2, y_out);

        coin::deposit(pool_addr, coin_x);
        coin::deposit(pool_addr, coin_y);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 105)]
    fun test_remove_liquidity_to_fail_if_less_than_minimum_y(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let lp_coins_val = 2u64;
        let pool_addr = signer::address_of(&pool_owner);
        let lp_coins_to_burn = coin::withdraw<LP>(&pool_owner, lp_coins_val);

        let (x_out, y_out) = router::get_reserves_for_lp_coins<BTC, USDT, LP>(
            pool_addr,
            lp_coins_val
        );
        let (coin_x, coin_y) =
            router::remove_liquidity<BTC, USDT, LP>(pool_addr, lp_coins_to_burn, x_out, y_out * 2);

        coin::deposit(pool_addr, coin_x);
        coin::deposit(pool_addr, coin_y);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_exact_coin_for_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coins_swap_val = 1;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<BTC, USDT, LP>(pool_owner_addr, btc_coins_swap_val);

        let usdt_coins = router::swap_exact_coin_for_coin<BTC, USDT, LP>(
            pool_owner_addr,
            btc_coins_to_swap,
            usdt_amount_out,
        );
        assert!(coin::value(&usdt_coins) == usdt_amount_out, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_exact_coin_for_coin_1(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 1230000000, 147600000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_to_swap_val = 572123800;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_to_swap_val);

        let usdt_to_get_val = router::get_amount_out<BTC, USDT, LP>(pool_owner_addr, btc_to_swap_val);

        let usdt_coins = router::swap_exact_coin_for_coin<BTC, USDT, LP>(
            pool_owner_addr,
            btc_coins_to_swap,
            usdt_to_get_val,
        );
        assert!(coin::value(&usdt_coins) == usdt_to_get_val, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_exact_coin_for_coin_2(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 10000000000, 2800000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdt_to_swap_val = 257817560;
        let usdt_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_to_swap_val);

        let btc_to_get_val = router::get_amount_out<USDT, BTC, LP>(pool_owner_addr, usdt_to_swap_val);

        let usdt_coins = router::swap_exact_coin_for_coin<USDT, BTC, LP>(
            pool_owner_addr,
            usdt_to_swap,
            btc_to_get_val,
        );
        assert!(coin::value(&usdt_coins) == btc_to_get_val, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_exact_coin_for_coin_reverse(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdt_coins_to_swap = test_coins::mint<USDT>(&coin_admin, 110);

        let btc_coins = router::swap_exact_coin_for_coin<USDT, BTC, LP>(
            pool_owner_addr,
            usdt_coins_to_swap,
            1,
        );
        assert!(coin::value(&btc_coins) == 1, 0);

        test_coins::burn(&coin_admin, btc_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 105)]
    fun test_swap_exact_coin_for_coin_to_fail_if_less_than_minimum_out(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coins_swap_val = 1;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<BTC, USDT, LP>(pool_owner_addr, btc_coins_swap_val);

        let usdt_coins = router::swap_exact_coin_for_coin<BTC, USDT, LP>(
            pool_owner_addr,
            btc_coins_to_swap,
            usdt_amount_out * 2,
        );

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coin_for_exact_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 1);

        let (remainder, usdt_coins) =
            router::swap_coin_for_exact_coin<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_swap,
                98,
            );

        assert!(coin::value(&usdt_coins) == 98, 0);
        assert!(coin::value(&remainder) == 0, 1);

        test_coins::burn(&coin_admin, usdt_coins);
        coin::destroy_zero(remainder);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coin_for_exact_coin_1(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 50000000000, 13500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        let usdt_coins_to_get = 5292719411;
        let btc_coins_to_swap_val = router::get_amount_in<BTC, USDT, LP>(pool_owner_addr, usdt_coins_to_get);
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_coins_to_swap_val);

        let (remainder, usdt_coins) =
            router::swap_coin_for_exact_coin<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_swap,
                usdt_coins_to_get,
            );

        assert!(coin::value(&usdt_coins) == usdt_coins_to_get, 0);
        assert!(coin::value(&remainder) == 0, 1);

        test_coins::burn(&coin_admin, usdt_coins);
        coin::destroy_zero(remainder);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coin_for_exact_coin_2(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 10000000000, 2800000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coins_to_get = 185200481;
        let usdt_coins_to_swap_val = router::get_amount_in<USDT, BTC, LP>(pool_owner_addr, btc_coins_to_get);

        let usdc_coins_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_coins_to_swap_val);

        let (remainder, btc_coins) =
            router::swap_coin_for_exact_coin<USDT, BTC, LP>(
                pool_owner_addr,
                usdc_coins_to_swap,
                btc_coins_to_get,
            );

        assert!(coin::value(&btc_coins) == btc_coins_to_get, 1);
        assert!(coin::value(&remainder) == 0, 2);

        test_coins::burn(&coin_admin, btc_coins);
        coin::destroy_zero(remainder);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code=106)]
    fun test_swap_coin_for_exact_coin_router_check_fails(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 10000000000, 2800000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coins_to_swap_val = 100000000;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_coins_to_swap_val);
        let usdt_to_get = router::get_amount_out<BTC, USDT, LP>(pool_owner_addr, btc_coins_to_swap_val) + 1;

        let (remainder, usdt_coins) =
            router::swap_coin_for_exact_coin<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_swap,
                usdt_to_get,
            );

        assert!(coin::value(&usdt_coins) == usdt_to_get, 1);
        assert!(coin::value(&remainder) == 0, 2);

        test_coins::burn(&coin_admin, usdt_coins);
        coin::destroy_zero(remainder);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coin_for_exact_coin_reverse(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdt_coins_to_swap = test_coins::mint<USDT>(&coin_admin, 1114);

        let (remainder, btc_coins) =
            router::swap_coin_for_exact_coin<USDT, BTC, LP>(
                pool_owner_addr,
                usdt_coins_to_swap,
                10,
            );

        assert!(coin::value(&btc_coins) == 10, 0);
        assert!(coin::value(&remainder) == 0, 1);

        test_coins::burn(&coin_admin, btc_coins);
        coin::destroy_zero(remainder);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 105)]
    fun test_fail_if_price_fell_behind_threshold(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coin_to_swap = test_coins::mint<BTC>(&coin_admin, 1);

        let usdt_coins =
            router::swap_exact_coin_for_coin<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coin_to_swap,
                102,
            );

        coin::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 104)]
    fun test_fail_if_swap_zero_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 0);

        let usdt_coins =
            router::swap_exact_coin_for_coin<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_swap,
                0,
            );

        coin::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_returned_usdt_proportially_decrease_for_big_swaps(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 200);

        let usdt_coins =
            router::swap_exact_coin_for_coin<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_swap,
                1,
            );
        assert!(coin::value(&usdt_coins) == 6704, 0);

        let (btc_reserve, usdt_reserve) = router::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(btc_reserve == 301, 1);
        assert!(usdt_reserve == 3396, 2);
        assert!(router::current_price<USDT, BTC, LP>(pool_owner_addr) == 11, 3);

        coin::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_pool_exists(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        router::register_pool<BTC, USDT, LP>(&pool_owner, 2);

        assert!(router::pool_exists_at<BTC, USDT, LP>(signer::address_of(&pool_owner)), 0);
        assert!(router::pool_exists_at<USDT, BTC, LP>(signer::address_of(&pool_owner)), 1);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_cumulative_prices_after_swaps(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);
        coin::register_internal<USDT>(&pool_owner);

        let pool_addr = signer::address_of(&pool_owner);
        let (btc_price, usdt_price, ts) =
            router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_price == 0, 0);
        assert!(usdt_price == 0, 1);
        assert!(ts == 0, 2);

        // 2 seconds
        timestamp::update_global_time_for_test(2000000);

        let btc_to_swap = test_coins::mint<BTC>(&coin_admin, 1);
        let usdts =
            router::swap_exact_coin_for_coin<BTC, USDT, LP>(
                pool_addr,
                btc_to_swap,
                95,
            );
        coin::deposit(pool_addr, usdts);

        let (btc_cum_price, usdt_cum_price, last_timestamp) =
            router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_cum_price == 3689348814741910323000, 3);
        assert!(usdt_cum_price == 368934881474191032, 4);
        assert!(last_timestamp == 2, 5);

        // 4 seconds
        timestamp::update_global_time_for_test(4000000);

        let btc_to_swap = test_coins::mint<BTC>(&coin_admin, 2);
        let usdts =
            router::swap_exact_coin_for_coin<BTC, USDT, LP>(
                pool_addr,
                btc_to_swap,
                190,
            );
        coin::deposit(pool_addr, usdts);

        let (btc_cum_price, usdt_cum_price, last_timestamp) =
            router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_cum_price == 7307080858374124739730, 6);
        assert!(usdt_cum_price == 745173212911578406, 7);
        assert!(last_timestamp == 4, 8);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_curve_swap_exact(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        let usdc_to_swap_val = 1258044;

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);
        let usdt_to_get = router::get_amount_out<USDC, USDT, LP>(pool_owner_addr, usdc_to_swap_val);

        let usdt_swapped = router::swap_exact_coin_for_coin<USDC, USDT, LP>(
            pool_owner_addr,
            usdc_to_swap,
            usdt_to_get,
        );

        assert!(coin::value(&usdt_swapped) == usdt_to_get, 1);

        coin::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, usdt_swapped);
    }

    #[test(core = @aptos_framework, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_curve_swap_exact_1(core: signer, coin_admin: signer, pool_owner: signer) {
        timestamp::set_time_has_started_for_testing(&core);

        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        let usdc_to_swap_val = 67482132;

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);
        let usdt_to_get = router::get_amount_out<USDC, USDT, LP>(pool_owner_addr, usdc_to_swap_val);

        let usdt_swapped = router::swap_exact_coin_for_coin<USDC, USDT, LP>(
            pool_owner_addr,
            usdc_to_swap,
            usdt_to_get,
        );
        assert!(coin::value(&usdt_swapped) == usdt_to_get, 1);

        coin::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, usdt_swapped);
    }

    #[test(core = @aptos_framework, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_curve_swap_exact_2(core: signer, coin_admin: signer, pool_owner: signer) {
        timestamp::set_time_has_started_for_testing(&core);

        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        let usdc_to_swap_val = 1207482132;

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);
        let usdt_to_get = router::get_amount_out<USDC, USDT, LP>(pool_owner_addr, usdc_to_swap_val);

        let usdt_swapped = router::swap_exact_coin_for_coin<USDC, USDT, LP>(
            pool_owner_addr,
            usdc_to_swap,
            usdt_to_get,
        );
        assert!(coin::value(&usdt_swapped) == usdt_to_get, 1);

        coin::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, usdt_swapped);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_curve_swap_exact_vice_versa(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        // Let's swap USDT -> USDC.
        let usdt_to_swap_val = 1254269;
        let usdc_to_get_val = router::get_amount_out<USDT, USDC, LP>(pool_owner_addr, usdt_to_swap_val);
        let usdt_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_to_swap_val);

        let usdc_swapped = router::swap_exact_coin_for_coin<USDT, USDC, LP>(
            pool_owner_addr,
            usdt_to_swap,
            usdc_to_get_val,
        );

        assert!(coin::value(&usdc_swapped) == usdc_to_get_val, 1);
        coin::register_internal<USDC>(&pool_owner);
        coin::deposit(pool_owner_addr, usdc_swapped);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_curve_swap_exact_vice_versa_1(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        let usdt_to_swap_val = 125426939;
        let usdc_to_get_val = router::get_amount_out<USDT, USDC, LP>(pool_owner_addr, usdt_to_swap_val);
        let usdt_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_to_swap_val);

        let usdc_swapped = router::swap_exact_coin_for_coin<USDT, USDC, LP>(
            pool_owner_addr,
            usdt_to_swap,
            usdc_to_get_val,
        );

        assert!(coin::value(&usdc_swapped) == usdc_to_get_val, 1);
        coin::register_internal<USDC>(&pool_owner);
        coin::deposit(pool_owner_addr, usdc_swapped);
    }

    // Doesn't work correctly, need fix.
    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_curve_exact_swap(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        let usdc_to_get_val = 1254269;
        let usdt_to_swap_val = router::get_amount_in<USDT, USDC, LP>(pool_owner_addr, usdc_to_get_val);

        let usdt_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_to_swap_val);
        let (usdt_reminder, usdc_swapped) = router::swap_coin_for_exact_coin<USDT, USDC, LP>(
            pool_owner_addr,
            usdt_to_swap,
            1258044,
        );

        assert!(coin::value(&usdt_reminder) == 0, 1);
        assert!(coin::value(&usdc_swapped) == usdc_to_get_val, 2);

        coin::register_internal<USDC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);

        coin::deposit(pool_owner_addr, usdt_reminder);
        coin::deposit(pool_owner_addr, usdc_swapped);
    }

    // Doesn't work correctly need fix.
    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_curve_exact_swap_vice_versa(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        let usdt_to_get_val = 125804401;
        let usdc_to_swap_val = router::get_amount_in<USDC, USDT, LP>(pool_owner_addr, usdt_to_get_val);

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);
        let (usdc_reminder, usdt_swapped) = router::swap_coin_for_exact_coin<USDC, USDT, LP>(
            pool_owner_addr,
            usdc_to_swap,
            usdt_to_get_val,
        );

        assert!(coin::value(&usdc_reminder) == 0, 1);
        assert!(coin::value(&usdt_swapped) == usdt_to_get_val, 2);

        coin::register_internal<USDC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);

        coin::deposit(pool_owner_addr, usdc_reminder);
        coin::deposit(pool_owner_addr, usdt_swapped);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_get_amount_in(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_in = router::get_amount_in<USDC, USDT, LP>(pool_owner_addr, 67279092);
        assert!(amount_in == 674816, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_get_amount_in(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 10828583259, 2764800200409);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_in = router::get_amount_in<USDT, BTC, LP>(pool_owner_addr, 158202011);
        assert!(amount_in == 41115034299, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_get_amount_in_1(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 10828583259, 2764800200409);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_in = router::get_amount_in<BTC, USDT, LP>(pool_owner_addr, 28253021000);
        assert!(amount_in == 112134290, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_get_amount_in_2(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 10828583259, 2764800200409);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_in = router::get_amount_in<USDT, BTC, LP>(pool_owner_addr, 1);
        assert!(amount_in == 257, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_get_amount_in_1(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 20000000000, 1000000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_in = router::get_amount_in<USDC, USDT, LP>(pool_owner_addr, 67279092);
        assert!(amount_in == 726737, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_get_amount_in_2(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_in = router::get_amount_in<USDC, USDT, LP>(pool_owner_addr, 15000);
        assert!(amount_in == 152, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_get_amount_in_3(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_in = router::get_amount_in<USDT, USDC, LP>(pool_owner_addr, 158282982);
        assert!(amount_in == 15875935305, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_get_amount_in_4(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_in = router::get_amount_in<USDT, USDC, LP>(pool_owner_addr, 1);
        assert!(amount_in == 102, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_get_amount_out(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_out = router::get_amount_out<USDC, USDT, LP>(pool_owner_addr, 674816);
        assert!(amount_out == 67279099, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_get_amount_out(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 18000000000, 4680000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_out = router::get_amount_out<USDT, BTC, LP>(pool_owner_addr, 1500000000);
        assert!(amount_out == 5750085, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_get_amount_out_1(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 18000000000, 4680000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_out = router::get_amount_out<BTC, USDT, LP>(pool_owner_addr, 100000000);
        assert!(amount_out == 25779211810, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_get_amount_out_2(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 18000000000, 4680000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_out = router::get_amount_out<BTC, USDT, LP>(pool_owner_addr, 1);
        assert!(amount_out == 259, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_get_amount_out_1(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 25000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_out = router::get_amount_out<USDC, USDT, LP>(pool_owner_addr, 323859);
        assert!(amount_out == 31295108, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_get_amount_out_2(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_out = router::get_amount_out<USDC, USDT, LP>(pool_owner_addr, 58201);
        assert!(amount_out == 5802599, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_get_amount_out_3(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_out = router::get_amount_out<USDT, USDC, LP>(pool_owner_addr, 15000);
        assert!(amount_out == 149, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_get_amount_out_4(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let amount_out = router::get_amount_out<USDT, USDC, LP>(pool_owner_addr, 1);
        assert!(amount_out == 0, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_curve_exact_swap_vice_vera_1(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        let usdt_to_get_val = 672790928312;
        let usdc_to_swap_val = router::get_amount_in<USDC, USDT, LP>(pool_owner_addr, usdt_to_get_val);

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);
        let (usdc_reminder, usdt_swapped) = router::swap_coin_for_exact_coin<USDC, USDT, LP>(
            pool_owner_addr,
            usdc_to_swap,
            usdt_to_get_val,
        );

        assert!(coin::value(&usdc_reminder) == 0, 1);
        assert!(coin::value(&usdt_swapped) == usdt_to_get_val, 2);

        coin::register_internal<USDC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);

        coin::deposit(pool_owner_addr, usdc_reminder);
        coin::deposit(pool_owner_addr, usdt_swapped);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_curve_exact_swap_vice_versa_2(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        let usdt_to_get_val = 672790928;
        let usdc_to_swap_val = router::get_amount_in<USDC, USDT, LP>(pool_owner_addr, usdt_to_get_val);

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);
        let (usdc_reminder, usdt_swapped) = router::swap_coin_for_exact_coin<USDC, USDT, LP>(
            pool_owner_addr,
            usdc_to_swap,
            usdt_to_get_val,
        );

        assert!(coin::value(&usdc_reminder) == 0, 1);
        assert!(coin::value(&usdt_swapped) == usdt_to_get_val, 2);

        coin::register_internal<USDC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);

        coin::deposit(pool_owner_addr, usdc_reminder);
        coin::deposit(pool_owner_addr, usdt_swapped);
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
    #[expected_failure(abort_code = 100)]
    fun test_fail_convert_with_current_price_coin_in_val() {
        router::convert_with_current_price(0, 1, 1);
    }

    #[test]
    #[expected_failure(abort_code = 101)]
    fun test_fail_convert_with_current_price_reserve_in_size() {
        router::convert_with_current_price(1, 0, 1);
    }

    #[test]
    #[expected_failure(abort_code = 101)]
    fun test_fail_convert_with_current_price_reserve_out_size() {
        router::convert_with_current_price(1, 1, 0);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_get_curve_type_stables(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_address = signer::address_of(&pool_owner);
        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_address) == 1, 0);
        assert!(router::get_curve_type<USDT, USDC, LP>(pool_owner_address) == 1, 1);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_get_curve_type_uncorrelated(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_address = signer::address_of(&pool_owner);
        assert!(router::get_curve_type<BTC, USDT, LP>(pool_owner_address) == 2, 0);
        assert!(router::get_curve_type<USDT, BTC, LP>(pool_owner_address) == 2, 1);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_get_decimals_scales_stables(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_address = signer::address_of(&pool_owner);
        let (x, y) = router::get_decimals_scales<USDC, USDT, LP>(pool_owner_address);

        // USDC 4 decimals
        assert!(x == 10000, 0);
        // USDT 6 decimals
        assert!(y == 1000000, 1);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_get_decimals_scales_uncorrelated(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_address = signer::address_of(&pool_owner);
        let (x, y) = router::get_decimals_scales<BTC, USDT, LP>(pool_owner_address);

        assert!(x == 0, 0);
        assert!(y == 0, 1);
    }
}
