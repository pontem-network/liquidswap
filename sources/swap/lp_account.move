module liquidswap::lp_account {
    use std::signer;
    use std::string::{Self, String};

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin::{Self, MintCapability, BurnCapability};
    use lp_coin_account::lp_coin::LP;

    friend liquidswap::liquidity_pool;

    const ERR_NOT_INITIALIZED: u64 = 901;

    struct LPCapability has key {
        signer_cap: SignerCapability
    }

    public entry fun initialize_lp_account(
        liquidswap_admin: &signer,
        seed: vector<u8>,
        lp_coin_metadata_serialized: vector<u8>,
        lp_coin_code: vector<u8>
    ) {
        assert!(signer::address_of(liquidswap_admin) == @liquidswap, 1);

        let (lp_acc, signer_cap) = account::create_resource_account(liquidswap_admin, seed);
        aptos_framework::code::publish_package_txn(
            &lp_acc,
            lp_coin_metadata_serialized,
            vector[lp_coin_code]
        );
        move_to(liquidswap_admin, LPCapability { signer_cap });
    }

    public(friend) fun register_lp_coin<X, Y>(lp_name: String, lp_symbol: String): (MintCapability<LP<X, Y>>, BurnCapability<LP<X, Y>>)
    acquires LPCapability {
        assert!(exists<LPCapability>(@liquidswap), ERR_NOT_INITIALIZED);
        let lp_cap = borrow_global<LPCapability>(@liquidswap);
        let lp_account = account::create_signer_with_capability(&lp_cap.signer_cap);

        let (lp_burn_cap, lp_freeze_cap, lp_mint_cap) =
            coin::initialize<LP<X, Y>>(
                &lp_account,
                lp_name,
                lp_symbol,
                6,
                true
            );
        coin::destroy_freeze_cap(lp_freeze_cap);

        (lp_mint_cap, lp_burn_cap)
    }

    #[test_only]
    public fun register_lp_coin_test<X, Y>(lp_name: String, lp_symbol: String): (MintCapability<LP<X, Y>>, BurnCapability<LP<X, Y>>)
    acquires LPCapability {
        register_lp_coin<X, Y>(lp_name, lp_symbol)
    }

    public fun is_lp_coin_registered<X, Y>(): bool {
        coin::is_coin_initialized<LP<X, Y>>()
    }

    #[test_only]
    public fun generate_lp_name<X, Y>(): String {
        let lp_name = string::utf8(b"LP");
        string::append(&mut lp_name, string::utf8(b"<"));
        string::append(&mut lp_name, coin::symbol<X>());
        string::append(&mut lp_name, string::utf8(b", "));
        string::append(&mut lp_name, coin::symbol<Y>());
        string::append(&mut lp_name, string::utf8(b">"));
        lp_name
    }
}
