#[test_only]
module liquidswap::extended_router_tests {
    use std::signer;

    use aptos_framework::coin;
    use liquidswap_lp::lp_coin::LP;

    use liquidswap::router;
    use liquidswap::extended_router;
    use liquidswap::curves::{Uncorrelated, Stable};
    use liquidswap::liquidity_pool;
    use test_coin_admin::test_coins::{Self, USDT, BTC, USDC, ETH, DAI};
    use test_helpers::test_pool;

    // Add BTC/USDT, USDC/USDT pair
    fun register_x2_pool_with_liquidity(x0_val: u64, y0_val: u64, x1_val: u64, y1_val: u64): (signer, signer) {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();

        router::register_pool<BTC, USDT, Uncorrelated>(&lp_owner);

        let lp_owner_addr = signer::address_of(&lp_owner);
        if (x0_val != 0 && y0_val != 0) {
            let btc_coins = test_coins::mint<BTC>(&coin_admin, x0_val);
            let usdt_coins = test_coins::mint<USDT>(&coin_admin, y0_val);
            let lp_coins =
                liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
            coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
            coin::deposit<LP<BTC, USDT, Uncorrelated>>(lp_owner_addr, lp_coins);
        };

        router::register_pool<USDC, USDT, Stable>(&lp_owner);

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

        router::register_pool<ETH, USDC, Uncorrelated>(&lp_owner);

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

        router::register_pool<DAI, ETH, Uncorrelated>(&lp_owner);

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

        router::register_pool<ETH, USDT, Uncorrelated>(&lp_owner);

        if (x4_val != 0 && y4_val != 0) {
            let eth_coins = test_coins::mint<ETH>(&coin_admin, x4_val);
            let usdt_coins = test_coins::mint<USDT>(&coin_admin, y4_val);
            let lp_coins = liquidity_pool::mint<ETH, USDT, Uncorrelated>(eth_coins, usdt_coins);
            coin::register<LP<ETH, USDT, Uncorrelated>>(&lp_owner);
            coin::deposit<LP<ETH, USDT, Uncorrelated>>(lp_owner_addr, lp_coins);
        };

        router::register_pool<BTC, ETH, Uncorrelated>(&lp_owner);

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
    fun test_swap_coin_for_coin_unchecked_x2() {
        let (coin_admin, _) = register_x2_pool_with_liquidity(
            101, 10100,
            150000000, 15000000000
        );

        let btc_coins_swap_val = 1;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<BTC, USDT, Uncorrelated>(btc_coins_swap_val);
        let usdc_amount_out = router::get_amount_out<USDT, USDC, Stable>(usdt_amount_out);

        let usdc_coins = extended_router::swap_coin_for_coin_unchecked_x2<BTC, USDT, USDC, Uncorrelated, Stable>(
            btc_coins_to_swap,
            usdc_amount_out
        );

        assert!(coin::value(&usdc_coins) == usdc_amount_out, 0);

        test_coins::burn(&coin_admin, usdc_coins);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_x2_1() {
        let (coin_admin, _) = register_x2_pool_with_liquidity(
            101, 10100,
            150000000, 15000000000
        );

        let usdc_coins_swap_val = 10000;
        let usdc_coins_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<USDC, USDT, Stable>(usdc_coins_swap_val);
        let btc_amount_out = router::get_amount_out<USDT, BTC, Uncorrelated>(usdt_amount_out);

        let btc_coins = extended_router::swap_coin_for_coin_unchecked_x2<USDC, USDT, BTC, Stable, Uncorrelated>(
            usdc_coins_to_swap,
            btc_amount_out
        );

        assert!(coin::value(&btc_coins) == btc_amount_out, 0);

        test_coins::burn(&coin_admin, btc_coins);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_x2_2() {
        let (coin_admin, _) = register_x2_pool_with_liquidity(
            236, 457800,
            1230000000, 123000000000
        );

        let btc_coins_swap_val = 100;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<BTC, USDT, Uncorrelated>(btc_coins_swap_val);
        let usdc_amount_out = router::get_amount_out<USDT, USDC, Stable>(usdt_amount_out);

        let usdc_coins = extended_router::swap_coin_for_coin_unchecked_x2<BTC, USDT, USDC, Uncorrelated, Stable>(
            btc_coins_to_swap,
            usdc_amount_out
        );

        assert!(coin::value(&usdc_coins) == usdc_amount_out, 0);

        test_coins::burn(&coin_admin, usdc_coins);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_x2_3() {
        let (coin_admin, _) = register_x3_pool_with_liquidity(
            101, 1010000,
            150000000, 15000000000,
            1100, 110000
        );

        let usdt_coins_swap_val = 1000000;
        let usdt_coins_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_coins_swap_val);
        let usdc_amount_out = router::get_amount_out<USDT, USDC, Stable>(usdt_coins_swap_val);
        let eth_amount_out = router::get_amount_out<USDC, ETH, Uncorrelated>(usdc_amount_out);

        let eth_coins = extended_router::swap_coin_for_coin_unchecked_x2<USDT, USDC, ETH, Stable, Uncorrelated>(
            usdt_coins_to_swap,
            eth_amount_out
        );

        assert!(coin::value(&eth_coins) == eth_amount_out, 0);

        test_coins::burn(&coin_admin, eth_coins);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_x3() {
        let (coin_admin, _) = register_x3_pool_with_liquidity(
            101, 1010000,
            150000000, 15000000000,
            1100, 110000
        );

        let btc_coins_swap_val = 10;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<BTC, USDT, Uncorrelated>(btc_coins_swap_val);
        let usdc_amount_out = router::get_amount_out<USDT, USDC, Stable>(usdt_amount_out);
        let eth_amount_out = router::get_amount_out<USDC, ETH, Uncorrelated>(usdc_amount_out);

        let eth_coins = extended_router::swap_coin_for_coin_unchecked_x3<BTC, USDT, USDC, ETH, Uncorrelated, Stable, Uncorrelated>(
            btc_coins_to_swap,
            eth_amount_out
        );

        assert!(coin::value(&eth_coins) == eth_amount_out, 0);

        test_coins::burn(&coin_admin, eth_coins);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_x3_1() {
        let (coin_admin, _) = register_x3_pool_with_liquidity(
            121, 11010000,
            150000000, 15000000000,
            110, 1100000000
        );

        let eth_coins_swap_val = 13;
        let eth_coins_to_swap = test_coins::mint<ETH>(&coin_admin, eth_coins_swap_val);
        let usdc_amount_out = router::get_amount_out<ETH, USDC, Uncorrelated>(eth_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<USDC, USDT, Stable>(usdc_amount_out);
        let btc_amount_out = router::get_amount_out<USDT, BTC, Uncorrelated>(usdt_amount_out);

        let btc_coins = extended_router::swap_coin_for_coin_unchecked_x3<ETH, USDC, USDT, BTC, Uncorrelated, Stable, Uncorrelated>(
            eth_coins_to_swap,
            btc_amount_out
        );

        assert!(coin::value(&btc_coins) == btc_amount_out, 0);

        test_coins::burn(&coin_admin, btc_coins);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_x3_2() {
        let (coin_admin, _) = register_x4_pool_with_liquidity(
            101, 1010000,
            150000000, 15000000000,
            1100, 110000,
            11000, 1100000
        );

        let dai_coins_swap_val = 13000;
        let dai_coins_to_swap = test_coins::mint<DAI>(&coin_admin, dai_coins_swap_val);
        let eth_amount_out = router::get_amount_out<DAI, ETH, Uncorrelated>(dai_coins_swap_val);
        let usdc_amount_out = router::get_amount_out<ETH, USDC, Uncorrelated>(eth_amount_out);
        let usdt_amount_out = router::get_amount_out<USDC, USDT, Stable>(usdc_amount_out);

        let usdt_coins = extended_router::swap_coin_for_coin_unchecked_x3<DAI, ETH, USDC, USDT, Uncorrelated, Uncorrelated, Stable>(
            dai_coins_to_swap,
            usdt_amount_out
        );

        assert!(coin::value(&usdt_coins) == usdt_amount_out, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_x4() {
        let (coin_admin, _) = register_x4_pool_with_liquidity(
            101, 1010000,
            150000000, 15000000000,
            1100, 110000,
            11000, 1100000
        );

        let btc_coins_swap_val = 10;
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, btc_coins_swap_val);
        let usdt_amount_out = router::get_amount_out<BTC, USDT, Uncorrelated>(btc_coins_swap_val);
        let usdc_amount_out = router::get_amount_out<USDT, USDC, Stable>(usdt_amount_out);
        let eth_amount_out = router::get_amount_out<USDC, ETH, Uncorrelated>(usdc_amount_out);
        let dai_amount_out = router::get_amount_out<ETH, DAI, Uncorrelated>(eth_amount_out);

        let dai_coins = extended_router::swap_coin_for_coin_unchecked_x4<BTC, USDT, USDC, ETH, DAI, Uncorrelated, Stable, Uncorrelated, Uncorrelated>(
                btc_coins_to_swap,
                dai_amount_out
            );

        assert!(coin::value(&dai_coins) == dai_amount_out, 0);

        test_coins::burn(&coin_admin, dai_coins);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_x4_1() {
        let (coin_admin, _) = register_x4_pool_with_liquidity(
            123, 12560000,
            150000000, 15000000000,
            25600, 2560000,
            13400, 134000000
        );

        let dai_coins_swap_val = 100000;
        let dai_coins_to_swap = test_coins::mint<DAI>(&coin_admin, dai_coins_swap_val);
        let eth_amount_out = router::get_amount_out<DAI, ETH, Uncorrelated>(dai_coins_swap_val);
        let usdc_amount_out = router::get_amount_out<ETH, USDC, Uncorrelated>(eth_amount_out);
        let usdt_amount_out = router::get_amount_out<USDC, USDT, Stable>(usdc_amount_out);
        let btc_amount_out = router::get_amount_out<USDT, BTC, Uncorrelated>(usdt_amount_out);

        let btc_coins = extended_router::swap_coin_for_coin_unchecked_x4<DAI, ETH, USDC, USDT, BTC, Uncorrelated, Uncorrelated, Stable, Uncorrelated>(
                dai_coins_to_swap,
                btc_amount_out
            );

        assert!(coin::value(&btc_coins) == btc_amount_out, 0);

        test_coins::burn(&coin_admin, btc_coins);
    }

    #[test]
    fun test_swap_coin_for_coin_unchecked_x4_2() {
        let (coin_admin, _) = register_x6_pool_with_liquidity(
            123, 12560000,
            150000000, 15000000000,
            25600, 25600000000,
            13400, 134000000,
            1570, 157000000,
            164, 15030
        );

        let dai_coins_swap_val = 1000000;
        let dai_coins_to_swap = test_coins::mint<DAI>(&coin_admin, dai_coins_swap_val);
        let eth_amount_out = router::get_amount_out<DAI, ETH, Uncorrelated>(dai_coins_swap_val);
        let btc_amount_out = router::get_amount_out<ETH, BTC, Uncorrelated>(eth_amount_out);
        let usdt_amount_out = router::get_amount_out<BTC, USDT, Uncorrelated>(btc_amount_out);
        let usdc_amount_out = router::get_amount_out<USDT, USDC, Stable>(usdt_amount_out);

        let usdc_coins = extended_router::swap_coin_for_coin_unchecked_x4<DAI, ETH, BTC, USDT, USDC, Uncorrelated, Uncorrelated, Uncorrelated, Stable>(
                dai_coins_to_swap,
                usdc_amount_out
            );

        assert!(coin::value(&usdc_coins) == usdc_amount_out, 0);

        test_coins::burn(&coin_admin, usdc_coins);
    }

    #[test]
    #[expected_failure(abort_code = 104)]
    fun test_swap_coin_for_coin_unchecked_x4_3() {
        let (coin_admin, _) = register_x6_pool_with_liquidity(
            123, 12560000,
            150000000, 15000000000,
            25600, 25600000000,
            13400, 134000000,
            1570, 157000000,
            164, 15030
        );

        let dai_coins_swap_val = 100000;
        let dai_coins_to_swap = test_coins::mint<DAI>(&coin_admin, dai_coins_swap_val);
        let eth_amount_out = router::get_amount_out<DAI, ETH, Uncorrelated>(dai_coins_swap_val);
        let btc_amount_out = router::get_amount_out<ETH, BTC, Uncorrelated>(eth_amount_out);
        let usdt_amount_out = router::get_amount_out<BTC, USDT, Uncorrelated>(btc_amount_out);
        let usdc_amount_out = router::get_amount_out<USDT, USDC, Stable>(usdt_amount_out);

        let usdc_coins = extended_router::swap_coin_for_coin_unchecked_x4<DAI, ETH, BTC, USDT, USDC, Uncorrelated, Uncorrelated, Uncorrelated, Stable>(
                dai_coins_to_swap,
                usdc_amount_out
            );

        assert!(coin::value(&usdc_coins) == usdc_amount_out, 0);

        test_coins::burn(&coin_admin, usdc_coins);
    }
}