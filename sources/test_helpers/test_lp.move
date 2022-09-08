#[test_only]
module test_pool_owner::test_lp {
    use std::string::utf8;

    use aptos_framework::coin::{Self, MintCapability, BurnCapability};
    use aptos_framework::account;
    use aptos_framework::genesis;
    use test_coin_admin::test_coins;

    struct LP {}

    struct Capabilities<phantom CoinType> has key {
        mint_cap: MintCapability<CoinType>,
        burn_cap: BurnCapability<CoinType>,
    }

    public fun get_mint_cap(pool_owner_addr: address): MintCapability<LP> acquires Capabilities {
        *&borrow_global<Capabilities<LP>>(pool_owner_addr).mint_cap
    }

    public fun get_burn_cap(pool_owner_addr: address): BurnCapability<LP> acquires Capabilities {
        *&borrow_global<Capabilities<LP>>(pool_owner_addr).burn_cap
    }

    public fun register_lp_for_fails(pool_owner: &signer) {
        let (burn_cap, freeze_cap, mint_cap) =
            coin::initialize<LP>(
                pool_owner,
                utf8(b"LP"),
                utf8(b"LP"),
                6,
                true
            );
        coin::destroy_freeze_cap(freeze_cap);

        move_to(pool_owner, Capabilities<LP> { mint_cap, burn_cap });
    }

    public fun create_pool_owner(): signer {
        let pool_owner = account::create_account_for_test(@test_pool_owner);
        pool_owner
    }

    public fun create_coin_admin_and_pool_owner(): (signer, signer) {
        let coin_admin = test_coins::create_coin_admin();
        let pool_owner = create_pool_owner();
        (coin_admin, pool_owner)
    }

    public fun setup_coins_and_pool_owner(): (signer, signer) {
        genesis::setup();
        let coin_admin = test_coins::create_admin_with_coins();
        let pool_owner = create_pool_owner();
        (coin_admin, pool_owner)
    }
}
