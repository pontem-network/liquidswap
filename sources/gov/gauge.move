module liquidswap::gauge {
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::event;
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info::{Self, TypeInfo};

    use liquidswap::bribe;
    use liquidswap::liquid::LAMM;
    use liquidswap::liquidity_pool;
    use liquidswap::math;
    use liquidswap::ve::{Self, VE_NFT};

    friend liquidswap::router;
    friend liquidswap::voter;

    const WEEK: u64 = 604800;

    // Error codes.

    /// When gauge doesn't exists
    const ERR_NOT_REGISTERED: u64 = 401;

    const ERR_INSUFFICIANT_REWARD: u64 = 402;

    const ERR_REWARD_TOO_HIGH: u64 = 403;

    const ERR_ZERO_COIN: u64 = 404;

    struct TokenConfig has copy, drop, store {
        reward: u64,
        reward_paid: u64,
        derived_balance: u64,
        balance: u64,
    }

    struct Gauge<phantom X, phantom Y, phantom LP> has key {
        last_update_time: u64,
        coin_reward: Coin<LAMM>,
        coin_stake: Coin<LP>,
        reward_rate: u64,
        period_finish: u64,
        tokens: Table<u64, TokenConfig>,    // token_id -> token config
        derived_supply: u64,
        total_supply: u64,
        reward_per_token_stored: u64,
        x_fee: Coin<X>,
        y_fee: Coin<Y>,
    }

    public(friend) fun register<X, Y, LP>(owner: &signer) {
        let t = timestamp::now_seconds() / WEEK * WEEK;

        let gauge = Gauge<X, Y, LP> {
            last_update_time: t,
            coin_reward: coin::zero(),
            coin_stake: coin::zero(),
            reward_rate: 0,
            period_finish: 0,
            tokens: table::new(),
            derived_supply: 0,
            total_supply: 0,
            reward_per_token_stored: 0,
            x_fee: coin::zero(),
            y_fee: coin::zero(),
        };
        move_to(owner, gauge);

        let events_store = EventsStore<X, Y, LP>{
            gauge_created_handle: account::new_event_handle(owner),
            gauge_claim_voting_fees_handle: account::new_event_handle(owner),
            gauge_reward_added_handle: account::new_event_handle(owner),
            gauge_reward_paid_handle: account::new_event_handle(owner),
            gauge_staked_handle: account::new_event_handle(owner),
            gauge_withdrawn_handle: account::new_event_handle(owner),
        };
        event::emit_event(
            &mut events_store.gauge_created_handle,
            GaugeCreatedEvent<X, Y, LP>{ pool_addr: signer::address_of(owner) }
        );

        move_to(owner, events_store);
    }

    public fun claim_voting_fees<X, Y, LP>(pool_addr: address) acquires Gauge, EventsStore {
        assert!(exists<Gauge<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);
        claim_voting_fees_internal<X, Y, LP>(pool_addr);
    }

    fun claim_voting_fees_internal<X, Y, LP>(pool_addr: address) acquires Gauge, EventsStore {
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

            let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
            event::emit_event(
                &mut events_store.gauge_claim_voting_fees_handle,
                GaugeClaimVotingFeesEvent<X, Y, LP>{ pool_addr, x_fee_val, y_fee_val }
            );
        };
    }

    public fun deposit<X, Y, LP>(pool_addr: address, ve_nft: &VE_NFT, coin_in: Coin<LP>) acquires Gauge, EventsStore {
        assert!(exists<Gauge<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);
        let gauge = borrow_global_mut<Gauge<X, Y, LP>>(pool_addr);
        let token_id = ve::get_nft_id(ve_nft);

        update_reward(gauge, token_id);

        let coin_val = coin::value(&coin_in);
        let token_config = table::borrow_mut_with_default(
            &mut gauge.tokens,
            token_id,
            zero_token_config()
        );
        token_config.balance = token_config.balance + coin_val;
        gauge.total_supply = gauge.total_supply + coin_val;

        coin::merge(&mut gauge.coin_stake, coin_in);

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.gauge_staked_handle,
            GaugeStakedEvent<X, Y, LP>{ pool_addr, coin_info: type_info::type_of<Coin<LP>>(), coin_val }
        );

        kick(gauge, ve_nft);
    }

    public fun withdraw<X, Y, LP>(pool_addr: address, ve_nft: &VE_NFT): Coin<LP> acquires Gauge, EventsStore {
        assert!(exists<Gauge<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);
        let gauge = borrow_global_mut<Gauge<X, Y, LP>>(pool_addr);
        let token_id = ve::get_nft_id(ve_nft);

        update_reward(gauge, token_id);

        let token_config = table::borrow_mut_with_default(
            &mut gauge.tokens,
            token_id,
            zero_token_config()
        );
        gauge.total_supply = gauge.total_supply - token_config.balance;
        let coin_out = coin::extract(&mut gauge.coin_stake, token_config.balance);
        token_config.balance = 0;

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.gauge_withdrawn_handle,
            GaugeWithdrawnEvent<X, Y, LP>{
                pool_addr,
                coin_info: type_info::type_of<Coin<LP>>(),
                coin_val: coin::value(&coin_out)
            }
        );

        kick(gauge, ve_nft);

        coin_out
    }

    public fun get_reward<X, Y, LP>(pool_addr: address, ve_nft: &VE_NFT): Coin<LAMM> acquires Gauge, EventsStore {
        assert!(exists<Gauge<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);
        let gauge = borrow_global_mut<Gauge<X, Y, LP>>(pool_addr);
        let token_id = ve::get_nft_id(ve_nft);

        update_reward(gauge, token_id);

        let coin_out = coin::zero();
        let token_config = table::borrow_mut_with_default(
            &mut gauge.tokens,
            token_id,
            zero_token_config()
        );
        if (token_config.reward > 0) {
            coin::merge(
                &mut coin_out,
                coin::extract(&mut gauge.coin_reward, token_config.reward)
            );
            token_config.reward = 0;

            let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
            event::emit_event(
                &mut events_store.gauge_reward_paid_handle,
                GaugeRewardPaidEvent<X, Y, LP>{ pool_addr, coin_val: coin::value(&coin_out) }
            );
        };

        kick(gauge, ve_nft);

        coin_out
    }

    public fun notify_reward_amount<X, Y, LP>(pool_addr: address, coin_in: Coin<LAMM>) acquires Gauge, EventsStore {
        assert!(exists<Gauge<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);
        let gauge = borrow_global_mut<Gauge<X, Y, LP>>(pool_addr);

        update_reward(gauge, 0);

        let coin_val = coin::value(&coin_in);
        assert!(coin_val > 0, ERR_ZERO_COIN);

        let now = timestamp::now_seconds();
        if (now >= gauge.period_finish) {
            gauge.reward_rate = coin_val / WEEK;
        } else {
            let remaining = gauge.period_finish - now;
            let left = remaining * gauge.reward_rate;
            assert!(coin_val > left, 1);
            gauge.reward_rate = (coin_val + left) / WEEK;
        };

        coin::merge(&mut gauge.coin_reward, coin_in);

        assert!(gauge.reward_rate <= coin::value(&gauge.coin_reward) / WEEK, ERR_REWARD_TOO_HIGH);

        gauge.last_update_time = now;
        gauge.period_finish = now + WEEK;

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.gauge_reward_added_handle,
            GaugeRewardAddedEvent<X, Y, LP>{ pool_addr, coin_val }
        );
    }

    fun last_time_reward_applicable<X, Y, LP>(gauge: &Gauge<X, Y, LP>): u64 {
        math::min(timestamp::now_seconds(), gauge.period_finish)
    }

    fun reward_per_token<X, Y, LP>(gauge: &Gauge<X, Y, LP>): u64 {
        if (gauge.derived_supply == 0) return 0;
        if (gauge.total_supply == 0) return gauge.reward_per_token_stored;

        gauge.reward_per_token_stored + math::mul_div(
            last_time_reward_applicable(gauge) - gauge.last_update_time,
            gauge.reward_rate * math::pow_10(coin::decimals<LAMM>()),
            gauge.derived_supply
        )
    }

    fun earned(token_config: &TokenConfig, reward_per_token_stored: u64): u64 {
        math::mul_div(
            token_config.derived_balance,
            reward_per_token_stored - token_config.reward_paid,
            math::pow_10(coin::decimals<LAMM>())
        ) + token_config.reward
    }

    fun derived_balance<X, Y, LP>(gauge: &mut Gauge<X, Y, LP>, ve_nft: &VE_NFT): u64 {
        let ve_supply = ve::supply();
        if (ve_supply == 0) return 0;
        let nft_point = ve::get_nft_history_point(ve_nft, ve::get_nft_epoch(ve_nft));
        let nft_votes = ve::get_voting_power(&nft_point);

        let token_config = table::borrow_mut_with_default(
            &mut gauge.tokens,
            ve::get_nft_id(ve_nft),
            zero_token_config()
        );
        let derived = token_config.balance * 40 / 100;
        let adjusted = (gauge.total_supply * nft_votes / ve_supply) * 60 / 100;
        math::min(derived + adjusted, token_config.balance)
    }

    fun kick<X, Y, LP>(gauge: &mut Gauge<X, Y, LP>, ve_nft: &VE_NFT) {
        let derived = derived_balance(gauge, ve_nft);
        let token_config = table::borrow_mut_with_default(
            &mut gauge.tokens,
            ve::get_nft_id(ve_nft),
            zero_token_config()
        );

        gauge.derived_supply = gauge.derived_supply - token_config.derived_balance;
        token_config.derived_balance = derived;
    }

    fun update_reward<X, Y, LP>(gauge: &mut Gauge<X, Y, LP>, token_id: u64) {
        let reward_per_token_stored = reward_per_token(gauge);
        gauge.reward_per_token_stored = reward_per_token_stored;
        gauge.last_update_time = last_time_reward_applicable(gauge);

        if (token_id != 0) {
            let token_config = table::borrow_mut_with_default(
                &mut gauge.tokens,
                token_id,
                zero_token_config()
            );
            token_config.reward = earned(token_config, reward_per_token_stored);
            token_config.reward_paid = gauge.reward_per_token_stored;
        }
    }

    fun zero_token_config(): TokenConfig {
        TokenConfig {
            reward: 0,
            reward_paid: 0,
            derived_balance: 0,
            balance: 0,
        }
    }

    // Events

    struct EventsStore<phantom X, phantom Y, phantom LP> has key {
        gauge_created_handle: event::EventHandle<GaugeCreatedEvent<X, Y, LP>>,
        gauge_claim_voting_fees_handle: event::EventHandle<GaugeClaimVotingFeesEvent<X, Y, LP>>,
        gauge_reward_added_handle: event::EventHandle<GaugeRewardAddedEvent<X, Y, LP>>,
        gauge_reward_paid_handle: event::EventHandle<GaugeRewardPaidEvent<X, Y, LP>>,
        gauge_staked_handle: event::EventHandle<GaugeStakedEvent<X, Y, LP>>,
        gauge_withdrawn_handle: event::EventHandle<GaugeWithdrawnEvent<X, Y, LP>>,
    }

    struct GaugeCreatedEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
    }

    struct GaugeClaimVotingFeesEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        x_fee_val: u64,
        y_fee_val: u64,
    }

    struct GaugeRewardAddedEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_val: u64,
    }

    struct GaugeRewardPaidEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_val: u64,
    }

    struct GaugeStakedEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_info: TypeInfo,
        coin_val: u64,
    }

    struct GaugeWithdrawnEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_info: TypeInfo,
        coin_val: u64,
    }
}
