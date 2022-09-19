#[test_only]
module liquidswap::coin_helper_tests {
    use std::string::{utf8, String};

    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_std::comparator;

    use liquidswap::coin_helper;
    use liquidswap::curves::{Uncorrelated, Stable};
    use test_coin_admin::test_coins::{Self, BTC, USDT, create_coin_admin};

    fun register_coins_for_lp_names(
        btc_name: vector<u8>,
        btc_symbol: vector<u8>,
        usdt_name: vector<u8>,
        usdt_symbol: vector<u8>
    ) {
        let coin_admin = create_coin_admin();
        let (coin1_burn_cap, coin1_freeze_cap, coin1_mint_cap) =
            coin::initialize<BTC>(
                &coin_admin,
                utf8(btc_name),
                utf8(btc_symbol),
                6,
                true
            );
        coin::destroy_mint_cap(coin1_mint_cap);
        coin::destroy_burn_cap(coin1_burn_cap);
        coin::destroy_freeze_cap(coin1_freeze_cap);

        let (coin2_burn_cap, coin2_freeze_cap, coin2_mint_cap) =
            coin::initialize<USDT>(
                &coin_admin,
                utf8(usdt_name),
                utf8(usdt_symbol),
                8,
                true
            );
        coin::destroy_mint_cap(coin2_mint_cap);
        coin::destroy_burn_cap(coin2_burn_cap);
        coin::destroy_freeze_cap(coin2_freeze_cap);
    }

    fun generate_lp_name_and_symbol_for_coins<Curve>(): (String, String) {
        coin_helper::generate_lp_name_and_symbol<BTC, USDT, Curve>()
    }

    #[test]
    fun test_end_to_end() {
        genesis::setup();

        let coin_admin = test_coins::create_admin_with_coins();

        coin_helper::assert_is_coin<USDT>();
        coin_helper::assert_is_coin<BTC>();

        let coins_minted = test_coins::mint<USDT>(&coin_admin, 1000000000);

        let usdt_supply = coin_helper::supply<USDT>();
        let btc_supply = coin_helper::supply<BTC>();
        assert!(usdt_supply == 1000000000, 0);
        assert!(btc_supply == 0, 1);

        test_coins::burn(&coin_admin, coins_minted);
        usdt_supply = coin_helper::supply<USDT>();
        assert!(usdt_supply == 0, 2);

        assert!(coin_helper::is_sorted<BTC, USDT>(), 3);
        assert!(!coin_helper::is_sorted<USDT, BTC>(), 4);

        let cmp = coin_helper::compare<BTC, USDT>();
        assert!(comparator::is_smaller_than(&cmp), 5);
        cmp = coin_helper::compare<BTC, BTC>();
        assert!(comparator::is_equal(&cmp), 6);
        cmp = coin_helper::compare<USDT, BTC>();
        assert!(comparator::is_greater_than(&cmp), 7);
    }

    #[test]
    #[expected_failure(abort_code = 3001)]
    fun test_assert_is_coin_failure() {
        coin_helper::assert_is_coin<USDT>();
    }

    #[test]
    #[expected_failure(abort_code = 3000)]
    fun test_cant_be_same_coin_failure() {
        genesis::setup();

        test_coins::create_admin_with_coins();

        coin_helper::assert_is_coin<USDT>();
        let _ = coin_helper::is_sorted<USDT, USDT>();
    }

    #[test]
    fun generate_lp_name_btc_usdt() {
        genesis::setup();

        register_coins_for_lp_names(
            b"Bitcoin",
            b"BTC",
            b"Usdt",
            b"USDT"
        );
        let (lp_name, lp_symbol) = generate_lp_name_and_symbol_for_coins<Uncorrelated>();
        assert!(lp_name == utf8(b"LiquidLP-BTC-USDT-U"), 0);
        assert!(lp_symbol == utf8(b"BTC-USDT"), 1);
    }

    #[test]
    fun generate_lp_name_usdc_usdt() {
        genesis::setup();

        register_coins_for_lp_names(
            b"USDC",
            b"USDC",
            b"USDT",
            b"USDT"
        );
        let (lp_name, lp_symbol) = generate_lp_name_and_symbol_for_coins<Stable>();
        assert!(lp_name == utf8(b"LiquidLP-USDC-USDT-S"), 0);
        assert!(lp_symbol == utf8(b"USDC-USDT*"), 1);
    }

    #[test]
    fun generate_lp_name_usdc_usdt_prefix() {
        genesis::setup();

        register_coins_for_lp_names(
            b"USDC",
            b"USDCSymbol",
            b"USDT",
            b"USDTSymbol"
        );
        let (lp_name, lp_symbol) = generate_lp_name_and_symbol_for_coins<Stable>();
        assert!(lp_name == utf8(b"LiquidLP-USDCSymbol-USDTSymbol-S"), 0);
        assert!(lp_symbol == utf8(b"USDC-USDT*"), 1);
    }
}
