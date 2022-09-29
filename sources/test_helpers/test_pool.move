#[test_only]
module test_helpers::test_pool {
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::genesis;
    use liquidswap_lp::lp_coin::LP;

    use liquidswap::liquidity_pool;
    use liquidswap::lp_account;
    use test_coin_admin::test_coins;

    public fun create_lp_owner(): signer {
        let pool_owner = account::create_account_for_test(@test_lp_owner);
        pool_owner
    }

    public fun create_liquidswap_admin(): signer {
        let admin = account::create_account_for_test(@liquidswap);
        admin
    }

    public fun create_coin_admin_and_lp_owner(): (signer, signer) {
        let coin_admin = test_coins::create_coin_admin();
        let lp_owner = create_lp_owner();
        (coin_admin, lp_owner)
    }

    public fun initialize_liquidity_pool() {
        let liquidswap_admin = account::create_account_for_test(@liquidswap);
        let lp_coin_metadata = x"064c50436f696e010000000000000000403239383333374145433830334331323945313337414344443138463135393936323344464146453735324143373738443344354437453231454133443142454389021f8b08000000000002ff2d90c16ec3201044ef7c45e44b4eb13160c0957aeab5952af51845d1b22c8995c45860bbfdfce2b4b79dd59b9dd11e27c01b5ce8c44678d0ee75b77fff7c8bc3b8672ba53cc4715bb535aff99eb123789f2867ca27769fce58b83320c6659c0b56f19f36980e21f4beb5207a05c48d54285b4784ad7306a5e8831460add6ce486dc98014aed78e2b521d5525c3d37af034d1e869c48172fd1157fa9afd7d702776199e49d7799ef24bd314795d5c8df1d1c034c77cb883cbff23c64475012a9668dd4c3668a91c7a41caa2ea8db0da7ace3be965274550c1680ed4f615cb8bf343da3c7fa71ea541135279d0774cb7669387fc6c54b15fb48937414101000001076c705f636f696e5c1f8b08000000000002ff35c8b10980301046e13e53fc0338411027b0b0d42a84535048ee82de5521bb6b615ef5f8b2ec960ea412482e0e91488cd5fb1f501dbe1ebd8d14f3329633b24ac63aa0ef36a136d7dc0b3946fd604b00000000000000";
        let lp_coin_code = x"a11ceb0b050000000501000202020a070c170823200a4305000000010003000100010001076c705f636f696e024c500b64756d6d795f6669656c6435e1873b2a1ae8c609598114c527b57d31ff5274f646ea3ff6ecad86c56d2cf8000201020100";

        lp_account::initialize_lp_account(
            &liquidswap_admin,
            lp_coin_metadata,
            lp_coin_code
        );
        // retrieves SignerCapability
        liquidity_pool::initialize(&liquidswap_admin);
    }

    public fun setup_coins_and_lp_owner(): (signer, signer) {
        genesis::setup();

        initialize_liquidity_pool();

        let coin_admin = test_coins::create_admin_with_coins();
        let lp_owner = create_lp_owner();
        (coin_admin, lp_owner)
    }

    public fun mint_liquidity<X, Y, Curve>(lp_owner: &signer, coin_x: Coin<X>, coin_y: Coin<Y>): u64 {
        let lp_owner_addr = signer::address_of(lp_owner);
        let lp_coins = liquidity_pool::mint<X, Y, Curve>(coin_x, coin_y);
        let lp_coins_val = coin::value(&lp_coins);
        if (!coin::is_account_registered<LP<X, Y, Curve>>(lp_owner_addr)) {
            coin::register<LP<X, Y, Curve>>(lp_owner);
        };
        coin::deposit(lp_owner_addr, lp_coins);
        lp_coins_val
    }
}
