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

        let lp_owner_addr = signer::address_of(&lp_owner);

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
}