#[test_only]
module MultiSwap::LiquidityPoolTests {
    use Std::ASCII::string;
    use Std::Signer;

    use AptosFramework::Genesis;
    use AptosFramework::Coin::{Self, MintCapability, BurnCapability};

    use MultiSwap::LiquidityPool;

    use TestCoinAdmin::TestCoins::{USDT, BTC};
    use TestPoolOwner::LP::LP;

    struct Caps has key {
        btc_mint_cap: MintCapability<BTC>,
        btc_burn_cap: BurnCapability<BTC>,
        usdt_mint_cap: MintCapability<USDT>,
        usdt_burn_cap: BurnCapability<USDT>,
    }

    fun register_coins(coin_admin: &signer) {
        let (usdt_mint_cap, usdt_burn_cap) =
            Coin::initialize<USDT>(
                coin_admin,
                string(b"USDT"),
                string(b"USDT"),
                6,
                true
            );

        let (btc_mint_cap, btc_burn_cap) =
            Coin::initialize<BTC>(
                coin_admin, string(b"BTC"),
                string(b"BTC"),
                8,
                true
            );

        let caps = Caps{ usdt_mint_cap, usdt_burn_cap, btc_mint_cap, btc_burn_cap };
        move_to(coin_admin, caps);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_create_empty_pool_without_any_liquidity(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        register_coins(&coin_admin);
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

        register_coins(&coin_admin);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        LiquidityPool::register<BTC, USDT, LP>(&pool_owner);

        // here generics are provided as USDT-BTC, but pool is BTC-USDT. `reverse` parameter is irrelevant
        let (_x_price, _y_price, _) =
            LiquidityPool::get_cumulative_prices<USDT, BTC, LP>(pool_owner_addr);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_add_liquidity_and_then_burn_it(core: signer, coin_admin: signer, pool_owner: signer)
    acquires Caps {
        Genesis::setup(&core);

        register_coins(&coin_admin);

        let coin_admin_addr = Signer::address_of(&coin_admin);
        let caps = borrow_global<Caps>(coin_admin_addr);

        LiquidityPool::register<BTC, USDT, LP>(&pool_owner);

        let btc_coins = Coin::mint(100100, &caps.btc_mint_cap);
        let usdt_coins = Coin::mint(100100, &caps.usdt_mint_cap);

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

        Coin::burn(btc_return, &caps.btc_burn_cap);
        Coin::burn(usdt_return, &caps.usdt_burn_cap);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_swap_coins(core: signer, coin_admin: signer, pool_owner: signer)
    acquires Caps {
        Genesis::setup(&core);

        register_coins(&coin_admin);

        let coin_admin_addr = Signer::address_of(&coin_admin);
        let caps = borrow_global<Caps>(coin_admin_addr);

        LiquidityPool::register<BTC, USDT, LP>(&pool_owner);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let btc_coins = Coin::mint(100100, &caps.btc_mint_cap);
        let usdt_coins = Coin::mint(100100, &caps.usdt_mint_cap);

        let lp_coins =
            LiquidityPool::add_liquidity<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        Coin::register_internal<LP>(&pool_owner);
        Coin::deposit(pool_owner_addr, lp_coins);

        let btc_coins_to_exchange = Coin::mint(2, &caps.btc_mint_cap);
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
        Coin::burn(usdt_coins, &caps.usdt_burn_cap);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    #[expected_failure(abort_code = 26881)]
    fun test_cannot_swap_coins_and_reduce_value_of_pool(core: signer, coin_admin: signer, pool_owner: signer)
    acquires Caps {
        Genesis::setup(&core);

        register_coins(&coin_admin);

        let coin_admin_addr = Signer::address_of(&coin_admin);
        let caps = borrow_global<Caps>(coin_admin_addr);

        LiquidityPool::register<BTC, USDT, LP>(&pool_owner);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let btc_coins = Coin::mint(100100, &caps.btc_mint_cap);
        let usdt_coins = Coin::mint(100100, &caps.usdt_mint_cap);

        let lp_coins =
            LiquidityPool::add_liquidity<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
        Coin::register_internal<LP>(&pool_owner);
        Coin::deposit(pool_owner_addr, lp_coins);

        // 1 minus fee for 1
        let btc_coins_to_exchange = Coin::mint(1, &caps.btc_mint_cap);
        let (zero, usdt_coins) =
            LiquidityPool::swap<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_exchange, 0,
                Coin::zero<USDT>(), 1
            );
        Coin::destroy_zero(zero);
        Coin::burn(usdt_coins, &caps.usdt_burn_cap);
    }

    #[test(core = @CoreResources, coin_admin = @TestCoinAdmin, pool_owner = @TestPoolOwner)]
    fun test_pool_exists(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        register_coins(&coin_admin);

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