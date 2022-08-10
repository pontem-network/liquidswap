module liquidswap::distribution {
    use std::signer;

    use aptos_framework::coin::{Self, Coin, MintCapability};
    use aptos_framework::timestamp;
    use aptos_std::table_with_length::{Self, TableWithLength};

    use liquidswap::ve;
    use liquidswap::math;
    use liquidswap::liquid::LAMM;

    friend liquidswap::minter;

    #[test_only]
    use aptos_framework::coins::register_internal;
    #[test_only]
    use aptos_framework::genesis;
    #[test_only]
    use liquidswap::liquid;
    #[test_only]
    use test_helpers::test_account::create_account;

    const ERR_CONFIG_EXISTS: u64 = 100;
    const ERR_WRONG_INITIALIZER: u64 = 101;

    const WEEK: u64 = 604800;

    struct DistConfig has key {
        start_time: u64,
        last_deposit_time: u64,
        time_cursor: u64,
        rewards: Coin<LAMM>,
        tokens_per_week: TableWithLength<u64, u64>,
        nft_epoch_of: TableWithLength<u64, u64>,
        time_cursor_of: TableWithLength<u64, u64>,
        ve_supply: TableWithLength<u64, u64>,
    }

    public fun initialize(account: &signer) {
        assert!(!exists<DistConfig>(@staking_pool), ERR_CONFIG_EXISTS);
        assert!(signer::address_of(account) == @staking_pool, ERR_WRONG_INITIALIZER);

        let t = timestamp::now_seconds() / WEEK * WEEK;

        move_to(account, DistConfig {
            start_time: t,
            last_deposit_time: t,
            time_cursor: t,
            rewards: coin::zero(),
            tokens_per_week: table_with_length::new(),
            time_cursor_of: table_with_length::new(),
            nft_epoch_of: table_with_length::new(),
            ve_supply: table_with_length::new(),
        });
    }

    public(friend) fun checkpoint(deposit: Coin<LAMM>) acquires DistConfig {
        let config = borrow_global_mut<DistConfig>(@staking_pool);

        checkpoint_token(config, deposit);
        checkpoint_total_supply_internal(config);
    }

    public fun checkpoint_total_supply() acquires DistConfig {
        let config = borrow_global_mut<DistConfig>(@staking_pool);

        checkpoint_total_supply_internal(config);
    }

    public fun claim(nft: &mut ve::VE_NFT) acquires DistConfig {
        let config = borrow_global_mut<DistConfig>(@staking_pool);

        let now = timestamp::now_seconds();
        if (now >= config.time_cursor) {
            checkpoint_total_supply_internal(config);
        };

        let last_deposit_time = config.last_deposit_time / WEEK * WEEK;
        let amount = claim_internal(nft, config, last_deposit_time);
        if (amount > 0) {
            let reward = coin::extract(&mut config.rewards, amount);
            ve::update_stake(nft, reward);
        };
    }

    public fun get_rewards_value(): u64 acquires DistConfig {
        let config = borrow_global_mut<DistConfig>(@staking_pool);
        coin::value(&config.rewards)
    }

    fun checkpoint_token(config: &mut DistConfig, deposit: Coin<LAMM>) {
        let deposit_value = coin::value(&deposit);

        coin::merge(&mut config.rewards, deposit);

        let now = timestamp::now_seconds();
        let t = config.last_deposit_time;
        let since_last = now - t;
        config.last_deposit_time = now;

        let this_week = t / WEEK * WEEK;

        let i = 0;
        while (i < 20) {
            let next_week = this_week + WEEK;
            if (now < next_week) {
                if (since_last == 0 && now == t) {
                    let per_week = table_with_length::borrow_mut_with_default(&mut config.tokens_per_week, this_week, 0);
                    *per_week = *per_week + deposit_value;
                } else {
                    let per_week = table_with_length::borrow_mut_with_default(&mut config.tokens_per_week, this_week, 0);
                    *per_week = *per_week + (deposit_value * (now - t) / since_last);
                };
                break
            } else {
                if (since_last == 0 && next_week == t) {
                    let per_week = table_with_length::borrow_mut_with_default(&mut config.tokens_per_week, this_week, 0);
                    *per_week = *per_week + deposit_value;
                } else {
                    let per_week = table_with_length::borrow_mut_with_default(&mut config.tokens_per_week, this_week, 0);
                    *per_week = *per_week + (deposit_value * (next_week - t) / since_last);
                };
            };

            t = next_week;
            this_week = next_week;
            i = i + 1;
        };
    }

    fun checkpoint_total_supply_internal(config: &mut DistConfig) {
        let now = timestamp::now_seconds();
        let t = config.time_cursor;
        let rounded_timestamp = now / WEEK * WEEK;
        ve::update();

        let i = 0;
        while (i < 20) {
            if (t > rounded_timestamp) {
                break
            } else {
                let epoch = find_timestamp_epoch(t);
                let point = ve::get_history_point(epoch);

                let dt = 0;
                let ts = ve::get_point_timestamp(&point);
                if (t > ts) {
                    dt = t - ts;
                };

                let supply = table_with_length::borrow_mut_with_default(&mut config.ve_supply, t, 0);
                *supply = ve::calc_voting_power(&point, dt);
            };

            t = t + WEEK;
        };

        config.time_cursor = t;
    }

    fun find_timestamp_epoch(timestamp: u64): u64 {
        let min = 0;
        let max = ve::get_current_epoch();

        let i = 0;
        while (i < 128) {
            if (min >= max) {
                break
            };

            let mid = (min + max + 2) / 2;
            let point = ve::get_history_point(mid);
            let ts = ve::get_point_timestamp(&point);

            if (ts <= timestamp) {
                min = mid;
            } else {
                max = mid - 1;
            };
        };

        min
    }

    fun claim_internal(nft: &ve::VE_NFT, config: &mut DistConfig, last_deposit_time: u64): u64 {
        let _nft_epoch = 0;
        let to_distribute = 0;

        let max_nft_epoch = ve::get_nft_epoch(nft);
        let start_time = config.start_time;
        if (max_nft_epoch == 0) {
            // probably impossible
            return 0
        };

        let token_id = ve::get_nft_id(nft);
        let week_cursor = get_time_cursor_of(config, token_id);
        if (week_cursor == 0) {
            _nft_epoch = find_timestamp_nft_epoch(nft, start_time, max_nft_epoch);
        } else {
            _nft_epoch = get_user_epoch_of(config, token_id);
        };

        if (_nft_epoch == 0) {
            _nft_epoch = 1;
        };

        let nft_point = ve::get_nft_history_point(nft, _nft_epoch);

        if (week_cursor == 0) week_cursor = (ve::get_point_timestamp(&nft_point) + WEEK - 1) / WEEK * WEEK;
        if (week_cursor >= last_deposit_time) {
            return 0
        };
        if (week_cursor < start_time) week_cursor = start_time;

        let old_nft_point = ve::zero_point();
        let i = 0;
        while (i < 50) {
            if (week_cursor >= last_deposit_time) {
                break
            };

            if (week_cursor >= ve::get_point_timestamp(&nft_point) && _nft_epoch <= max_nft_epoch) {
                _nft_epoch = _nft_epoch + 1;
                old_nft_point = nft_point;

                if (_nft_epoch > max_nft_epoch) {
                    nft_point = ve::zero_point();
                } else {
                    nft_point = ve::get_nft_history_point(nft, _nft_epoch);
                };
            } else {
                let dt = week_cursor - ve::get_point_timestamp(&old_nft_point);

                let balance_of = ve::calc_voting_power(&old_nft_point, dt);

                if (balance_of == 0 && _nft_epoch > max_nft_epoch) {
                    break
                };

                if (balance_of > 0) {
                    to_distribute = to_distribute + math::mul_div(
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

        *(table_with_length::borrow_mut_with_default(&mut config.nft_epoch_of, token_id, 0)) = _nft_epoch;
        *(table_with_length::borrow_mut_with_default(&mut config.time_cursor_of, token_id, 0)) = week_cursor;

        to_distribute
    }

    fun get_tokens_per_week(config: &DistConfig, time: u64): u64 {
        if (table_with_length::contains(&config.tokens_per_week, time)) {
            *table_with_length::borrow(&config.tokens_per_week, time)
        } else {
            0
        }
    }

    fun get_ve_supply(config: &DistConfig, time: u64): u64 {
        if (table_with_length::contains(&config.ve_supply, time)) {
            *table_with_length::borrow(&config.ve_supply, time)
        } else {
            0
        }
    }

    fun get_time_cursor_of(config: &DistConfig, token_id: u64): u64 {
        if (table_with_length::contains(&config.time_cursor_of, token_id)) {
            *table_with_length::borrow(&config.time_cursor_of, token_id)
        } else {
            0
        }
    }

    fun get_user_epoch_of(config: &DistConfig, token_id: u64): u64 {
        if (table_with_length::contains(&config.nft_epoch_of, token_id)) {
            *table_with_length::borrow(&config.nft_epoch_of, token_id)
        } else {
            0
        }
    }

    fun find_timestamp_nft_epoch(nft: &ve::VE_NFT, timestamp: u64, max_user_epoch: u64): u64 {
        let min = 0;
        let max = max_user_epoch;

        let i = 0;
        while (i < 128) {
            if (min >= max) {
                break
            };

            let mid = (min + max + 2) / 2;
            let point = ve::get_nft_history_point(nft, mid);

            let ts = ve::get_point_timestamp(&point);

            if (ts <= timestamp) {
                min = mid;
            } else {
                max = mid - 1;
            };
        };

        min
    }

    // Tests.

    #[test_only]
    struct NFTs has key {
        nfts: TableWithLength<u64, ve::VE_NFT>,
    }

    #[test_only]
    struct MintCap has key { mint_cap: MintCapability<LAMM> }

    #[test_only]
    fun initialize_test(core: &signer, staking_admin: &signer, admin: &signer, staker: &signer) {
        genesis::setup(core);

        create_account(staking_admin);
        create_account(admin);
        create_account(staker);

        liquid::initialize(admin);
        ve::initialize(staking_admin);

        let to_mint_val = 20000000000;
        let staker_addr = signer::address_of(staker);
        register_internal<LAMM>(staker);
        liquid::mint_internal(admin, staker_addr, to_mint_val);
    }

    #[test(core = @core_resources, staking_admin = @staking_pool)]
    fun test_initialize(core: signer, staking_admin: signer) acquires DistConfig {
        genesis::setup(&core);

        create_account(&staking_admin);

        initialize(&staking_admin);

        let t = timestamp::now_seconds() / WEEK * WEEK;
        let stacker_admin_addr = signer::address_of(&staking_admin);
        assert!(exists<DistConfig>(stacker_admin_addr), 0);
        let config = borrow_global<DistConfig>(stacker_admin_addr);

        assert!(config.start_time == t, 1);
        assert!(config.last_deposit_time == t, 2);
        assert!(config.time_cursor == t, 3);
        assert!(coin::value(&config.rewards) == 0, 4);
        assert!(table_with_length::length(&config.tokens_per_week) == 0, 5);
        assert!(table_with_length::length(&config.time_cursor_of) == 0, 6);
        assert!(table_with_length::length(&config.nft_epoch_of) == 0, 7);
        assert!(table_with_length::length(&config.ve_supply) == 0, 8);
    }

    #[test(core = @core_resources, staking_admin = @staking_pool)]
    #[expected_failure(abort_code = 100)]
    fun test_initialize_fail_if_config_exists(core: signer, staking_admin: signer) {
        genesis::setup(&core);

        create_account(&staking_admin);

        initialize(&staking_admin);
        initialize(&staking_admin);
    }

    #[test(core = @core_resources, staker = @test_staker)]
    #[expected_failure(abort_code = 101)]
    fun test_initialize_fail_if_wrong_initializer(core: signer, staker: signer) {
        genesis::setup(&core);

        create_account(&staker);

        initialize(&staker);
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, admin = @liquidswap, staker = @test_staker)]
    fun test_checkpoint(core: signer, staking_admin: signer, admin: signer, staker: signer) acquires DistConfig {
        initialize_test(&core, &staking_admin, &admin, &staker);

        initialize(&staking_admin);

        assert!(get_rewards_value() == 0, 0);

        let new_time = (timestamp::now_seconds() + WEEK) * 1000000;
        timestamp::update_global_time_for_test(new_time);

        let rewards_value = 1000000000;
        let mint_cap = liquid::get_mint_cap(&admin);
        let rewards = coin::mint<LAMM>(rewards_value, &mint_cap);

        checkpoint(rewards);
        assert!(get_rewards_value() == rewards_value, 1);

        move_to(&admin, MintCap { mint_cap });
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, admin = @liquidswap, staker = @test_staker)]
    fun test_checkpoint_token(core: signer, staking_admin: signer, admin: signer, staker: signer) acquires DistConfig {
        initialize_test(&core, &staking_admin, &admin, &staker);

        initialize(&staking_admin);

        let config = borrow_global_mut<DistConfig>(@staking_pool);
        let mint_cap = liquid::get_mint_cap(&admin);
        let rewards_value_1 = 100000000;
        let rewards = coin::mint<LAMM>(rewards_value_1, &mint_cap);
        checkpoint_token(config, rewards);
        let this_week_1 = timestamp::now_seconds() / WEEK * WEEK;
        assert!(get_tokens_per_week(config, this_week_1) == rewards_value_1, 0);

        let new_time = (timestamp::now_seconds() + WEEK) * 1000000;
        timestamp::update_global_time_for_test(new_time);

        let rewards_value_2 = 200000000;
        let rewards = coin::mint<LAMM>(rewards_value_2, &mint_cap);
        checkpoint_token(config, rewards);
        assert!(get_tokens_per_week(config, this_week_1) == rewards_value_1 + rewards_value_2, 1);
        let this_week_2 = timestamp::now_seconds() / WEEK * WEEK;
        assert!(get_tokens_per_week(config, this_week_2) == 0, 2);

        let new_time = (timestamp::now_seconds() + WEEK * 2) * 1000000;
        timestamp::update_global_time_for_test(new_time);

        let rewards_value_3 = 300000000;
        let rewards = coin::mint<LAMM>(rewards_value_3, &mint_cap);
        checkpoint_token(config, rewards);
        assert!(get_tokens_per_week(config, this_week_1) == rewards_value_1 + rewards_value_2, 3);
        assert!(get_tokens_per_week(config, this_week_2) == rewards_value_3 / 2, 4);
        let this_week_3 = timestamp::now_seconds() / WEEK * WEEK;
        assert!(get_tokens_per_week(config, this_week_3 - WEEK) == rewards_value_3 / 2, 5);
        assert!(get_tokens_per_week(config, this_week_3) == 0, 6);

        assert!(get_rewards_value() == rewards_value_1 + rewards_value_2 + rewards_value_3, 7);

        move_to(&admin, MintCap { mint_cap });
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, admin = @liquidswap, staker = @test_staker)]
    fun test_checkpoint_total_supply_internal(
        core: signer,
        staking_admin: signer,
        admin: signer,
        staker: signer
    ) acquires DistConfig {
        initialize_test(&core, &staking_admin, &admin, &staker);

        initialize(&staking_admin);
        let config = borrow_global_mut<DistConfig>(@staking_pool);

        let to_stake_val = 1000000000;
        let to_stake = coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft = ve::stake(to_stake, WEEK);

        let this_week = timestamp::now_seconds() / WEEK * WEEK;
        let new_time = (timestamp::now_seconds() + WEEK) * 1000000;
        timestamp::update_global_time_for_test(new_time);

        assert!(get_ve_supply(config, this_week) == 0, 0);

        checkpoint_total_supply_internal(config);

        assert!(get_ve_supply(config, this_week) == 4233600, 1);
        assert!(get_ve_supply(config, this_week + WEEK) == 0, 2);

        let staking_rewards = ve::unstake(nft, false);
        coin::deposit(signer::address_of(&staker), staking_rewards);
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, admin = @liquidswap, staker = @test_staker)]
    fun test_claim(core: signer, staking_admin: signer, admin: signer, staker: signer) acquires DistConfig {
        initialize_test(&core, &staking_admin, &admin, &staker);

        initialize(&staking_admin);

        let to_stake_val = 1000000000;
        let to_stake = coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft = ve::stake(to_stake, WEEK);

        let new_time = (timestamp::now_seconds() + WEEK) * 1000000;
        timestamp::update_global_time_for_test(new_time);

        let mint_cap = liquid::get_mint_cap(&admin);
        let rewards_value = 100000000;
        let rewards = coin::mint<LAMM>(rewards_value, &mint_cap);

        checkpoint(rewards);
        claim(&mut nft);

        assert!(ve::get_nft_staked_value(&nft) - to_stake_val == rewards_value, 0);

        let staking_rewards = ve::unstake(nft, true);
        assert!(coin::value(&staking_rewards) == (rewards_value + to_stake_val), 1);

        coin::deposit(signer::address_of(&staker), staking_rewards);
        move_to(&admin, MintCap { mint_cap });
    }
}
