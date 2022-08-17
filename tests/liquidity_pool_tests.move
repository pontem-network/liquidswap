#[test_only]
module liquidswap::liquidity_pool_tests {
    use std::string::utf8;
    use std::signer;
    use std::option;

    use aptos_framework::coin;
    use aptos_framework::coins;
    use aptos_framework::genesis;
    use aptos_framework::timestamp;

    use liquidswap::liquidity_pool;
    use liquidswap::coin_helper::supply;

    use test_coin_admin::test_coins::{Self, USDT, BTC, USDC};
    use test_pool_owner::test_lp::{Self, LP};
    use test_helpers::test_account::create_account;
    use liquidswap::emergency;

    // Register pool tests.

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_create_empty_pool(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);
        let pool_owner_addr = signer::address_of(&pool_owner);

        let pool_curve_type = 2;
        let pool_lp_name = utf8(b"LiquidSwap LP");
        let pool_lp_symbol = utf8(b"LP-BTC-USDT");

        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            pool_lp_name,
            pool_lp_symbol,
            pool_curve_type,
        );

        let (x_res_val, y_res_val) =
            liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res_val == 0, 0);
        assert!(y_res_val == 0, 1);

        let (x_price, y_price, _) =
            liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_price == 0, 2);
        assert!(y_price == 0, 3);

        // Check created LP.

        let curve_type = liquidity_pool::get_curve_type<BTC, USDT, LP>(pool_owner_addr);
        assert!(coin::is_coin_initialized<LP>(), 4);
        assert!(curve_type == pool_curve_type, 5);
        let lp_name = coin::name<LP>();
        assert!(lp_name == pool_lp_name, 6);
        let lp_symbol = coin::symbol<LP>();
        assert!(lp_symbol == pool_lp_symbol, 7);
        let lp_supply = coin::supply<LP>();
        assert!(option::is_some(&lp_supply), 8);
        assert!(*option::borrow(&lp_supply) == 0, 9);

        // Get cummulative prices.

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 0, 10);
        assert!(y_cum_price == 0, 11);
        assert!(ts == 0, 12);

        // Check if it's locked.
        assert!(!liquidity_pool::is_pool_locked<BTC, USDT, LP>(pool_owner_addr), 13);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner, emergency_acc = @emergency)]
    #[expected_failure(abort_code=4002)]
    fun test_create_pool_emergency_fails(core: signer, coin_admin: signer, pool_owner: signer, emergency_acc: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        let pool_curve_type = 2;
        let pool_lp_name = utf8(b"LiquidSwap LP");
        let pool_lp_symbol = utf8(b"LP-BTC-USDT");

        emergency::pause(&emergency_acc);
        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            pool_lp_name,
            pool_lp_symbol,
            pool_curve_type,
        );
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_create_empty_pool_stable(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);
        let pool_owner_addr = signer::address_of(&pool_owner);

        let pool_curve_type = 1;
        let pool_lp_name = utf8(b"LiquidSwap LP");
        let pool_lp_symbol = utf8(b"LP-BTC-USDT");

        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            pool_lp_name,
            pool_lp_symbol,
            pool_curve_type,
        );

        let (x_res_val, y_res_val) =
            liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res_val == 0, 0);
        assert!(y_res_val == 0, 1);

        // Check scales.
        let (x_scale, y_scale) = liquidity_pool::get_decimals_scales<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_scale == 100000000, 2);
        assert!(y_scale == 1000000, 3);

        // Check created LP.

        let curve_type = liquidity_pool::get_curve_type<BTC, USDT, LP>(pool_owner_addr);
        assert!(coin::is_coin_initialized<LP>(), 4);
        assert!(curve_type == pool_curve_type, 5);
        let lp_name = coin::name<LP>();
        assert!(lp_name == pool_lp_name, 6);
        let lp_symbol = coin::symbol<LP>();
        assert!(lp_symbol == pool_lp_symbol, 7);
        let lp_supply = coin::supply<LP>();
        assert!(option::is_some(&lp_supply), 8);

        // Get cummulative prices.

        let (x_cumm_price, y_cumm_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cumm_price == 0, 9);
        assert!(y_cumm_price == 0, 10);
        assert!(ts == 0, 11);

        // Check if it's locked.
        assert!(!liquidity_pool::is_pool_locked<BTC, USDT, LP>(pool_owner_addr), 12);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 100)]
    fun test_fail_if_coin_generics_provided_in_the_wrong_order(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);
        let pool_owner_addr = signer::address_of(&pool_owner);
        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-BTC-USDT"),
            2
        );

        // here generics are provided as USDT-BTC, but pool is BTC-USDT. `reverse` parameter is irrelevant
        let (_x_price, _y_price, _) =
            liquidity_pool::get_cumulative_prices<USDT, BTC, LP>(pool_owner_addr);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 3001)]
    fun test_fail_if_x_is_not_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coin<USDT>(&coin_admin, b"USDT", b"USDT", 6);

        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-BTC-USDT"),
            2
        );
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 3001)]
    fun test_fail_if_y_is_not_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coin<BTC>(&coin_admin, b"BTC", b"BTC", 8);

        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-BTC-USDT"),
            2
        );
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 524289)]
    fun test_fail_register_if_lp_is_coin_already(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);
        test_lp::register_lp_for_fails(&pool_owner);

        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-BTC-USDT"),
            2
        );
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 101)]
    fun test_fail_if_pool_already_exists(core: signer, coin_admin: signer, pool_owner: signer) {
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

        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-BTC-USDT"),
            2
        );
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 110)]
    fun test_fail_if_wrong_curve(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-BTC-USDT"),
            0
        );
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 110)]
    fun test_fail_if_wrong_curve_1(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-BTC-USDT"),
            3
        );
    }

    // Add liquidity tests.
    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_add_liquidity_to_empty_pool(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_liq_val = 100000000;
        let usdt_liq_val = 28000000000;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val);

        timestamp::fast_forward_seconds(1660338836);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_liq, usdt_liq);

        let expected_liquidity = 1673320053 - 1000;
        assert!(coin::value(&lp_coins) == expected_liquidity, 0);
        assert!(supply<LP>() == (expected_liquidity as u128), 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == btc_liq_val, 2);
        assert!(y_res == usdt_liq_val, 3);

        let (x_price, y_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_price == 0, 4);
        assert!(y_price == 0, 5);
        assert!(ts == 1660338836, 6);

        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins)
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code=102)]
    fun test_add_liquidity_less_than_minimal(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_liq_val = 1000;
        let usdt_liq_val = 1000;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_liq, usdt_liq);

        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins)
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code=102)]
    fun test_add_liquidity_zero_initially(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_liq_val = 0;
        let usdt_liq_val = 0;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_liq, usdt_liq);

        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins)
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_add_liquidity_minimal(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_liq_val = 1001;
        let usdt_liq_val = 1001;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_liq, usdt_liq);

        let expected_liquidity = 1001 - 1000;
        assert!(coin::value(&lp_coins) == expected_liquidity, 0);
        assert!(supply<LP>() == (expected_liquidity as u128), 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == btc_liq_val, 2);
        assert!(y_res == usdt_liq_val, 3);

        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins)
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner, emergency_acc = @emergency)]
    #[expected_failure(abort_code=4002)]
    fun test_add_liquidity_emergency_stop_fails(core: signer, coin_admin: signer, pool_owner: signer, emergency_acc: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_liq_val = 1001;
        let usdt_liq_val = 1001;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val);

        emergency::pause(&emergency_acc);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_liq, usdt_liq);

        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins)
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_add_liquidity_after_initial_liquidity_added(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_liq_val = 100000000;
        let usdt_liq_val = 28000000000;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val);

        let initial_ts = 1660338836;
        timestamp::fast_forward_seconds(initial_ts);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_liq, usdt_liq);

        let expected_liquidity = 1673320053 - 1000;
        assert!(coin::value(&lp_coins) == expected_liquidity, 0);
        assert!(supply<LP>() == (expected_liquidity as u128), 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == btc_liq_val, 2);
        assert!(y_res == usdt_liq_val, 3);

        let (x_price, y_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_price == 0, 4);
        assert!(y_price == 0, 5);
        assert!(ts == initial_ts, 6);

        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        timestamp::fast_forward_seconds(360);

        let expected_liquidity_2 = 3346638106;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val * 2);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val * 2);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_liq, usdt_liq);

        assert!(coin::value(&lp_coins) == expected_liquidity_2, 7);
        assert!(supply<LP>() == ((expected_liquidity_2+expected_liquidity) as u128), 8);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == btc_liq_val * 3, 9);
        assert!(y_res == usdt_liq_val * 3, 10);

        let (x_price, y_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_price == 1859431802629922802792000, 11);
        assert!(y_price == 23717242380483709200, 12);
        assert!(ts == initial_ts + 360, 13);

        coin::deposit(pool_owner_addr, lp_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 103)]
    fun test_add_liquidity_zero(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        assert!(coin::value(&lp_coins) == 99100, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 100100, 1);
        assert!(y_res == 100100, 2);

        let lp_coins_zero = liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, coin::zero(), coin::zero());

        coins::register_internal<LP>(&coin_admin);
        coin::deposit(signer::address_of(&coin_admin), lp_coins);
        coin::deposit(signer::address_of(&coin_admin), lp_coins_zero);
    }

    // Test burn liquidity.
    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_burn_liquidity(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 2000000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 560000000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        assert!(coin::value(&lp_coins) == 33466401060363, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 2000000000000, 1);
        assert!(y_res == 560000000000000, 2);

        let (btc_return, usdt_return) =
            liquidity_pool::burn<BTC, USDT, LP>(pool_owner_addr, lp_coins);

        assert!(coin::value(&btc_return) == 2000000000000, 3);
        assert!(coin::value(&usdt_return) == 560000000000000, 4);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 0, 5);
        assert!(y_res == 0, 6);

        test_coins::burn(&coin_admin, btc_return);
        test_coins::burn(&coin_admin, usdt_return);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_burn_liquidity_after_initial(core: signer, coin_admin: signer, pool_owner: signer) {
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

        // Initial liquidity

        timestamp::fast_forward_seconds(1660517742);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 2000000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 560000000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let lp_coins_initial =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);

        // Additional liquidity

        timestamp::fast_forward_seconds(7200);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 50000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 14000000000);

        let lp_coins_user =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);

        let (btc_return, usdt_return) =
            liquidity_pool::burn<BTC, USDT, LP>(pool_owner_addr, lp_coins_initial);

        assert!(coin::value(&btc_return) == 2000000000000, 0);
        assert!(coin::value(&usdt_return) == 560000000000008, 1);

        test_coins::burn(&coin_admin, btc_return);
        test_coins::burn(&coin_admin, usdt_return);

        let (btc_return, usdt_return) =
            liquidity_pool::burn<BTC, USDT, LP>(pool_owner_addr, lp_coins_user);

        assert!(coin::value(&btc_return) == 50000000, 2);
        assert!(coin::value(&usdt_return) == 13999999992, 3);

        test_coins::burn(&coin_admin, btc_return);
        test_coins::burn(&coin_admin, usdt_return);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 0, 4);
        assert!(y_res == 0, 5);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 37188636052598456055840000, 6);
        assert!(y_cum_price == 474344847609674184000, 7);
        assert!(ts == 1660517742 + 7200, 8);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_overflow_and_emergency_exit(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 18446744073709551615);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 18446744073709551615);

        // Now we can't swap or add liquidity, if cumulative price is still has space, it wouldn never overflow,
        // we are able to exit.

        let pool_owner_addr = signer::address_of(&pool_owner);
        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);

        let (btc_return, usdt_return) =
            liquidity_pool::burn<BTC, USDT, LP>(pool_owner_addr, lp_coins);

        assert!(coin::value(&btc_return) == 18446744073709551615, 0);
        assert!(coin::value(&usdt_return) == 18446744073709551615, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 0, 2);
        assert!(y_res == 0, 3);

        test_coins::burn(&coin_admin, btc_return);
        test_coins::burn(&coin_admin, usdt_return);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner, emergency_acc = @emergency)]
    fun test_emergency_exit(core: signer, coin_admin: signer, pool_owner: signer, emergency_acc: signer) {
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

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 18446744073709551615);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 18446744073709551615);

        // Now we can't swap or add liquidity, if cumulative price is still has space, it wouldn never overflow,
        // we are able to exit.

        let pool_owner_addr = signer::address_of(&pool_owner);
        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);

        emergency::pause(&emergency_acc);
        assert!(emergency::is_emergency() == true, 0);

        let (btc_return, usdt_return) =
            liquidity_pool::burn<BTC, USDT, LP>(pool_owner_addr, lp_coins);

        assert!(coin::value(&btc_return) == 18446744073709551615, 1);
        assert!(coin::value(&usdt_return) == 18446744073709551615, 2);

        test_coins::burn(&coin_admin, btc_return);
        test_coins::burn(&coin_admin, usdt_return);
    }

    // Test swap.
    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 1
            );
        assert!(coin::value(&usdt_coins) == 1, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 100102, 1);
        assert!(y_res == 100099, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner, emergency_acc = @emergency)]
    #[expected_failure(abort_code=4002)]
    fun test_swap_coins_emergency_fails(core: signer, coin_admin: signer, pool_owner: signer, emergency_acc: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        emergency::pause(&emergency_acc);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 1
            );

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_max_amounts(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 18446744073709550615);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 18446744073709551615);

         let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 1000);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 0
            );

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_1(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        timestamp::fast_forward_seconds(1660545565);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        timestamp::fast_forward_seconds(20);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 100000000);
        let (btc_zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 27640424963
            );
        assert!(coin::value(&usdt_coins) == 27640424963, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 10099900000, 1);
        assert!(y_res == 2772359575037, 2);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 103301766812773489044000, 3);
        assert!(y_cum_price == 1317624576693539400, 4);
        assert!(ts == 1660545565+20,5);

        timestamp::fast_forward_seconds(3600);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 1000000);
        let (btc_coins, usdt_zero) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                coin::zero<BTC>(), 3632,
                usdt_coins_to_exchange, 0
            );

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 10099896368, 6);
        assert!(y_res == 2772360574037, 7);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 18331960191116039718441600, 8);
        assert!(y_cum_price == 243247632405227595000, 9);
        assert!(ts == 1660545565+20+3600, 10);

        coin::destroy_zero(btc_zero);
        coin::destroy_zero(usdt_zero);
        test_coins::burn(&coin_admin, btc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code=105)]
    fun test_swap_coins_1_fail(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 100000000);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 27640424964
            );
        assert!(coin::value(&usdt_coins) == 27640424964, 0);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code=104)]
    fun test_swap_coins_zero_fail(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let (btc_coins, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                coin::zero<BTC>(), 1,
                coin::zero<USDT>(), 1
            );

        test_coins::burn(&coin_admin, usdt_coins);
        test_coins::burn(&coin_admin, btc_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_vice_versa(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 28000000000);
        let (btc_coins, zero) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                coin::zero<BTC>(), 98715803,
                usdt_coins_to_exchange, 0
            );
        assert!(coin::value(&btc_coins) == 98715803, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 9901284197, 1);
        assert!(y_res == 2827972000000, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, btc_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code=105)]
    fun test_swap_coins_vice_versa_fail(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 28000000000);
        let (btc_coins, zero) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                coin::zero<BTC>(), 98715804,
                usdt_coins_to_exchange, 0
            );
        assert!(coin::value(&btc_coins) == 98715804, 0);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, btc_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_two_coins(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 28000000000);
        let btc_to_exchange = test_coins::mint<BTC>(&coin_admin, 100000000);
        let (btc_coins, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_to_exchange, 99900003,
                usdt_coins_to_exchange, 27859998039
            );

        assert!(coin::value(&btc_coins) == 99900003, 0);
        assert!(coin::value(&usdt_coins) == 27859998039, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 9999999997, 2);
        assert!(y_res == 2800112001961, 3);

        test_coins::burn(&coin_admin, btc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code=105)]
    fun test_swap_two_coins_failure(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 28000000000);
        let btc_to_exchange = test_coins::mint<BTC>(&coin_admin, 100000000);
        let (btc_coins, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_to_exchange, 99900003,
                usdt_coins_to_exchange, 27859998040
            );

        assert!(coin::value(&btc_coins) == 99900003, 0);
        assert!(coin::value(&usdt_coins) == 27859998040, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 9999999997, 2);
        assert!(y_res == 2800112001960, 3);

        test_coins::burn(&coin_admin, btc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 105)]
    fun test_cannot_swap_coins_and_reduce_value_of_pool(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        // 1 minus fee for 1
        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 1);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 1
            );
        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_with_stable_curve_type(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<USDC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-USDC-USDT"),
            1
        );

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 1);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 99
            );
        assert!(coin::value(&usdt_coins) == 99, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 1000001, 1);
        assert!(y_res == 99999901, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_with_stable_curve_type_1(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<USDC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-USDC-USDT"),
            1
        );

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 15000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1500000000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 7078017525);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 672790928423
            );
        assert!(coin::value(&usdt_coins) == 672790928423, 0);

         let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
         assert!(x_res == 22070939508, 1);
         assert!(y_res == 827209071577, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_with_stable_curve_type_2(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<USDC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-USDC-USDT"),
            1
        );

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 15000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1500000000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 152);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 15199
            );
        assert!(coin::value(&usdt_coins) == 15199, 0);

         let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
         assert!(x_res == 15000000152, 1);
         assert!(y_res == 1499999984801, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_with_stable_curve_type_3(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<USDC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-USDC-USDT"),
            1
        );

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 15000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1500000000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 6748155);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 672791099
            );
        assert!(coin::value(&usdt_coins) == 672791099, 0);

         let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
         assert!(x_res == 15006741407, 1);
         assert!(y_res == 1499327208901, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_with_stable_curve_type_1_unit(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<USDC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-USDC-USDT"),
            1
        );

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 10000);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 996999
            );
        assert!(coin::value(&usdt_coins) == 996999, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 1009990, 1);
        assert!(y_res == 99003001, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code=105)]
    fun test_swap_coins_with_stable_curve_type_1_unit_fail(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<USDC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-USDC-USDT"),
            1
        );

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 10000);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 997000
            );
        assert!(coin::value(&usdt_coins) == 997000, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 1009990, 1);
        assert!(y_res == 99003000, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code=105)]
    fun test_swap_coins_with_stable_curve_type_fails(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<USDC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-USDC-USDT"),
            1
        );

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 1);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 100
            );
        assert!(coin::value(&usdt_coins) == 100, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 1000001, 1);
        assert!(y_res == 99999901, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_with_stable_curve_type_vice_versa(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<USDC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-USDC-USDT"),
            1
        );

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 999901);
        let (usdc_coins, zero) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                coin::zero<USDC>(), 9969,
                usdt_coins_to_exchange, 0
            );
        assert!(coin::value(&usdc_coins) == 9969, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
        assert!(y_res == 100998902, 1);
        assert!(x_res == 990031, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdc_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_two_coins_with_stable_curve(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<USDC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-USDC-USDT"),
            1
        );

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 1000000);
        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 10000);

        let (usdc_coins, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                usdc_coins_to_exchange, 9969,
                usdt_coins_to_exchange, 997099
            );

        assert!(coin::value(&usdc_coins) == 9969, 0);
        assert!(coin::value(&usdt_coins) == 997099, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 1000021, 2);
        assert!(y_res == 100001901, 3);

        test_coins::burn(&coin_admin, usdc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code=105)]
    fun test_swap_coins_two_coins_with_stable_curve_fail(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<USDC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-USDC-USDT"),
            1
        );

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 1000000);
        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 10000);

        let (usdc_coins, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                usdc_coins_to_exchange, 9970,
                usdt_coins_to_exchange, 997099
            );

        assert!(coin::value(&usdc_coins) == 9970, 0);
        assert!(coin::value(&usdt_coins) == 997099, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 1000020, 2);
        assert!(y_res == 100001901, 3);

        test_coins::burn(&coin_admin, usdc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_with_stable_curve_type_vice_versa_1(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<USDC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-USDC-USDT"),
            1
        );

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 15000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1500000000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 125804314);
        let (usdc_coins, zero) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                coin::zero<USDC>(), 1254269,
                usdt_coins_to_exchange, 0
            );
        assert!(coin::value(&usdc_coins) == 1254269, 0);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdc_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code=105)]
    fun test_swap_coins_with_stable_curve_type_vice_versa_fail(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<USDC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-USDC-USDT"),
            1
        );

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 1000000);
        let (usdc_coins, zero) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                coin::zero<USDC>(), 9970,
                usdt_coins_to_exchange, 0
            );
        assert!(coin::value(&usdc_coins) == 9970, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
        assert!(y_res == 100999000, 1);
        assert!(x_res == 990030, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdc_coins);
    }

    // Getters.

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner, emergency_acc = @emergency)]
    #[expected_failure(abort_code=4002)]
    fun test_get_reserves_emergency_fails(core: signer, coin_admin: signer, pool_owner: signer, emergency_acc: signer) {
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

        emergency::pause(&emergency_acc);

        let (_, _) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(signer::address_of(&pool_owner));
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner, emergency_acc = @emergency)]
    #[expected_failure(abort_code=4002)]
    fun test_get_cumulative_price_emergency_fails(core: signer, coin_admin: signer, pool_owner: signer, emergency_acc: signer) {
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

        emergency::pause(&emergency_acc);

        let (_, _, _) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(signer::address_of(&pool_owner));
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_pool_exists(core: signer, coin_admin: signer, pool_owner: signer) {
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

        assert!(liquidity_pool::pool_exists_at<BTC, USDT, LP>(signer::address_of(&pool_owner)), 0);
        assert!(!liquidity_pool::pool_exists_at<USDT, BTC, LP>(signer::address_of(&pool_owner)), 1);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_fees_config(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let (fee_pct, fee_scale) = liquidity_pool::get_fees_config();

        assert!(fee_pct == 30, 0);
        assert!(fee_scale == 10000, 1);
    }

    // End to end.

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_end_to_end(core: signer, coin_admin: signer, pool_owner: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins_initial = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins_initial = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        timestamp::fast_forward_seconds(1660545565);

        let lp_coins_initial =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins_initial, usdt_coins_initial);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 10000000000, 0);
        assert!(y_res == 2800000000000, 1);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 0, 2);
        assert!(y_cum_price == 0, 3);
        assert!(ts == 1660545565, 4);

        let btc_coins_user = test_coins::mint<BTC>(&coin_admin, 1500000000);
        let usdt_coins_user = test_coins::mint<USDT>(&coin_admin, 420000000000);

        let lp_coins_user =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins_user, usdt_coins_user);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 11500000000, 5);
        assert!(y_res == 3220000000000, 6);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 0, 7);
        assert!(y_cum_price == 0, 8);
        assert!(ts == 1660545565, 9);

        timestamp::fast_forward_seconds(3600);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2500000000);
        let (btc_zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 573582276219
            );
        assert!(coin::value(&usdt_coins) == 573582276219, 10);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 13997500000, 11);
        assert!(y_res == 2646417723781, 12);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 18594318026299228027920000, 12);
        assert!(y_cum_price == 237172423804837092000, 13);
        assert!(ts == 1660549165, 14);

        let lp_coins_user_val = coin::value(&lp_coins_user);
        let lp_coins_to_burn_part = coin::extract(&mut lp_coins_user, lp_coins_user_val / 2);
        let (btc_earned_user, usdt_earned_user) = liquidity_pool::burn<BTC, USDT, LP>(
            pool_owner_addr,
            lp_coins_to_burn_part,
        );

        assert!(coin::value(&btc_earned_user) == 912880434, 15);
        assert!(coin::value(&usdt_earned_user) == 172592460234, 16);

        test_coins::burn(&coin_admin, btc_earned_user);
        test_coins::burn(&coin_admin, usdt_earned_user);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 13084619566, 17);
        assert!(y_res == 2473825263547, 18);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 18594318026299228027920000, 19);
        assert!(y_cum_price == 237172423804837092000, 20);
        assert!(ts == 1660549165, 21);

        timestamp::fast_forward_seconds(3600);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 10000000000);
        let (btc_coins, usdt_zero) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                coin::zero<BTC>(), 52521904,
                usdt_coins_to_exchange, 0
            );

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 13032097662, 22);
        assert!(y_res == 2483815263547, 23);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 31149706178195224153700400, 24);
        assert!(y_cum_price == 588420782034956560800, 25);
        assert!(ts == 1660552765, 26);

        timestamp::fast_forward_seconds(3600);

        let (btc_earned_user, usdt_earned_user) = liquidity_pool::burn<BTC, USDT, LP>(
            pool_owner_addr,
            lp_coins_user,
        );
        assert!(coin::value(&btc_earned_user) == 909216115, 27);
        assert!(coin::value(&usdt_earned_user) == 173289436992, 28);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 12122881547, 29);
        assert!(y_res == 2310525826555, 30);

        let (btc_earned_initial, usdt_earned_initial) = liquidity_pool::burn<BTC, USDT, LP>(
            pool_owner_addr,
            lp_coins_initial,
        );
        assert!(coin::value(&btc_earned_initial) == 12122881547, 31);
        assert!(coin::value(&usdt_earned_initial) == 2310525826555, 32);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 0, 33);
        assert!(y_res == 0, 34);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 43806601518678425423523600, 35);
        assert!(y_cum_price == 936852159292991150400, 36);
        assert!(ts == 1660556365, 37);

        coin::destroy_zero(btc_zero);
        coin::destroy_zero(usdt_zero);
        test_coins::burn(&coin_admin, btc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
        test_coins::burn(&coin_admin, btc_earned_user);
        test_coins::burn(&coin_admin, usdt_earned_user);
        test_coins::burn(&coin_admin, btc_earned_initial);
        test_coins::burn(&coin_admin, usdt_earned_initial);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner, emergency_acc = @emergency)]
    fun test_end_to_end_emergency(core: signer, coin_admin: signer, pool_owner: signer, emergency_acc: signer) {
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

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins_initial = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins_initial = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        timestamp::fast_forward_seconds(1660545565);

        let lp_coins_initial =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins_initial, usdt_coins_initial);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 10000000000, 0);
        assert!(y_res == 2800000000000, 1);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 0, 2);
        assert!(y_cum_price == 0, 3);
        assert!(ts == 1660545565, 4);

        let btc_coins_user = test_coins::mint<BTC>(&coin_admin, 1500000000);
        let usdt_coins_user = test_coins::mint<USDT>(&coin_admin, 420000000000);

        let lp_coins_user =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins_user, usdt_coins_user);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 11500000000, 5);
        assert!(y_res == 3220000000000, 6);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 0, 7);
        assert!(y_cum_price == 0, 8);
        assert!(ts == 1660545565, 9);

        timestamp::fast_forward_seconds(3600);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2500000000);
        let (btc_zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 573582276219
            );
        assert!(coin::value(&usdt_coins) == 573582276219, 10);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 13997500000, 11);
        assert!(y_res == 2646417723781, 12);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 18594318026299228027920000, 13);
        assert!(y_cum_price == 237172423804837092000, 14);
        assert!(ts == 1660549165, 15);

        emergency::pause(&emergency_acc);
        let lp_coins_user_val = coin::value(&lp_coins_user);
        let lp_coins_to_burn_part = coin::extract(&mut lp_coins_user, lp_coins_user_val / 2);
        let (btc_earned_user, usdt_earned_user) = liquidity_pool::burn<BTC, USDT, LP>(
            pool_owner_addr,
            lp_coins_to_burn_part,
        );

        assert!(coin::value(&btc_earned_user) == 912880434, 16);
        assert!(coin::value(&usdt_earned_user) == 172592460234, 17);

        test_coins::burn(&coin_admin, btc_earned_user);
        test_coins::burn(&coin_admin, usdt_earned_user);

        emergency::resume(&emergency_acc);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 13084619566, 18);
        assert!(y_res == 2473825263547, 19);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 18594318026299228027920000, 20);
        assert!(y_cum_price == 237172423804837092000, 21);
        assert!(ts == 1660549165, 22);

        timestamp::fast_forward_seconds(3600);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 10000000000);
        let (btc_coins, usdt_zero) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                coin::zero<BTC>(), 52521904,
                usdt_coins_to_exchange, 0
            );

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 13032097662, 23);
        assert!(y_res == 2483815263547, 24);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 31149706178195224153700400, 25);
        assert!(y_cum_price == 588420782034956560800, 26);
        assert!(ts == 1660552765, 27);

        timestamp::fast_forward_seconds(3600);

        emergency::pause(&emergency_acc);

        let (btc_earned_user, usdt_earned_user) = liquidity_pool::burn<BTC, USDT, LP>(
            pool_owner_addr,
            lp_coins_user,
        );
        assert!(coin::value(&btc_earned_user) == 909216115, 28);
        assert!(coin::value(&usdt_earned_user) == 173289436992, 29);

        let (btc_earned_initial, usdt_earned_initial) = liquidity_pool::burn<BTC, USDT, LP>(
            pool_owner_addr,
            lp_coins_initial,
        );
        assert!(coin::value(&btc_earned_initial) == 12122881547, 30);
        assert!(coin::value(&usdt_earned_initial) == 2310525826555, 31);

        emergency::resume(&emergency_acc);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 0, 32);
        assert!(y_res == 0, 33);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_cum_price == 43806601518678425423523600, 34);
        assert!(y_cum_price == 936852159292991150400, 35);
        assert!(ts == 1660556365, 36);

        coin::destroy_zero(btc_zero);
        coin::destroy_zero(usdt_zero);
        test_coins::burn(&coin_admin, btc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
        test_coins::burn(&coin_admin, btc_earned_user);
        test_coins::burn(&coin_admin, usdt_earned_user);
        test_coins::burn(&coin_admin, btc_earned_initial);
        test_coins::burn(&coin_admin, usdt_earned_initial);
    }
}
