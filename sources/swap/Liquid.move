module MultiSwap::Liquid {
    use Std::ASCII;

    use AptosFramework::Coin;
    use AptosFramework::Coin::{MintCapability, BurnCapability, Coin};
    use Std::Signer;

    struct LAMM {}

    struct Capabilities has key {
        mint_cap: MintCapability<LAMM>,
        burn_cap: BurnCapability<LAMM>,
    }

    public(script) fun initialize(admin: &signer) {
        let (mint_cap, burn_cap) = Coin::initialize<LAMM>(
            admin,
            ASCII::string(b"LAMM"),
            ASCII::string(b"LAMM"),
            6,
            true
        );
        move_to(admin, Capabilities { mint_cap, burn_cap });
    }

    public(script) fun mint(admin: &signer, addr: address, amount: u64) acquires Capabilities {
        let admin_addr = Signer::address_of(admin);
        let caps = borrow_global<Capabilities>(admin_addr);
        let coins = Coin::mint(amount, &caps.mint_cap);
        Coin::deposit(addr, coins);
    }

    public fun burn(admin: &signer, coins: Coin<LAMM>) acquires Capabilities {
        let admin_addr = Signer::address_of(admin);
        let caps = borrow_global<Capabilities>(admin_addr);
        Coin::burn(coins, &caps.burn_cap);
    }
}
