module MultiSwap::Liquid {
    use Std::ASCII;
    use Std::Signer;

    use AptosFramework::Coin::{Self, MintCapability, BurnCapability, Coin};
    use AptosFramework::Timestamp;

    // TODO: convert errors to Std::Errors.
    const ERR_CAPABILITIES_DOESNT_EXIST: u64 = 100;
    const ERR_MINTING_LOCKED: u64 = 101;

    const LOCK_MINT_AFTER_SECONDS: u64 = 60 * 60 * 24 * 30 * 6; // 6 months

    struct LAMM {}

    struct Capabilities has key {
        mint_cap: MintCapability<LAMM>,
        burn_cap: BurnCapability<LAMM>,
        lock_mint_cap: bool,
        lock_mint_time: u64,
    }

    public fun initialize(admin: &signer) {
        let (mint_cap, burn_cap) = Coin::initialize<LAMM>(
            admin,
            ASCII::string(b"Liquid"),
            ASCII::string(b"LAMM"),
            6,
            true
        );

        move_to(admin, Capabilities {
            mint_cap,
            burn_cap,
            lock_mint_cap: false,
            lock_mint_time: Timestamp::now_seconds() + LOCK_MINT_AFTER_SECONDS
        });
    }

    public(script) fun lock_minting(admin: &signer) acquires Capabilities {
        lock_minting_internal(admin);
    }

    public fun lock_minting_internal(admin: &signer) acquires Capabilities {
        let admin_addr = Signer::address_of(admin);
        assert!(exists<Capabilities>(admin_addr), ERR_CAPABILITIES_DOESNT_EXIST);

        let caps = borrow_global_mut<Capabilities>(admin_addr);
        caps.lock_mint_cap = true;
    }

    public fun get_mint_cap(admin: &signer): MintCapability<LAMM> acquires Capabilities {
        let admin_addr = Signer::address_of(admin);
        assert!(exists<Capabilities>(admin_addr), ERR_CAPABILITIES_DOESNT_EXIST);

        let caps = borrow_global<Capabilities>(admin_addr);
        assert!(!caps.lock_mint_cap, ERR_MINTING_LOCKED);

        *&caps.mint_cap
    }

    public fun get_burn_cap(): BurnCapability<LAMM> acquires Capabilities {
        assert!(exists<Capabilities>(@MultiSwap), ERR_CAPABILITIES_DOESNT_EXIST);

        let caps = borrow_global<Capabilities>(@MultiSwap);
        *&caps.burn_cap
    }

    public(script) fun mint(admin: &signer, addr: address, amount: u64) acquires Capabilities {
        mint_internal(admin, addr, amount);
    }

    public fun mint_internal(admin: &signer, addr: address, amount: u64) acquires Capabilities {
        let admin_addr = Signer::address_of(admin);
        assert!(exists<Capabilities>(admin_addr), ERR_CAPABILITIES_DOESNT_EXIST);

        let caps = borrow_global<Capabilities>(admin_addr);
        assert!(!caps.lock_mint_cap && Timestamp::now_seconds() < caps.lock_mint_time, ERR_MINTING_LOCKED);

        let coins = Coin::mint(amount, &caps.mint_cap);
        Coin::deposit(addr, coins);
    }

    public(script) fun burn(admin: &signer, coins: Coin<LAMM>) acquires Capabilities {
        burn_internal(admin, coins);
    }

    public fun burn_internal(admin: &signer, coins: Coin<LAMM>) acquires Capabilities {
        let admin_addr = Signer::address_of(admin);
        let caps = borrow_global<Capabilities>(admin_addr);
        Coin::burn(coins, &caps.burn_cap);
    }
}
