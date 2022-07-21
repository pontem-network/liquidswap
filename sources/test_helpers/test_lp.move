#[test_only]
module test_pool_owner::test_lp {
    use std::string::utf8;

    use aptos_framework::coin::{Self, MintCapability, BurnCapability};

    struct LP {}

    struct Capabilities<phantom CoinType> has key {
        mint_cap: MintCapability<CoinType>,
        burn_cap: BurnCapability<CoinType>,
    }

    public fun register_lp_for_fails(pool_owner: &signer) {
        let (mint_cap, burn_cap) =
            coin::initialize<LP>(
                pool_owner,
                utf8(b"LP"),
                utf8(b"LP"),
                6,
                true
            );

        move_to(pool_owner, Capabilities<LP> { mint_cap, burn_cap });
    }
}