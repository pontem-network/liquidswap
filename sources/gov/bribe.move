module liquidswap::bribe {
    use std::signer;

    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::event;

    friend liquidswap::liquidity_pool;
    friend liquidswap::voter;

    const WEEK: u64 = 604800;

    // Error codes.

    /// When gauge doesn't exists
    const ERR_NOT_REGISTERED: u64 = 401;

    const ERR_INSUFFICIANT_REWARD: u64 = 402;

    struct Bribe<phantom X, phantom Y, phantom LP> has key {
        x_reward: Coin<X>,
        y_reward: Coin<Y>,
        x_reward_rate: u64,
        y_reward_rate: u64,
        period_finish: u64,
    }

    public(friend) fun register<X, Y, LP>(owner: &signer) {
        let bribe = Bribe<X, Y, LP> {
            x_reward: coin::zero(),
            y_reward: coin::zero(),
            x_reward_rate: 0,
            y_reward_rate: 0,
            period_finish: 0,
        };
        move_to(owner, bribe);

        let events_store = EventsStore<X, Y, LP>{
            bribe_created_handle: event::new_event_handle(owner),
            bribe_add_reward_handle: event::new_event_handle(owner),
            bribe_withdraw_reward_handle: event::new_event_handle(owner),
        };
        event::emit_event(
            &mut events_store.bribe_created_handle,
            BribeCreatedEvent<X, Y, LP>{ pool_addr: signer::address_of(owner) }
        );

        move_to(owner, events_store);
    }

    public fun add_reward<X, Y, LP>(pool_addr: address, coin_x: Coin<X>, coin_y: Coin<Y>) acquires Bribe, EventsStore {
        assert!(exists<Bribe<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        let bribe = borrow_global_mut<Bribe<X, Y, LP>>(pool_addr);
        let coin_x_val = coin::value(&coin_x);
        let coin_y_val = coin::value(&coin_y);
        let now = timestamp::now_seconds();
        if (now >= bribe.period_finish) {
            bribe.x_reward_rate = coin_x_val / WEEK;
            bribe.y_reward_rate = coin_y_val / WEEK;
        } else {
            let remaining = bribe.period_finish - now;
            let x_left = remaining * bribe.x_reward_rate;
            let y_left = remaining * bribe.y_reward_rate;
            assert!(coin_x_val > x_left, 1);
            assert!(coin_y_val > y_left, 2);
            bribe.x_reward_rate = (coin_x_val + x_left) / WEEK;
            bribe.y_reward_rate = (coin_y_val + y_left) / WEEK;
        };

        coin::merge(&mut bribe.x_reward, coin_x);
        coin::merge(&mut bribe.y_reward, coin_y);

        assert!(bribe.x_reward_rate <= coin::value(&bribe.x_reward) / WEEK, 3);
        assert!(bribe.y_reward_rate <= coin::value(&bribe.y_reward) / WEEK, 4);
        bribe.period_finish = now + WEEK;

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.bribe_add_reward_handle,
            BribeAddRewardEvent<X, Y, LP>{ pool_addr, coin_x_val, coin_y_val }
        );
    }

    public(friend) fun withdraw_reward<X, Y, LP>(
        pool_addr: address,
        token_votes: u64,
        total_votes: u64
    ): (Coin<X>, Coin<Y>) acquires Bribe, EventsStore {
        assert!(exists<Bribe<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        let bribe = borrow_global_mut<Bribe<X, Y, LP>>(pool_addr);

        let now = timestamp::now_seconds();
        let time = if (now >= bribe.period_finish) { WEEK } else { now + WEEK - bribe.period_finish };
        let x_amount = time * bribe.x_reward_rate * token_votes / total_votes;
        let y_amount = time * bribe.y_reward_rate * token_votes / total_votes;
        assert!(x_amount <= coin::value(&bribe.x_reward), ERR_INSUFFICIANT_REWARD);
        assert!(y_amount <= coin::value(&bribe.y_reward), ERR_INSUFFICIANT_REWARD);
        let coin_x = coin::extract(&mut bribe.x_reward, x_amount);
        let coin_y = coin::extract(&mut bribe.y_reward, y_amount);

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.bribe_withdraw_reward_handle,
            BribeWithdrawRewardEvent<X, Y, LP>{
                pool_addr,
                coin_x_val: coin::value(&coin_x),
                coin_y_val: coin::value(&coin_y),
            }
        );

        (coin_x, coin_y)
    }

    // Events

    struct EventsStore<phantom X, phantom Y, phantom LP> has key {
        bribe_created_handle: event::EventHandle<BribeCreatedEvent<X, Y, LP>>,
        bribe_add_reward_handle: event::EventHandle<BribeAddRewardEvent<X, Y, LP>>,
        bribe_withdraw_reward_handle: event::EventHandle<BribeWithdrawRewardEvent<X, Y, LP>>,
    }

    struct BribeCreatedEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
    }

    struct BribeAddRewardEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_x_val: u64,
        coin_y_val: u64,
    }

    struct BribeWithdrawRewardEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_x_val: u64,
        coin_y_val: u64,
    }
}
