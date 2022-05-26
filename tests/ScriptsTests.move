#[test_only]
module CoinAdmin::ScriptsTests {
    use Std::Signer;
    use Std::ASCII::string;
    use AptosFramework::Coin;
    use MultiSwap::Router;
    use MultiSwap::LiquidityPool;
    use AptosFramework::Coin::{MintCapability, BurnCapability};
    use AptosFramework::Genesis;
    use MultiSwap::Scripts;

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
    public(script) fun test_add_liquidity(core: signer, coin_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);
        register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 0, 0);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let btc_coins = Coin::mint(101, &caps.btc_mint_cap);
        let usdt_coins = Coin::mint(10100, &caps.usdt_mint_cap);

        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, btc_coins);
        Coin::deposit(pool_owner_addr, usdt_coins);

        Coin::register_internal<LP>(&pool_owner);

        Scripts::add_liquidity<BTC, USDT, LP>(
            pool_owner,
            pool_owner_addr,
            101,
            101,
            10100,
            10100
        );

        assert!(Coin::balance<BTC>(pool_owner_addr) == 0, 1);
        assert!(Coin::balance<USDT>(pool_owner_addr) == 0, 2);
        assert!(Coin::balance<LP>(pool_owner_addr) == 10, 3);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    public(script) fun test_remove_liquidity(core: signer, coin_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);
        register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 0, 0);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let btc_coins = Coin::mint(101, &caps.btc_mint_cap);
        let usdt_coins = Coin::mint(10100, &caps.usdt_mint_cap);

        let (btc, usdt, lp) =
            Router::add_liquidity<BTC, USDT, LP>(pool_owner_addr, btc_coins, 101, usdt_coins, 10100);
        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);
        Coin::register_internal<LP>(&pool_owner);
        Coin::deposit(pool_owner_addr, btc);
        Coin::deposit(pool_owner_addr, usdt);
        Coin::deposit(pool_owner_addr, lp);

        Scripts::remove_liquidity<BTC, USDT, LP>(pool_owner, pool_owner_addr, 10, 98, 10000);

        assert!(Coin::balance<LP>(pool_owner_addr) == 0, 1);
        assert!(Coin::balance<BTC>(pool_owner_addr) == 101, 2);
        assert!(Coin::balance<USDT>(pool_owner_addr) == 10100, 3);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    public(script) fun test_swap_exact_btc_for_usdt(core: signer, coin_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);
        register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let btc_coins_to_swap = Coin::mint(10, &caps.btc_mint_cap);
        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, btc_coins_to_swap);

        Scripts::swap<BTC, USDT, LP>(pool_owner, pool_owner_addr, 10, 900);

        assert!(Coin::balance<BTC>(pool_owner_addr) == 0, 1);
        assert!(Coin::balance<USDT>(pool_owner_addr) == 907, 2);
    }

    #[test(core = @CoreResources, coin_admin = @CoinAdmin, pool_owner = @0x42)]
    public(script) fun test_swap_btc_for_exact_usdt(core: signer, coin_admin: signer, pool_owner: signer) acquires Caps {
        Genesis::setup(&core);
        register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);
        let pool_owner_addr = Signer::address_of(&pool_owner);

        let caps = borrow_global<Caps>(Signer::address_of(&coin_admin));
        let btc_coins_to_swap = Coin::mint(10, &caps.btc_mint_cap);
        Coin::register_internal<BTC>(&pool_owner);
        Coin::register_internal<USDT>(&pool_owner);
        Coin::deposit(pool_owner_addr, btc_coins_to_swap);

        Scripts::swap_into<BTC, USDT, LP>(pool_owner, pool_owner_addr, 10, 700);

        assert!(Coin::balance<BTC>(pool_owner_addr) == 2, 1);
        assert!(Coin::balance<USDT>(pool_owner_addr) == 700, 2);
    }
}
