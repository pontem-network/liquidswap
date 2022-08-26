module liquidswap::bribe {
    use std::signer;

    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::event;

    friend liquidswap::router;
    friend liquidswap::voter;

    const WEEK: u64 = 604800;

    // Error codes.

    /// When gauge doesn't exists
    const ERR_NOT_REGISTERED: u64 = 401;

    const ERR_INSUFFICIANT_REWARD: u64 = 402;

    const ERR_INVALID_COIN_TYPE: u64 = 403;

    struct CoinConfig<phantom CoinType> has store {
        reward: Coin<CoinType>,
        reward_rate: u64,
        period_finish: u64,
    }

    struct Bribe<phantom X, phantom Y, phantom LP> has key {
        x_config: CoinConfig<X>,
        y_config: CoinConfig<Y>,
    }

    public(friend) fun register<X, Y, LP>(owner: &signer) {
        let bribe = Bribe<X, Y, LP> {
            x_config: CoinConfig<X> {
                reward: coin::zero(),
                reward_rate: 0,
                period_finish: 0,
            },
            y_config: CoinConfig<Y> {
                reward: coin::zero(),
                reward_rate: 0,
                period_finish: 0,
            },
        };
        move_to(owner, bribe);

        let events_store = EventsStore<X, Y, LP>{
            bribe_created_handle: event::new_event_handle(owner),
            bribe_notify_reward_handle: event::new_event_handle(owner),
            bribe_withdraw_reward_handle: event::new_event_handle(owner),
        };
        event::emit_event(
            &mut events_store.bribe_created_handle,
            BribeCreatedEvent<X, Y, LP>{ pool_addr: signer::address_of(owner) }
        );

        move_to(owner, events_store);
    }

    public fun notify_reward_amount<X, Y, LP>(
        pool_addr: address,
        coin_x: Coin<X>,
        coin_y: Coin<Y>,
    ) acquires Bribe, EventsStore {
        assert!(exists<Bribe<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        let coin_x_val = coin::value(&coin_x);
        let coin_y_val = coin::value(&coin_y);
        let bribe = borrow_global_mut<Bribe<X, Y, LP>>(pool_addr);
        add_reward_internal(&mut bribe.x_config, coin_x);
        add_reward_internal(&mut bribe.y_config, coin_y);

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.bribe_notify_reward_handle,
            BribeNotifyRewardEvent<X, Y, LP>{ pool_addr, coin_x_val, coin_y_val }
        );
    }

    fun add_reward_internal<CoinType>(config: &mut CoinConfig<CoinType>, coin_in: Coin<CoinType>) {
        let coin_in_val = coin::value(&coin_in);
        let now = timestamp::now_seconds();
        if (now >= config.period_finish) {
            config.reward_rate = coin_in_val / WEEK;
        } else {
            let remaining = config.period_finish - now;
            let left_val = remaining * config.reward_rate;
            assert!(coin_in_val > left_val, ERR_INSUFFICIANT_REWARD);
            config.reward_rate = (coin_in_val + left_val) / WEEK;
        };

        coin::merge(&mut config.reward, coin_in);

        assert!(config.reward_rate <= coin::value(&config.reward) / WEEK, ERR_INSUFFICIANT_REWARD);

        config.period_finish = now + WEEK;
    }

    public(friend) fun withdraw_reward<X, Y, LP>(
        pool_addr: address,
        token_votes: u64,
        total_votes: u64
    ): (Coin<X>, Coin<Y>) acquires Bribe, EventsStore {
        assert!(exists<Bribe<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        let bribe = borrow_global_mut<Bribe<X, Y, LP>>(pool_addr);

        let coin_x = withdraw_reward_internal(&mut bribe.x_config, token_votes, total_votes);
        let coin_y = withdraw_reward_internal(&mut bribe.y_config, token_votes, total_votes);

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

    fun withdraw_reward_internal<CoinType>(
        config: &mut CoinConfig<CoinType>,
        token_votes: u64,
        total_votes: u64
    ): Coin<CoinType> {
        let now = timestamp::now_seconds();
        let time = if (now >= config.period_finish) { WEEK } else { now + WEEK - config.period_finish };
        let amount = time * config.reward_rate * token_votes / total_votes;
        assert!(amount <= coin::value(&config.reward), ERR_INSUFFICIANT_REWARD);
        coin::extract(&mut config.reward, amount)
    }

    public fun left<X, Y, LP>(pool_addr: address): (u64, u64) acquires Bribe {
        assert!(exists<Bribe<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        let bribe = borrow_global<Bribe<X, Y, LP>>(pool_addr);
        let now = timestamp::now_seconds();
        let x_remaining = 0;
        let y_remaining = 0;
        if (now < bribe.x_config.period_finish) x_remaining = bribe.x_config.period_finish - now;
        if (now < bribe.y_config.period_finish) y_remaining = bribe.y_config.period_finish - now;

        (x_remaining * bribe.x_config.reward_rate, y_remaining * bribe.y_config.reward_rate)
    }

    // Events

    struct EventsStore<phantom X, phantom Y, phantom LP> has key {
        bribe_created_handle: event::EventHandle<BribeCreatedEvent<X, Y, LP>>,
        bribe_notify_reward_handle: event::EventHandle<BribeNotifyRewardEvent<X, Y, LP>>,
        bribe_withdraw_reward_handle: event::EventHandle<BribeWithdrawRewardEvent<X, Y, LP>>,
    }

    struct BribeCreatedEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
    }

    struct BribeNotifyRewardEvent<phantom X, phantom Y, phantom LP> has store, drop {
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
