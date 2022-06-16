#[test_only]
module MultiSwap::LiquidityPoolTests {
    use Std::Signer;

    use AptosFramework::Genesis;
    use AptosFramework::Coin;

    use MultiSwap::LiquidityPool;

    use TestCoinAdmin::TestCoins::{Self, USDT, BTC};
    use TestPoolOwner::LP::{Self, LP};

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_create_empty_pool_without_any_liquidity(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        LiquidityPool::register<BTC, USDT, LP>(&pool_owner);

        let (x_res_val, y_res_val) =
            LiquidityPool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res_val == 0, 3);
        assert!(y_res_val == 0, 4);

        let (x_price, y_price, _) =
            LiquidityPool::get_cumulative_prices<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_price == 0, 1);
        assert!(y_price == 0, 2);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    #[expected_failure(abort_code = 25607)]
    fun test_fail_if_coin_generics_provided_in_the_wrong_order(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);
        let pool_owner_addr = Signer::address_of(&pool_owner);
        LiquidityPool::register<BTC, USDT, LP>(&pool_owner);

        // here generics are provided as USDT-BTC, but pool is BTC-USDT. `reverse` parameter is irrelevant
        let (_x_price, _y_price, _) =
            LiquidityPool::get_cumulative_prices<USDT, BTC, LP>(pool_owner_addr);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    #[expected_failure(abort_code = 7)]
    fun test_fail_if_coin_lp_registered_as_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);
        LP::register_lp_for_fails(&coin_admin);

        LiquidityPool::register<BTC, USDT, LP>(&pool_owner);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_add_liquidity_and_then_burn_it(core: signer, coin_admin: signer, pool_owner: signer)
    {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        LiquidityPool::register<BTC, USDT, LP>(&pool_owner);

        let btc_coins = TestCoins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = TestCoins::mint<USDT>(&coin_admin, 100100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let lp_coins =
            LiquidityPool::add_liquidity<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        assert!(Coin::value(&lp_coins) == 99100, 1);

        let (x_res, y_res) = LiquidityPool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 100100, 2);
        assert!(y_res == 100100, 3);

        let (btc_return, usdt_return) =
            LiquidityPool::burn_liquidity<BTC, USDT, LP>(pool_owner_addr, lp_coins);

        assert!(Coin::value(&btc_return) == 100100, 1);
        assert!(Coin::value(&usdt_return) == 100100, 1);

        let (x_res, y_res) = LiquidityPool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 0, 2);
        assert!(y_res == 0, 3);

        TestCoins::burn(&coin_admin, btc_return);
        TestCoins::burn(&coin_admin, usdt_return);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_swap_coins(core: signer, coin_admin: signer, pool_owner: signer)
    {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        LiquidityPool::register<BTC, USDT, LP>(&pool_owner);

        let pool_owner_addr = Signer::address_of(&pool_owner);

        let btc_coins = TestCoins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = TestCoins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            LiquidityPool::add_liquidity<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        Coin::register_internal<LP>(&pool_owner);
        Coin::deposit(pool_owner_addr, lp_coins);

        let btc_coins_to_exchange = TestCoins::mint<BTC>(&coin_admin, 2);
        let (zero, usdt_coins) =
            LiquidityPool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                Coin::zero<USDT>(), 1
            );
        assert!(Coin::value(&usdt_coins) == 1, 1);

        let (x_res, y_res) = LiquidityPool::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(x_res == 100102, 2);
        assert!(y_res == 100099, 2);

        Coin::destroy_zero(zero);
        TestCoins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    #[expected_failure(abort_code = 26881)]
    fun test_cannot_swap_coins_and_reduce_value_of_pool(core: signer, coin_admin: signer, pool_owner: signer)
    {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        LiquidityPool::register<BTC, USDT, LP>(&pool_owner);

        let pool_owner_addr = Signer::address_of(&pool_owner);

        let btc_coins = TestCoins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = TestCoins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            LiquidityPool::add_liquidity<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        Coin::register_internal<LP>(&pool_owner);
        Coin::deposit(pool_owner_addr, lp_coins);

        // 1 minus fee for 1
        let btc_coins_to_exchange = TestCoins::mint<BTC>(&coin_admin, 1);
        let (zero, usdt_coins) =
            LiquidityPool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                Coin::zero<USDT>(), 1
            );
        Coin::destroy_zero(zero);
        TestCoins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_pool_exists(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        TestCoins::register_coins(&coin_admin);

        LiquidityPool::register<BTC, USDT, LP>(&pool_owner);

        assert!(LiquidityPool::pool_exists_at<BTC, USDT, LP>(Signer::address_of(&pool_owner)), 1);
        assert!(!LiquidityPool::pool_exists_at<USDT, BTC, LP>(Signer::address_of(&pool_owner)), 2);
    }

    #[test]
    fun test_fees_config() {
        let (fee_pct, fee_scale) = LiquidityPool::get_fees_config();
        assert!(fee_pct == 3, 1);
        assert!(fee_scale == 1000, 2);
    }
}