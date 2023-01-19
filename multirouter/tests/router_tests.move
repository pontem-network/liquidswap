#[test_only]
module multirouter::router_tests {
    use std::signer;

    use aptos_framework::coin;
    use liquidswap_lp::lp_coin::LP;

    use liquidswap::router_v2;
    use multirouter::router as multirouter;
    use liquidswap::curves::{Uncorrelated, Stable};
    use liquidswap::liquidity_pool;
    use test_coin_admin::test_coins::{Self, USDT, BTC, USDC, ETH, DAI};
    use test_helpers::test_pool;
    use aptos_framework::account;

    // Add BTC/USDT, USDC/USDT pair
    fun register_x2_pool_with_liquidity(x0_val: u64, y0_val: u64, x1_val: u64, y1_val: u64): (signer, signer) {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();

        router_v2::register_pool<BTC, USDT, Uncorrelated>(&lp_owner);

        let lp_owner_addr = signer::address_of(&lp_owner);
        if (x0_val != 0 && y0_val != 0) {
            let btc_coins = test_coins::mint<BTC>(&coin_admin, x0_val);
            let usdt_coins = test_coins::mint<USDT>(&coin_admin, y0_val);
            let lp_coins =
                liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
            coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
            coin::deposit<LP<BTC, USDT, Uncorrelated>>(lp_owner_addr, lp_coins);
        };

        router_v2::register_pool<USDC, USDT, Stable>(&lp_owner);

        if (x1_val != 0 && y1_val != 0) {
            let usdc_coins = test_coins::mint<USDC>(&coin_admin, x1_val);
            let usdt_coins = test_coins::mint<USDT>(&coin_admin, y1_val);
            let lp_coins =
                liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
            coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
            coin::deposit<LP<USDC, USDT, Stable>>(lp_owner_addr, lp_coins);
        };

        (coin_admin, lp_owner)
    }

    // Add ETH/USDC pair
    fun register_x3_pool_with_liquidity(x0_val: u64, y0_val: u64, x1_val: u64, y1_val: u64, x2_val: u64, y2_val: u64): (signer, signer) {
        let (coin_admin, lp_owner) = register_x2_pool_with_liquidity(x0_val, y0_val, x1_val, y1_val);

        let lp_owner_addr = signer::address_of(&lp_owner);

        router_v2::register_pool<ETH, USDC, Uncorrelated>(&lp_owner);

        if (x2_val != 0 && y2_val != 0) {
            let eth_coins = test_coins::mint<ETH>(&coin_admin, x2_val);
            let usdc_coins = test_coins::mint<USDC>(&coin_admin, y2_val);
            let lp_coins =
                liquidity_pool::mint<ETH, USDC, Uncorrelated>(eth_coins, usdc_coins);
            coin::register<LP<ETH, USDC, Uncorrelated>>(&lp_owner);
            coin::deposit<LP<ETH, USDC, Uncorrelated>>(lp_owner_addr, lp_coins);
        };

        (coin_admin, lp_owner)
    }

    // Add DAI/ETH pair
    fun register_x4_pool_with_liquidity(x0_val: u64, y0_val: u64, x1_val: u64, y1_val: u64, x2_val: u64, y2_val: u64, x3_val: u64, y3_val: u64): (signer, signer) {
        let (coin_admin, lp_owner) = register_x3_pool_with_liquidity(x0_val, y0_val, x1_val, y1_val, x2_val, y2_val);

        let lp_owner_addr = signer::address_of(&lp_owner);

        router_v2::register_pool<DAI, ETH, Uncorrelated>(&lp_owner);

        if (x3_val != 0 && y3_val != 0) {
            let eth_coins = test_coins::mint<ETH>(&coin_admin, x3_val);
            let dai_coins = test_coins::mint<DAI>(&coin_admin, y3_val);
            let lp_coins = liquidity_pool::mint<DAI, ETH, Uncorrelated>(dai_coins, eth_coins);
            coin::register<LP<DAI, ETH, Uncorrelated>>(&lp_owner);
            coin::deposit<LP<DAI, ETH, Uncorrelated>>(lp_owner_addr, lp_coins);
        };

        (coin_admin, lp_owner)
    }

    // Add ETH/USDT, BTC/ETH pair
    fun register_x6_pool_with_liquidity(
        x0_val: u64,
        y0_val: u64,
        x1_val: u64,
        y1_val: u64,
        x2_val: u64,
        y2_val: u64,
        x3_val: u64,
        y3_val: u64,
        x4_val: u64,
        y4_val: u64,
        x5_val: u64,
        y5_val: u64
    ): (signer, signer) {
        let (coin_admin, lp_owner) = register_x4_pool_with_liquidity(x0_val, y0_val, x1_val, y1_val, x2_val, y2_val, x3_val, y3_val);

        let lp_owner_addr = signer::address_of(&lp_owner);

        router_v2::register_pool<ETH, USDT, Uncorrelated>(&lp_owner);

        if (x4_val != 0 && y4_val != 0) {
            let eth_coins = test_coins::mint<ETH>(&coin_admin, x4_val);
            let usdt_coins = test_coins::mint<USDT>(&coin_admin, y4_val);
            let lp_coins = liquidity_pool::mint<ETH, USDT, Uncorrelated>(eth_coins, usdt_coins);
            coin::register<LP<ETH, USDT, Uncorrelated>>(&lp_owner);
            coin::deposit<LP<ETH, USDT, Uncorrelated>>(lp_owner_addr, lp_coins);
        };

        router_v2::register_pool<BTC, ETH, Uncorrelated>(&lp_owner);

        if (x5_val != 0 && y5_val != 0) {
            let btc_coins = test_coins::mint<BTC>(&coin_admin, x5_val);
            let eth_coins = test_coins::mint<ETH>(&coin_admin, y5_val);
            let lp_coins = liquidity_pool::mint<BTC, ETH, Uncorrelated>(btc_coins, eth_coins);
            coin::register<LP<BTC, ETH, Uncorrelated>>(&lp_owner);
            coin::deposit<LP<BTC, ETH, Uncorrelated>>(lp_owner_addr, lp_coins);
        };

        (coin_admin, lp_owner)
    }

    #[test]
    public entry fun test_swap_coin_for_coin_unchecked_x2() {
        let account = account::create_account_for_test(@test_account);
        let account_addr = signer::address_of(&account);

        let (coin_admin, _) = register_x2_pool_with_liquidity(
            1000000000, 150000000000,
            1500000000, 150000000000
        );

        let btc_user_balance_val = 50000000;
        let btc_user_balance = test_coins::mint<BTC>(&coin_admin, btc_user_balance_val);
        coin::register<BTC>(&account);
        coin::deposit(account_addr, btc_user_balance);

        let usdc_to_get_val = 149;
        let usdt_amount_in = router_v2::get_amount_in<USDT, USDC, Stable>(usdc_to_get_val);
        let btc_amount_in = router_v2::get_amount_in<BTC, USDT, Uncorrelated>(usdt_amount_in);

        multirouter::swap_coin_for_coin_unchecked_x2<BTC, USDT, USDC, Uncorrelated, Stable>(
            &account,
            btc_amount_in,
            usdc_to_get_val
        );

        let (btc_res_val, usdt_res_val) = router_v2::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(btc_res_val == 1000000000 + btc_amount_in, 0);
        assert!(usdt_res_val == 150000000000 - usdt_amount_in, 0);

        let (usdc_res_val, usdt_res_val) = router_v2::get_reserves_size<USDC, USDT, Stable>();

        assert!(usdt_res_val == 150000014905, 0); // We count non-zero DAO fee.
        assert!(usdc_res_val == 1500000000 - usdc_to_get_val, 0);

        assert!(coin::balance<BTC>(account_addr) == btc_user_balance_val - btc_amount_in, 0);
        assert!(coin::balance<USDC>(account_addr) == usdc_to_get_val, 0);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_x2_1() {
        let account = account::create_account_for_test(@test_account);
        let account_addr = signer::address_of(&account);

        let (coin_admin, _) = register_x2_pool_with_liquidity(
            1000000000, 150000000000,
            1500000000, 150000000000
        );

        let usdc_user_balance = 100000000;
        let usdc_coins_user_balance = test_coins::mint<USDC>(&coin_admin, usdc_user_balance);
        coin::register<USDC>(&account);
        coin::deposit(account_addr, usdc_coins_user_balance);

        let btc_to_get_val = 100;
        let usdt_amount_in = router_v2::get_amount_in<USDT, BTC, Uncorrelated>(btc_to_get_val);
        let usdc_amount_in = router_v2::get_amount_in<USDC, USDT, Stable>(usdt_amount_in);

        multirouter::swap_coin_for_coin_unchecked_x2<USDC, USDT, BTC, Stable, Uncorrelated>(
            &account,
            usdc_amount_in,
            btc_to_get_val
        );

        let (usdc_res_val, usdt_res_val) = router_v2::get_reserves_size<USDC, USDT, Stable>();
        assert!(usdt_res_val == 150000000000 - usdt_amount_in, 0);
        assert!(usdc_res_val == 1500000000 + usdc_amount_in, 0);

        let (usdt_res_val, btc_res_val) = router_v2::get_reserves_size<USDT, BTC, Uncorrelated>();
        assert!(usdt_res_val == 150000015031, 0); // We count non-zero DAO fee.
        assert!(btc_res_val == 1000000000 - btc_to_get_val, 0);

        assert!(coin::balance<USDC>(account_addr) == usdc_user_balance - usdc_amount_in, 0);
        assert!(coin::balance<BTC>(account_addr) == btc_to_get_val, 0);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_x3() {
        let account = account::create_account_for_test(@test_account);
        let account_addr = signer::address_of(&account);

        let (coin_admin, _) = register_x3_pool_with_liquidity(
            1000000000, 13200000000000,
            1500000000, 150000000000,
            1000000000, 111500000,
        );

        let btc_user_balance_val = 100000000;
        let btc_coins_user_balance = test_coins::mint<BTC>(&coin_admin, btc_user_balance_val);
        coin::register<BTC>(&account);
        coin::deposit(account_addr, btc_coins_user_balance);

        let eth_amount_to_get = 100000000;
        let usdc_amount_in = router_v2::get_amount_in<USDC, ETH, Uncorrelated>(eth_amount_to_get);
        let usdt_amount_in = router_v2::get_amount_in<USDT, USDC, Stable>(usdc_amount_in);
        let btc_amount_in =  router_v2::get_amount_in<BTC, USDT, Uncorrelated>(usdt_amount_in);

        multirouter::swap_coin_for_coin_unchecked_x3<BTC, USDT, USDC, ETH, Uncorrelated, Stable, Uncorrelated>(
            &account,
            btc_amount_in,
            eth_amount_to_get
        );

        let (btc_res_val, usdt_res_val) = router_v2::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(btc_res_val == 1000094374, 0); // We count non-zero DAO fee.
        assert!(usdt_res_val == 13200000000000 - usdt_amount_in, 0);

        let (usdt_res_val, usdc_res_val) = router_v2::get_reserves_size<USDT, USDC, Stable>();
        assert!(usdt_res_val == 151242865778, 0); // We count non-zero DAO fee.
        assert!(usdc_res_val == 1500000000 - usdc_amount_in, 0);

        let (usdc_res_val, eth_res_val) = router_v2::get_reserves_size<USDC, ETH, Uncorrelated>();

        assert!(usdc_res_val == 123913742, 0); // We count non-zero DAO fee.
        assert!(eth_res_val == 1000000000 - eth_amount_to_get, 0);

        assert!(coin::balance<BTC>(account_addr) == btc_user_balance_val - btc_amount_in, 0);
        assert!(coin::balance<ETH>(account_addr) == eth_amount_to_get, 0);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_x4() {
        let account = account::create_account_for_test(@test_account);
        let account_addr = signer::address_of(&account);

        let (coin_admin, _) = register_x4_pool_with_liquidity(
            1000000000, 13200000000000,
            1500000000, 150000000000,
            1000000000, 111500000,
            900000000, 1176100000000,
        );

        let btc_user_balance_val = 100000000;
        let btc_coins_user_balance = test_coins::mint<BTC>(&coin_admin, btc_user_balance_val);
        coin::register<BTC>(&account);
        coin::deposit(account_addr, btc_coins_user_balance);

        let dai_amount_to_get = 100000000000;
        let eth_amount_in = router_v2::get_amount_in<ETH, DAI, Uncorrelated>(dai_amount_to_get);
        let usdc_amount_in = router_v2::get_amount_in<USDC, ETH, Uncorrelated>(eth_amount_in);
        let usdt_amount_in = router_v2::get_amount_in<USDT, USDC, Stable>(usdc_amount_in);
        let btc_amount_in =  router_v2::get_amount_in<BTC, USDT, Uncorrelated>(usdt_amount_in);

        multirouter::swap_coin_for_coin_unchecked_x4<
            BTC,
            USDT,
            USDC,
            ETH,
            DAI,
            Uncorrelated,
            Stable,
            Uncorrelated,
            Uncorrelated
        >(
            &account,
            btc_amount_in,
            dai_amount_to_get
        );

        let (btc_res_val, usdt_res_val) = router_v2::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(btc_res_val == 1000077774, 0); // We count non-zero DAO fee.
        assert!(usdt_res_val == 13200000000000 - usdt_amount_in, 0);

        let (usdt_res_val, usdc_res_val) = router_v2::get_reserves_size<USDT, USDC, Stable>();
        assert!(usdt_res_val == 151024265058, 0); // We count non-zero DAO fee.
        assert!(usdc_res_val == 1500000000 - usdc_amount_in, 0);

        let (usdc_res_val, eth_res_val) = router_v2::get_reserves_size<USDC, ETH, Uncorrelated>();
        assert!(usdc_res_val == 121730360, 0); // We count non-zero DAO fee.
        assert!(eth_res_val == 1000000000 - eth_amount_in, 0);

        let (dai_res_val, eth_res_val) = router_v2::get_reserves_size<DAI, ETH, Uncorrelated>();
        assert!(eth_res_val == 983803124, 0); // We count non-zero DAO fee.
        assert!(dai_res_val == 1176100000000 - dai_amount_to_get, 0);

        assert!(coin::balance<BTC>(account_addr) == btc_user_balance_val - btc_amount_in, 0);
        assert!(coin::balance<DAI>(account_addr) == dai_amount_to_get, 0);
    }

    // Errors.

    #[test]
    #[expected_failure(abort_code = multirouter::router::ERR_INSUFFICIENT_AMOUNT)]
    fun test_swap_coin_for_coin_x2_fails_enfucient_amount() {
        let account = account::create_account_for_test(@test_account);

        let (_, _) = register_x2_pool_with_liquidity(
            1000000000, 13200000000000,
            1500000000, 150000000000,
        );

        multirouter::swap_coin_for_coin_unchecked_x2<BTC, USDT, USDC, Uncorrelated, Stable>(
            &account,
            1,
            10000000
        );
    }

    #[test]
    #[expected_failure(abort_code = multirouter::router::ERR_INSUFFICIENT_AMOUNT)]
    fun test_swap_coin_for_coin_x3_fails_enfucient_amount() {
        let account = account::create_account_for_test(@test_account);

        let (_, _) = register_x3_pool_with_liquidity(
            1000000000, 13200000000000,
            1500000000, 150000000000,
            1000000000, 111500000,
        );

        multirouter::swap_coin_for_coin_unchecked_x3<BTC, USDT, USDC, ETH, Uncorrelated, Stable, Uncorrelated>(
            &account,
            1,
            10000000
        );
    }

    #[test]
    #[expected_failure(abort_code = multirouter::router::ERR_INSUFFICIENT_AMOUNT)]
    fun test_swap_coin_for_coin_x4_fails_enfucient_amount() {
        let account = account::create_account_for_test(@test_account);

        let (_, _) = register_x4_pool_with_liquidity(
            1000000000, 13200000000000,
            1500000000, 150000000000,
            1000000000, 111500000,
            900000000, 1176100000000,
        );

        multirouter::swap_coin_for_coin_unchecked_x4<
            BTC,
            USDT,
            USDC,
            ETH,
            DAI,
            Uncorrelated,
            Stable,
            Uncorrelated,
            Uncorrelated
        >(
            &account,
            1,
            10000000
        );
    }
}