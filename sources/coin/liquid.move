module liquidswap::liquid {
    use std::string;
    use std::signer;

    use aptos_framework::coin::{Self, MintCapability, BurnCapability, Coin};
    use aptos_framework::timestamp;

    // Erorrs.

    /// When capability doesn't exists on account.
    const ERR_CAPABILITIES_DOESNT_EXIST: u64 = 100;

    /// When minting locked but trying to mint.
    const ERR_MINTING_LOCKED: u64 = 101;

    // Constants.

    /// In 6 months we stop direct minting and issuing of mint capabilities automatically.
    /// Yet contracts who has mint capability can continue minting.
    const LOCK_MINT_AFTER_SECONDS: u64 = 15552000; // 6 months

    /// The Liquidswap coin.
    struct LAMM {}

    /// Capabilities stored under admin account and also we determine if minting locked with `lock_mint_cap`
    /// and `lock_mint_time`.
    struct Capabilities has key {
        mint_cap: MintCapability<LAMM>,
        burn_cap: BurnCapability<LAMM>,
        // If new mints and creation of new mint capabilities locked in this contract.
        lock_mint_cap: bool,
        // Time when minting automatically will be locked in this function if admin doesn't make a call.
        lock_mint_time: u64,
    }

    /// Initialize LAMM coin.
    /// Use `@liquidswap` admin account to do it.
    public fun initialize(admin: &signer) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<LAMM>(
            admin,
            string::utf8(b"Liquid"),
            string::utf8(b"LAMM"),
            6,
            true
        );

        coin::destroy_freeze_cap(freeze_cap);

        move_to(admin, Capabilities {
            mint_cap,
            burn_cap,
            lock_mint_cap: false,
            lock_mint_time: timestamp::now_seconds() + LOCK_MINT_AFTER_SECONDS
        });
    }

    /// Lock minting public entry point.
    public entry fun lock_minting(admin: &signer) acquires Capabilities {
        lock_minting_internal(admin);
    }

    /// Lock minting using admin account.
    public fun lock_minting_internal(admin: &signer) acquires Capabilities {
        let admin_addr = signer::address_of(admin);
        assert!(exists<Capabilities>(admin_addr), ERR_CAPABILITIES_DOESNT_EXIST);

        let caps = borrow_global_mut<Capabilities>(admin_addr);
        caps.lock_mint_cap = true;
    }

    /// Get new mint capability for LAMM minting using admin account.
    public fun get_mint_cap(admin: &signer): MintCapability<LAMM> acquires Capabilities {
        let admin_addr = signer::address_of(admin);
        assert!(exists<Capabilities>(admin_addr), ERR_CAPABILITIES_DOESNT_EXIST);

        let caps = borrow_global<Capabilities>(admin_addr);
        assert!(!caps.lock_mint_cap && timestamp::now_seconds() < caps.lock_mint_time, ERR_MINTING_LOCKED);

        *&caps.mint_cap
    }

    /// Public entry to mint new coins for user using admin account.
    /// * `addr` - recipient address.
    /// * `amount` - amount of LAMM coins to mint.
    public entry fun mint(admin: &signer, addr: address, amount: u64) acquires Capabilities {
        mint_internal(admin, addr, amount);
    }

    /// Same like `mint` but for public functions usage (not entries).
    /// * `addr` - recipient address.
    /// * `amount` - amount of LAMM coins to mint.
    public fun mint_internal(admin: &signer, addr: address, amount: u64) acquires Capabilities {
        let admin_addr = signer::address_of(admin);
        assert!(exists<Capabilities>(admin_addr), ERR_CAPABILITIES_DOESNT_EXIST);

        let caps = borrow_global<Capabilities>(admin_addr);
        assert!(!caps.lock_mint_cap && timestamp::now_seconds() < caps.lock_mint_time, ERR_MINTING_LOCKED);

        let coins = coin::mint(amount, &caps.mint_cap);
        coin::deposit(addr, coins);
    }

    /// Get burn capability for LAMM coin.
    public fun get_burn_cap(): BurnCapability<LAMM> acquires Capabilities {
        assert!(exists<Capabilities>(@liquidswap), ERR_CAPABILITIES_DOESNT_EXIST);

        let caps = borrow_global<Capabilities>(@liquidswap);
        *&caps.burn_cap
    }

    /// Entry function in case `account` wants to burn LAMM coins.
    /// * `amount` - amount of LAMM to withdraw from account and burn.
    public entry fun burn(account: &signer, amount: u64) acquires Capabilities {
        let to_burn = coin::withdraw<LAMM>(account, amount);

        burn_internal(to_burn);
    }

    /// Burn LAMM coins.
    /// * `coins` - LAMM coins to burn.
    public fun burn_internal(coins: Coin<LAMM>) acquires Capabilities {
        assert!(exists<Capabilities>(@liquidswap), ERR_CAPABILITIES_DOESNT_EXIST);
        let caps = borrow_global<Capabilities>(@liquidswap);
        coin::burn(coins, &caps.burn_cap);
    }
}
