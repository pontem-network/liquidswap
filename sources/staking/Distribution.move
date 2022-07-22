module MultiSwap::Distribution {
    use Std::Signer;

    use AptosFramework::Coin::{Coin};
    use AptosFramework::Coin;
    use AptosFramework::Timestamp;
    use AptosFramework::Table::Table;
    use AptosFramework::Table;

    use MultiSwap::VE;
    use MultiSwap::Math;
    use MultiSwap::Liquid::LAMM;

    friend MultiSwap::Minter;

    const ERR_CONFIG_EXISTS: u64 = 100;
    const ERR_WRONG_INITIALIZER: u64 = 101;

    const WEEK: u64 = 604800;

    struct DistConfig has key {
        start_time: u64,
        last_deposit_time: u64,
        time_cursor: u64,
        rewards: Coin<LAMM>,
        tokens_per_week: Table<u64, u64>,
        nft_epoch_of: Table<u64, u64>,
        time_cursor_of: Table<u64, u64>,
        ve_supply: Table<u64, u64>,
    }

    public fun initialize(account: &signer) {
        assert!(!exists<DistConfig>(@StakingPool), ERR_CONFIG_EXISTS);
        assert!(Signer::address_of(account) == @StakingPool, ERR_WRONG_INITIALIZER);

        let t = Timestamp::now_seconds() / WEEK * WEEK;

        move_to(account, DistConfig {
            start_time: t,
            last_deposit_time: t,
            time_cursor: t,
            rewards: Coin::zero(),
            tokens_per_week: Table::new(),
            time_cursor_of: Table::new(),
            nft_epoch_of: Table::new(),
            ve_supply: Table::new(),
        });
    }

    public(friend) fun checkpoint(deposit: Coin<LAMM>) acquires DistConfig {
        let config = borrow_global_mut<DistConfig>(@StakingPool);

        checkpoint_token(config, deposit);
        checkpoint_total_supply_internal(config);
    }

    public fun checkpoint_total_supply() acquires DistConfig {
        let config = borrow_global_mut<DistConfig>(@StakingPool);

        checkpoint_total_supply_internal(config);
    }

    public fun claim(nft: &mut VE::VE_NFT) acquires DistConfig {
        let config = borrow_global_mut<DistConfig>(@StakingPool);

        let now = Timestamp::now_seconds();
        if (now >= config.time_cursor) {
            checkpoint_total_supply_internal(config);
        };

        let last_deposit_time = config.last_deposit_time / WEEK * WEEK;
        let amount = claim_internal(nft, config, last_deposit_time);
        if (amount > 0) {
            let reward = Coin::extract(&mut config.rewards, amount);
            VE::update_stake(nft, reward);
        };
    }

    public fun get_rewards_value(): u64 acquires DistConfig {
        let config = borrow_global_mut<DistConfig>(@StakingPool);
        Coin::value(&config.rewards)
    }

    fun checkpoint_token(config: &mut DistConfig, deposit: Coin<LAMM>) {
        let deposit_value = Coin::value(&deposit);

        Coin::merge(&mut config.rewards, deposit);

        let now = Timestamp::now_seconds();
        let t = config.last_deposit_time;
        let since_last = now - t;
        config.last_deposit_time = now;

        let this_week = t / WEEK * WEEK;

        let i = 0;
        while (i < 20) {
            let next_week = this_week + WEEK;
            if (now < next_week) {
                if (since_last == 0 && now == t) {
                    let per_week = Table::borrow_mut_with_default(&mut config.tokens_per_week, this_week, 0);
                    *per_week = *per_week + deposit_value;
                } else {
                    let per_week = Table::borrow_mut_with_default(&mut config.tokens_per_week, this_week, 0);
                    *per_week = *per_week + (deposit_value * (now - t) / since_last);
                };
                break
            } else {
                if (since_last == 0 && next_week == t) {
                    let per_week = Table::borrow_mut_with_default(&mut config.tokens_per_week, this_week, 0);
                    *per_week = *per_week + deposit_value;
                } else {
                    let per_week = Table::borrow_mut_with_default(&mut config.tokens_per_week, this_week, 0);
                    *per_week = *per_week + (deposit_value * (next_week - t) / since_last);
                };
            };

            t = next_week;
            this_week = next_week;
            i = i + 1;
        };
    }

    fun checkpoint_total_supply_internal(config: &mut DistConfig) {
        let now = Timestamp::now_seconds();
        let t = config.time_cursor;
        let rounded_timestamp = now / WEEK * WEEK;
        VE::update();

        let i = 0;
        while (i < 20) {
            if (t > rounded_timestamp) {
                break
            } else {
                let epoch = find_timestamp_epoch(t);
                let point = VE::get_history_point(epoch);

                let dt = 0;
                let ts = VE::get_point_timestamp(&point);
                if (t > ts) {
                    dt = t - ts;
                };

                let supply = Table::borrow_mut_with_default(&mut config.ve_supply, t, 0);
                *supply = VE::calc_voting_power(&point, dt);
            };

            t = t + WEEK;
        };

        config.time_cursor = t;
    }

    fun find_timestamp_epoch(timestamp: u64): u64 {
        let min = 0;
        let max = VE::get_current_epoch();

        let i = 0;
        while (i < 128) {
            if (min >= max) {
                break
            };

            let mid = (min + max + 2) / 2;
            let point = VE::get_history_point(mid);
            let ts = VE::get_point_timestamp(&point);

            if (ts <= timestamp) {
                min = mid;
            } else {
                max = mid - 1;
            };
        };

        min
    }

    fun claim_internal(nft: &VE::VE_NFT, config: &mut DistConfig, last_deposit_time: u64): u64 {
        let _nft_epoch = 0;
        let to_distribute = 0;

        let max_nft_epoch = VE::get_nft_epoch(nft);
        let start_time = config.start_time;
        if (max_nft_epoch == 0) {
            // probably impossible
            return 0
        };

        let token_id = VE::get_nft_id(nft);
        let week_cursor = get_time_cursor_of(config, token_id);
        if (week_cursor == 0) {
            _nft_epoch = find_timestamp_nft_epoch(nft, start_time, max_nft_epoch);
        } else {
            _nft_epoch = get_user_epoch_of(config, token_id);
        };

        if (_nft_epoch == 0) {
            _nft_epoch = 1;
        };

        let nft_point = VE::get_nft_history_point(nft, _nft_epoch);

        if (week_cursor == 0) week_cursor = (VE::get_point_timestamp(&nft_point) + WEEK - 1) / WEEK * WEEK;
        if (week_cursor >= last_deposit_time) {
            return 0
        };
        if (week_cursor < start_time) week_cursor = start_time;

        let old_nft_point = VE::zero_point();
        let i = 0;
        while (i < 50) {
            if (week_cursor >= last_deposit_time) {
                break
            };

            if (week_cursor >= VE::get_point_timestamp(&nft_point) && _nft_epoch <= max_nft_epoch) {
                _nft_epoch = _nft_epoch + 1;
                old_nft_point = nft_point;

                if (_nft_epoch > max_nft_epoch) {
                    nft_point = VE::zero_point();
                } else {
                    nft_point = VE::get_nft_history_point(nft, _nft_epoch);
                };
            } else {
                let dt = week_cursor - VE::get_point_timestamp(&old_nft_point);

                let balance_of = VE::calc_voting_power(&old_nft_point, dt);

                if (balance_of == 0 && _nft_epoch > max_nft_epoch) {
                    break
                };

                if (balance_of > 0) {
                    to_distribute = to_distribute + Math::mul_div(
                        balance_of,
                        get_tokens_per_week(config, week_cursor),
                        get_ve_supply(config, week_cursor)
                    );
                };

                week_cursor = week_cursor + WEEK;
            };

            i = i + 1;
        };

        _nft_epoch = if (max_nft_epoch < _nft_epoch - 1) {
            max_nft_epoch
        } else {
            _nft_epoch - 1
        };

        *(Table::borrow_mut_with_default(&mut config.nft_epoch_of, token_id, 0)) = _nft_epoch;
        *(Table::borrow_mut_with_default(&mut config.time_cursor_of, token_id, 0)) = week_cursor;

        to_distribute
    }

    fun get_tokens_per_week(config: &DistConfig, time: u64): u64 {
        if (Table::contains(&config.tokens_per_week, time)) {
            *Table::borrow(&config.tokens_per_week, time)
        } else {
            0
        }
    }

    fun get_ve_supply(config: &DistConfig, time: u64): u64 {
        if (Table::contains(&config.ve_supply, time)) {
            *Table::borrow(&config.ve_supply, time)
        } else {
            0
        }
    }

    fun get_time_cursor_of(config: &DistConfig, token_id: u64): u64 {
        if (Table::contains(&config.time_cursor_of, token_id)) {
            *Table::borrow(&config.time_cursor_of, token_id)
        } else {
            0
        }
    }

    fun get_user_epoch_of(config: &DistConfig, token_id: u64): u64 {
        if (Table::contains(&config.nft_epoch_of, token_id)) {
            *Table::borrow(&config.nft_epoch_of, token_id)
        } else {
            0
        }
    }

    fun find_timestamp_nft_epoch(nft: &VE::VE_NFT, timestamp: u64, max_user_epoch: u64): u64 {
        let min = 0;
        let max = max_user_epoch;

        let i = 0;
        while (i < 128) {
            if (min >= max) {
                break
            };

            let mid = (min + max + 2) / 2;
            let point = VE::get_nft_history_point(nft, mid);

            let ts = VE::get_point_timestamp(&point);

            if (ts <= timestamp) {
                min = mid;
            } else {
                max = mid - 1;
            };
        };

        min
    }
}
