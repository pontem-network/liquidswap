/// The module allows for emergency stop Liquidswap operations.
module liquidswap::emergency {
    use std::signer;

    // Error codes.

    /// When the wrong account attempted to create an emergency resource.
    const ERR_NO_PERMISSIONS: u64 = 4000;

    /// When attempted to execute operation during an emergency.
    const ERR_EMERGENCY: u64 = 4001;

    /// When emergency functional disabled.
    const ERR_DISABLED: u64 = 4002;

    /// When attempted to resume, but we are not in an emergency state.
    const ERR_NOT_EMERGENCY: u64 = 4003;

    /// The resource stored under account means we are in an emergency.
    struct Emergency has key {}

    /// The resource stored under the account means we disabled pause/resume and stay in the current condition forever..
    struct Disabled has key {}

    /// Pauses all operations.
    public entry fun pause(account: &signer) {
        assert!(!is_disabled(), ERR_DISABLED);
        assert_no_emergency();

        assert!(signer::address_of(account) == @emergency_admin, ERR_NO_PERMISSIONS);

        move_to(account, Emergency {});
    }

    /// Resumes all operations.
    public entry fun resume(account: &signer) acquires Emergency {
        assert!(!is_disabled(), ERR_DISABLED);

        let account_addr = signer::address_of(account);
        assert!(account_addr == @emergency_admin, ERR_NO_PERMISSIONS);
        assert!(is_emergency(), ERR_NOT_EMERGENCY);

        let Emergency {} = move_from<Emergency>(account_addr);
    }

    /// Get if it's paused or not.
    public fun is_emergency(): bool {
        exists<Emergency>(@emergency_admin)
    }

    /// Would abort if currently paused.
    public fun assert_no_emergency() {
        assert!(!is_emergency(), ERR_EMERGENCY);
    }

    /// Get if it's disabled or not.
    public fun is_disabled(): bool {
        exists<Disabled>(@emergency_admin)
    }

    /// Disable condition forever.
    public entry fun disable_forever(account: &signer) {
        assert!(!is_disabled(), ERR_DISABLED);
        assert!(signer::address_of(account) == @emergency_admin, ERR_NO_PERMISSIONS);

        move_to(account, Disabled {});
    }
}
