module liquidswap::gauge {
    use std::signer;

    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::event;

    use liquidswap::liquid::LAMM;
    use liquidswap::bribe;
    use liquidswap::liquidity_pool;

    friend liquidswap::router;
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
        x_fee: Coin<X>,
        y_fee:Coin<Y>,
    }

    public(friend) fun register<X, Y, LP>(owner: &signer) {
        let gauge = Gauge<X, Y, LP> {
            reward: coin::zero(),
            reward_rate: 0,
            period_finish: 0,
            x_fee: coin::zero(),
            y_fee: coin::zero(),
        };
        move_to(owner, gauge);

        let events_store = EventsStore<X, Y, LP>{
            gauge_created_handle: event::new_event_handle(owner),
            gauge_notify_reward_handle: event::new_event_handle(owner),
            gauge_withdraw_reward_handle: event::new_event_handle(owner),
        };
        event::emit_event(
            &mut events_store.gauge_created_handle,
            GaugeCreatedEvent<X, Y, LP>{ pool_addr: signer::address_of(owner) }
        );

        move_to(owner, events_store);
    }

    public fun notify_reward_amount<X, Y, LP>(pool_addr: address, coin_in: Coin<LAMM>) acquires Gauge, EventsStore {
        assert!(exists<Gauge<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        claim_fees_internal<X, Y, LP>(pool_addr);

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

        assert!(gauge.reward_rate <= coin::value(&gauge.reward) / WEEK, ERR_INSUFFICIANT_REWARD);

        gauge.period_finish = now + WEEK;

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.gauge_notify_reward_handle,
            GaugeNotifyRewardEvent<X, Y, LP>{ pool_addr, coin_val }
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

    public fun claim_fees<X, Y, LP>(pool_addr: address) acquires Gauge {
        assert!(exists<Gauge<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        claim_fees_internal<X, Y, LP>(pool_addr);
    }

    fun claim_fees_internal<X, Y, LP>(pool_addr: address) acquires Gauge {
        let gauge = borrow_global_mut<Gauge<X, Y, LP>>(pool_addr);

        let (x_fee, y_fee) = liquidity_pool::claim_fees<X, Y, LP>(pool_addr);
        let x_fee_val = coin::value(&x_fee);
        let y_fee_val = coin::value(&y_fee);
        coin::merge(&mut gauge.x_fee, x_fee);
        coin::merge(&mut gauge.y_fee, y_fee);
        if (x_fee_val > 0 || y_fee_val > 0) {
            let x_fee_total_val = coin::value(&gauge.x_fee);
            let y_fee_total_val = coin::value(&gauge.y_fee);

            let (x_left_val, y_left_val) = bribe::left<X, Y, LP>(pool_addr);

            let x_reward = coin::zero<X>();
            let y_reward = coin::zero<Y>();
            if (x_fee_total_val > x_left_val && x_fee_total_val / WEEK > 0) {
                coin::merge(&mut x_reward, coin::extract(&mut gauge.x_fee, x_fee_total_val));
            };
            if (y_fee_total_val > y_left_val && y_fee_total_val / WEEK > 0) {
                coin::merge(&mut y_reward, coin::extract(&mut gauge.y_fee, y_fee_total_val));
            };

            bribe::notify_reward_amount<X, Y, LP>(pool_addr, x_reward, y_reward);
        };
    }

    // Events

    struct EventsStore<phantom X, phantom Y, phantom LP> has key {
        gauge_created_handle: event::EventHandle<GaugeCreatedEvent<X, Y, LP>>,
        gauge_notify_reward_handle: event::EventHandle<GaugeNotifyRewardEvent<X, Y, LP>>,
        gauge_withdraw_reward_handle: event::EventHandle<GaugeWithdrawRewardEvent<X, Y, LP>>,
    }

    struct GaugeCreatedEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
    }

    struct GaugeNotifyRewardEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_val: u64,
    }

    struct GaugeWithdrawRewardEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_val: u64,
    }
}
