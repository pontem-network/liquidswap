/// The module allows for emergency stop Liquidswap operations.
module liquidswap::emergency {
    use std::signer;
    use liquidswap::global_config;

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

    struct EmergencyConfig has key {
        is_emergency: bool,
        is_disabled: bool
    }

    public(friend) fun initialize(liquidswap_admin: &signer) {
        assert!(signer::address_of(liquidswap_admin) == @liquidswap, ERR_UNREACHABLE);
        move_to(liquidswap_admin, EmergencyConfig {
            is_emergency: false,
            is_disabled: false
        })
    }

    /// Pauses all operations.
    public entry fun pause(account: &signer) acquires EmergencyConfig {
        assert!(!is_disabled(), ERR_DISABLED);
        assert_no_emergency();

        assert!(signer::address_of(account) == global_config::get_emergency_admin(), ERR_NO_PERMISSIONS);

        let emergency_config = borrow_global_mut<EmergencyConfig>(@liquidswap);
        emergency_config.is_emergency = true;
    }

    /// Resumes all operations.
    public entry fun resume(account: &signer) acquires EmergencyConfig {
        assert!(!is_disabled(), ERR_DISABLED);

        let account_addr = signer::address_of(account);
        assert!(account_addr == global_config::get_emergency_admin(), ERR_NO_PERMISSIONS);
        assert!(is_emergency(), ERR_NOT_EMERGENCY);

        let emergency_config = borrow_global_mut<EmergencyConfig>(@liquidswap);
        emergency_config.is_emergency = false;
    }

    /// Get if it's paused or not.
    public fun is_emergency(): bool acquires EmergencyConfig {
        let emergency_config = borrow_global<EmergencyConfig>(@liquidswap);
        emergency_config.is_emergency
    }

    /// Would abort if currently paused.
    public fun assert_no_emergency() acquires EmergencyConfig {
        assert!(!is_emergency(), ERR_EMERGENCY);
    }

    /// Get if it's disabled or not.
    public fun is_disabled(): bool acquires EmergencyConfig {
        let emergency_config = borrow_global<EmergencyConfig>(@liquidswap);
        emergency_config.is_disabled
    }

    /// Disable condition forever.
    public entry fun disable_forever(account: &signer) acquires EmergencyConfig {
        assert!(!is_disabled(), ERR_DISABLED);
        assert!(signer::address_of(account) == global_config::get_emergency_admin(), ERR_NO_PERMISSIONS);

        let emergency_config = borrow_global_mut<EmergencyConfig>(@liquidswap);
        emergency_config.is_disabled = true;
    }
}
