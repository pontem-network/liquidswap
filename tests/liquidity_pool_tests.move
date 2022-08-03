#[test_only]
module liquidswap::liquidity_pool_tests {
    use std::string::utf8;
    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::genesis;

    use liquidswap::liquidity_pool;
    use test_coin_admin::test_coins::{Self, USDT, BTC, USDC};
    use test_pool_owner::test_lp::{Self, LP};

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_create_empty_pool_without_any_liquidity(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);
        let pool_owner_addr = signer::address_of(&pool_owner);

        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-BTC-USDT"),
            2
        );

        let (x_res_val, y_res_val) =
            liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res_val == 0, 0);
        assert!(y_res_val == 0, 1);

        let (x_price, y_price, _) =
            liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_price == 0, 2);
        assert!(y_price == 0, 3);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 100)]
    fun test_fail_if_coin_generics_provided_in_the_wrong_order(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

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
    #[expected_failure(abort_code = 524289)]
    fun test_fail_if_coin_lp_registered_as_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

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
    fun test_add_liquidity_and_then_burn_it(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

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

        let (btc_return, usdt_return) =
            liquidity_pool::burn<BTC, USDT, LP>(pool_owner_addr, lp_coins);

        assert!(coin::value(&btc_return) == 100100, 3);
        assert!(coin::value(&usdt_return) == 100100, 4);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 0, 5);
        assert!(y_res == 0, 6);

        test_coins::burn(&coin_admin, btc_return);
        test_coins::burn(&coin_admin, usdt_return);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 103)]
    fun test_add_liquidity_zero(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

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

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 100100, 3);
        assert!(y_res == 100100, 4);

        coin::register_internal<LP>(&coin_admin);
        coin::deposit(signer::address_of(&coin_admin), lp_coins);
        coin::deposit(signer::address_of(&coin_admin), lp_coins_zero);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

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
        coin::register_internal<LP>(&pool_owner);
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

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_1(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

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
        coin::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 100000000);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 27640424963
            );
        assert!(coin::value(&usdt_coins) == 27640424963, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 10099900000, 1);
        assert!(y_res == 2772359575037, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code=105)]
    fun test_swap_coins_1_fail(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

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
        coin::register_internal<LP>(&pool_owner);
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
        coin::register_internal<LP>(&pool_owner);
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
        coin::register_internal<LP>(&pool_owner);
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
        coin::register_internal<LP>(&pool_owner);
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
        coin::register_internal<LP>(&pool_owner);
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
        coin::register_internal<LP>(&pool_owner);
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
        coin::register_internal<LP>(&pool_owner);
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
    fun test_pool_exists(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

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

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_with_stable_curve_type(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

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
        coin::register_internal<LP>(&pool_owner);
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
        coin::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 7078017525);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 672790928315
            );
        assert!(coin::value(&usdt_coins) == 672790928315, 0);

         let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
         assert!(x_res == 22070939508, 1);
         assert!(y_res == 827209071685, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_with_stable_curve_type_2(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

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
        coin::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 152);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 15000
            );
        assert!(coin::value(&usdt_coins) == 15000, 0);

         let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
         assert!(x_res == 15000000152, 1);
         assert!(y_res == 1499999985000, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_with_stable_curve_type_3(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

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
        coin::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 6748155);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 672790928
            );
        assert!(coin::value(&usdt_coins) == 672790928, 0);

         let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
         assert!(x_res == 15006741407, 1);
         assert!(y_res == 1499327209072, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_with_stable_curve_type_1_unit(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

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
        coin::register_internal<LP>(&pool_owner);
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
        coin::register_internal<LP>(&pool_owner);
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
        coin::register_internal<LP>(&pool_owner);
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
        coin::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 1000000);
        let (usdc_coins, zero) =
            liquidity_pool::swap<USDC, USDT, LP>(
                pool_owner_addr,
                coin::zero<USDC>(), 9969,
                usdt_coins_to_exchange, 0
            );
        assert!(coin::value(&usdc_coins) == 9969, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, LP>(pool_owner_addr);
        assert!(y_res == 100999000, 1);
        assert!(x_res == 990031, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdc_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_two_coins_with_stable_curve(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

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
        coin::register_internal<LP>(&pool_owner);
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
        coin::register_internal<LP>(&pool_owner);
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
        coin::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 125804400);
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
        coin::register_internal<LP>(&pool_owner);
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
}
