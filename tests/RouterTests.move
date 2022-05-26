#[test_only]
module CoinAdmin::RouterTests {
    use Std::ASCII::string;
    use Std::Signer;

    use AptosFramework::Genesis;
    use AptosFramework::Coin::{Self, MintCapability, BurnCapability};

    use MultiSwap::LiquidityPool;
    use MultiSwap::Router;
    use AptosFramework::Timestamp;

    struct USDT {}

    struct BTC {}

    struct LP {}

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
                true,
            );
        let (btc_mint_cap, btc_burn_cap) =
            Coin::initialize<BTC>(
                coin_admin,
                string(b"BTC"),
                string(b"BTC"),
                8,
                true,
            );
        let caps = Caps{ usdt_mint_cap, usdt_burn_cap, btc_mint_cap, btc_burn_cap };
        move_to(coin_admin, caps);
    }

    fun register_pool_with_liquidity(coin_admin: &signer,
                                     pool_owner: &signer,
                                     x_val: u64, y_val: u64) acquires Caps {
        let coin_admin_addr = Signer::address_of(coin_admin);
        let caps = borrow_global<Caps>(coin_admin_addr);

        let (lp_mint_cap, lp_burn_cap) =
            Coin::initialize<LP>(
                coin_admin,
                string(b"LP"),
                string(b"LP"),
                8,
                true
            );
        Router::register_liquidity_pool<BTC, USDT, LP>(pool_owner, lp_mint_cap, lp_burn_cap);

        let pool_owner_addr = Signer::address_of(pool_owner);
        if (x_val != 0 && y_val != 0) {
            let btc_coins = Coin::mint(x_val, &caps.btc_mint_cap);
            let usdt_coins = Coin::mint(y_val, &caps.usdt_mint_cap);
            let lp_coins =
                LiquidityPool::add_liquidity<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
            Coin::register_internal<LP>(pool_owner);
            Coin::deposit<LP>(pool_owner_addr, lp_coins);
        };
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    fun test_add_initial_liquidity(core: signer, coin_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);
        register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 0, 0);

        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let btc_coins = Coin::mint(101, &caps.btc_mint_cap);
        let usdt_coins = Coin::mint(10100, &caps.usdt_mint_cap);
        let pool_addr = Signer::address_of(&pool_owner);

        let (coin_x, coin_y, lp_coins) =
            Router::add_liquidity<BTC, USDT, LP>(
                pool_addr,
                btc_coins,
                101,
                usdt_coins,
                10100
            );

        assert!(Coin::value(&coin_x) == 0, 1);
        assert!(Coin::value(&coin_y) == 0, 2);
        // 1010 - 1000 = 10
        assert!(Coin::value(&lp_coins) == 10, 3);

        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);
        Coin::register_internal<LP>(&pool_owner);

        Coin::deposit(pool_addr, coin_x);
        Coin::deposit(pool_addr, coin_y);
        Coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    fun test_add_liquidity_to_pool(core: signer, coin_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);

        register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let btc_coins = Coin::mint(101, &caps.btc_mint_cap);
        let usdt_coins = Coin::mint(9000, &caps.usdt_mint_cap);
        let pool_addr = Signer::address_of(&pool_owner);

        let (coin_x, coin_y, lp_coins) =
            Router::add_liquidity<BTC, USDT, LP>(pool_addr, btc_coins, 10, usdt_coins, 9000);
        // 101 - 90 = 11
        assert!(Coin::value(&coin_x) == 11, 1);
        assert!(Coin::value(&coin_y) == 0, 2);
        // 8.91 ~ 8
        assert!(Coin::value(&lp_coins) == 8, 3);

        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);

        Coin::deposit(pool_addr, coin_x);
        Coin::deposit(pool_addr, coin_y);
        Coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    fun test_add_liquidity_to_pool_reverse(core: signer, coin_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);
        register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let btc_coins = Coin::mint(101, &caps.btc_mint_cap);
        let usdt_coins = Coin::mint(9000, &caps.usdt_mint_cap);
        let pool_addr = Signer::address_of(&pool_owner);

        let (coin_y, coin_x, lp_coins) =
            Router::add_liquidity<USDT, BTC, LP>(pool_addr, usdt_coins, 9000, btc_coins, 10);
        // 101 - 90 = 11
        assert!(Coin::value(&coin_x) == 11, 1);
        assert!(Coin::value(&coin_y) == 0, 2);
        // 8.91 ~ 8
        assert!(Coin::value(&lp_coins) == 8, 3);

        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);

        Coin::deposit(pool_addr, coin_x);
        Coin::deposit(pool_addr, coin_y);
        Coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    fun test_remove_liquidity(core: signer, coin_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);
        register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let lp_coins_val = 2u64;
        let pool_addr = Signer::address_of(&pool_owner);
        let lp_coins_to_burn = Coin::withdraw<LP>(&pool_owner, lp_coins_val);

        let (x_out, y_out) = Router::get_reserves_for_lp_coins<BTC, USDT, LP>(
            pool_addr,
            lp_coins_val
        );
        let (coin_x, coin_y) =
            Router::remove_liquidity<BTC, USDT, LP>(pool_addr, lp_coins_to_burn, x_out, y_out);

        let (usdt_reserve, btc_reserve) = Router::get_reserves_size<USDT, BTC, LP>(pool_addr);
        assert!(usdt_reserve == 8080, 3);
        assert!(btc_reserve == 81, 4);

        assert!(Coin::value(&coin_x) == x_out, 1);
        assert!(Coin::value(&coin_y) == y_out, 2);

        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);

        Coin::deposit(pool_addr, coin_x);
        Coin::deposit(pool_addr, coin_y);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    fun test_swap_exact_coin_for_coin(core: signer, coin_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);

        register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let btc_coins_to_swap = Coin::mint(1, &caps.btc_mint_cap);

        let usdt_coins =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_owner_addr, btc_coins_to_swap, 90);
        assert!(Coin::value(&usdt_coins) == 98, 1);

        Coin::burn(usdt_coins, &caps.usdt_burn_cap);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    fun test_swap_exact_coin_for_coin_reverse(core: signer, coin_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);

        register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let usdt_coins_to_swap = Coin::mint(110, &caps.usdt_mint_cap);

        let btc_coins =
            Router::swap_exact_coin_for_coin<USDT, BTC, LP>(pool_owner_addr, usdt_coins_to_swap, 1);
        assert!(Coin::value(&btc_coins) == 1, 1);

        Coin::burn(btc_coins, &caps.btc_burn_cap);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    fun test_swap_coin_for_exact_coin(core: signer, coin_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);

        register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let btc_coins_to_swap = Coin::mint(1, &caps.btc_mint_cap);

        let (remainder, usdt_coins) =
            Router::swap_coin_for_exact_coin<BTC, USDT, LP>(pool_owner_addr, btc_coins_to_swap, 98);

        assert!(Coin::value(&usdt_coins) == 98, 1);
        assert!(Coin::value(&remainder) == 0, 2);

        Coin::burn(usdt_coins, &caps.usdt_burn_cap);
        Coin::destroy_zero(remainder);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    fun test_swap_coin_for_exact_coin_reverse(core: signer, coin_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);

        register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let usdt_coins_to_swap = Coin::mint(1114, &caps.usdt_mint_cap);

        let (remainder, btc_coins) =
            Router::swap_coin_for_exact_coin<USDT, BTC, LP>(pool_owner_addr, usdt_coins_to_swap, 10);

        assert!(Coin::value(&btc_coins) == 10, 1);
        assert!(Coin::value(&remainder) == 0, 2);

        Coin::burn(btc_coins, &caps.btc_burn_cap);
        Coin::destroy_zero(remainder);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    #[expected_failure(abort_code = 26887)]
    fun test_fail_if_price_fell_behind_threshold(core: signer, coin_admin: signer, pool_owner: signer)
    acquires Caps {
        Genesis::setup(&core);

        register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let btc_coin_to_swap = Coin::mint(1, &caps.btc_mint_cap);

        let usdt_coins =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_owner_addr, btc_coin_to_swap, 102);

        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, usdt_coins);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    #[expected_failure(abort_code = 26887)]
    fun test_fail_if_swap_zero_coin(core: signer, coin_admin: signer, pool_owner: signer)
    acquires Caps {
        Genesis::setup(&core);
        register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let btc_coins_to_swap = Coin::mint(0, &caps.btc_mint_cap);

        let usdt_coins =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_owner_addr, btc_coins_to_swap, 0);

        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, usdt_coins);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    fun test_returned_usdt_proportially_decrease_for_big_swaps(core: signer, coin_admin: signer, pool_owner: signer)
    acquires Caps {
        Genesis::setup(&core);

        register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = Signer::address_of(&pool_owner);
        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let btc_coins_to_swap = Coin::mint(200, &caps.btc_mint_cap);

        let usdt_coins =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_owner_addr, btc_coins_to_swap, 1);
        assert!(Coin::value(&usdt_coins) == 6704, 1);

        let (btc_reserve, usdt_reserve) = Router::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(btc_reserve == 301, 2);
        assert!(usdt_reserve == 3396, 3);
        assert!(Router::current_price<USDT, BTC, LP>(pool_owner_addr) == 11, 4);

        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, usdt_coins);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    fun test_pool_exists(core: signer, coin_admin: signer, pool_owner: signer) {
        Genesis::setup(&core);

        register_coins(&coin_admin);

        let (lp_mint_cap, lp_burn_cap) =
            Coin::initialize<LP>(
                &coin_admin,
                string(b"LP"),
                string(b"LP"),
                8,
                true,
            );

        Router::register_liquidity_pool<BTC, USDT, LP>(&pool_owner, lp_mint_cap, lp_burn_cap);

        assert!(Router::pool_exists_at<BTC, USDT, LP>(Signer::address_of(&pool_owner)), 1);
        assert!(Router::pool_exists_at<USDT, BTC, LP>(Signer::address_of(&pool_owner)), 2);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    fun test_cumulative_prices_after_swaps(core: signer, coin_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);
        register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);
        Coin::register_internal<USDT>(&pool_owner);

        let pool_addr = Signer::address_of(&pool_owner);
        let (btc_price, usdt_price, ts) =
            Router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_price == 0, 1);
        assert!(usdt_price == 0, 2);
        assert!(ts == 0, 3);

        // 2 seconds
        Timestamp::update_global_time_for_test(2000000);

        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let btc_to_swap = Coin::mint<BTC>(1, &caps.btc_mint_cap);
        let usdts =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_addr, btc_to_swap, 95);
        Coin::deposit(pool_addr, usdts);

        let (btc_cum_price, usdt_cum_price, last_timestamp) =
            Router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_cum_price == 3689348814741910323000, 4);
        assert!(usdt_cum_price == 368934881474191032, 5);
        assert!(last_timestamp == 2, 6);

        // 4 seconds
        Timestamp::update_global_time_for_test(4000000);

        let btc_to_swap = Coin::mint<BTC>(2, &caps.btc_mint_cap);
        let usdts =
            Router::swap_exact_coin_for_coin<BTC, USDT, LP>(pool_addr, btc_to_swap, 190);
        Coin::deposit(pool_addr, usdts);

        let (btc_cum_price, usdt_cum_price, last_timestamp) =
            Router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_cum_price == 7307080858374124739730, 7);
        assert!(usdt_cum_price == 745173212911578406, 8);
        assert!(last_timestamp == 4, 9);
    }
}
