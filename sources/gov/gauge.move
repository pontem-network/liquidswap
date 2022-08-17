module liquidswap::gauge {
    use std::signer;
    use std::string::String;

    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::table::{Self, Table};

    use liquidswap::liquid::LAMM;
    use liquidswap::liquidity_pool;

    friend liquidswap::voter;

    const WEEK: u64 = 604800;

    struct PoolId has copy, drop, store {
        pool_address: address,
        x_symbol: String,
        y_symbol: String,
        lp_symbol: String,
    }

    struct Gauge has drop, store {
        rewards: u64,
        reward_rate: u64,
        period_finish: u64,
    }

    struct GaugeConfig has key {
        rewards: Coin<LAMM>,
        gauges: Table<PoolId, Gauge>
    }

    public fun initialize(account: &signer) {
        assert!(!exists<GaugeConfig>(@gov_admin), 1);
        assert!(signer::address_of(account) == @gov_admin, 2);

        move_to(account, GaugeConfig {
            rewards: coin::zero(),
            gauges: table::new<PoolId, Gauge>()
        });
    }

    public(friend) fun add_rewards(pool_id: PoolId, deposit: Coin<LAMM>) acquires GaugeConfig {
        let config = borrow_global_mut<GaugeConfig>(@gov_admin);

        let deposit_value = coin::value(&deposit);

        coin::merge(&mut config.rewards, deposit);

        let gauge = table::borrow_mut_with_default(&mut config.gauges, pool_id, zero_gauge());

        let now = timestamp::now_seconds();
        if (now >= gauge.period_finish) {
            gauge.reward_rate = deposit_value / WEEK;
        } else {
            let remaining = gauge.period_finish - now;
            let left = remaining * gauge.reward_rate;
            assert!(deposit_value > left, 2);
            gauge.reward_rate = (deposit_value + left) / WEEK;
        };

        gauge.rewards = gauge.rewards + deposit_value;
        assert!(gauge.reward_rate <= gauge.rewards / WEEK, 3);
        gauge.period_finish = now + WEEK;
    }

    public(friend) fun withdraw_rewards(pool_id: PoolId, amount: u64): Coin<LAMM> acquires GaugeConfig {
        let config = borrow_global_mut<GaugeConfig>(@gov_admin);
        let gauge = table::borrow_mut_with_default(&mut config.gauges, pool_id, zero_gauge());
        assert!(amount >= gauge.rewards, 1);
        gauge.rewards = gauge.rewards - amount;
        gauge.reward_rate = gauge.rewards / WEEK;
        gauge.period_finish = timestamp::now_seconds();

        coin::extract(&mut config.rewards, amount)
    }

    public fun get_rewards(pool_id: PoolId): u64 acquires GaugeConfig {
        let config = borrow_global<GaugeConfig>(@gov_admin);
        assert!(table::contains(&config.gauges, pool_id), 1);
        let gauge = table::borrow( &config.gauges, pool_id);
        gauge.rewards
    }

    fun zero_gauge(): Gauge {
        Gauge {
            rewards: 0,
            reward_rate: 0,
            period_finish: 0,
        }
    }

    public fun get_liquidity_pool_id<X, Y, LP>(pool_addr: address): PoolId {
        assert!(liquidity_pool::pool_exists_at<X, Y, LP>(pool_addr), 1);
        PoolId {
            pool_address: pool_addr,
            x_symbol: coin::symbol<X>(),
            y_symbol: coin::symbol<Y>(),
            lp_symbol: coin::symbol<LP>(),
        }
    }
}
