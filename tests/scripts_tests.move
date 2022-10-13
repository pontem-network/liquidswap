#[test_only]
module liquidswap::scripts_tests {
    use std::signer;

    use aptos_framework::coin;

    use liquidswap_lp::lp_coin::LP;
    use test_coins::coins::{Self, BTC, USDT};

    use liquidswap::curves::Uncorrelated;
    use liquidswap::liquidity_pool;
    use liquidswap::router;
    use liquidswap::scripts;
    use liquidswap::test_pool;

    fun register_pool_with_existing_liquidity(x_val: u64, y_val: u64): (signer, signer) {
        let (coin_admin, lp_user) = test_pool::setup_btc_usdt_coins_and_lp_user();

        router::register_pool<BTC, USDT, Uncorrelated>(&lp_user);

        if (x_val != 0 && y_val != 0) {
            let btc_coins = coins::mint<BTC>(&coin_admin, x_val);
            let usdt_coins = coins::mint<USDT>(&coin_admin, y_val);
            let lp_coins =
                liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
            coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_user);
            coin::deposit<LP<BTC, USDT, Uncorrelated>>(signer::address_of(&lp_user), lp_coins);
        };
        (coin_admin, lp_user)
    }

    #[test]
    public entry fun test_register_pool_with_script() {
        let (_, lp_user) = test_pool::setup_btc_usdt_coins_and_lp_user();

        scripts::register_pool<BTC, USDT, Uncorrelated>(&lp_user);

        assert!(liquidity_pool::is_pool_exists<BTC, USDT, Uncorrelated>(), 1);
    }

    #[test]
    public entry fun test_register_and_add_liquidity_in_one_script() {
        let (coin_admin, lp_user) = test_pool::setup_btc_usdt_coins_and_lp_user();

        let btc_coins = coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = coins::mint<USDT>(&coin_admin, 10100);

        coin::register<BTC>(&lp_user);
        coin::register<USDT>(&lp_user);

        let lp_user_addr = signer::address_of(&lp_user);
        coin::deposit(lp_user_addr, btc_coins);
        coin::deposit(lp_user_addr, usdt_coins);

        scripts::register_pool_and_add_liquidity<BTC, USDT, Uncorrelated>(
            &lp_user,
            101,
            101,
            10100,
            10100,
        );

        assert!(liquidity_pool::is_pool_exists<BTC, USDT, Uncorrelated>(), 1);

        assert!(coin::balance<BTC>(lp_user_addr) == 0, 2);
        assert!(coin::balance<USDT>(lp_user_addr) == 0, 3);
        assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(lp_user_addr) == 10, 4);
    }

    #[test]
    public entry fun test_add_liquidity() {
        let (coin_admin, lp_user) = register_pool_with_existing_liquidity(0, 0);

        let btc_coins = coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = coins::mint<USDT>(&coin_admin, 10100);

        coin::register<BTC>(&lp_user);
        coin::register<USDT>(&lp_user);

        let lp_user_addr = signer::address_of(&lp_user);
        coin::deposit(lp_user_addr, btc_coins);
        coin::deposit(lp_user_addr, usdt_coins);

        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_user);

        scripts::add_liquidity<BTC, USDT, Uncorrelated>(
            &lp_user,
            101,
            101,
            10100,
            10100,
        );

        assert!(coin::balance<BTC>(lp_user_addr) == 0, 1);
        assert!(coin::balance<USDT>(lp_user_addr) == 0, 2);
        assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(lp_user_addr) == 10, 3);
    }

    #[test]
    public entry fun test_remove_liquidity() {
        let (coin_admin, lp_user) = register_pool_with_existing_liquidity(0, 0);

        let btc_coins = coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = coins::mint<USDT>(&coin_admin, 10100);

        let (btc, usdt, lp) =
            router::add_liquidity<BTC, USDT, Uncorrelated>(
                btc_coins,
                101,
                usdt_coins,
                10100,
            );
        coin::register<BTC>(&lp_user);
        coin::register<USDT>(&lp_user);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_user);

        let lp_user_addr = signer::address_of(&lp_user);
        coin::deposit(lp_user_addr, btc);
        coin::deposit(lp_user_addr, usdt);
        coin::deposit(lp_user_addr, lp);

        scripts::remove_liquidity<BTC, USDT, Uncorrelated>(
            &lp_user,
            10,
            98,
            10000,
        );

        assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(lp_user_addr) == 0, 1);
        assert!(coin::balance<BTC>(lp_user_addr) == 101, 2);
        assert!(coin::balance<USDT>(lp_user_addr) == 10100, 3);
    }

    #[test]
    public entry fun test_swap_exact_btc_for_usdt() {
        let (coin_admin, lp_user) = register_pool_with_existing_liquidity(101, 10100);

        let btc_coins_to_swap = coins::mint<BTC>(&coin_admin, 10);
        coin::register<BTC>(&lp_user);
        coin::register<USDT>(&lp_user);

        let lp_user_addr = signer::address_of(&lp_user);
        coin::deposit(lp_user_addr, btc_coins_to_swap);

        scripts::swap<BTC, USDT, Uncorrelated>(
            &lp_user,
            10,
            900,
        );

        assert!(coin::balance<BTC>(lp_user_addr) == 0, 1);
        assert!(coin::balance<USDT>(lp_user_addr) == 907, 2);
    }

    #[test]
    public entry fun test_swap_btc_for_exact_usdt() {
        let (coin_admin, lp_user) = register_pool_with_existing_liquidity(101, 10100);

        let btc_coins_to_swap = coins::mint<BTC>(&coin_admin, 10);
        coin::register<BTC>(&lp_user);
        coin::register<USDT>(&lp_user);

        let lp_user_addr = signer::address_of(&lp_user);
        coin::deposit(lp_user_addr, btc_coins_to_swap);

        scripts::swap_into<BTC, USDT, Uncorrelated>(
            &lp_user,
            10,
            700,
        );

        assert!(coin::balance<BTC>(lp_user_addr) == 2, 1);
        assert!(coin::balance<USDT>(lp_user_addr) == 700, 2);
    }
}
