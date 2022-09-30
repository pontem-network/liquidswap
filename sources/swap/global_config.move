/// The global config for liquidswap: fees and manager accounts (admins).
module liquidswap::global_config {
    use std::signer;

    use aptos_std::event::{Self, EventHandle};
    use aptos_framework::account;

    use liquidswap::curves;

    friend liquidswap::liquidity_pool;

    // Error codes.

    /// When config doesn't exists.
    const ERR_CONFIG_DOES_NOT_EXIST: u64 = 300;

    /// When user is not admin
    const ERR_NOT_ADMIN: u64 = 301;

    /// When invalid fee amount
    const ERR_INVALID_FEE: u64 = 302;

    /// Unreachable, is a bug if thrown
    const ERR_UNREACHABLE: u64 = 303;

    // Constants.

    /// Minimum value of fee, 0.01%
    const MIN_FEE: u64 = 1;

    /// Maximum value of fee, 1%
    const MAX_FEE: u64 = 100;

    /// Minimum value of dao fee, 0%
    const MIN_DAO_FEE: u64 = 0;

    /// Maximum value of dao fee, 100%
    const MAX_DAO_FEE: u64 = 100;

    /// The global configuration (fees and admin accounts).
    struct GlobalConfig has key {
        dao_admin_address: address,
        emergency_admin_address: address,
        fee_admin_address: address,
        default_uncorrelated_fee: u64,
        default_stable_fee: u64,
        default_dao_fee: u64,
    }

    /// Event store for configuration module.
    struct EventsStore has key {
        default_uncorrelated_fee_handle: EventHandle<UpdateDefaultFeeEvent>,
        default_stable_fee_handle: EventHandle<UpdateDefaultFeeEvent>,
        default_dao_fee_handle: EventHandle<UpdateDefaultFeeEvent>,
    }

    /// Initializes admin contracts when initializing the liquidity pool.
    public(friend) fun initialize(liquidswap_admin: &signer) {
        assert!(signer::address_of(liquidswap_admin) == @liquidswap, ERR_UNREACHABLE);

        move_to(liquidswap_admin, GlobalConfig {
            dao_admin_address: @dao_admin,
            emergency_admin_address: @emergency_admin,
            fee_admin_address: @fee_admin,
            default_uncorrelated_fee: 30,   // 0.3%
            default_stable_fee: 4,          // 0.04%
            default_dao_fee: 33,            // 33%
        });
        move_to(
            liquidswap_admin,
            EventsStore {
                default_uncorrelated_fee_handle: account::new_event_handle(liquidswap_admin),
                default_stable_fee_handle: account::new_event_handle(liquidswap_admin),
                default_dao_fee_handle: account::new_event_handle(liquidswap_admin),
            }
        )
    }

    /// Get DAO admin address.
    public fun get_dao_admin(): address acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global<GlobalConfig>(@liquidswap);
        config.dao_admin_address
    }

    /// Set DAO admin account.
    public entry fun set_dao_admin(dao_admin: &signer, new_addr: address) acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global_mut<GlobalConfig>(@liquidswap);
        assert!(config.dao_admin_address == signer::address_of(dao_admin), ERR_NOT_ADMIN);

        config.dao_admin_address = new_addr;
    }

    /// Get emergency admin address.
    public fun get_emergency_admin(): address acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global<GlobalConfig>(@liquidswap);
        config.emergency_admin_address
    }

    /// Set emergency admin account.
    public entry fun set_emergency_admin(emergency_admin: &signer, new_addr: address) acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global_mut<GlobalConfig>(@liquidswap);
        assert!(config.emergency_admin_address == signer::address_of(emergency_admin), ERR_NOT_ADMIN);

        config.emergency_admin_address = new_addr;
    }

    /// Get fee admin address.
    public fun get_fee_admin(): address acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global<GlobalConfig>(@liquidswap);
        config.fee_admin_address
    }

    /// Set fee admin account.
    public entry fun set_fee_admin(fee_admin: &signer, new_addr: address) acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global_mut<GlobalConfig>(@liquidswap);
        assert!(config.fee_admin_address == signer::address_of(fee_admin), ERR_NOT_ADMIN);

        config.fee_admin_address = new_addr;
    }

    /// Get default fee for pool.
    /// IMPORTANT: use functions in Liquidity Pool module as pool fees could be different from default ones.
    public fun get_default_fee<Curve>(): u64 acquires GlobalConfig {
        curves::assert_valid_curve<Curve>();
        assert!(exists<GlobalConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global<GlobalConfig>(@liquidswap);
        if (curves::is_stable<Curve>()) {
            config.default_stable_fee
        } else if (curves::is_uncorrelated<Curve>()) {
            config.default_uncorrelated_fee
        } else {
            abort ERR_UNREACHABLE
        }
    }

    /// Set new default fee.
    public entry fun set_default_fee<Curve>(fee_admin: &signer, default_fee: u64) acquires GlobalConfig, EventsStore {
        curves::assert_valid_curve<Curve>();
        assert!(exists<GlobalConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global_mut<GlobalConfig>(@liquidswap);
        assert!(config.fee_admin_address == signer::address_of(fee_admin), ERR_NOT_ADMIN);

        assert_valid_fee(default_fee);

        let events_store = borrow_global_mut<EventsStore>(@liquidswap);
        if (curves::is_stable<Curve>()) {
            config.default_stable_fee = default_fee;
            event::emit_event(
                &mut events_store.default_stable_fee_handle,
                UpdateDefaultFeeEvent { fee: default_fee }
            );
        } else if (curves::is_uncorrelated<Curve>()) {
            config.default_uncorrelated_fee = default_fee;
            event::emit_event(
                &mut events_store.default_uncorrelated_fee_handle,
                UpdateDefaultFeeEvent { fee: default_fee }
            );
        } else {
            abort ERR_UNREACHABLE
        };
    }

    /// Get default DAO fee.
    public fun get_default_dao_fee(): u64 acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global<GlobalConfig>(@liquidswap);
        config.default_dao_fee
    }

    /// Set default DAO fee.
    public entry fun set_default_dao_fee(fee_admin: &signer, default_fee: u64) acquires GlobalConfig, EventsStore {
        assert!(exists<GlobalConfig>(@liquidswap), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global_mut<GlobalConfig>(@liquidswap);
        assert!(config.fee_admin_address == signer::address_of(fee_admin), ERR_NOT_ADMIN);

        assert_valid_dao_fee(default_fee);

        config.default_dao_fee = default_fee;

        let event_store = borrow_global_mut<EventsStore>(@liquidswap);
        event::emit_event(
            &mut event_store.default_dao_fee_handle,
            UpdateDefaultFeeEvent { fee: default_fee }
        );
    }

    /// Aborts if fee is valid.
    public fun assert_valid_fee(fee: u64) {
        assert!(MIN_FEE <= fee && fee <= MAX_FEE, ERR_INVALID_FEE);
    }

    /// Aborts if dao fee is valid.
    public fun assert_valid_dao_fee(dao_fee: u64) {
        assert!(MIN_DAO_FEE <= dao_fee && dao_fee <= MAX_DAO_FEE, ERR_INVALID_FEE);
    }

    /// Event struct when fee updates.
    struct UpdateDefaultFeeEvent has drop, store {
        fee: u64,
    }

    #[test_only]
    public fun initialize_for_test() {
        let liquidswap_admin = aptos_framework::account::create_account_for_test(@liquidswap);
        initialize(&liquidswap_admin);
    }
}
