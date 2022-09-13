module liquidswap::lp {
    use std::signer;
    use std::string::String;

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin::{Self, MintCapability, BurnCapability};

    use lp_coin_account::lp_coin::LP;

    use liquidswap::lp_init;

    friend liquidswap::liquidity_pool;

    const ERR_NOT_INITIALIZED: u64 = 901;

    const ERR_NO_PERMISSIONS: u64 = 902;

    struct LPCapability has key {
        signer_cap: SignerCapability
    }

    public entry fun initialize(liquidswap_admin: &signer) {
        assert!(signer::address_of(liquidswap_admin) == @liquidswap, ERR_NO_PERMISSIONS);
        let signer_cap = lp_init::retrieve_signer_cap(liquidswap_admin);
        move_to(liquidswap_admin, LPCapability { signer_cap });
    }

    public(friend) fun register_lp_coin<X, Y, Curve>(
        lp_name: String,
        lp_symbol: String
    ): (MintCapability<LP<X, Y, Curve>>, BurnCapability<LP<X, Y, Curve>>)
    acquires LPCapability {
        assert!(exists<LPCapability>(@liquidswap), ERR_NOT_INITIALIZED);
        let lp_cap = borrow_global<LPCapability>(@liquidswap);
        let lp_account = account::create_signer_with_capability(&lp_cap.signer_cap);

        let (lp_burn_cap, lp_freeze_cap, lp_mint_cap) =
            coin::initialize<LP<X, Y, Curve>>(
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
    public fun register_lp_coin_test<X, Y, Curve>(lp_name: String, lp_symbol: String): (MintCapability<LP<X, Y, Curve>>, BurnCapability<LP<X, Y, Curve>>)
    acquires LPCapability {
        register_lp_coin<X, Y, Curve>(lp_name, lp_symbol)
    }

    public fun is_lp_coin_registered<X, Y, Curve>(): bool {
        coin::is_coin_initialized<LP<X, Y, Curve>>()
    }
}
