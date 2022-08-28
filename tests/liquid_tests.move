#[test_only]
module liquidswap::liquid_tests {
    use std::option;
    use std::signer;

    use aptos_framework::coin::{Self, MintCapability, BurnCapability};
    use aptos_framework::genesis;
    use aptos_framework::timestamp;

    use liquidswap::liquid::{Self, LAMM};
    use test_helpers::test_account::create_account;

    struct MintCap has key { mint_cap: MintCapability<LAMM> }

    struct BurnCap has key { burn_cap: BurnCapability<LAMM> }

    #[test(admin = @liquidswap, user = @0x43)]
    fun test_mint_burn_with_functions(admin: signer, user: signer) {
        genesis::setup();

        create_account(&admin);
        create_account(&user);

        liquid::initialize(&admin);
        coin::register<LAMM>(&user);

        let user_addr = signer::address_of(&user);
        liquid::mint_internal(&admin, user_addr, 100);
        assert!(coin::balance<LAMM>(user_addr) == 100, 1);

        let lamm_coins = coin::withdraw<LAMM>(&user, 50);
        liquid::burn_internal(lamm_coins);
        assert!(coin::supply<LAMM>() == option::some(50), 2);
    }

    #[test(admin = @liquidswap)]
    fun test_mint_burn_with_caps(admin: signer) {
        genesis::setup();

        create_account(&admin);

        liquid::initialize(&admin);

        let mint_cap = liquid::get_mint_cap(&admin);
        let lamm_coins = coin::mint(100, &mint_cap);

        let burn_cap = liquid::get_burn_cap();
        coin::burn(lamm_coins, &burn_cap);

        move_to(&admin, MintCap { mint_cap });
        coin::destroy_burn_cap(burn_cap);
    }

    #[test(admin = @liquidswap)]
    #[expected_failure(abort_code = 101)]
    fun test_cannot_get_mint_cap_if_locked(admin: signer) {
        genesis::setup();

        create_account(&admin);

        liquid::initialize(&admin);

        liquid::lock_minting_internal(&admin);
        // failure here, need to store mint_cap somewhere anyway, otherwise it won't compile
        let mint_cap = liquid::get_mint_cap(&admin);
        move_to(&admin, MintCap { mint_cap });
    }

    #[test(admin = @liquidswap)]
    #[expected_failure(abort_code = 101)]
    fun test_cannot_mint_if_locked(admin: signer) {
        genesis::setup();

        create_account(&admin);

        liquid::initialize(&admin);

        liquid::lock_minting_internal(&admin);
        // failure here
        liquid::mint_internal(&admin, signer::address_of(&admin), 100);
    }

    #[test(admin = @liquidswap, user = @0x42)]
    #[expected_failure(abort_code = 100)]
    fun test_cannot_mint_if_no_cap(admin: signer, user: signer) {
        genesis::setup();

        create_account(&admin);
        create_account(&user);

        liquid::initialize(&admin);

        liquid::mint_internal(&user, signer::address_of(&user), 100);
    }

    #[test(admin = @liquidswap, user = @0x42)]
    #[expected_failure(abort_code = 100)]
    fun test_cannot_get_mint_cap_if_no_cap(admin: signer, user: signer) {
        genesis::setup();

        create_account(&admin);
        create_account(&user);

        liquid::initialize(&admin);

        let mint_cap = liquid::get_mint_cap(&user);
        move_to(&user, MintCap { mint_cap });
    }

    #[test(admin = @liquidswap, user = @0x43)]
    fun test_anyone_can_acquire_burn_cap(admin: signer, user: signer) {
        genesis::setup();

        create_account(&admin);
        create_account(&user);

        liquid::initialize(&admin);
        coin::register<LAMM>(&user);

        liquid::mint_internal(&admin, signer::address_of(&user), 100);

        let coins = coin::withdraw<LAMM>(&user, 100);
        let burn_cap = liquid::get_burn_cap();
        coin::burn(coins, &burn_cap);

        move_to(&admin, BurnCap { burn_cap });
    }

    #[test(admin = @liquidswap)]
    #[expected_failure(abort_code = 101)]
    fun test_lock_minting_after_6_months_later(admin: signer) {
        genesis::setup();

        create_account(&admin);

        liquid::initialize(&admin);

        timestamp::update_global_time_for_test((timestamp::now_seconds() + (60 * 60 * 24 * 30 * 6)) * 1000000);

        liquid::mint_internal(&admin, signer::address_of(&admin), 100);
    }

    #[test(admin = @liquidswap)]
    #[expected_failure(abort_code = 101)]
    fun test_cannot_get_mint_cap_after_6_months_late(admin: signer) {
        genesis::setup();

        create_account(&admin);

        liquid::initialize(&admin);

        timestamp::update_global_time_for_test((timestamp::now_seconds() + (60 * 60 * 24 * 30 * 6)) * 1000000);
        // failure here, need to store mint_cap somewhere anyway, otherwise it won't compile
        let mint_cap = liquid::get_mint_cap(&admin);
        move_to(&admin, MintCap { mint_cap });
    }
}
