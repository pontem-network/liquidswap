#[test_only]
module dao_admin::dao_deposit_tests {
    use std::signer;
    use std::string::utf8;

    use aptos_framework::coin;
    use aptos_framework::coins;
    use aptos_framework::genesis;
    use liquidswap::dao_storage;
    use liquidswap::liquidity_pool;
    use test_coin_admin::test_coins::{Self, BTC, USDT};
    use test_helpers::test_account::create_account;
    use test_pool_owner::test_lp::LP;
    use dao_admin::dao_deposit;

    #[test(
        core = @core_resources,
        coin_admin = @test_coin_admin,
        pool_owner = @test_pool_owner,
        dao_admin = @dao_admin
    )]
    fun test_withdraw_coins_from_pool_and_deposit_inside_contract(
        core: signer,
        coin_admin: signer,
        pool_owner: signer,
        dao_admin: signer
    ) {
        genesis::setup(&core);

        create_account(&coin_admin);
        create_account(&pool_owner);

        test_coins::register_coins(&coin_admin);

        liquidity_pool::register<BTC, USDT, LP>(
            &pool_owner,
            utf8(b"LiquidSwap LP"),
            utf8(b"LP-BTC-USDT"),
            2
        );

        let pool_owner_addr = signer::address_of(&pool_owner);

        let btc_liq_val = 100000000;
        let usdt_liq_val = 28000000000;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val);
        let lp_coins =
            liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_liq, usdt_liq);
        coins::register_internal<LP>(&pool_owner);
        coin::deposit(pool_owner_addr, lp_coins);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 200000);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 100000
            );
        coin::destroy_zero(zero);
        coins::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, usdt_coins);

        let (dao_x_val, dao_y_val) = dao_storage::get_storage_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(dao_x_val == 200, 3);
        assert!(dao_y_val == 0, 4);

        dao_deposit::withdraw_coins_from_pool<BTC, USDT, LP>(&dao_admin, pool_owner_addr, 200, 0);

        let (dao_x_val, dao_y_val) = dao_storage::get_storage_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(dao_x_val == 0, 3);
        assert!(dao_y_val == 0, 4);

        assert!(dao_deposit::get_coin_deposit_size<BTC>() == 200, 5);
        assert!(dao_deposit::get_coin_deposit_size<USDT>() == 0, 5);
    }
}
