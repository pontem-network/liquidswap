#[test_only]
module liquidswap::dao_storage_tests {
    use std::signer;

    use aptos_framework::coin;
    use liquidswap_lp::lp_coin::LP;

    use liquidswap::curves::Uncorrelated;
    use liquidswap::dao_storage;
    use liquidswap::liquidity_pool;
    use liquidswap::router;
    use test_coin_admin::test_coins::{Self, BTC, USDT};
    use test_helpers::test_account::create_account;
    use test_helpers::test_pool;
    use liquidswap::global_config;

    #[test]
    fun test_register() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        dao_storage::register_for_test<BTC, USDT, Uncorrelated>(&lp_owner);

        let (x_val, y_val) = dao_storage::get_storage_size<BTC, USDT, Uncorrelated>(signer::address_of(&lp_owner));
        assert!(x_val == 0, 0);
        assert!(y_val == 0, 1);
    }

    #[test]
    fun test_deposit() {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();

        dao_storage::register_for_test<BTC, USDT, Uncorrelated>(&lp_owner);

        let lp_owner_addr = signer::address_of(&lp_owner);
        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1000000);

        let (x_val, y_val) = dao_storage::get_storage_size<BTC, USDT, Uncorrelated>(signer::address_of(&lp_owner));
        assert!(x_val == 0, 0);
        assert!(y_val == 0, 1);

        dao_storage::deposit_for_test<BTC, USDT, Uncorrelated>(lp_owner_addr, btc_coins, usdt_coins);
        (x_val, y_val) = dao_storage::get_storage_size<BTC, USDT, Uncorrelated>(signer::address_of(&lp_owner));
        assert!(x_val == 100000000, 2);
        assert!(y_val == 1000000, 3);
    }

    #[test]
    #[expected_failure(abort_code = 401)]
    fun test_deposit_fail_if_not_registered() {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();

        let lp_owner_addr = signer::address_of(&lp_owner);
        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1000000);

        dao_storage::deposit_for_test<BTC, USDT, Uncorrelated>(lp_owner_addr, btc_coins, usdt_coins);
    }

    #[test(dao_admin_acc = @dao_admin)]
    fun test_withdraw(dao_admin_acc: signer) {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();

        dao_storage::register_for_test<BTC, USDT, Uncorrelated>(&lp_owner);

        create_account(&dao_admin_acc);

        let lp_owner_addr = signer::address_of(&lp_owner);
        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1000000);

        dao_storage::deposit_for_test<BTC, USDT, Uncorrelated>(lp_owner_addr, btc_coins, usdt_coins);

        let (x, y) =
            dao_storage::withdraw<BTC, USDT, Uncorrelated>(&dao_admin_acc, lp_owner_addr, 100000000, 0);
        assert!(coin::value(&x) == 100000000, 0);
        assert!(coin::value(&y) == 0, 1);

        let (x_val, y_val) = dao_storage::get_storage_size<BTC, USDT, Uncorrelated>(signer::address_of(&lp_owner));
        assert!(x_val == 0, 2);
        assert!(y_val == 1000000, 3);

        global_config::set_dao_admin(&dao_admin_acc, signer::address_of(&coin_admin));
        let (x0, y0) =
            dao_storage::withdraw<BTC, USDT, Uncorrelated>(&coin_admin, lp_owner_addr, 0, 1000000);
        assert!(coin::value(&x0) == 0, 4);
        assert!(coin::value(&y0) == 1000000, 5);

        test_coins::burn(&coin_admin, x);
        test_coins::burn(&coin_admin, y);
        test_coins::burn(&coin_admin, x0);
        test_coins::burn(&coin_admin, y0);
    }

    #[test(dao_admin_acc = @dao_admin)]
    #[expected_failure(abort_code = 65542)]
    fun test_withdraw_fail_if_more_deposited(dao_admin_acc: signer) {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();

        dao_storage::register_for_test<BTC, USDT, Uncorrelated>(&lp_owner);

        create_account(&dao_admin_acc);

        let lp_owner_addr = signer::address_of(&lp_owner);
        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1000000);

        dao_storage::deposit_for_test<BTC, USDT, Uncorrelated>(lp_owner_addr, btc_coins, usdt_coins);

        let (x, y) =
            dao_storage::withdraw<BTC, USDT, Uncorrelated>(&dao_admin_acc, lp_owner_addr, 200000000, 0);

        test_coins::burn(&coin_admin, x);
        test_coins::burn(&coin_admin, y);
    }

    #[test(dao_admin_acc = @0xca)]
    #[expected_failure(abort_code = 402)]
    fun test_withdraw_fail_if_not_dao_admin(dao_admin_acc: signer) {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();

        dao_storage::register_for_test<BTC, USDT, Uncorrelated>(&lp_owner);

        create_account(&dao_admin_acc);

        let lp_owner_addr = signer::address_of(&lp_owner);
        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1000000);

        dao_storage::deposit_for_test<BTC, USDT, Uncorrelated>(lp_owner_addr, btc_coins, usdt_coins);

        let (x, y) =
            dao_storage::withdraw<BTC, USDT, Uncorrelated>(&dao_admin_acc, lp_owner_addr, 100000000, 0);

        test_coins::burn(&coin_admin, x);
        test_coins::burn(&coin_admin, y);
    }

    #[test(dao_admin_acc = @dao_admin)]
    fun test_split_third_of_fees_into_dao_storage_account(dao_admin_acc: signer) {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();

        create_account(&dao_admin_acc);

        // 0.3% fee
        router::register_pool<BTC, USDT, Uncorrelated>(&lp_owner);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 1000);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 960
            );

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 100999, 2);
        assert!(y_res == 99040, 3);

        let (dao_x, dao_y) = dao_storage::get_storage_size<BTC, USDT, Uncorrelated>(@liquidswap_pool_account);
        assert!(dao_x == 1, 4);
        assert!(dao_y == 0, 5);

        let (x, y) =
            dao_storage::withdraw<BTC, USDT, Uncorrelated>(&dao_admin_acc, @liquidswap_pool_account, 1, 0);
        assert!(coin::value(&x) == 1, 6);
        assert!(coin::value(&y) == 0, 7);

        test_coins::burn(&coin_admin, x);
        test_coins::burn(&coin_admin, y);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }
}
