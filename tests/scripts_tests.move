#[test_only]
module liquidswap::scripts_tests {
    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::coins;
    use aptos_framework::genesis;

    use liquidswap::liquidity_pool;
    use liquidswap::router;
    use liquidswap::scripts;

    use test_coin_admin::test_coins::{Self, USDT, BTC};
    use test_pool_owner::test_lp::LP;
    use test_helpers::test_account::create_account;

    fun register_pool_with_existing_liquidity(
        coin_admin: &signer,
        pool_owner: &signer,
        x_val: u64,
        y_val: u64
    ) {
        router::register_pool<BTC, USDT, LP>(pool_owner, 2);

        let pool_owner_addr = signer::address_of(pool_owner);
        if (x_val != 0 && y_val != 0) {
            let btc_coins = test_coins::mint<BTC>(coin_admin, x_val);
            let usdt_coins = test_coins::mint<USDT>(coin_admin, y_val);
            let lp_coins =
                liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
            coins::register_internal<LP>(pool_owner);
            coin::deposit<LP>(pool_owner_addr, lp_coins);
        };
    }

    #[test(coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    public entry fun test_register_pool_with_script(
        coin_admin: signer,
        pool_owner: signer
    ) {
        genesis::setup();

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        let pool_owner_addr = signer::address_of(&pool_owner);

        scripts::register_pool<BTC, USDT, LP>(pool_owner, 2);

        assert!(liquidity_pool::pool_exists_at<BTC, USDT, LP>(pool_owner_addr), 1);
    }

    #[test(coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    public entry fun test_register_and_add_liquidity_in_one_script(
        coin_admin: signer,
        pool_owner: signer
    ) {
        genesis::setup();

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        coins::register_internal<BTC>(&pool_owner);
        coins::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, btc_coins);
        coin::deposit(pool_owner_addr, usdt_coins);

        scripts::register_pool_and_add_liquidity<BTC, USDT, LP>(
            pool_owner,
            2,
            101,
            101,
            10100,
            10100,
        );

        assert!(liquidity_pool::pool_exists_at<BTC, USDT, LP>(pool_owner_addr), 1);

        assert!(coin::balance<BTC>(pool_owner_addr) == 0, 2);
        assert!(coin::balance<USDT>(pool_owner_addr) == 0, 3);
        assert!(coin::balance<LP>(pool_owner_addr) == 10, 4);
    }

    #[test(coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    public entry fun test_add_liquidity(coin_admin: signer, pool_owner: signer) {
        genesis::setup();

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);
        register_pool_with_existing_liquidity(&coin_admin, &pool_owner, 0, 0);
        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 10100);

        coins::register_internal<BTC>(&pool_owner);
        coins::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, btc_coins);
        coin::deposit(pool_owner_addr, usdt_coins);

        coins::register_internal<LP>(&pool_owner);

        scripts::add_liquidity<BTC, USDT, LP>(
            pool_owner,
            pool_owner_addr,
            101,
            101,
            10100,
            10100,
        );

        assert!(coin::balance<BTC>(pool_owner_addr) == 0, 1);
        assert!(coin::balance<USDT>(pool_owner_addr) == 0, 2);
        assert!(coin::balance<LP>(pool_owner_addr) == 10, 3);
    }

    #[test(coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    public entry fun test_remove_liquidity(coin_admin: signer, pool_owner: signer) {
        genesis::setup();

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);
        register_pool_with_existing_liquidity(&coin_admin, &pool_owner, 0, 0);
        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 10100);

        let (btc, usdt, lp) =
            router::add_liquidity<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins,
                101,
                usdt_coins,
                10100,
            );
        coins::register_internal<BTC>(&pool_owner);
        coins::register_internal<USDT>(&pool_owner);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, btc);
        coin::deposit(pool_owner_addr, usdt);
        coin::deposit(pool_owner_addr, lp);

        scripts::remove_liquidity<BTC, USDT, LP>(
            pool_owner,
            pool_owner_addr,
            10,
            98,
            10000,
        );

        assert!(coin::balance<LP>(pool_owner_addr) == 0, 1);
        assert!(coin::balance<BTC>(pool_owner_addr) == 101, 2);
        assert!(coin::balance<USDT>(pool_owner_addr) == 10100, 3);
    }

    #[test(coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    public entry fun test_swap_exact_btc_for_usdt(coin_admin: signer, pool_owner: signer) {
        genesis::setup();

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);
        register_pool_with_existing_liquidity(&coin_admin, &pool_owner, 101, 10100);
        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 10);
        coins::register_internal<BTC>(&pool_owner);
        coins::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, btc_coins_to_swap);

        scripts::swap<BTC, USDT, LP>(
            pool_owner,
            pool_owner_addr,
            10,
            900,
        );

        assert!(coin::balance<BTC>(pool_owner_addr) == 0, 1);
        assert!(coin::balance<USDT>(pool_owner_addr) == 907, 2);
    }

    #[test(coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    public entry fun test_swap_btc_for_exact_usdt(coin_admin: signer, pool_owner: signer) {
        genesis::setup();

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);
        register_pool_with_existing_liquidity(&coin_admin, &pool_owner, 101, 10100);
        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 10);
        coins::register_internal<BTC>(&pool_owner);
        coins::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, btc_coins_to_swap);

        scripts::swap_into<BTC, USDT, LP>(
            pool_owner,
            pool_owner_addr,
            10,
            700,
        );

        assert!(coin::balance<BTC>(pool_owner_addr) == 2, 1);
        assert!(coin::balance<USDT>(pool_owner_addr) == 700, 2);
    }
}
