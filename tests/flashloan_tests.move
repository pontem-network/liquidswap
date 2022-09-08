#[test_only]
module liquidswap::flashloan_tests {
    use std::signer;
    use std::string::utf8;

    use aptos_framework::coin;

    use liquidswap::liquidity_pool;
    use test_coin_admin::test_coins::{Self, USDT, BTC};
    use test_pool_owner::test_lp::{Self, LP};

    fun setup_btc_usdt_pool(): (signer, signer) {
        let (coin_admin, pool_owner) = test_lp::setup_coins_and_pool_owner();
        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            utf8(b"Liquidswap LP"),
            utf8(b"LP-BTC-USDT"),
            2
        );
        (coin_admin, pool_owner)
    }

    #[test]
    fun test_flashloan_coins() {
        let (coin_admin, pool_owner) = setup_btc_usdt_pool();

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coin::register<LP>(&pool_owner);
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

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_fail_if_pay_less_flashloaned_coins() {
        let (coin_admin, pool_owner) = setup_btc_usdt_pool();

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coin::register<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let (zero, usdt_coins, loan) =
            liquidity_pool::flashloan<BTC, USDT, LP>(pool_owner_addr, 0, 3);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2);
        liquidity_pool::pay_flashloan(btc_coins_to_exchange, coin::zero<USDT>(), loan);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_fail_if_pay_equal_flashloaned_coins() {
        let (coin_admin, pool_owner) = setup_btc_usdt_pool();

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coin::register<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let (zero, usdt_coins, loan) =
            liquidity_pool::flashloan<BTC, USDT, LP>(pool_owner_addr, 0, 1);

        liquidity_pool::pay_flashloan(coin::zero<BTC>(), usdt_coins, loan);

        coin::destroy_zero(zero);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_fail_if_mint_when_pool_is_locked() {
        let (coin_admin, pool_owner) = setup_btc_usdt_pool();

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coin::register<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let (zero, usdt_coins, loan) =
            liquidity_pool::flashloan<BTC, USDT, LP>(pool_owner_addr, 0, 1);
        assert!(coin::value(&usdt_coins) == 1, 1);

        // mint when pool is locked
        let btc_coins_mint = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins_mint = test_coins::mint<USDT>(&coin_admin, 100100);
        let lp_coins_mint =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins_mint, usdt_coins_mint);
        coin::deposit(pool_owner_addr, lp_coins_mint);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2);
        liquidity_pool::pay_flashloan(btc_coins_to_exchange, coin::zero<USDT>(), loan);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_fail_if_swap_when_pool_is_locked() {
        let (coin_admin, pool_owner) = setup_btc_usdt_pool();

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coin::register<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let (zero, usdt_coins, loan) =
            liquidity_pool::flashloan<BTC, USDT, LP>(pool_owner_addr, 0, 1);
        assert!(coin::value(&usdt_coins) == 1, 1);

        // swap when pool is locked
        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2);
        let (zero_swap, usdt_coins_swap) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 140000000
            );
        coin::destroy_zero(zero_swap);
        test_coins::burn(&coin_admin, usdt_coins_swap);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2);
        liquidity_pool::pay_flashloan(btc_coins_to_exchange, coin::zero<USDT>(), loan);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_fail_if_burn_when_pool_is_locked() {
        let (coin_admin, pool_owner) = setup_btc_usdt_pool();

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coin::register<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let (zero, usdt_coins, loan) =
            liquidity_pool::flashloan<BTC, USDT, LP>(pool_owner_addr, 0, 1);
        assert!(coin::value(&usdt_coins) == 1, 1);

        // burn when pool is locked
        let lp_coins = coin::withdraw<LP>(&pool_owner, 1);
        let (btc_return, usdt_return) =
            liquidity_pool::burn<BTC, USDT, LP>(pool_owner_addr, lp_coins);
        test_coins::burn(&coin_admin, btc_return);
        test_coins::burn(&coin_admin, usdt_return);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2);
        liquidity_pool::pay_flashloan(btc_coins_to_exchange, coin::zero<USDT>(), loan);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_fail_if_flashloan_when_pool_is_locked() {
        let (coin_admin, pool_owner) = setup_btc_usdt_pool();

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coin::register<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let (zero, usdt_coins, loan) =
            liquidity_pool::flashloan<BTC, USDT, LP>(pool_owner_addr, 0, 1);
        assert!(coin::value(&usdt_coins) == 1, 1);

        // flashloan when pool is locked
        let (zero_test, usdt_coins_test, loan_test) =
            liquidity_pool::flashloan<BTC, USDT, LP>(pool_owner_addr, 0, 1);
        let btc_coins_to_exchange_test = test_coins::mint<BTC>(&coin_admin, 2);
        liquidity_pool::pay_flashloan(btc_coins_to_exchange_test, coin::zero<USDT>(), loan_test);
        coin::destroy_zero(zero_test);
        test_coins::burn(&coin_admin, usdt_coins_test);


        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2);
        liquidity_pool::pay_flashloan(btc_coins_to_exchange, coin::zero<USDT>(), loan);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_fail_if_get_reserves_when_pool_is_locked() {
        let (coin_admin, pool_owner) = setup_btc_usdt_pool();

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coin::register<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let (zero, usdt_coins, loan) =
            liquidity_pool::flashloan<BTC, USDT, LP>(pool_owner_addr, 0, 1);
        assert!(coin::value(&usdt_coins) == 1, 1);

        // get reserves when pool is locked
        let (_, _) = liquidity_pool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2);
        liquidity_pool::pay_flashloan(btc_coins_to_exchange, coin::zero<USDT>(), loan);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_fail_if_get_cumulative_prices_when_pool_is_locked() {
        let (coin_admin, pool_owner) = setup_btc_usdt_pool();

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        coin::register<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let (zero, usdt_coins, loan) =
            liquidity_pool::flashloan<BTC, USDT, LP>(pool_owner_addr, 0, 1);
        assert!(coin::value(&usdt_coins) == 1, 1);

        // get cumulative prices when pool is locked
        let (_, _, _) = liquidity_pool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2);
        liquidity_pool::pay_flashloan(btc_coins_to_exchange, coin::zero<USDT>(), loan);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }
}
