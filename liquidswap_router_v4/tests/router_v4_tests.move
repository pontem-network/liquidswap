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

    const ONE_BTC_COIN: u64 = 1000000;

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

    fun initialize_coin<CoinType>(admin: &signer) {
        let coin_typeinfo = type_info::type_of<CoinType>();
        managed_coin::initialize<CoinType>(
            admin,
            type_info::struct_name(&coin_typeinfo),
            type_info::struct_name(&coin_typeinfo),
            6,
            true
        );
    }

    fun mint_coins<CoinType>(admin: &signer, amount: u64): Coin<CoinType> {
        let admin_addr = signer::address_of(admin);
        if (!coin::is_account_registered<CoinType>(admin_addr)) {
            coin::register<CoinType>(admin);
        };
        managed_coin::mint<CoinType>(admin, admin_addr, amount);
        coin::withdraw<CoinType>(admin, amount)
    }

    fun create_signer(addr: address): signer {
        account::create_signer_with_capability(&account::create_test_signer_cap(addr))
    }

    fun register_pool_with_liquidity(x_val: u64, y_val: u64) {
        let router_v4 = create_signer(@router_v4);
        let lp_owner = account::create_account_for_test(@test_lp_owner);

        router::register_pool<BTC, USDT, Uncorrelated>(&lp_owner);

        let lp_owner_addr = signer::address_of(&lp_owner);
        if (x_val != 0 && y_val != 0) {
            let btc_coins = mint_coins<BTC>(&router_v4, x_val);
            let usdt_coins = mint_coins<USDT>(&router_v4, y_val);
            let lp_coins =
                liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
            managed_coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
            coin::deposit<LP<BTC, USDT, Uncorrelated>>(lp_owner_addr, lp_coins);
        };
    }

    // fun mint_coin<CoinType>(admin: &signer, amount: u64): Coin<CoinType> acquires Caps {
    //     let caps = borrow_global<Caps<CoinType>>(signer::address_of(admin));
    //     coin::mint(amount, &caps.mint)
    // }

    #[test]
    fun test_swap_e2e() {
        market::init_test();
        test_pool::initialize_liquidity_pool();

        let router_v4_admin = account::create_account_for_test(@router_v4);
        initialize_coin<BTC>(&router_v4_admin);
        initialize_coin<USDT>(&router_v4_admin);

        let econia = create_signer(@econia);
        let utility_coins = assets::mint<UC>(&econia, 2000 * ONE_UC_COIN);
        let market_id =
            market::register_market_base_coin<BTC, USDT, UC>(1 * ONE_BTC_COIN, 1, 1, utility_coins);
        registry::set_recognized_market(&econia, market_id);

        // 175 BTC/USDT
        register_pool_with_liquidity(100 * ONE_BTC_COIN, 17500 * ONE_USDT_COIN);

        let market_user = account::create_account_for_test(@test_user);
        user::register_market_account<BTC, USDT>(&market_user, market_id, NO_CUSTODIAN);

        let btc_coins = mint_coins<BTC>(&router_v4_admin, 100 * ONE_BTC_COIN);
        user::deposit_coins(@test_user, market_id, NO_CUSTODIAN, btc_coins);

        let usdt_coins = mint_coins<USDT>(&router_v4_admin, 100000 * ONE_USDT_COIN);
        user::deposit_coins(@test_user, market_id, NO_CUSTODIAN, usdt_coins);

        // bid: I want to sell BTC and willing to do it for at least this price
        // ask: I want to buy BTC and willing to pay at most this price

        // to sell 1 BTC for 100 BTC/USDT
        let (_, _, _, _) =
            market::place_limit_order_user<BTC, USDT>(
                &market_user,
                market_id,
                @econia,
                ASK,
                1,
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
                2,
                150 * ONE_USDT_COIN,
                NO_RESTRICTION,
            );
        // sell 3 BTC for 250 BTC/USDT
        let (_, _, _, _) =
            market::place_limit_order_user<BTC, USDT>(
                &market_user,
                market_id,
                @econia,
                ASK,
                3,
                250 * ONE_USDT_COIN,
                NO_RESTRICTION,
            );

        let usdts = mint_coins<USDT>(&router_v4_admin, 180 * ONE_USDT_COIN);
        // 1_015_076
        let btcs_swapped =
            router_v4::swap_exact_coin_for_coin_with_orderbook<USDT, BTC, Uncorrelated>(
                usdts,
                1 * ONE_BTC_COIN,
            );

        coin::register<BTC>(&market_user);
        coin::deposit(@test_user, btcs_swapped);
    }
}
