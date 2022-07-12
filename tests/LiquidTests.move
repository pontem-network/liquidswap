#[test_only]
module MultiSwap::LiquidTests {
    use Std::Option;
    use Std::Signer;

    use AptosFramework::Coin::{Self, MintCapability, BurnCapability};
    use AptosFramework::Genesis;

    use MultiSwap::Liquid::{Self, LAMM};

    struct MintCap has key { mint_cap: MintCapability<LAMM> }

    struct BurnCap has key { burn_cap: BurnCapability<LAMM> }

    #[test(core_resource = @CoreResources, admin = @MultiSwap, user = @0x43)]
    #[expected_failure(abort_code = 101)]
    fun test_mint_burn_with_functions(core_resource: signer, admin: signer, user: signer) {
        Genesis::setup(&core_resource);
        Liquid::initialize(&admin);
        Coin::register_internal<LAMM>(&user);

        let user_addr = Signer::address_of(&user);
        Liquid::mint(&admin, user_addr, 100);
        assert!(Coin::balance<LAMM>(user_addr) == 100, 1);

        let lamm_coins = Coin::withdraw<LAMM>(&user, 50);
        Liquid::burn(&admin, lamm_coins);
        assert!(Coin::supply<LAMM>() == Option::some(50), 2);

        Liquid::lock_minting(&admin);
        Liquid::mint(&admin, user_addr, 100);
    }

    #[test(core_resource = @CoreResources, admin = @MultiSwap)]
    #[expected_failure(abort_code = 101)]
    fun test_mint_burn_with_caps(core_resource: signer, admin: signer) {
        Genesis::setup(&core_resource);
        Liquid::initialize(&admin);

        let mint_cap = Liquid::get_mint_cap(&admin);
        let lamm_coins = Coin::mint(100, &mint_cap);

        let burn_cap = Liquid::get_burn_cap();
        Coin::burn(lamm_coins, &burn_cap);

        move_to(&admin, MintCap { mint_cap });
        Coin::destroy_burn_cap(burn_cap);

        Liquid::lock_minting(&admin);
        let mint_cap = Liquid::get_mint_cap(&admin);
        move_to(&admin, MintCap { mint_cap });
    }

    #[test(core_resource = @CoreResources, admin = @MultiSwap, user = @0x42)]
    #[expected_failure(abort_code = 100)]
    fun test_cannot_mint_if_no_cap(core_resource: signer, admin: signer, user: signer) {
        Genesis::setup(&core_resource);
        Liquid::initialize(&admin);

        Liquid::mint(&user, Signer::address_of(&user), 100);
    }

    #[test(core_resource = @CoreResources, admin = @MultiSwap, user = @0x43)]
    fun test_anyone_can_acquire_burn_cap(core_resource: signer, admin: signer, user: signer) {
        Genesis::setup(&core_resource);
        Liquid::initialize(&admin);
        Coin::register_internal<LAMM>(&user);

        Liquid::mint(&admin, Signer::address_of(&user), 100);

        let coins = Coin::withdraw<LAMM>(&user, 100);
        let burn_cap = Liquid::get_burn_cap();
        Coin::burn(coins, &burn_cap);

        move_to(&admin, BurnCap { burn_cap });
    }
}
