/// The module describing NFTized staking position (Voting Escrow).
/// The staking position could be transfered between accounts, used for voting, etc.
/// Detailed explanation of VE standard: https://curve.readthedocs.io/dao-vecrv.html
module liquidswap::ve {
    use std::signer;

    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::table::{Self, Table};
    use aptos_framework::timestamp;

    use liquidswap::liquid::LAMM;

    #[test_only]
    use aptos_framework::coin::register_internal;
    #[test_only]
    use aptos_framework::genesis;
    #[test_only]
    use liquidswap::liquid;

    friend liquidswap::distribution;

    // Errors.

    /// When staking pool already exists.
    const ERR_POOL_EXISTS: u64 = 100;

    /// When wrong account initializing staking pool.
    const ERR_WRONG_INITIALIZATION_ACCOUNT: u64 = 101;

    /// When user tried to stake for time more than 4 years (see `MAX_TIME`).
    const ERR_DURATION_MORE_THAN_MAX_TIME: u64 = 102;

    /// When no key found in Table.
    const ERR_KEY_NOT_FOUND: u64 = 103;

    /// When unstake before unlock time.
    const ERR_EARLY_UNSTAKE: u64 = 104;

    /// When there is still rewards on
    const ERR_NON_ZERO_REWARDS: u64 = 105;

    /// When staked amount is less than minimum required for VE_NFT minting
    const ERR_NOT_ENOUGH_STAKE_FOR_NFT: u64 = 106;

    // Constants.

    /// One week in seconds.
    const WEEK: u64 = 604800;

    /// Max staking time (~4 years).
    /// 4 * 365 * 86400
    const MAX_LOCK_DURATION: u64 = 126144000;

    /// Represents a staking history point.
    struct Point has store, drop, copy {
        timestamp: u64,
        power_drop_rate: u64,
        voting_power: u64,
    }

    /// Represents staking pool.
    struct StakingPool has key {
        // Stores ID of last VE NFT minted.
        token_id_counter: u64,
        // Current history epoch, changed after a WEEK of seconds.
        current_epoch: u64,
        // History points: <epoch, point>.
        point_history: Table<u64, Point>,
        // The historical slope changes we should take into account during each new epoch.
        change_rate_history: Table<u64, u64>,
    }

    /// Represents VE NFT itself.
    /// Can't be dropped or cloned, only stored.
    struct VE_NFT has store {
        // ID of the current NFT.
        token_id: u64,
        // Stake.
        stake: Coin<LAMM>,
        // Time when NFT could be redeemed.
        unlock_timestamp: u64,

        // The current epoch, when last slope/bias change happened.
        epoch: u64,
        // History points: <epoch, point>.
        point_history: Table<u64, Point>,
    }

    // Public functions.

    /// Initialize staking pool.
    /// Can be called only by @StakingPool address.
    /// Should be called first and immidiatelly after deploy.
    public fun initialize(account: &signer) {
        assert!(!exists<StakingPool>(@staking_pool), ERR_POOL_EXISTS);
        assert!(
            signer::address_of(account) == @staking_pool,
            ERR_WRONG_INITIALIZATION_ACCOUNT
        );

        let point_history = table::new();
        table::add(&mut point_history, 0, Point {
            voting_power: 0,
            power_drop_rate: 0,
            timestamp: timestamp::now_seconds(),
        });

        move_to(account, StakingPool {
            token_id_counter: 0,
            current_epoch: 0,
            point_history,
            change_rate_history: table::new(),
        });
    }

    /// Stake LAMM coins for `lock_duration` seconds.
    /// - `coins` - LAMM coins to stake.
    /// - `lock_duration` - duration of lock in seconds, can't be more than `MAX_TIME`.
    /// Returns `VE_NFT` object contains staked position and related information.
    public fun stake(coins: Coin<LAMM>, lock_duration: u64): VE_NFT acquires StakingPool {
        let pool = borrow_global_mut<StakingPool>(@staking_pool);

        let now = timestamp::now_seconds();
        let unlock_timestamp = round_off_to_week_multiplier(now + lock_duration);
        let lock_duration = unlock_timestamp - now;
        assert!(lock_duration <= MAX_LOCK_DURATION, ERR_DURATION_MORE_THAN_MAX_TIME);

        pool.token_id_counter = pool.token_id_counter + 1;

        let coins_val = coin::value(&coins);
        // checks that power_drop_rate will be non-zero
        assert!(coins_val >= MAX_LOCK_DURATION, ERR_NOT_ENOUGH_STAKE_FOR_NFT);

        let u_power_drop_rate = coins_val / MAX_LOCK_DURATION;
        let u_voting_power = u_power_drop_rate * lock_duration;

        update_internal(pool);

        let last_point = table::borrow_mut(&mut pool.point_history, pool.current_epoch);
        last_point.power_drop_rate = last_point.power_drop_rate + u_power_drop_rate;
        last_point.voting_power = last_point.voting_power + u_voting_power;

        let change_rate_at_unlock_ts =
            table::borrow_mut_with_default(&mut pool.change_rate_history, unlock_timestamp, 0);
        *change_rate_at_unlock_ts = *change_rate_at_unlock_ts + u_power_drop_rate;

        let start_epoch = 1;
        let user_point_history = table::new();
        table::add(&mut user_point_history, start_epoch, Point {
            timestamp: now,
            voting_power: u_voting_power,
            power_drop_rate: u_power_drop_rate,
        });

        let ve_nft = VE_NFT {
            token_id: pool.token_id_counter,
            stake: coins,
            unlock_timestamp,
            epoch: start_epoch,
            point_history: user_point_history,
        };
        ve_nft
    }

    /// Unstake NFT and get rewards and staked amount back.
    /// `nft` - `VE_NFT` object to unstake.
    /// `check_rewards` - determine if we should check if `nft` have rewards to earn. If assigned bool and in case `nft`
    /// has rewards to earn would revert with error.
    /// Returns staked `LAMM` coins + rewards.
    public fun unstake(nft: VE_NFT, check_rewards: bool): Coin<LAMM> {
        // probably if we still have bias and slope we should revert, as it means there is still rewards on nft.
        let now = timestamp::now_seconds();
        assert!(now >= nft.unlock_timestamp, ERR_EARLY_UNSTAKE);

        // this is just a escape hatch, it's assumed that `check_rewards` will always be true
        let point = get_nft_history_point(&nft, nft.epoch);
        assert!(!check_rewards || (point.power_drop_rate == 0 && point.voting_power == 0), ERR_NON_ZERO_REWARDS);

        let VE_NFT {
            token_id: _,
            stake,
            unlock_timestamp: _,
            epoch,
            point_history,
        } = nft;

        // destroy point_history from nft
        let i = 1;
        while (i <= epoch) {
            // currently it's less than 208 iterations
            table::remove(&mut point_history, i);
            i = i + 1;
        };
        table::destroy_empty(point_history);

        stake
    }

    /// Get `VE_NFT` supply (staked supply).
    public fun supply(): u64 acquires StakingPool {
        let pool = borrow_global<StakingPool>(@staking_pool);
        let last_point = *table::borrow(&pool.point_history, pool.current_epoch);

        let now = timestamp::now_seconds();
        // starts at the last_point recording time
        let epoch_ts = round_off_to_week_multiplier(last_point.timestamp);
        let i = 0;
        while (i < 255) {
            epoch_ts = epoch_ts + WEEK;

            let drop_rate = 0;
            if (epoch_ts > now) {
                epoch_ts = now;
            } else {
                drop_rate = get_drop_rate_at_timestamp(pool, epoch_ts);
            };

            last_point.voting_power = calc_voting_power(&last_point, (epoch_ts - last_point.timestamp));

            if (epoch_ts == now) {
                break
            };

            last_point.power_drop_rate = last_point.power_drop_rate - drop_rate;
            last_point.timestamp = epoch_ts;

            i = i + 1;
        };

        last_point.voting_power
    }

    /// Create a new epoch and update historical points.
    public fun update() acquires StakingPool {
        let pool = borrow_global_mut<StakingPool>(@staking_pool);

        update_internal(pool);
    }

    /// Creating a new `Point` filled with zeros.
    public fun zero_point(): Point {
        Point {
            voting_power: 0,
            power_drop_rate: 0,
            timestamp: 0,
        }
    }

    // Internal & friend funcs.

    /// Update the `VE_NFT` with rewards.
    /// Only distribution (friend) contract can call it.
    ///
    /// We could allow to update stake with new LAMM coins if NFT holder wants
    /// yet we really can't at this stage, as history table can become too large
    /// and we wouldn't be able destroy it. Yet i think we can play around it later.
    /// So for now it's friend function and we can't merge two NFTs.
    ///
    /// * `nft` - the `VE_NFT` object to update.
    /// * `coins` - coins that will be added to `nft`, usually it's rewards from staking.
    public(friend) fun update_stake(nft: &mut VE_NFT, coins: Coin<LAMM>) acquires StakingPool {
        let pool = borrow_global_mut<StakingPool>(@staking_pool);

        let coins_value = coin::value(&coins);

        let old_locked = coin::value(&nft.stake);
        let new_locked = coins_value + old_locked;

        let locked_end = nft.unlock_timestamp;
        let now = timestamp::now_seconds();

        let u_old_slope = 0;
        let u_old_bias = 0;

        if (locked_end > now && old_locked > 0) {
            u_old_slope = old_locked / MAX_LOCK_DURATION;
            u_old_bias = u_old_slope * (locked_end - now);
        };

        let u_new_slope = 0;
        let u_new_bias = 0;

        if (locked_end > now && new_locked > 0) {
            u_new_slope = new_locked / MAX_LOCK_DURATION;
            u_new_bias = u_new_slope * (locked_end - now);
        };

        update_internal(pool);

        // probably should be just borrow?
        let last_point = table::borrow_mut(&mut pool.point_history, pool.current_epoch);
        last_point.power_drop_rate = last_point.power_drop_rate + (u_new_slope - u_old_slope);
        last_point.voting_power = last_point.voting_power + (u_new_bias - u_old_bias);

        let old_dslope = get_drop_rate_at_timestamp(pool, locked_end);
        if (old_locked > now) {
            let m_slope = table::borrow_mut_with_default(&mut pool.change_rate_history, locked_end, 0);
            *m_slope = old_dslope - u_old_slope + u_new_slope; // maybe: old_dslope - u_old_slope + u_new_slope?
        };

        nft.epoch = nft.epoch + 1;
        let new_point = Point {
            power_drop_rate: u_new_slope,
            voting_power: u_new_bias,
            timestamp: now,
        };

        table::add(&mut nft.point_history, nft.epoch, new_point);
        coin::merge(&mut nft.stake, coins);
    }

    /// Filling history with new epochs, always adding at least one epoch and history point.
    /// `pool` - staking pool to update.
    fun update_internal(pool: &mut StakingPool) {
        let last_point = *table::borrow(&pool.point_history, pool.current_epoch);

        let last_checkpoint = last_point.timestamp;
        let epoch = pool.current_epoch;

        let now = timestamp::now_seconds();
        let epoch_ts = round_off_to_week_multiplier(last_checkpoint);
        let i = 0;
        while (i < 255) {
            epoch_ts = epoch_ts + WEEK;

            let drop_rate = 0;
            if (epoch_ts > now) {
                epoch_ts = now;
            } else {
                drop_rate = get_drop_rate_at_timestamp(pool, epoch_ts);
            };

            last_point.voting_power = calc_voting_power(&last_point, (epoch_ts - last_checkpoint));
            last_point.power_drop_rate = last_point.power_drop_rate - drop_rate;

            last_checkpoint = epoch_ts;
            last_point.timestamp = epoch_ts;
            epoch = epoch + 1;

            if (epoch_ts == now) {
                break
            } else {
                table::add(&mut pool.point_history, epoch, last_point);
            };

            i = i + 1;
        };

        pool.current_epoch = epoch;

        let new_point =
            table::borrow_mut_with_default(&mut pool.point_history, pool.current_epoch, zero_point());
        new_point.power_drop_rate = last_point.power_drop_rate;
        new_point.voting_power = last_point.voting_power;
        new_point.timestamp = last_point.timestamp;
    }

    /// Get m_slope value with default value equal zero.
    /// `timestamp` - as m_slope stored by timestamps, we should provide time.
    fun get_drop_rate_at_timestamp(pool: &StakingPool, timestamp: u64): u64 {
        if (table::contains(&pool.change_rate_history, timestamp)) {
            *table::borrow(&pool.change_rate_history, timestamp)
        } else {
            0
        }
    }

    // Getters funcs.

    /// Calculates new bias: Math.max(point.voting_power - point.power_change_rate * time_diff, 0);
    /// Bias can't go under zero, so we should check if we can substrate point * slope
    /// from bias or just replace it with zero.
    /// `point` - point to calculate new bias.
    /// `time_diff` - time difference used in math.
    /// Returns new bias value.
    public fun calc_voting_power(point: &Point, time_diff: u64): u64 {
        let r = point.power_drop_rate * time_diff;

        if (point.voting_power < r) {
            0
        } else {
            point.voting_power - r
        }
    }

    /// Get current epoch.
    public fun get_current_epoch(): u64 acquires StakingPool {
        borrow_global<StakingPool>(@staking_pool).current_epoch
    }

    /// Get history point.
    /// `epoch` - epoch of history point.
    public fun get_history_point(epoch: u64): Point acquires StakingPool {
        let pool = borrow_global<StakingPool>(@staking_pool);

        assert!(table::contains(&pool.point_history, epoch), ERR_KEY_NOT_FOUND);

        *table::borrow(&pool.point_history, epoch)
    }

    // VE NFT getters.

    /// Get VE NFT id.
    /// `nft` - reference to `VE_NFT`.
    public fun get_nft_id(nft: &VE_NFT): u64 {
        nft.token_id
    }

    /// Get VE NFT staked value.
    /// `nft` - reference to `VE_NFT`.
    public fun get_nft_staked_value(nft: &VE_NFT): u64 {
        coin::value(&nft.stake)
    }

    /// Get VE NFT unlock time (timestamp).
    /// `nft` - reference to `VE_NFT`.
    public fun get_nft_unlock_timestamp(nft: &VE_NFT): u64 {
        nft.unlock_timestamp
    }

    /// Get current VE NFT epoch.
    /// `nft` - reference to `VE_NFT`.
    public fun get_nft_epoch(nft: &VE_NFT): u64 {
        nft.epoch
    }

    /// Get VE NFT history point.
    /// `nft` - reference to `VE_NFT`.
    /// `epoch` - epoch of history point.
    public fun get_nft_history_point(nft: &VE_NFT, epoch: u64): Point {
        assert!(table::contains(&nft.point_history, epoch), ERR_KEY_NOT_FOUND);

        *table::borrow(&nft.point_history, epoch)
    }

    // Point getters.

    /// Get a time when `point` created.
    public fun get_point_timestamp(point: &Point): u64 {
        point.timestamp
    }

    /// Get a bias value of `point`.
    public fun get_voting_power(point: &Point): u64 {
        point.voting_power
    }

    /// Get a slope value of `point`.
    public fun get_power_drop_rate(point: &Point): u64 {
        point.power_drop_rate
    }

    /// rounds `val` to the closest week, so the resulting number is a integer multiplier of WEEK
    fun round_off_to_week_multiplier(val: u64): u64 {
        val / WEEK * WEEK
    }

    // Tests.

    #[test_only]
    struct NFTs has key {
        nfts: Table<u64, VE_NFT>,
    }

    #[test_only]
    fun get_id_counter(): u64 acquires StakingPool {
        borrow_global<StakingPool>(@staking_pool).token_id_counter
    }

    #[test_only]
    fun get_m_slope_for_test(epoch: u64): u64 acquires StakingPool {
        let pool = borrow_global<StakingPool>(@staking_pool);
        get_drop_rate_at_timestamp(pool, epoch)
    }

    #[test]
    fun test_zero_point() {
        let point = zero_point();
        assert!(point.power_drop_rate == 0, 0);
        assert!(point.voting_power == 0, 1);
        assert!(point.timestamp == 0, 2);
    }

    #[test]
    fun test_reduce_bias() {
        let point = Point {
            voting_power: 32,
            power_drop_rate: 7,
            timestamp: 0,
        };

        let new_bias = calc_voting_power(&point, 5);
        assert!(new_bias == 0, 0);

        let new_bias = calc_voting_power(&point, 1);
        assert!(new_bias == 25, 1);
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, multi_swap = @liquidswap)]
    fun test_initialize(core: signer, staking_admin: signer, multi_swap: signer) acquires StakingPool {
        genesis::setup(&core);
        liquid::initialize(&multi_swap);

        initialize(&staking_admin);

        let stacker_admin_addr = signer::address_of(&staking_admin);
        let pool = borrow_global<StakingPool>(stacker_admin_addr);

        assert!(pool.current_epoch == 0, 0);
        assert!(pool.token_id_counter == 0, 1);
        assert!(table::length(&pool.change_rate_history) == 0, 2);
        assert!(table::length(&pool.point_history) == 1, 3);

        let point = table::borrow(&pool.point_history, 0);
        assert!(point.timestamp == timestamp::now_seconds(), 4);
        assert!(point.power_drop_rate == 0, 5);
        assert!(point.voting_power == 0, 6);

        assert!(get_current_epoch() == 0, 7);
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, multi_swap = @liquidswap)]
    #[expected_failure(abort_code = 100)]
    fun test_initialize_fail(core: signer, staking_admin: signer, multi_swap: signer) {
        genesis::setup(&core);
        liquid::initialize(&multi_swap);

        initialize(&staking_admin);
        initialize(&staking_admin);
    }

    #[test(core = @core_resources, multi_swap = @liquidswap)]
    #[expected_failure(abort_code = 101)]
    fun test_initialize_wrong_account(core: signer, multi_swap: signer) {
        genesis::setup(&core);
        liquid::initialize(&multi_swap);

        initialize(&multi_swap);
    }

    #[test(core = @core_resources, multi_swap = @liquidswap, staker = @test_staker)]
    public fun test_nft_getters(core: signer, multi_swap: signer, staker: signer) {
        genesis::setup(&core);
        liquid::initialize(&multi_swap);

        let to_mint_val = 10000000000;
        register_internal<LAMM>(&staker);
        liquid::mint_internal(&multi_swap, signer::address_of(&staker), to_mint_val);

        let to_stake_val = 1000000000;
        let to_stake = coin::withdraw<LAMM>(&staker, to_stake_val);

        let now = timestamp::now_seconds();

        let history_points = table::new();
        let epoch = 523;
        table::add(&mut history_points, epoch, Point {
            voting_power: 50,
            power_drop_rate: 250,
            timestamp: now,
        });

        let nft = VE_NFT {
            token_id: 100,
            stake: to_stake,
            unlock_timestamp: timestamp::now_seconds(),
            epoch,
            point_history: history_points,
        };

        assert!(get_nft_id(&nft) == 100, 0);
        assert!(get_nft_staked_value(&nft) == to_stake_val, 1);
        assert!(get_nft_unlock_timestamp(&nft) == now, 2);
        assert!(get_nft_epoch(&nft) == epoch, 3);

        let point = get_nft_history_point(&nft, epoch);

        assert!(point.voting_power == 50, 4);
        assert!(point.power_drop_rate == 250, 5);
        assert!(point.timestamp == now, 6);

        let nfts = table::new<u64, VE_NFT>();
        table::add(&mut nfts, nft.token_id, nft);

        move_to(&staker, NFTs {
            nfts
        });
    }

    #[test(aptos_core = @aptos_framework, staker = @test_staker)]
    #[expected_failure(abort_code = 103)]
    fun test_get_nft_history_point_fail(aptos_core: signer, staker: signer) {
        timestamp::set_time_has_started_for_testing(&aptos_core);

        let nft = VE_NFT {
            token_id: 1,
            stake: coin::zero(),
            unlock_timestamp: timestamp::now_seconds(),
            epoch: 0,
            point_history: table::new(),
        };

        let _ = get_nft_history_point(&nft, 100);

        let nfts = table::new<u64, VE_NFT>();
        table::add(&mut nfts, nft.token_id, nft);

        move_to(&staker, NFTs {
            nfts
        });
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, multi_swap = @liquidswap, staker = @test_staker)]
    fun test_stake(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) acquires StakingPool {
        genesis::setup(&core);
        liquid::initialize(&multi_swap);
        initialize(&staking_admin);

        let to_mint_val = 20000000000;
        register_internal<LAMM>(&staker);
        liquid::mint_internal(&multi_swap, signer::address_of(&staker), to_mint_val);

        let to_stake_val = 2000000000;
        let to_stake = coin::withdraw<LAMM>(&staker, to_stake_val);

        let now = timestamp::now_seconds();
        let until = round_off_to_week_multiplier(now + WEEK);

        let nft = stake(to_stake, WEEK);
        assert!(nft.token_id == 1, 0);
        assert!(nft.unlock_timestamp == until, 1);

        let nft_point = get_nft_history_point(&nft, nft.epoch);
        assert!(table::length(&nft.point_history) == 1, 2);
        assert!(nft_point.power_drop_rate == (to_stake_val / MAX_LOCK_DURATION), 3);
        assert!(nft_point.voting_power == (nft_point.power_drop_rate * (until - now)), 4);
        assert!(nft_point.timestamp == now, 5);

        assert!(get_current_epoch() == 1, 6);
        assert!(get_id_counter() == 1, 7);

        let point = get_history_point(get_current_epoch());
        assert!(point.voting_power == nft_point.voting_power, 8);
        assert!(point.power_drop_rate == nft_point.power_drop_rate, 9);
        assert!(point.timestamp == now, 10);

        let m_slope = get_m_slope_for_test(until);
        assert!(m_slope == nft_point.power_drop_rate, 11);

        to_stake_val = 1000000000;
        to_stake = coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft_2 = stake(to_stake, WEEK * 208);
        assert!(get_current_epoch() == 2, 12);
        assert!(get_id_counter() == 2, 13);

        until = (now + WEEK * 208) / WEEK * WEEK;
        let nft_point2 = get_nft_history_point(&nft_2, nft_2.epoch);
        assert!(table::length(&nft.point_history) == 1, 14);
        assert!(nft_point2.power_drop_rate == (to_stake_val / MAX_LOCK_DURATION), 15);
        assert!(nft_point2.voting_power == (nft_point2.power_drop_rate * (until - now)), 16);
        assert!(nft_point2.timestamp == now, 17);

        let point2 = get_history_point(get_current_epoch());
        assert!(point2.voting_power == (nft_point.voting_power + nft_point2.voting_power), 18);
        assert!(point2.power_drop_rate == (nft_point.power_drop_rate + nft_point2.power_drop_rate), 19);
        assert!(point2.timestamp == now, 20);

        let m_slope = get_m_slope_for_test(until);
        assert!(m_slope == nft_point2.power_drop_rate, 21);

        let nfts = table::new<u64, VE_NFT>();
        table::add(&mut nfts, nft.token_id, nft);
        table::add(&mut nfts, nft_2.token_id, nft_2);

        move_to(&staker, NFTs {
            nfts
        });
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, multi_swap = @liquidswap, staker = @test_staker)]
    #[expected_failure(abort_code = 102)]
    fun test_stake_fails(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) acquires StakingPool {
        genesis::setup(&core);
        liquid::initialize(&multi_swap);
        initialize(&staking_admin);

        let to_mint_val = 20000000000;
        register_internal<LAMM>(&staker);
        liquid::mint_internal(&multi_swap, signer::address_of(&staker), to_mint_val);

        let to_stake_val = 1000000000;
        let to_stake = coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft = stake(to_stake, WEEK * 209);

        let nfts = table::new<u64, VE_NFT>();
        table::add(&mut nfts, nft.token_id, nft);

        move_to(&staker, NFTs {
            nfts
        });
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, multi_swap = @liquidswap, staker = @test_staker)]
    fun test_update(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) acquires StakingPool {
        genesis::setup(&core);
        liquid::initialize(&multi_swap);
        initialize(&staking_admin);

        update();

        assert!(get_current_epoch() == 1, 0);
        let now = timestamp::now_seconds();
        let point = get_history_point(get_current_epoch());

        assert!(point.power_drop_rate == 0, 1);
        assert!(point.voting_power == 0, 2);
        assert!(point.timestamp == now, 3);

        // Let's move time and check how history changes.
        now = (timestamp::now_seconds() + WEEK);
        timestamp::update_global_time_for_test(now * 1000000);

        update();

        assert!(get_current_epoch() == 2, 4);
        point = get_history_point(get_current_epoch());
        assert!(point.power_drop_rate == 0, 5);
        assert!(point.voting_power == 0, 6);
        assert!(point.timestamp == now, 7);

        // Let's stake and see how history changed.
        let to_mint_val = 20000000000;
        register_internal<LAMM>(&staker);
        liquid::mint_internal(&multi_swap, signer::address_of(&staker), to_mint_val);

        let to_stake_val_1 = 1000000000;
        let to_stake_1 = coin::withdraw<LAMM>(&staker, to_stake_val_1);
        let dur_1 = WEEK;
        let nft_1 = stake(to_stake_1, dur_1);
        let until_1 = now + dur_1;

        assert!(get_current_epoch() == 3, 8);
        point = get_history_point(get_current_epoch());
        assert!(point.power_drop_rate == to_stake_val_1 / MAX_LOCK_DURATION, 9);
        assert!(point.voting_power == point.power_drop_rate * (until_1 - now), 10);
        assert!(point.timestamp == now, 11);
        assert!(get_m_slope_for_test(until_1) == point.power_drop_rate, 12);

        update();

        // Let's check nothing changed.
        assert!(get_current_epoch() == 4, 13);
        let point_1 = get_history_point(get_current_epoch());
        assert!(point_1.power_drop_rate == to_stake_val_1 / MAX_LOCK_DURATION, 14);
        assert!(point_1.voting_power == point_1.power_drop_rate * (until_1 - now), 15);
        assert!(point_1.timestamp == now, 16);

        // Let's stake again.
        let to_stake_val_2 = 5000000000;
        let to_stake_2 = coin::withdraw<LAMM>(&staker, to_stake_val_2);
        let dur_2 = WEEK * 208;
        let nft_2 = stake(to_stake_2, dur_2);
        let until_2 = now + dur_2;

        let bias_sum = get_nft_history_point(&nft_1, 1).voting_power + get_nft_history_point(&nft_2, 1).voting_power;

        assert!(get_current_epoch() == 5, 17);
        let point_2 = get_history_point(get_current_epoch());

        assert!(point_2.power_drop_rate == point_1.power_drop_rate + (to_stake_val_2 / MAX_LOCK_DURATION), 18);
        assert!(point_2.voting_power == point_1.voting_power + ((to_stake_val_2 / MAX_LOCK_DURATION) * (until_2 - now)), 19);
        assert!(point_2.voting_power == bias_sum, 20);

        // Let's move time to half of week and check history.
        now = timestamp::now_seconds() + WEEK / 2;
        timestamp::update_global_time_for_test(now * 1000000);
        update();

        assert!(get_current_epoch() == 6, 21);
        let point_3 = get_history_point(get_current_epoch());
        // Slope is not changed yet.
        assert!(point_3.power_drop_rate == point_2.power_drop_rate, 22);
        assert!(point_3.voting_power == point_2.voting_power - (point_2.power_drop_rate * (now - point_2.timestamp)), 23);
        assert!(point_3.timestamp == now, 24);

        // Let's expire one stake and see how points changed.
        now = timestamp::now_seconds() + WEEK;
        timestamp::update_global_time_for_test(now * 1000000);
        update();

        assert!(get_current_epoch() == 8, 25); // Increased on 2, because week passed.
        let point_4 = get_history_point(get_current_epoch());
        assert!(point_4.power_drop_rate == (point_3.power_drop_rate - get_m_slope_for_test(until_1)), 26);

        // As we had already epoch on middle of the week, so we should calculate middle of the week
        // with old slope and another part of week with new slope.
        let new_slope = point_3.power_drop_rate - get_m_slope_for_test(until_1);
        let should_be_bias = point_3.voting_power - (point_3.power_drop_rate * (WEEK / 2));
        should_be_bias = should_be_bias - (new_slope * (WEEK / 2));
        assert!(point_4.voting_power == should_be_bias, 27);

        // Let's stake again for half of week.
        let to_stake_val_3 = 500000000;
        let to_stake_3 = coin::withdraw<LAMM>(&staker, to_stake_val_3);
        let dur_3 = WEEK / 2;
        let nft_3 = stake(to_stake_3, dur_3);

        // Let's expire everything and see how points changed.
        now = timestamp::now_seconds() + WEEK * 208;
        timestamp::update_global_time_for_test(now * 1000000);
        update();

        let point = get_history_point(get_current_epoch());
        assert!(point.voting_power == 0, 28);
        assert!(point.power_drop_rate == 0, 29);

        let nfts = table::new<u64, VE_NFT>();
        table::add(&mut nfts, nft_1.token_id, nft_1);
        table::add(&mut nfts, nft_2.token_id, nft_2);
        table::add(&mut nfts, nft_3.token_id, nft_3);

        move_to(&staker, NFTs {
            nfts
        });
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, multi_swap = @liquidswap, staker = @test_staker)]
    fun test_supply(core: signer, staking_admin: signer, multi_swap: signer, staker: signer)  acquires StakingPool {
        genesis::setup(&core);
        liquid::initialize(&multi_swap);
        initialize(&staking_admin);

        let supply = supply();
        assert!(supply == 0, 0);

        let to_mint_val = 20000000000;
        register_internal<LAMM>(&staker);
        liquid::mint_internal(&multi_swap, signer::address_of(&staker), to_mint_val);

        let to_stake_val_1 = 1000000000;
        let to_stake_1 = coin::withdraw<LAMM>(&staker, to_stake_val_1);
        let dur_1 = 208 * WEEK;
        let nft_1 = stake(to_stake_1, dur_1);

        let expected_supply = (to_stake_val_1 / MAX_LOCK_DURATION) * dur_1;

        supply = supply();
        assert!(supply == expected_supply, 1);

        // 1 week passed.
        let now = timestamp::now_seconds() + WEEK;
        timestamp::update_global_time_for_test(now * 1000000);

        expected_supply = (to_stake_val_1 / MAX_LOCK_DURATION) * (dur_1 - WEEK);
        supply = supply();
        assert!(supply == expected_supply, 2);

        // 104 weeks passed.
        now = timestamp::now_seconds() + WEEK * 103;
        timestamp::update_global_time_for_test(now * 1000000);

        expected_supply = (to_stake_val_1 / MAX_LOCK_DURATION) * (dur_1 - (WEEK * 104));
        supply = supply();
        assert!(supply == expected_supply, 3);

        // 208 weeks passed.
        now = timestamp::now_seconds() + WEEK * 104;
        timestamp::update_global_time_for_test(now * 1000000);
        // Nothing staked.
        assert!(supply() == 0, 4);

        let nfts = table::new<u64, VE_NFT>();
        table::add(&mut nfts, nft_1.token_id, nft_1);

        move_to(&staker, NFTs {
            nfts
        });
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, multi_swap = @liquidswap, staker = @test_staker)]
    fun test_update_stake(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) acquires StakingPool {
        genesis::setup(&core);
        liquid::initialize(&multi_swap);
        initialize(&staking_admin);

        let to_mint_val = 20000000000;
        register_internal<LAMM>(&staker);
        liquid::mint_internal(&multi_swap, signer::address_of(&staker), to_mint_val);

        let now = timestamp::now_seconds();
        let to_stake_val = 1000000000;
        let dist = WEEK * 208;
        let until = timestamp::now_seconds() + dist;
        let to_stake = coin::withdraw<LAMM>(&staker, to_stake_val);

        let rewards_val = 256000000;
        let rewards = coin::withdraw<LAMM>(&staker, rewards_val);

        let nft = stake(to_stake, dist);
        let token_id = nft.token_id;

        let slope = to_stake_val / MAX_LOCK_DURATION;
        let bias = slope * (until - now);

        let nft_point = get_nft_history_point(&nft, 1);
        assert!(nft_point.power_drop_rate == slope, 0);
        assert!(nft_point.voting_power == bias, 1);

        // Move time on one week and update stake.
        now = timestamp::now_seconds() + WEEK;
        timestamp::update_global_time_for_test(now * 1000000);
        update_stake(&mut nft, rewards);

        assert!(nft.epoch == 2, 2);
        assert!(coin::value(&nft.stake) == to_stake_val + rewards_val, 3);
        assert!(nft.token_id == token_id, 4);
        assert!(nft.unlock_timestamp == until, 5);

        let new_slope = (to_stake_val + rewards_val) / MAX_LOCK_DURATION;
        let new_bias = new_slope * (until - now);

        let nft_point = get_nft_history_point(&nft, 2);

        assert!(nft_point.voting_power == new_bias, 6);
        assert!(nft_point.power_drop_rate == new_slope, 7);
        assert!(nft_point.timestamp == now, 8);

        assert!(new_slope == get_m_slope_for_test(until), 9);

        let point = get_history_point(get_current_epoch());

        let old_bias = slope * (until - now);
        assert!(point.power_drop_rate == slope + (new_slope - slope), 10);
        assert!(point.voting_power == old_bias + (new_bias - old_bias), 11);
        assert!(point.timestamp == now, 12);

        // Move to 208 weeks and check update.
        now = timestamp::now_seconds() + WEEK * 208;
        timestamp::update_global_time_for_test(now * 1000000);

        rewards = coin::withdraw<LAMM>(&staker, rewards_val);
        update_stake(&mut nft, rewards);

        nft_point = get_nft_history_point(&nft, 3);
        assert!(nft_point.voting_power == 0, 14);
        assert!(nft_point.power_drop_rate == 0, 15);
        assert!(nft_point.timestamp == now, 16);

        point = get_history_point(get_current_epoch());
        assert!(point.power_drop_rate == 0, 17);
        assert!(point.voting_power == 0, 18);
        assert!(point.timestamp == now, 19);

        let nfts = table::new<u64, VE_NFT>();
        table::add(&mut nfts, nft.token_id, nft);

        move_to(&staker, NFTs {
            nfts
        });
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, multi_swap = @liquidswap, staker = @test_staker)]
    fun test_unstake(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) acquires StakingPool {
        genesis::setup(&core);
        liquid::initialize(&multi_swap);
        initialize(&staking_admin);

        let to_mint_val = 20000000000;
        register_internal<LAMM>(&staker);
        liquid::mint_internal(&multi_swap, signer::address_of(&staker), to_mint_val);

        let to_stake_val = 1000000000;
        let dist = WEEK;
        let to_stake = coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft = stake(to_stake, dist);

        let now = timestamp::now_seconds() + WEEK;
        timestamp::update_global_time_for_test(now * 1000000);

        let unstaked = unstake(nft, false);
        assert!(coin::value(&unstaked) == to_stake_val, 0);

        coin::deposit(signer::address_of(&staker), unstaked);

        to_stake = coin::withdraw<LAMM>(&staker, to_stake_val);
        nft = stake(to_stake, dist);

        let reward_val = 256000000;
        let reward = coin::withdraw<LAMM>(&staker, reward_val);

        now = timestamp::now_seconds() + WEEK;
        timestamp::update_global_time_for_test(now * 1000000);
        update_stake(&mut nft, reward);

        unstaked = unstake(nft, true);
        assert!(coin::value(&unstaked) == (to_stake_val + reward_val), 1);
        coin::deposit(signer::address_of(&staker), unstaked);
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, multi_swap = @liquidswap, staker = @test_staker)]
    #[expected_failure(abort_code = 104)]
    fun test_unstake_fail_early(
        core: signer,
        staking_admin: signer,
        multi_swap: signer,
        staker: signer
    ) acquires StakingPool {
        genesis::setup(&core);
        liquid::initialize(&multi_swap);
        initialize(&staking_admin);

        let to_mint_val = 20000000000;
        register_internal<LAMM>(&staker);
        liquid::mint_internal(&multi_swap, signer::address_of(&staker), to_mint_val);

        let to_stake_val = 1000000000;
        let dist = WEEK;
        let to_stake = coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft = stake(to_stake, dist);
        let unstaked = unstake(nft, false);

        coin::deposit(signer::address_of(&staker), unstaked);
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, multi_swap = @liquidswap, staker = @test_staker)]
    #[expected_failure(abort_code = 105)]
    fun test_unstake_fail_has_rewards(
        core: signer,
        staking_admin: signer,
        multi_swap: signer,
        staker: signer
    ) acquires StakingPool {
        genesis::setup(&core);
        liquid::initialize(&multi_swap);
        initialize(&staking_admin);

        let to_mint_val = 20000000000;
        register_internal<LAMM>(&staker);
        liquid::mint_internal(&multi_swap, signer::address_of(&staker), to_mint_val);

        let to_stake_val = 1000000000;
        let dist = WEEK;
        let to_stake = coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft = stake(to_stake, dist);

        let now = timestamp::now_seconds() + WEEK;
        timestamp::update_global_time_for_test(now * 1000000);

        let unstaked = unstake(nft, true);

        coin::deposit(signer::address_of(&staker), unstaked);
    }

    #[test(core = @core_resources, staking_admin = @staking_pool, multi_swap = @liquidswap, staker = @test_staker)]
    fun end_to_end(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) acquires StakingPool {
        genesis::setup(&core);

        liquid::initialize(&multi_swap);

        initialize(&staking_admin);

        let current_epoch = get_current_epoch();
        assert!(current_epoch == 0, 0);

        let point = get_history_point(current_epoch);
        assert!(point.timestamp == timestamp::now_seconds(), 1);
        assert!(point.voting_power == 0, 2);
        assert!(point.power_drop_rate == 0, 3);

        let to_mint_val = 10000000000;
        register_internal<LAMM>(&staker);
        liquid::mint_internal(&multi_swap, signer::address_of(&staker), to_mint_val);

        let to_stake_val = 1000000000;
        let to_stake = coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft = stake(to_stake, WEEK);

        let now = timestamp::now_seconds();
        let until = (now + WEEK) / WEEK * WEEK;

        let nft_point = get_nft_history_point(&nft, nft.epoch);
        assert!(nft_point.power_drop_rate == (to_stake_val / MAX_LOCK_DURATION), 4);
        assert!(nft_point.voting_power == (nft_point.power_drop_rate * (until - now)), 5);

        current_epoch = get_current_epoch();
        assert!(current_epoch == 1, 6);

        let new_time = (now + WEEK) * 1000000;
        timestamp::update_global_time_for_test(new_time);
        update();
        current_epoch = get_current_epoch();
        assert!(current_epoch == 2, 7);
        point = get_history_point(current_epoch);
        assert!(point.voting_power == 0, 8);
        assert!(point.power_drop_rate == 0, 9);
        assert!(point.timestamp == WEEK, 10);

        let nfts = table::new<u64, VE_NFT>();
        table::add(&mut nfts, nft.token_id, nft);

        move_to(&staker, NFTs {
            nfts
        });
    }
}
