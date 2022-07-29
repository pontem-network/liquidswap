module liquidswap::dao_storage {
    use std::signer;

    use aptos_std::event;

    use aptos_framework::coin::{Self, Coin};

    friend liquidswap::liquidity_pool;

    const ERR_NOT_REGISTERED: u64 = 101;
    const ERR_NOT_ADMIN_ACCOUNT: u64 = 102;

    struct Storage<phantom X, phantom Y, phantom LP> has key {
        coin_x: Coin<X>,
        coin_y: Coin<Y>
    }

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
