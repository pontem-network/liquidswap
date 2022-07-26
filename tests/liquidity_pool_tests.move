#[test_only]
module liquidswap::liquidity_pool_tests {
    use std::string::utf8;
    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::genesis;

    use liquidswap::liquidity_pool;
    use test_coin_admin::test_coins::{Self, USDT, BTC};
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
        assert!(x_res_val == 0, 3);
        assert!(y_res_val == 0, 4);

        let (x_price, y_price, _) =
            liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_price == 0, 1);
        assert!(y_price == 0, 2);
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
    #[expected_failure(abort_code = 7)]
    fun test_fail_if_coin_lp_registered_as_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);
        test_lp::register_lp_for_fails(&coin_admin);

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
        assert!(coin::value(&lp_coins) == 99100, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 100100, 2);
        assert!(y_res == 100100, 3);

        let (btc_return, usdt_return) =
            liquidity_pool::burn<BTC, USDT, LP>(pool_owner_addr, lp_coins);

        assert!(coin::value(&btc_return) == 100100, 1);
        assert!(coin::value(&usdt_return) == 100100, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 0, 2);
        assert!(y_res == 0, 3);

        test_coins::burn(&coin_admin, btc_return);
        test_coins::burn(&coin_admin, usdt_return);
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
        assert!(coin::value(&usdt_coins) == 1, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 100102, 2);
        assert!(y_res == 100099, 2);

        coin::destroy_zero(zero);
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

        assert!(liquidity_pool::pool_exists_at<BTC, USDT, LP>(signer::address_of(&pool_owner)), 1);
        assert!(!liquidity_pool::pool_exists_at<USDT, BTC, LP>(signer::address_of(&pool_owner)), 2);
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

        assert!(fee_pct == 30, 1);
        assert!(fee_scale == 10000, 2);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coins_with_stable_curve_type(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-BTC-USDT"),
            1
        );

        let pool_owner_addr = signer::address_of(&pool_owner);
        // 10 btc
        let btc_coins = test_coins::mint<BTC>(&coin_admin, 1000000000);
        // 10000 usdt
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1000000000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coin::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        // 2 btc
        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 200000000);
        // 200 usdt
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 140000000
            );
        assert!(coin::value(&usdt_coins) == 140000000, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 1199800000, 2);
        assert!(y_res == 860000000, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_flashloan_coins(core: signer, coin_admin: signer, pool_owner: signer) {
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
        let (zero, usdt_coins, loan) =
            liquidity_pool::flashloan<BTC, USDT, LP>(pool_owner_addr, 0, 1);
        assert!(coin::value(&usdt_coins) == 1, 1);

        liquidity_pool::pay_flashloan(btc_coins_to_exchange, coin::zero<USDT>(), loan);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 100102, 2);
        assert!(y_res == 100099, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }
}
