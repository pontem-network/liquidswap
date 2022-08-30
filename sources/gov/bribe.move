module liquidswap::bribe {
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::event;
    use aptos_std::table::{Self, Table};

    use liquidswap::math;
    use liquidswap::ve::{Self, VE_NFT};

    friend liquidswap::router;
    friend liquidswap::voter;

    const WEEK: u64 = 604800;

    // Error codes.

    /// When gauge doesn't exists
    const ERR_NOT_REGISTERED: u64 = 401;

    const ERR_INSUFFICIANT_REWARD: u64 = 402;

    const ERR_INVALID_COIN_TYPE: u64 = 403;

    struct TokenConfig has copy, drop, store {
        reward: u64,
        reward_paid: u64,
    }

    struct CoinConfig<phantom CoinType> has store {
        reward: Coin<CoinType>,
        reward_rate: u64,
        period_finish: u64,
        last_update_time: u64,
        tokens: Table<u64, TokenConfig>,    // token_id -> token config
        reward_per_token_stored: u64,
    }

    struct BribeConfig has store {
        total_supply: u64,
        balances: Table<u64, u64>,          // token_id -> balance
    }

    struct Bribe<phantom X, phantom Y, phantom LP> has key {
        x_config: CoinConfig<X>,
        y_config: CoinConfig<Y>,
        config: BribeConfig,
    }

    public(friend) fun register<X, Y, LP>(owner: &signer) {
        let now = timestamp::now_seconds();
        let bribe = Bribe<X, Y, LP> {
            x_config: CoinConfig<X> {
                reward: coin::zero(),
                reward_rate: 0,
                period_finish: now,
                last_update_time: now,
                tokens: table::new(),
                reward_per_token_stored: 0,
            },
            y_config: CoinConfig<Y> {
                reward: coin::zero(),
                reward_rate: 0,
                period_finish: now,
                last_update_time: now,
                tokens: table::new(),
                reward_per_token_stored: 0,
            },
            config : BribeConfig {
                total_supply: 0,
                balances: table::new(),
            }
        };
        move_to(owner, bribe);

        let events_store = EventsStore<X, Y, LP> {
            bribe_created_handle: account::new_event_handle(owner),
            bribe_staked_handle: account::new_event_handle(owner),
            bribe_withdrawn_handle: account::new_event_handle(owner),
            bribe_reward_added_handle: account::new_event_handle(owner),
            bribe_reward_paid_handle: account::new_event_handle(owner),
        };
        event::emit_event(
            &mut events_store.bribe_created_handle,
            BribeCreatedEvent<X, Y, LP> { pool_addr: signer::address_of(owner) }
        );

        move_to(owner, events_store);
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

    public fun get_total_supply<X, Y, LP>(pool_addr: address): u64 acquires Bribe {
        assert!(exists<Bribe<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        let bribe = borrow_global<Bribe<X, Y, LP>>(pool_addr);
        bribe.config.total_supply
    }

    public fun get_balance_of<X, Y, LP>(pool_addr: address, ve_nft: &VE_NFT): u64 acquires Bribe {
        assert!(exists<Bribe<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        let bribe = borrow_global_mut<Bribe<X, Y, LP>>(pool_addr);
        *table::borrow_mut_with_default(&mut bribe.config.balances, ve::get_nft_id(ve_nft), 0)
    }

    fun last_time_reward_applicable<CoinType>(coin_config: &CoinConfig<CoinType>): u64 {
        let now = timestamp::now_seconds();
        (math::min(now, coin_config.period_finish))
    }

    fun reward_per_token<CoinType>(coin_cofig: &CoinConfig<CoinType>, bribe_config: &BribeConfig): u64 {
        if (bribe_config.total_supply == 0) {
            return coin_cofig.reward_per_token_stored
        };
        coin_cofig.reward_per_token_stored + math::mul_div (
            last_time_reward_applicable(coin_cofig) - coin_cofig.last_update_time,
            coin_cofig.reward_rate * math::pow_10(coin::decimals<CoinType>()),
            bribe_config.total_supply
        )
    }

    fun earned<CoinType>(coin_config: &mut CoinConfig<CoinType>, bribe_config: &BribeConfig, token_id: u64): u64 {
        let token_config = table::borrow_mut_with_default(
            &mut coin_config.tokens,
            token_id,
            zero_token_config()
        );
        let balance = 0;
        if (table::contains(&bribe_config.balances, token_id))
            balance = *table::borrow(&bribe_config.balances, token_id);
        math::mul_div(
            balance,
            reward_per_token(coin_config, bribe_config) - token_config.reward_paid,
            math::pow_10(coin::decimals<CoinType>())
        ) + token_config.reward
    }

    public(friend) fun deposit<X, Y, LP>(
        pool_addr: address,
        ve_nft: &VE_NFT,
        coin_val: u64
    ) acquires Bribe, EventsStore {
        assert!(exists<Bribe<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        let bribe = borrow_global_mut<Bribe<X, Y, LP>>(pool_addr);
        let token_id = ve::get_nft_id(ve_nft);

        update_reward(&mut bribe.x_config, &bribe.config, token_id);
        update_reward(&mut bribe.y_config, &bribe.config, token_id);

        bribe.config.total_supply = bribe.config.total_supply + coin_val;
        let balance = table::borrow_mut_with_default(&mut bribe.config.balances, token_id, 0);
        *balance = *balance + coin_val;

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.bribe_staked_handle,
            BribeStakedEvent<X, Y, LP> { pool_addr, coin_val }
        );
    }

    public(friend) fun withdraw<X, Y, LP>(
        pool_addr: address,
        ve_nft: &VE_NFT,
        coin_val: u64
    ) acquires Bribe, EventsStore {
        assert!(exists<Bribe<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        let bribe = borrow_global_mut<Bribe<X, Y, LP>>(pool_addr);
        let token_id = ve::get_nft_id(ve_nft);

        update_reward(&mut bribe.x_config, &bribe.config, token_id);
        update_reward(&mut bribe.y_config, &bribe.config, token_id);

        let balance = table::borrow_mut_with_default(&mut bribe.config.balances, token_id, 0);
        if (coin_val <= *balance) {
            bribe.config.total_supply = bribe.config.total_supply - coin_val;
            *balance = *balance - coin_val;

            let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
            event::emit_event(
                &mut events_store.bribe_withdrawn_handle,
                BribeWithdrawnEvent<X, Y, LP> { pool_addr, coin_val }
            );
        }
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
        add_reward_internal(&mut bribe.x_config, &bribe.config, coin_x);
        add_reward_internal(&mut bribe.y_config, &bribe.config, coin_y);

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.bribe_reward_added_handle,
            BribeRewardAddedEvent<X, Y, LP> { pool_addr, coin_x_val, coin_y_val }
        );
    }

    fun add_reward_internal<CoinType>(
        coin_config: &mut CoinConfig<CoinType>,
        bribe_config: &BribeConfig,
        coin_in: Coin<CoinType>
    ) {
        update_reward(coin_config, bribe_config, 0);

        let coin_in_val = coin::value(&coin_in);
        assert!(coin_in_val > WEEK, ERR_INSUFFICIANT_REWARD);

        coin_config.reward_per_token_stored = reward_per_token(coin_config, bribe_config);
        coin_config.last_update_time = last_time_reward_applicable(coin_config);

        let now = timestamp::now_seconds();
        if (now >= coin_config.period_finish) {
            coin_config.reward_rate = coin_in_val / WEEK;
        } else {
            let remaining = coin_config.period_finish - now;
            let left_val = remaining * coin_config.reward_rate;

            assert!(coin_in_val > left_val, ERR_INSUFFICIANT_REWARD);

            coin_config.reward_rate = (coin_in_val + left_val) / WEEK;
        };

        coin::merge(&mut coin_config.reward, coin_in);

        coin_config.last_update_time = now;
        coin_config.period_finish = now + WEEK;
    }

    public(friend) fun get_reward<X, Y, LP>(
        pool_addr: address,
        ve_nft: &VE_NFT
    ): (Coin<X>, Coin<Y>) acquires Bribe, EventsStore {
        assert!(exists<Bribe<X, Y, LP>>(pool_addr), ERR_NOT_REGISTERED);

        let bribe = borrow_global_mut<Bribe<X, Y, LP>>(pool_addr);

        let token_id = ve::get_nft_id(ve_nft);
        let coin_x = get_reward_internal(&mut bribe.x_config, &bribe.config, token_id);
        let coin_y = get_reward_internal(&mut bribe.y_config, &bribe.config, token_id);

        let events_store = borrow_global_mut<EventsStore<X, Y, LP>>(pool_addr);
        event::emit_event(
            &mut events_store.bribe_reward_paid_handle,
            BribeRewardPaidEvent<X, Y, LP> {
                pool_addr,
                coin_x_val: coin::value(&coin_x),
                coin_y_val: coin::value(&coin_y),
            }
        );

        (coin_x, coin_y)
    }

    fun get_reward_internal<CoinType>(
        coin_config: &mut CoinConfig<CoinType>,
        bribe_config: &BribeConfig,
        token_id: u64,
    ): Coin<CoinType> {
        update_reward(coin_config, bribe_config, token_id);

        let token_config = table::borrow_mut_with_default(
            &mut coin_config.tokens,
            token_id,
            zero_token_config()
        );
        let coin_out = coin::zero();
        if (token_config.reward > 0) {
            coin::merge(
                &mut coin_out,
                coin::extract(&mut coin_config.reward, token_config.reward)
            );
            token_config.reward = 0;
        };

        coin_out
    }

    fun update_reward<CoinType>(coin_config: &mut CoinConfig<CoinType>, bribe_config: &BribeConfig, token_id: u64) {
        coin_config.reward_per_token_stored = reward_per_token(coin_config, bribe_config);
        coin_config.last_update_time = last_time_reward_applicable(coin_config);

        if (token_id != 0) {
            let token_config = table::borrow_mut_with_default(
                &mut coin_config.tokens,
                token_id,
                zero_token_config()
            );
            token_config.reward = earned(coin_config, bribe_config, token_id);
            token_config.reward_paid = coin_config.reward_per_token_stored;
        }
    }

    fun zero_token_config(): TokenConfig {
        TokenConfig {
            reward: 0,
            reward_paid: 0,
        }
    }

    // Events

    struct EventsStore<phantom X, phantom Y, phantom LP> has key {
        bribe_created_handle: event::EventHandle<BribeCreatedEvent<X, Y, LP>>,
        bribe_staked_handle: event::EventHandle<BribeStakedEvent<X, Y, LP>>,
        bribe_withdrawn_handle: event::EventHandle<BribeWithdrawnEvent<X, Y, LP>>,
        bribe_reward_added_handle: event::EventHandle<BribeRewardAddedEvent<X, Y, LP>>,
        bribe_reward_paid_handle: event::EventHandle<BribeRewardPaidEvent<X, Y, LP>>,
    }

    struct BribeCreatedEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
    }

    struct BribeStakedEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_val: u64,
    }

    struct BribeWithdrawnEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_val: u64,
    }

    struct BribeRewardAddedEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_x_val: u64,
        coin_y_val: u64,
    }

    struct BribeRewardPaidEvent<phantom X, phantom Y, phantom LP> has store, drop {
        pool_addr: address,
        coin_x_val: u64,
        coin_y_val: u64,
    }
}
