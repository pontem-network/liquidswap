module liquidswap::admins {
    use std::signer;

    friend liquidswap::liquidity_pool;

    // Error codes.

    /// When config doesn't exists.
    const ERR_CONFIG_DOES_NOT_EXIST: u64 = 300;

    /// When user is not admin
    const ERR_NOT_ADMIN: u64 = 301;

    struct AdminConfig has key {
        dao_admin_address: address,
        emergency_admin_address: address,
    }

    /// Initializes admin contracts when initializing the liquidity pool.
    public(friend) fun initialize(liquidswap_admin: &signer) {
        move_to(liquidswap_admin, AdminConfig {
            dao_admin_address: @dao_admin,
            emergency_admin_address: @emergency_admin
        });
    }

    public fun get_dao_admin(): address acquires AdminConfig {
        assert!(exists<AdminConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);
        let config = borrow_global<AdminConfig>(@liquidswap);
        config.dao_admin_address
    }

    public entry fun set_dao_admin(dao_admin: &signer, new_addr: address) acquires AdminConfig {
        assert!(exists<AdminConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);
        let config = borrow_global_mut<AdminConfig>(@liquidswap);
        assert!(config.dao_admin_address == signer::address_of(dao_admin), ERR_NOT_ADMIN);
        config.dao_admin_address = new_addr;
    }

    public fun get_emergency_admin(): address acquires AdminConfig {
        assert!(exists<AdminConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);
        let config = borrow_global<AdminConfig>(@liquidswap);
        config.emergency_admin_address
    }

    public entry fun set_emergency_admin(emergency_admin: &signer, new_addr: address) acquires AdminConfig {
        assert!(exists<AdminConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);
        let config = borrow_global_mut<AdminConfig>(@liquidswap);
        assert!(config.emergency_admin_address == signer::address_of(emergency_admin), ERR_NOT_ADMIN);
        config.emergency_admin_address = new_addr;
    }

    #[test_only]
    public fun initialize_for_test() {
        let liquidswap_admin = aptos_framework::account::create_account_for_test(@liquidswap);
        initialize(&liquidswap_admin);
    }
}
