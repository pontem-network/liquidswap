module liquidswap::dao_storage {
    use std::signer;

    use aptos_std::event;

    use aptos_framework::coin::{Self, Coin};

    friend liquidswap::liquidity_pool;

    // Error codes.

    /// When storage doesn't exists
    const ERR_NOT_REGISTERED: u64 = 401;

    /// When invalid DAO admin account
    const ERR_NOT_ADMIN_ACCOUNT: u64 = 402;

    // Public functions.

    /// Storage for keeping coins
    struct Storage<phantom X, phantom Y, phantom LP> has key {
        coin_x: Coin<X>,
        coin_y: Coin<Y>
    }

    /// Register storage
    /// Parameters:
    /// * `owner` - owner of storage
    public(friend) fun register<X, Y, LP>(owner: &signer) {
        let storage = Storage<X, Y, LP>{ coin_x: coin::zero<X>(), coin_y: coin::zero<Y>() };
        move_to(owner, storage);

        let events_store = EventsStore<X, Y, LP>{
            storage_registered_handle: event::new_event_handle(owner),
            coin_deposited_handle: event::new_event_handle(owner),
            coin_withdrawn_handle: event::new_event_handle(owner)
        };
        event::emit_event(
            &mut events_store.storage_registered_handle,
            StorageCreatedEvent<X, Y, LP>{}
        );

        move_to(owner, events_store);
    }

    /// Deposit coins to storage from liquidity pool
    /// Parameters:
    /// * `pool_addr` - pool owner address
    /// * `coin_x` - X coin to deposit
    /// * `coin_y` - Y coin to deposit
    public(friend) fun deposit<X, Y, LP>(pool_addr: address, coin_x: Coin<X>, coin_y: Coin<Y>) acquires Storage, EventsStore {
        assert!(exists<Storage<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        let x_val = coin::value(&coin_x);
        let y_val = coin::value(&coin_y);
        let storage = borrow_global_mut<Storage<X, Y, LP>>(pool_addr);
        coin::merge(&mut storage.coin_x, coin_x);
        coin::merge(&mut storage.coin_y, coin_y);

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.coin_deposited_handle,
            CoinDepositedEvent<X, Y, LP>{ x_val, y_val }
        );
    }

    /// Withdraw coins from storage
    /// Parameters:
    /// * `dao_admin_acc` - DAO admin
    /// * `pool_addr` - pool owner address
    /// * `x_val` - amount of X coins to withdraw
    /// * `y_val` - amount of Y coins to withdraw
    /// Returns both withdrawn X and Y coins: `(Coin<X>, Coin<Y>)`.
    public fun withdraw<X, Y, LP>(dao_admin_acc: &signer, pool_addr: address, x_val: u64, y_val: u64): (Coin<X>, Coin<Y>)
    acquires Storage, EventsStore {
        assert!(signer::address_of(dao_admin_acc) == @dao_admin, ERR_NOT_ADMIN_ACCOUNT);

        let storage = borrow_global_mut<Storage<X, Y, LP>>(pool_addr);
        let coin_x = coin::extract(&mut storage.coin_x, x_val);
        let coin_y = coin::extract(&mut storage.coin_y, y_val);

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.coin_deposited_handle,
            CoinDepositedEvent<X, Y, LP>{ x_val, y_val }
        );

        (coin_x, coin_y)
    }

    #[test_only]
    public fun get_storage_size<X, Y, LP>(pool_addr: address): (u64, u64) acquires Storage {
        let storage = borrow_global<Storage<X, Y, LP>>(pool_addr);
        let x_val = coin::value(&storage.coin_x);
        let y_val = coin::value(&storage.coin_y);
        (x_val, y_val)
    }

    #[test_only]
    public fun register_for_test<X, Y, LP>(owner: &signer) {
        register<X, Y, LP>(owner);
    }

    #[test_only]
    public fun deposit_for_test<X, Y, LP>(
        pool_addr: address,
        coin_x: Coin<X>,
        coin_y: Coin<Y>
    ) acquires Storage, EventsStore {
        deposit<X, Y, LP>(pool_addr, coin_x, coin_y);
    }

    // Events

    struct EventsStore<phantom X, phantom Y, phantom LP> has key {
        storage_registered_handle: event::EventHandle<StorageCreatedEvent<X, Y, LP>>,
        coin_deposited_handle: event::EventHandle<CoinDepositedEvent<X, Y, LP>>,
        coin_withdrawn_handle: event::EventHandle<CoinWithdrawnEvent<X, Y, LP>>,
    }

    struct StorageCreatedEvent<phantom X, phantom Y, phantom LP> has store, drop {}

    struct CoinDepositedEvent<phantom X, phantom Y, phantom LP> has store, drop {
        x_val: u64,
        y_val: u64,
    }

    struct CoinWithdrawnEvent<phantom X, phantom Y, phantom LP> has store, drop {
        x_val: u64,
        y_val: u64,
    }
}
