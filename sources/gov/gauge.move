module liquidswap::gauge {
    use std::signer;

    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::event;

    use liquidswap::liquid::LAMM;

    friend liquidswap::liquidity_pool;
    friend liquidswap::voter;

    const WEEK: u64 = 604800;

    // Error codes.

    /// When gauge doesn't exists
    const ERR_NOT_REGISTERED: u64 = 401;

    const ERR_INSUFFICIANT_REWARD: u64 = 402;

    struct Gauge<phantom X, phantom Y, phantom LP> has key {
        reward: Coin<LAMM>,
        reward_rate: u64,
        period_finish: u64,
    }

    public(friend) fun register<X, Y, LP>(owner: &signer) {
        let gauge = Gauge<X, Y, LP> {
            reward: coin::zero(),
            reward_rate: 0,
            period_finish: 0,
        };
        move_to(owner, gauge);

        let events_store = EventsStore<X, Y, LP>{
            gauge_created_handle: event::new_event_handle(owner),
            gauge_add_reward_handle: event::new_event_handle(owner),
            gauge_withdraw_reward_handle: event::new_event_handle(owner),
        };
        event::emit_event(
            &mut events_store.gauge_created_handle,
            GaugeCreatedEvent<X, Y, LP>{ pool_addr: signer::address_of(owner) }
        );

        move_to(owner, events_store);
    }

    public fun add_reward<X, Y, LP>(pool_addr: address, coin_in: Coin<LAMM>) acquires Gauge, EventsStore {
        assert!(exists<Gauge<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        let gauge = borrow_global_mut<Gauge<X, Y, LP>>(pool_addr);
        let coin_val = coin::value(&coin_in);
        let now = timestamp::now_seconds();
        if (now >= gauge.period_finish) {
            gauge.reward_rate = coin_val / WEEK;
        } else {
            let remaining = gauge.period_finish - now;
            let left = remaining * gauge.reward_rate;
            assert!(coin_val > left, 1);
            gauge.reward_rate = (coin_val + left) / WEEK;
        };

        coin::merge(&mut gauge.reward, coin_in);

        assert!(gauge.reward_rate <= coin::value(&gauge.reward) / WEEK, 2);
        gauge.period_finish = now + WEEK;

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.gauge_add_reward_handle,
            GaugeAddRewardEvent<X, Y, LP>{ pool_addr, coin_val }
        );
    }

    public(friend) fun withdraw_reward<X, Y, LP>(
        pool_addr: address,
        token_votes: u64,
        total_votes: u64
    ): Coin<LAMM> acquires Gauge, EventsStore {
        assert!(exists<Gauge<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        let gauge = borrow_global_mut<Gauge<X, Y, LP>>(pool_addr);

        let now = timestamp::now_seconds();
        let time = if (now >= gauge.period_finish) { WEEK } else { now + WEEK - gauge.period_finish };
        let amount = time * gauge.reward_rate * token_votes / total_votes;
        assert!(amount <= coin::value(&gauge.reward), ERR_INSUFFICIANT_REWARD);
        let coin_out = coin::extract(&mut gauge.reward, amount);

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.gauge_withdraw_reward_handle,
            GaugeWithdrawRewardEvent<X, Y, LP>{ pool_addr, coin_val: coin::value(&coin_out) }
        );

        coin_out
    }

    // Events

    struct EventsStore<phantom X, phantom Y, phantom LP> has key {
        gauge_created_handle: event::EventHandle<GaugeCreatedEvent<X, Y, LP>>,
        gauge_add_reward_handle: event::EventHandle<GaugeAddRewardEvent<X, Y, LP>>,
        gauge_withdraw_reward_handle: event::EventHandle<GaugeWithdrawRewardEvent<X, Y, LP>>,
    }

    struct GaugeCreatedEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
    }

    struct GaugeAddRewardEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_val: u64,
    }

    struct GaugeWithdrawRewardEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_val: u64,
    }
}
