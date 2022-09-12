#[test_only]
module liquidswap::scripts_tests {
    use std::signer;

    use aptos_framework::coin;

    use liquidswap::liquidity_pool;
    use liquidswap::router;
    use liquidswap::scripts;
    use test_coin_admin::test_coins::{Self, USDT, BTC};
    use lp_coin_account::lp_coin::LP;
    use test_helpers::test_pool;

    fun register_pool_with_existing_liquidity(x_val: u64, y_val: u64): (signer, signer) {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();

        router::register_pool<BTC, USDT>(&lp_owner, 2);

        let lp_owner_addr = signer::address_of(&lp_owner);
        if (x_val != 0 && y_val != 0) {
            let btc_coins = test_coins::mint<BTC>(&coin_admin, x_val);
            let usdt_coins = test_coins::mint<USDT>(&coin_admin, y_val);
            let lp_coins =
                liquidity_pool::mint<BTC, USDT>(lp_owner_addr, btc_coins, usdt_coins);
            coin::register<LP<BTC, USDT>>(&lp_owner);
            coin::deposit<LP<BTC, USDT>>(lp_owner_addr, lp_coins);
        };
        (coin_admin, lp_owner)
    }

    #[test]
    public entry fun test_register_pool_with_script() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        let lp_owner_addr = signer::address_of(&lp_owner);

        scripts::register_pool<BTC, USDT>(&lp_owner, 2);

        assert!(liquidity_pool::pool_exists_at<BTC, USDT>(lp_owner_addr), 1);
    }

    #[test]
    public entry fun test_register_and_add_liquidity_in_one_script() {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 10100);

        let lp_owner_addr = signer::address_of(&lp_owner);
        coin::register<BTC>(&lp_owner);
        coin::register<USDT>(&lp_owner);
        coin::deposit(lp_owner_addr, btc_coins);
        coin::deposit(lp_owner_addr, usdt_coins);

        scripts::register_pool_and_add_liquidity<BTC, USDT>(
            &lp_owner,
            2,
            101,
            101,
            10100,
            10100,
        );

        assert!(liquidity_pool::pool_exists_at<BTC, USDT>(lp_owner_addr), 1);

        assert!(coin::balance<BTC>(lp_owner_addr) == 0, 2);
        assert!(coin::balance<USDT>(lp_owner_addr) == 0, 3);
        assert!(coin::balance<LP<BTC, USDT>>(lp_owner_addr) == 10, 4);
    }

    #[test]
    public entry fun test_add_liquidity() {
        let (coin_admin, lp_owner) = register_pool_with_existing_liquidity(0, 0);

        let lp_owner_addr = signer::address_of(&lp_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 10100);

        coin::register<BTC>(&lp_owner);
        coin::register<USDT>(&lp_owner);
        coin::deposit(lp_owner_addr, btc_coins);
        coin::deposit(lp_owner_addr, usdt_coins);

        coin::register<LP<BTC, USDT>>(&lp_owner);

        scripts::add_liquidity<BTC, USDT>(
            &lp_owner,
            lp_owner_addr,
            101,
            101,
            10100,
            10100,
        );

        assert!(coin::balance<BTC>(lp_owner_addr) == 0, 1);
        assert!(coin::balance<USDT>(lp_owner_addr) == 0, 2);
        assert!(coin::balance<LP<BTC, USDT>>(lp_owner_addr) == 10, 3);
    }

    #[test]
    public entry fun test_remove_liquidity() {
        let (coin_admin, lp_owner) = register_pool_with_existing_liquidity(0, 0);

        let lp_owner_addr = signer::address_of(&lp_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 10100);

        let (btc, usdt, lp) =
            router::add_liquidity<BTC, USDT>(
                lp_owner_addr,
                btc_coins,
                101,
                usdt_coins,
                10100,
            );
        coin::register<BTC>(&lp_owner);
        coin::register<USDT>(&lp_owner);
        coin::register<LP<BTC, USDT>>(&lp_owner);
        coin::deposit(lp_owner_addr, btc);
        coin::deposit(lp_owner_addr, usdt);
        coin::deposit(lp_owner_addr, lp);

        scripts::remove_liquidity<BTC, USDT>(
            &lp_owner,
            lp_owner_addr,
            10,
            98,
            10000,
        );

        assert!(coin::balance<LP<BTC, USDT>>(lp_owner_addr) == 0, 1);
        assert!(coin::balance<BTC>(lp_owner_addr) == 101, 2);
        assert!(coin::balance<USDT>(lp_owner_addr) == 10100, 3);
    }

    #[test]
    public entry fun test_swap_exact_btc_for_usdt() {
        let (coin_admin, lp_owner) = register_pool_with_existing_liquidity(101, 10100);

        let lp_owner_addr = signer::address_of(&lp_owner);

        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 10);
        coin::register<BTC>(&lp_owner);
        coin::register<USDT>(&lp_owner);
        coin::deposit(lp_owner_addr, btc_coins_to_swap);

        scripts::swap<BTC, USDT>(
            &lp_owner,
            lp_owner_addr,
            10,
            900,
        );

        assert!(coin::balance<BTC>(lp_owner_addr) == 0, 1);
        assert!(coin::balance<USDT>(lp_owner_addr) == 907, 2);
    }

    #[test]
    public entry fun test_swap_btc_for_exact_usdt() {
        let (coin_admin, lp_owner) = register_pool_with_existing_liquidity(101, 10100);

        let lp_owner_addr = signer::address_of(&lp_owner);

        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 10);
        coin::register<BTC>(&lp_owner);
        coin::register<USDT>(&lp_owner);
        coin::deposit(lp_owner_addr, btc_coins_to_swap);

        scripts::swap_into<BTC, USDT>(
            &lp_owner,
            lp_owner_addr,
            10,
            700,
        );

        assert!(coin::balance<BTC>(lp_owner_addr) == 2, 1);
        assert!(coin::balance<USDT>(lp_owner_addr) == 700, 2);
    }
}
