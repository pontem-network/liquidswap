/// The module describing NFTized staking position (Voting Escrow).
/// The staking position could be transfered between accounts, used for voting, etc.
/// Detailed explanation of VE standard: https://curve.readthedocs.io/dao-vecrv.html
module liquidswap::ve {
    use std::signer;

    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::table_with_length::{Self, TableWithLength};

    use liquidswap::liquid::LAMM;

    // Errors.

    /// When staking pool already exists.
    const ERR_POOL_EXISTS: u64 = 100;

    /// When wrong account initializing staking pool.
    const ERR_WRONG_INITIALIZATION_ACCOUNT: u64 = 101;

    /// When user tried to stake for time more than 4 years (see `MAX_TIME`).
    const ERR_DURATION_MORE_THAN_MAX_TIME: u64 = 102;

    /// When no key found in TableWithLength.
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
        point_history: TableWithLength<u64, Point>,
        // The historical slope changes we should take into account during each new epoch.
        change_rate_history: TableWithLength<u64, u64>,
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
        point_history: TableWithLength<u64, Point>,
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

        let point_history = table_with_length::new();
        table_with_length::add(&mut point_history, 0, Point {
            voting_power: 0,
            power_drop_rate: 0,
            timestamp: timestamp::now_seconds(),
        });

        move_to(account, StakingPool {
            token_id_counter: 0,
            current_epoch: 0,
            point_history,
            change_rate_history: table_with_length::new(),
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

        let last_point = table_with_length::borrow_mut(&mut pool.point_history, pool.current_epoch);
        last_point.power_drop_rate = last_point.power_drop_rate + u_power_drop_rate;
        last_point.voting_power = last_point.voting_power + u_voting_power;

        let change_rate_at_unlock_ts =
            table_with_length::borrow_mut_with_default(&mut pool.change_rate_history, unlock_timestamp, 0);
        *change_rate_at_unlock_ts = *change_rate_at_unlock_ts + u_power_drop_rate;

        let start_epoch = 1;
        let user_point_history = table_with_length::new();
        table_with_length::add(&mut user_point_history, start_epoch, Point {
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
            table_with_length::remove(&mut point_history, i);
            i = i + 1;
        };
        table_with_length::destroy_empty(point_history);

        stake
    }

    /// Get `VE_NFT` supply (staked supply).
    public fun supply(): u64 acquires StakingPool {
        let pool = borrow_global<StakingPool>(@staking_pool);
        let last_point = *table_with_length::borrow(&pool.point_history, pool.current_epoch);

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
    /// yet we really can't at this stage, as history table_with_length can become too large
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
        let last_point = table_with_length::borrow_mut(&mut pool.point_history, pool.current_epoch);
        last_point.power_drop_rate = last_point.power_drop_rate + (u_new_slope - u_old_slope);
        last_point.voting_power = last_point.voting_power + (u_new_bias - u_old_bias);

        let old_dslope = get_drop_rate_at_timestamp(pool, locked_end);
        if (old_locked > now) {
            let m_slope = table_with_length::borrow_mut_with_default(&mut pool.change_rate_history, locked_end, 0);
            *m_slope = old_dslope - u_old_slope + u_new_slope; // maybe: old_dslope - u_old_slope + u_new_slope?
        };

        nft.epoch = nft.epoch + 1;
        let new_point = Point {
            power_drop_rate: u_new_slope,
            voting_power: u_new_bias,
            timestamp: now,
        };

        table_with_length::add(&mut nft.point_history, nft.epoch, new_point);
        coin::merge(&mut nft.stake, coins);
    }

    /// Filling history with new epochs, always adding at least one epoch and history point.
    /// `pool` - staking pool to update.
    fun update_internal(pool: &mut StakingPool) {
        let last_point = *table_with_length::borrow(&pool.point_history, pool.current_epoch);

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
                table_with_length::add(&mut pool.point_history, epoch, last_point);
            };

            i = i + 1;
        };

        pool.current_epoch = epoch;

        let new_point =
            table_with_length::borrow_mut_with_default(&mut pool.point_history, pool.current_epoch, zero_point());
        new_point.power_drop_rate = last_point.power_drop_rate;
        new_point.voting_power = last_point.voting_power;
        new_point.timestamp = last_point.timestamp;
    }

    /// Get m_slope value with default value equal zero.
    /// `timestamp` - as m_slope stored by timestamps, we should provide time.
    fun get_drop_rate_at_timestamp(pool: &StakingPool, timestamp: u64): u64 {
        if (table_with_length::contains(&pool.change_rate_history, timestamp)) {
            *table_with_length::borrow(&pool.change_rate_history, timestamp)
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

        assert!(table_with_length::contains(&pool.point_history, epoch), ERR_KEY_NOT_FOUND);

        *table_with_length::borrow(&pool.point_history, epoch)
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
        assert!(table_with_length::contains(&nft.point_history, epoch), ERR_KEY_NOT_FOUND);

        *table_with_length::borrow(&nft.point_history, epoch)
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
}
