/// The module allows for emergency stop Liquidswap operations.
module liquidswap::emergency {
    use std::signer;

    // Error codes.

    /// When the wrong account attempted to create an emergency resource.
    const ERR_WRONG_ADDR: u64 = 4000;

    /// When operations stopped already.
    const ERR_ALREADY_STOPPED: u64 = 4001;

    /// When attempted to execute operation during an emergency.
    const ERR_EMERGENCY: u64 = 4002;

    /// When emergency functional disabled.
    const ERR_DISABLED: u64 = 4003;

    /// The resource stored under account means we are in an emergency.
    struct Emergency has key {}

    /// The resource stored under the account means we disabled pause/resume and stay in the current condition forever..
    struct Disabled has key {}

    /// Pauses all operations.
    public entry fun pause(account: &signer) {
        let account_addr = signer::address_of(account);
        assert!(account_addr == @emergency, ERR_WRONG_ADDR);
        assert!(!is_disabled(), ERR_DISABLED);

        assert!(!exists<Emergency>(account_addr), ERR_ALREADY_STOPPED);

        move_to(account, Emergency {});
    }

    /// Resumes all operations.
    public entry fun resume(account: &signer) acquires Emergency {
        let account_addr = signer::address_of(account);
        assert!(!is_disabled(), ERR_DISABLED);

        assert!(exists<Emergency>(account_addr), ERR_WRONG_ADDR);

        let Emergency {} = move_from<Emergency>(account_addr);
    }

    /// Get if it's paused or not.
    public fun is_emergency(): bool {
        exists<Emergency>(@emergency)
    }

    /// Would abort if currently paused.
    public fun assert_emergency() {
        assert!(!exists<Emergency>(@emergency), ERR_EMERGENCY);
    }

    /// Get if it's disabled or not.
    public fun is_disabled(): bool {
        exists<Disabled>(@emergency)
    }

    /// Disable condition forever.
    public entry fun disable_forever(account: &signer) {
        let account_addr = signer::address_of(account);

        assert!(account_addr == @emergency, ERR_WRONG_ADDR);
        assert!(!is_disabled(), ERR_DISABLED);

        move_to(account, Disabled {});
    }
}
