module liquidswap::lp_init {
    use std::signer;

    use aptos_framework::account::{Self, SignerCapability};

    const ERR_NOT_ENOUGH_PERMISSIONS: u64 = 1701;

    struct SignerCapStorage has key { signer_cap: SignerCapability }

    public entry fun initialize_lp_account(
        liquidswap_admin: &signer,
        lp_coin_metadata_serialized: vector<u8>,
        lp_coin_code: vector<u8>
    ) {
        assert!(signer::address_of(liquidswap_admin) == @liquidswap, ERR_NOT_ENOUGH_PERMISSIONS);

        let (lp_acc, signer_cap) =
            account::create_resource_account(liquidswap_admin, b"liquidswap_account_seed");
        aptos_framework::code::publish_package_txn(
            &lp_acc,
            lp_coin_metadata_serialized,
            vector[lp_coin_code]
        );
        move_to(liquidswap_admin, SignerCapStorage { signer_cap });
    }

    public fun retrieve_signer_cap(liquidswap_admin: &signer): SignerCapability acquires SignerCapStorage {
        let SignerCapStorage { signer_cap } =
            move_from<SignerCapStorage>(signer::address_of(liquidswap_admin));
        signer_cap
    }
}
