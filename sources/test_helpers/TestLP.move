#[test_only]
module TestPoolOwner::TestLP {
    use Std::ASCII::string;

    use AptosFramework::Coin::{Self, MintCapability, BurnCapability};

    struct LP {}

    struct Capabilities<phantom CoinType> has key {
        mint_cap: MintCapability<CoinType>,
        burn_cap: BurnCapability<CoinType>,
    }

    public fun register_lp_for_fails(pool_owner: &signer) {
        let (mint_cap, burn_cap) =
            Coin::initialize<LP>(
                pool_owner,
                string(b"LP"),
                string(b"LP"),
                6,
                true
            );

        move_to(pool_owner, Capabilities<LP> { mint_cap, burn_cap });
    }
}