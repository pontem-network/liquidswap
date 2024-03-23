#[test_only]
module router_v4::router_v4_tests {
    use std::signer;

    use aptos_std::type_info;
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::managed_coin;

    use econia::assets::{Self, UC};
    use econia::market;
    use econia::registry;
    use econia::user;
    use liquidswap::curves::Uncorrelated;
    use liquidswap::liquidity_pool;
    use liquidswap::router;
    use liquidswap::router_v4;
    use liquidswap_lp::lp_coin::LP;
    use test_helpers::test_pool;

    const ONE_BTC_COIN: u64 = 100000000;

    const ONE_USDT_COIN: u64 = 1000000;

    const ONE_UC_COIN: u64 = 1000000;

    const BID: bool = false;
    const ASK: bool = true;

    /// Custodian ID flag for no custodian.
    const NO_CUSTODIAN: u64 = 0;

    /// Flag for fill-or-abort order restriction.
    const FILL_OR_ABORT: u8 = 1;
    const IMMEDIATE_OR_CANCEL: u8 = 2;
    const POST_OR_ABORT: u8 = 3;
    const NO_RESTRICTION: u8 = 0;

    struct BTC {}

    struct USDT {}

    fun initialize_coin<CoinType>(admin: &signer, decimals: u8) {
        let coin_typeinfo = type_info::type_of<CoinType>();
        managed_coin::initialize<CoinType>(
            admin,
            type_info::struct_name(&coin_typeinfo),
            type_info::struct_name(&coin_typeinfo),
            decimals,
            true
        );
    }

    fun initialize_test_coins() {
        let router_v4 = account::create_account_for_test(@router_v4);
        initialize_coin<BTC>(&router_v4, 8);
        initialize_coin<USDT>(&router_v4, 6);
    }

    fun mint_test_coins<CoinType>(amount: u64): Coin<CoinType> {
        let router_v4_admin = create_signer(@router_v4);
        if (!coin::is_account_registered<CoinType>(@router_v4)) {
            coin::register<CoinType>(&router_v4_admin);
        };
        managed_coin::mint<CoinType>(&router_v4_admin, @router_v4, amount);
        coin::withdraw<CoinType>(&router_v4_admin, amount)
    }

    fun create_signer(addr: address): signer {
        account::create_signer_with_capability(&account::create_test_signer_cap(addr))
    }

    fun register_pool_with_liquidity(x_val: u64, y_val: u64) {
        let lp_owner = account::create_account_for_test(@test_lp_owner);

        router::register_pool<BTC, USDT, Uncorrelated>(&lp_owner);

        let lp_owner_addr = signer::address_of(&lp_owner);
        if (x_val != 0 && y_val != 0) {
            let btc_coins = mint_test_coins<BTC>(x_val);
            let usdt_coins = mint_test_coins<USDT>(y_val);
            let lp_coins =
                liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
            managed_coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
            coin::deposit<LP<BTC, USDT, Uncorrelated>>(lp_owner_addr, lp_coins);
        };
    }

    fun register_market<Base, Quote>(econia: &signer, lot_size: u64, tick_size: u64): u64 {
        let utility_coins = assets::mint<UC>(econia, 2000 * ONE_UC_COIN);
        let market_id =
            market::register_market_base_coin<BTC, USDT, UC>(lot_size, tick_size, 1, utility_coins);
        registry::set_recognized_market(econia, market_id);
        market_id
    }

    fun register_market_account_with_deposit<Base, Quote>(
        market_user: &signer,
        market_id: u64,
        base_liq: u64,
        quote_liq: u64
    ) {
        user::register_market_account<BTC, USDT>(market_user, market_id, NO_CUSTODIAN);

        let market_user_addr = signer::address_of(market_user);

        let base_coins = mint_test_coins<Base>(base_liq);
        user::deposit_coins(market_user_addr, market_id, NO_CUSTODIAN, base_coins);

        let quote_coins = mint_test_coins<Quote>(quote_liq);
        user::deposit_coins(market_user_addr, market_id, NO_CUSTODIAN, quote_coins);
    }

    #[test]
    fun test_swap_usdt_to_btc_same_tick_lot() {
        market::init_test();
        test_pool::initialize_liquidity_pool();
        initialize_test_coins();

        let econia = create_signer(@econia);
        // 0.01
        let lot_size = 1000000;
        // 0.01
        let tick_size = 10000;
        let market_id = register_market<BTC, USDT>(&econia, lot_size, tick_size);

        // 125 BTC/USDT
        register_pool_with_liquidity(1000 * ONE_BTC_COIN, 125000 * ONE_USDT_COIN);

        let market_user = account::create_account_for_test(@test_user);
        register_market_account_with_deposit<BTC, USDT>(
            &market_user,
            market_id,
            100 * ONE_BTC_COIN,
            100000 * ONE_USDT_COIN
        );

        // to sell 1 BTC for 100 BTC/USDT
        let (_, _, _, _) =
            market::place_limit_order_user<BTC, USDT>(
                &market_user,
                market_id,
                @econia,
                ASK,
                100,
                100,
                NO_RESTRICTION,
            );
        // sell 2 BTC for 150 BTC/USDT
        let (_, _, _, _) =
            market::place_limit_order_user<BTC, USDT>(
                &market_user,
                market_id,
                @econia,
                ASK,
                200,
                150,
                NO_RESTRICTION,
            );

        let usdts = mint_test_coins<USDT>(170 * ONE_USDT_COIN);
        // 170 USDT:
        // 1. 100 USDT swapped from orderbook with price 100 BTC/USDT, giving 1 BTC
        // 2. remaining 70 USDT swapped with pool with price ~125 BTC/USDT, giving ~0.56 BTC
        let btcs_swapped =
            router_v4::swap_exact_coin_for_coin_econia<USDT, BTC, Uncorrelated>(
                usdts,
                135408397, // 1.2 BTC
            );
        assert!(coin::value(&btcs_swapped) == 155761009, 1);

        coin::register<BTC>(&market_user);
        coin::deposit(@test_user, btcs_swapped);
    }

    #[test]
    fun test_swap_btc_to_usdt_same_tick_lot() {
        market::init_test();
        test_pool::initialize_liquidity_pool();
        initialize_test_coins();

        let econia = create_signer(@econia);
        let market_id = register_market<BTC, USDT>(
            &econia,
            1000000,  // 0.01
            10000  // 0.01
        );

        // 125 BTC/USDT
        register_pool_with_liquidity(1000 * ONE_BTC_COIN, 125000 * ONE_USDT_COIN);

        let market_user = account::create_account_for_test(@test_user);
        register_market_account_with_deposit<BTC, USDT>(
            &market_user,
            market_id,
            100 * ONE_BTC_COIN,
            100000 * ONE_USDT_COIN
        );

        // to sell 1 BTC for 150 BTC/USDT
        let (_, _, _, _) =
            market::place_limit_order_user<BTC, USDT>(
                &market_user,
                market_id,
                @econia,
                BID,
                100,
                150,
                NO_RESTRICTION,
            );
        // sell 2 BTC for 100 BTC/USDT
        let (_, _, _, _) =
            market::place_limit_order_user<BTC, USDT>(
                &market_user,
                market_id,
                @econia,
                BID,
                200,
                100,
                NO_RESTRICTION,
            );

        // 150 USDT from 1 BTC (orderbook)
        // ~62 USDT from 0.5 BTC (swap)
        let btcs = mint_test_coins<BTC>(150000000);  // 1.5 BTC
        let usdts_swapped =
            router_v4::swap_exact_coin_for_coin_econia<BTC, USDT, Uncorrelated>(
                btcs,
                180 * ONE_USDT_COIN,
            );
        assert!(coin::value(&usdts_swapped) == 212206452, 1);

        coin::register<USDT>(&market_user);
        coin::deposit(@test_user, usdts_swapped);
    }

    #[test]
    fun test_swap_btc_to_usdt_different_tick_lot_size() {
        market::init_test();
        test_pool::initialize_liquidity_pool();
        initialize_test_coins();

        let econia = create_signer(@econia);

        let market_id = register_market<BTC, USDT>(
            &econia,
            10000000,  // 0.1
            1000  // 0.001
        );

        // 125 BTC/USDT
        register_pool_with_liquidity(1000 * ONE_BTC_COIN, 125000 * ONE_USDT_COIN);

        let market_user = account::create_account_for_test(@test_user);
        register_market_account_with_deposit<BTC, USDT>(
            &market_user,
            market_id,
            100000 * ONE_BTC_COIN,
            100000 * ONE_USDT_COIN
        );

        let (_, _, _, _) =
            market::place_limit_order_user<BTC, USDT>(
                &market_user,
                market_id,
                @econia,
                BID,
                10,
                15000,
                NO_RESTRICTION,
            );
        // buy 2 BTC for 100 BTC/USDT
        let (_, _, _, _) =
            market::place_limit_order_user<BTC, USDT>(
                &market_user,
                market_id,
                @econia,
                BID,
                20,
                10000,
                NO_RESTRICTION,
            );

        // 150 USDT from 1 BTC (orderbook)
        // ~62 USDT from 0.5 BTC (swap)
        let btcs = mint_test_coins<BTC>(150000000);  // 1.5 BTC
        let usdts_swapped =
            router_v4::swap_exact_coin_for_coin_econia<BTC, USDT, Uncorrelated>(
                btcs,
                180 * ONE_USDT_COIN,
            );
        assert!(coin::value(&usdts_swapped) == 212206452, 1);

        coin::register<USDT>(&market_user);
        coin::deposit(@test_user, usdts_swapped);
    }

    #[test]
    fun test_swap_usdt_to_btc_different_tick_lot() {
        market::init_test();
        test_pool::initialize_liquidity_pool();
        initialize_test_coins();

        let econia = create_signer(@econia);

        let market_id = register_market<BTC, USDT>(
            &econia,
            100000,  // 0.001
            10000  // 0.01
        );
        // 125 BTC/USDT
        register_pool_with_liquidity(1000 * ONE_BTC_COIN, 125000 * ONE_USDT_COIN);

        let market_user = account::create_account_for_test(@test_user);
        register_market_account_with_deposit<BTC, USDT>(
            &market_user,
            market_id,
            1000 * ONE_BTC_COIN,
            100000 * ONE_USDT_COIN
        );

        // to sell 1 BTC for 100 BTC/USDT
        let (_, _, _, _) =
            market::place_limit_order_user<BTC, USDT>(
                &market_user,
                market_id,
                @econia,
                ASK,
                1000,
                10,
                NO_RESTRICTION,
            );
        // sell 2 BTC for 150 BTC/USDT
        let (_, _, _, _) =
            market::place_limit_order_user<BTC, USDT>(
                &market_user,
                market_id,
                @econia,
                ASK,
                2000,
                15,
                NO_RESTRICTION,
            );

        let usdts = mint_test_coins<USDT>(170 * ONE_USDT_COIN);
        // 170 USDT:
        // 1. 100 USDT swapped from orderbook with price 100 BTC/USDT, giving 1 BTC
        // 2. remaining 70 USDT swapped with pool with price ~125 BTC/USDT, giving ~0.56 BTC
        let btcs_swapped =
            router_v4::swap_exact_coin_for_coin_econia<USDT, BTC, Uncorrelated>(
                usdts,
                135408397, // 1.2 BTC
            );
        assert!(coin::value(&btcs_swapped) == 155761009, 1);

        coin::register<BTC>(&market_user);
        coin::deposit(@test_user, btcs_swapped);
    }

    #[test]
    fun test_swap_coin_for_exact_coin_lot_tick_same() {
        market::init_test();
        test_pool::initialize_liquidity_pool();
        initialize_test_coins();

        let econia = create_signer(@econia);

        let market_id = register_market<BTC, USDT>(
            &econia,
            10000000,  // 0.1
            1000  // 0.001
        );

        // 125 BTC/USDT
        register_pool_with_liquidity(1000 * ONE_BTC_COIN, 125000 * ONE_USDT_COIN);

        let market_user = account::create_account_for_test(@test_user);
        register_market_account_with_deposit<BTC, USDT>(
            &market_user,
            market_id,
            100000 * ONE_BTC_COIN,
            100000 * ONE_USDT_COIN
        );

        let (_, _, _, _) =
            market::place_limit_order_user<BTC, USDT>(
                &market_user,
                market_id,
                @econia,
                BID,
                10,
                15000,
                NO_RESTRICTION,
            );
        // buy 2 BTC for 100 BTC/USDT
        let (_, _, _, _) =
            market::place_limit_order_user<BTC, USDT>(
                &market_user,
                market_id,
                @econia,
                BID,
                20,
                10000,
                NO_RESTRICTION,
            );

        // 150 USDT from 1 BTC (orderbook)
        // ~62 USDT from 0.5 BTC (swap)
        let btcs = mint_test_coins<BTC>(150000000);  // 1.5 BTC
        let (remaining_btcs, usdts_swapped) =
            router_v4::swap_coin_for_exact_coin<BTC, USDT, Uncorrelated>(
                btcs,
                128 * ONE_USDT_COIN,
            );
        assert!(coin::value(&usdts_swapped) == 128 * ONE_USDT_COIN, 1);
        assert!(coin::value(&remaining_btcs) == 47186594, 1);

        coin::register<USDT>(&market_user);
        coin::deposit(@test_user, usdts_swapped);
        coin::register<BTC>(&market_user);
        coin::deposit(@test_user, remaining_btcs);
    }
}
