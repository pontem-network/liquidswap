/// The module describing NFTized staking position (Voting Escrow).
/// The staking position could be transfered between account, used for voting, etc.
/// Detailed explanation of VE standard: https://curve.readthedocs.io/dao-vecrv.html
module MultiSwap::VE {
    use Std::Signer;

    use AptosFramework::Coin::Coin;
    use AptosFramework::Coin;
    use AptosFramework::Table::Table;
    use AptosFramework::Table;
    use AptosFramework::Timestamp;

    use MultiSwap::Liquid::LAMM;

    friend MultiSwap::Distribution;

    /// Constants.

    // Errors.

    /// When staking pool already exists.
    const ERR_POOL_EXISTS: u64 = 100;

    /// When wrong account initializing staking pool.
    const ERR_WRONG_INITIALIZER: u64 = 101;

    /// When user tried to stake for time more than 4 years (see `MAX_TIME`).
    const ERR_DURATION_MORE_THAN_MAX_TIME: u64 = 102;

    /// When no key found in Table.
    const ERR_KEY_NOT_FOUND: u64 = 103;

    // One week in seconds.
    const WEEK: u64 = 604800;

    // Max stacking time (~4 years).
    const MAX_TIME: u64 = 4 * 365 * 86400;

    /// Represents a staking history point.
    struct Point has store, drop, copy {
        bias: u64,
        slope: u64,
        ts: u64, // Time when point created.
    }

    /// Represents staking pool.
    struct StakingPool has key {
        token_id_counter: u64, // ID counter for new VE NFTs.
        current_epoch: u64, // Current history epoch.
        history_points: Table<u64, Point>, // History points: <epoch, point>.
        m_slope: Table<u64, u64>, // The historical slope changes we should take into account during each new epoch.
    }

    /// Represents VE NFT itself.
    /// Can't be dropped or cloned, only stored.
    struct VE_NFT has store {
        token_id: u64, // ID of the current NFT.
        stake: Coin<LAMM>, // Stake.
        unlock_time: u64, // Time when NFT could be reedemed.

        // Local history of VE_NFT.
        epoch: u64, // The current epoch, when last slope/bias change happened.
        history_points: Table<u64, Point>, // History points: <epoch, point>.
    }

    // Public functions.

    /// Initialize staking pool.
    /// Can be called only by @StakingPool address.
    /// Should be called first and immidiatelly after deploy.
    public fun initialize(account: &signer) {
        assert!(!exists<StakingPool>(@StakingPool), ERR_POOL_EXISTS);
        assert!(Signer::address_of(account) == @StakingPool, ERR_WRONG_INITIALIZER);

        let point_history = Table::new();
        Table::add(&mut point_history, 0, Point {
            bias: 0,
            slope: 0,
            ts: Timestamp::now_seconds(),
        });

        move_to(account, StakingPool {
            token_id_counter: 0,
            current_epoch: 0,
            history_points: point_history,
            m_slope: Table::new(),
        });
    }

    /// Stake LAMM coins for lock_duration seconds.
    public fun stake(coins: Coin<LAMM>, lock_duration: u64): VE_NFT acquires StakingPool {
        let pool = borrow_global_mut<StakingPool>(@StakingPool);

        let now = Timestamp::now_seconds();
        let unlock_time = (now + lock_duration) / WEEK * WEEK;

        assert!((unlock_time - now) <= MAX_TIME, ERR_DURATION_MORE_THAN_MAX_TIME);

        pool.token_id_counter = pool.token_id_counter + 1;

        let coins_value = Coin::value(&coins);
        let u_slope = coins_value / MAX_TIME;
        let u_bias = u_slope * (unlock_time - now);

        let last_point = Table::borrow_mut(&mut pool.history_points, pool.current_epoch);
        last_point.bias = last_point.bias + u_bias;
        last_point.slope = last_point.slope + u_slope;

        update_internal(pool);

        let m_slope = Table::borrow_mut_with_default(&mut pool.m_slope, unlock_time, 0);
        *m_slope = *m_slope + u_slope;

        let u_epoch = 1;
        let user_point_history = Table::new();

        Table::add(&mut user_point_history, u_epoch, Point {
            bias: u_bias,
            slope: u_slope,
            ts: now,
        });

        let nft = VE_NFT {
            token_id: pool.token_id_counter,
            stake: coins,
            unlock_time,
            epoch: u_epoch,
            history_points: user_point_history,
        };

        nft
    }

    public fun unstake(nft: VE_NFT): Coin<LAMM> acquires StakingPool {
        // probably if we still have bias and slope we should revert, as it means there is still rewards on nft.
        let pool = borrow_global_mut<StakingPool>(@StakingPool);

        let now = Timestamp::now_seconds();
        assert!(now >= nft.unlock_time, 0);

        // double check we don't have to update m_slope and etc.
        update_internal(pool);

        let VE_NFT {
            token_id: _,
            stake,
            unlock_time: _,
            epoch,
            history_points: point_history,
        } = nft;

        let i = 1;
        while (i <= epoch) { // i doubt it can more than 208 iterations
            Table::remove(&mut point_history, i);
            i = i + 1;
        };
        Table::destroy_empty(point_history);

        stake
    }

    /// Get VE NFT supply (staked supply).
    public fun supply(): u64 acquires StakingPool {
        let pool = borrow_global<StakingPool>(@StakingPool);
        let last_point = *Table::borrow(&pool.history_points, pool.current_epoch);

        let now = Timestamp::now_seconds();
        let t_i = last_point.ts / WEEK * WEEK;
        let i = 0;
        while (i < 255) {
            i = i + 1;
            t_i = t_i + WEEK;

            let m_slope = 0;
            if (t_i > now) {
                t_i = now;
            } else {
                m_slope = get_m_slope(pool, t_i);
            };

            last_point.bias = calc_bias(&last_point, (t_i - last_point.ts));

            if (t_i == now) {
                break
            };

            last_point.slope = last_point.slope - m_slope;
            last_point.ts = t_i;
        };

        last_point.bias
    }

    /// Creates a new epoch and update historical points.
    public fun update() acquires StakingPool {
        let pool = borrow_global_mut<StakingPool>(@StakingPool);

        update_internal(pool);
    }

    /// Creating a new `Point` filled with zeros.
    public fun zero_point(): Point {
        Point {
            bias: 0,
            slope: 0,
            ts: 0,
        }
    }

    // Internal & friend funcs.

    // It updates stake (VE NFT) with new coins (rewards or just transfered).
    // I think it should be public and called merge.
    // Yet let's close the rest of things, cover with tests, etc.
    public(friend) fun update_stake(nft: &mut VE_NFT, coins: Coin<LAMM>) acquires StakingPool {
        let pool = borrow_global_mut<StakingPool>(@StakingPool);

        let coins_value = Coin::value(&coins);
        assert!(coins_value > 0, 0);

        let old_locked = Coin::value(&nft.stake);
        let new_locked = coins_value + old_locked;

        let locked_end = nft.unlock_time;
        let now = Timestamp::now_seconds();

        let u_old_slope = 0;
        let u_old_bias = 0;

        if (locked_end > now && old_locked > 0) {
            u_old_slope = old_locked / MAX_TIME;
            u_old_bias = u_old_slope * (locked_end - now);
        };

        let u_new_slope = 0;
        let u_new_bias = 0;

        if (locked_end > now && new_locked > 0) {
            u_new_slope = new_locked / MAX_TIME;
            u_new_bias = u_new_slope * (locked_end - now);
        };

        let old_dslope = get_m_slope(pool, locked_end);

        let last_point = Table::borrow_mut(&mut pool.history_points, pool.current_epoch);
        last_point.bias = last_point.bias + (u_new_slope - u_old_slope);
        last_point.slope = last_point.slope + (u_new_bias - u_old_bias);

        update_internal(pool);

        if (old_locked > now) {
            let m_slope = Table::borrow_mut_with_default(&mut pool.m_slope, locked_end, 0);
            *m_slope = old_dslope - u_old_slope + u_new_slope; // maybe: old_dslope - u_old_slope + u_new_slope?
        };

        nft.epoch = nft.epoch + 1;
        let new_point = Point {
            slope: u_new_slope,
            bias: u_new_bias,
            ts: now,
        };

        Table::add(&mut nft.history_points, nft.epoch, new_point);
        Coin::merge(&mut nft.stake, coins);
    }

    // Update history internal.
    fun update_internal(pool: &mut StakingPool) {
        let last_point = *Table::borrow(&pool.history_points, pool.current_epoch);
        let now = Timestamp::now_seconds();

        let last_checkpoint = last_point.ts;
        let t_i = last_checkpoint / WEEK * WEEK;
        let epoch = pool.current_epoch;

        let i = 0;
        while (i < 255) {
            i = i + 1;

            t_i = t_i + WEEK;

            let m_slope = 0;
            if (t_i > now) {
                t_i = now;
            } else {
                m_slope = get_m_slope(pool, t_i);
            };

            last_point.bias = calc_bias(&last_point, (t_i - last_checkpoint));
            last_point.slope = last_point.slope - m_slope;

            last_checkpoint = t_i;
            last_point.ts = t_i;
            epoch = epoch + 1;

            if (t_i == now) {
                break
            } else {
                Table::add(&mut pool.history_points, epoch, last_point);
            };
        };

        pool.current_epoch = epoch;

        if (!Table::contains(&pool.history_points, pool.current_epoch)) {
            Table::add(&mut pool.history_points, pool.current_epoch, last_point);
        } else {
            let point = Table::borrow_mut(&mut pool.history_points, pool.current_epoch);

            point.slope = last_point.slope;
            point.bias = last_point.bias;
            point.ts = last_point.ts;
        };
    }

    /// Get m_slope value with default value equal zero.
    fun get_m_slope(pool: &StakingPool, timestamp: u64): u64 {
        if (Table::contains(&pool.m_slope, timestamp)) {
            *Table::borrow(&pool.m_slope, timestamp)
        } else {
            0
        }
    }

    // Getters funcs.

    /// Calculates new bias: Math.max(point.bias - point.slope * time_diff, 0);
    /// Bias can't go under zero, so we should check if we can substrate point * slope
    /// from bias or just replace it with zero.
    public fun calc_bias(point: &Point, time_diff: u64): u64 {
        let r = point.slope * time_diff;

        if (point.bias < r) {
            0
        } else {
            point.bias - r
        }
    }

    /// Get current epoch.
    public fun get_current_epoch(): u64 acquires StakingPool {
        borrow_global<StakingPool>(@StakingPool).current_epoch
    }

    /// Get history point.
    public fun get_history_point(epoch: u64): Point acquires StakingPool {
        let pool = borrow_global<StakingPool>(@StakingPool);

        assert!(Table::contains(&pool.history_points, epoch), ERR_KEY_NOT_FOUND);

        *Table::borrow(&pool.history_points, epoch)
    }

    // VE NFT getters.

    /// Get VE NFT id.
    public fun get_nft_id(nft: &VE_NFT): u64 {
        nft.token_id
    }

    /// Get VE NFT staked value.
    public fun get_nft_staked_value(nft: &VE_NFT): u64 {
        Coin::value(&nft.stake)
    }

    /// Get VE NFT unlock time (timestamp).
    public fun get_nft_unlock_time(nft: &VE_NFT): u64 {
        nft.unlock_time
    }

    /// Get current VE NFT epoch.
    public fun get_nft_epoch(nft: &VE_NFT): u64 {
        nft.epoch
    }

    /// Get VE NFT history point.
    public fun get_nft_history_point(nft: &VE_NFT, epoch: u64): Point {
        assert!(Table::contains(&nft.history_points, epoch), ERR_KEY_NOT_FOUND);

        *Table::borrow(&nft.history_points, epoch)
    }

    // Point getters.

    /// Get a time when Point created.
    public fun get_point_ts(point: &Point): u64 {
        point.ts
    }

    /// Get a bias value of Point.
    public fun get_point_bias(point: &Point): u64 {
        point.bias
    }

    /// Get a slope value of Point.
    public fun get_point_slope(point: &Point): u64 {
        point.slope
    }

    // Tests.

    #[test_only]
    use AptosFramework::Genesis;
    #[test_only]
    use MultiSwap::Liquid;
    #[test_only]
    use AptosFramework::Coin::register_internal;

    #[test_only]
    struct NFTs has key {
        nfts: Table<u64, VE_NFT>,
    }

    #[test]
    fun test_zero_point() {
        let point = zero_point();
        assert!(point.slope == 0, 0);
        assert!(point.bias == 0, 1);
        assert!(point.ts == 0, 2);
    }

    #[test]
    fun test_reduce_bias() {
        let point = Point {
            bias: 32,
            slope: 7,
            ts: 0,
        };

        let new_bias = calc_bias(&point, 5);
        assert!(new_bias == 0, 0);

        let new_bias = calc_bias(&point, 1);
        assert!(new_bias == 25, 1);
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap)]
    fun test_initialize(core: signer, staking_admin: signer, multi_swap: signer) acquires StakingPool {
        Genesis::setup(&core);
        Liquid::initialize(&multi_swap);

        initialize(&staking_admin);

        let stacker_admin_addr = Signer::address_of(&staking_admin);
        let pool = borrow_global<StakingPool>(stacker_admin_addr);

        assert!(pool.current_epoch == 0, 0);
        assert!(pool.token_id_counter == 0, 1);
        assert!(Table::length(&pool.m_slope) == 0, 2);
        assert!(Table::length(&pool.history_points) == 1, 3);

        let point = Table::borrow(&pool.history_points, 0);
        assert!(point.ts == Timestamp::now_seconds(), 5);
        assert!(point.slope == 0, 5);
        assert!(point.bias == 0, 6);

        assert!(get_current_epoch() == 0, 7);
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap)]
    #[expected_failure(abort_code = 100)]
    fun test_initialize_fail(core: signer, staking_admin: signer, multi_swap: signer) {
        Genesis::setup(&core);
        Liquid::initialize(&multi_swap);

        initialize(&staking_admin);
        initialize(&staking_admin);
    }

    #[test(core = @CoreResources, multi_swap = @MultiSwap)]
    #[expected_failure(abort_code = 101)]
    fun test_initialize_wrong_account(core: signer, multi_swap: signer) {
        Genesis::setup(&core);
        Liquid::initialize(&multi_swap);

        initialize(&multi_swap);
    }

    #[test(core = @CoreResources, multi_swap = @MultiSwap, staker = @TestStaker)]
    public fun test_nft_getters(core: signer, multi_swap: signer, staker: signer) {
        Genesis::setup(&core);
        Liquid::initialize(&multi_swap);

        let to_mint_val = 10000000000;
        register_internal<LAMM>(&staker);
        Liquid::mint(&multi_swap, Signer::address_of(&staker), to_mint_val);

        let to_stake_val = 1000000000;
        let to_stake = Coin::withdraw<LAMM>(&staker, to_stake_val);

        let now = Timestamp::now_seconds();

        let history_points = Table::new();
        let epoch = 523;
        Table::add(&mut history_points, epoch, Point {
            bias: 50,
            slope: 250,
            ts: now,
        });

        let nft = VE_NFT {
            token_id: 100,
            stake: to_stake,
            unlock_time: Timestamp::now_seconds(),
            epoch,
            history_points,
        };

        assert!(get_nft_id(&nft) == 100, 0);
        assert!(get_nft_staked_value(&nft) == to_stake_val, 1);
        assert!(get_nft_unlock_time(&nft) == now, 2);
        assert!(get_nft_epoch(&nft) == epoch, 3);

        let point = get_nft_history_point(&nft, epoch);

        assert!(point.bias == 50, 4);
        assert!(point.slope == 250, 5);
        assert!(point.ts == now, 6);

        let nfts = Table::new<u64, VE_NFT>();
        Table::add(&mut nfts, nft.token_id, nft);

        move_to(&staker, NFTs {
            nfts
        });
    }

    #[test(core = @CoreResources, staker = @TestStaker)]
    #[expected_failure(abort_code = 103)]
    fun test_get_nft_history_point_fail(core: signer, staker: signer) {
        Timestamp::set_time_has_started_for_testing(&core);

        let nft = VE_NFT {
            token_id: 1,
            stake: Coin::zero(),
            unlock_time: Timestamp::now_seconds(),
            epoch: 0,
            history_points: Table::new(),
        };

        let _ = get_nft_history_point(&nft, 100);

        let nfts = Table::new<u64, VE_NFT>();
        Table::add(&mut nfts, nft.token_id, nft);

        move_to(&staker, NFTs {
            nfts
        });
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    fun end_to_end(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) acquires StakingPool {
        Genesis::setup(&core);

        Liquid::initialize(&multi_swap);

        initialize(&staking_admin);

        let current_epoch = get_current_epoch();
        assert!(current_epoch == 0, 0);

        let point = get_history_point(current_epoch);
        assert!(point.ts == Timestamp::now_seconds(), 1);
        assert!(point.bias == 0, 1);
        assert!(point.slope == 0, 2);

        let to_mint_val = 10000000000;
        register_internal<LAMM>(&staker);
        Liquid::mint(&multi_swap, Signer::address_of(&staker), to_mint_val);

        let to_stake_val = 1000000000;
        let to_stake = Coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft = stake(to_stake, WEEK);

        let now = Timestamp::now_seconds();
        let until = (now + WEEK) / WEEK * WEEK;

        let nft_point = get_nft_history_point(&nft, nft.epoch);
        assert!(nft_point.slope == (to_stake_val / MAX_TIME), 3);
        assert!(nft_point.bias == (nft_point.slope * (until - now)), 4);

        current_epoch = get_current_epoch();
        assert!(current_epoch == 1, 5);

        let new_time = (now + WEEK) * 1000000;
        Timestamp::update_global_time_for_test(new_time);
        update();
        current_epoch = get_current_epoch();
        assert!(current_epoch == 2, 6);
        point = get_history_point(current_epoch);
        assert!(point.bias == 0, 7);
        assert!(point.slope == 0, 8);
        assert!(point.ts == WEEK, 9);

        let nfts = Table::new<u64, VE_NFT>();
        Table::add(&mut nfts, nft.token_id, nft);

        move_to(&staker, NFTs {
            nfts
        });
    }

}
