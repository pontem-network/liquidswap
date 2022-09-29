/// The module allows for emergency stop Liquidswap operations.
module liquidswap::emergency {
    use std::signer;
    use liquidswap::global_config;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::account;

    friend liquidswap::liquidity_pool;

    // Error codes.
    /// When the wrong account attempted to create an emergency resource.
    const ERR_NO_PERMISSIONS: u64 = 4000;

    /// When attempted to execute operation during an emergency.
    const ERR_EMERGENCY: u64 = 4001;

    /// When emergency functional disabled.
    const ERR_DISABLED: u64 = 4002;

    /// When attempted to resume, but we are not in an emergency state.
    const ERR_NOT_EMERGENCY: u64 = 4003;

    /// Should never occur.
    const ERR_UNREACHABLE: u64 = 4004;

    struct IsEmergency has key {}

    struct IsDisabled has key {}

    struct EmergencyAccountCapability has key {
        signer_cap: SignerCapability
    }

    public(friend) fun initialize(liquidswap_admin: &signer) {
        assert!(signer::address_of(liquidswap_admin) == @liquidswap, ERR_UNREACHABLE);

        let (_, signer_cap) =
            account::create_resource_account(liquidswap_admin, b"emergency_account_seed");
        move_to(liquidswap_admin, EmergencyAccountCapability { signer_cap });
    }

    /// Pauses all operations.
    public entry fun pause(account: &signer) acquires EmergencyAccountCapability {
        assert!(!is_disabled(), ERR_DISABLED);
        assert_no_emergency();

        assert!(signer::address_of(account) == global_config::get_emergency_admin(), ERR_NO_PERMISSIONS);

        let emergency_account_cap =
            borrow_global<EmergencyAccountCapability>(@liquidswap);
        let emergency_account = account::create_signer_with_capability(&emergency_account_cap.signer_cap);
        move_to(&emergency_account, IsEmergency {});
    }

    /// Resumes all operations.
    public entry fun resume(account: &signer) acquires IsEmergency {
        assert!(!is_disabled(), ERR_DISABLED);

        let account_addr = signer::address_of(account);
        assert!(account_addr == global_config::get_emergency_admin(), ERR_NO_PERMISSIONS);
        assert!(is_emergency(), ERR_NOT_EMERGENCY);

        let IsEmergency {} = move_from<IsEmergency>(@liquidswap_emergency_account);
    }

    /// Get if it's paused or not.
    public fun is_emergency(): bool {
        exists<IsEmergency>(@liquidswap_emergency_account)
    }

    /// Would abort if currently paused.
    public fun assert_no_emergency() {
        assert!(!is_emergency(), ERR_EMERGENCY);
    }

    /// Get if it's disabled or not.
    public fun is_disabled(): bool {
        exists<IsDisabled>(@liquidswap_emergency_account)
    }

    /// Disable condition forever.
    public entry fun disable_forever(account: &signer) acquires EmergencyAccountCapability {
        assert!(!is_disabled(), ERR_DISABLED);
        assert!(signer::address_of(account) == global_config::get_emergency_admin(), ERR_NO_PERMISSIONS);

        let emergency_account_cap =
            borrow_global<EmergencyAccountCapability>(@liquidswap);
        let emergency_account = account::create_signer_with_capability(&emergency_account_cap.signer_cap);
        move_to(&emergency_account, IsDisabled {});
    }
}
