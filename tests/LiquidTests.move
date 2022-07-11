#[test_only]
module MultiSwap::LiquidTests {
    use AptosFramework::Coin::{Self, MintCapability};
    use AptosFramework::Genesis;

    use MultiSwap::Liquid::{Self, LAMM};
    use Std::Signer;
    use Std::Option;

    struct Caps has key { mint_cap: MintCapability<LAMM> }

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

        let burn_cap = Liquid::get_burn_cap(&admin);
        Coin::burn(lamm_coins, &burn_cap);

        move_to(&admin, Caps { mint_cap });
        Coin::destroy_burn_cap(burn_cap);

        Liquid::lock_minting(&admin);
        let mint_cap = Liquid::get_mint_cap(&admin);
        move_to(&admin, Caps { mint_cap });
    }
}
