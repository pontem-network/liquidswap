// Voting Escrow.
module MultiSwap::VE {
    use Std::Signer;

    use AptosFramework::Coin::Coin;
    use AptosFramework::Coin;
    use AptosFramework::Table::Table;
    use AptosFramework::Table;
    use AptosFramework::Timestamp;

    use MultiSwap::Liquid::LAMM;

    const ERR_POOL_EXISTS: u64 = 100;
    const ERR_WRONG_INITIALIZER: u64 = 101;
    const ERR_DURATION_MORE_THAN_MAX_TIME: u64 = 102;

    // One week in seconds.
    const WEEK: u64 = 604800;

    // Max stacking time (~4 years).
    const MAX_TIME: u64 = 4 * 365 * 86400;

    // Staking history point.
    struct Point has store, drop, copy {
        bias: u64,
        slope: u64,
        ts: u64,
    }

    // Staking pool.
    struct StakingPool has key {
        token_id_counter: u64,
        current_epoch: u64,
        point_history: Table<u64, Point>,
        m_slope: Table<u64, u64>, // The slope value that we should minus later when time happens.
    }

    // Our NFT position.
    struct NFT has store {
        token_id: u64,
        stake: Coin<LAMM>,
        unlock_time: u64,
        bias: u64,
        slope: u64,
    }

    // Initialize staking pool.
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
            point_history,
            m_slope: Table::new(),
        });
    }

    // Stake LAMM coins and get locked position.
    public fun stake(coins: Coin<LAMM>, lock_duration: u64): NFT acquires StakingPool {
        let pool = borrow_global_mut<StakingPool>(@StakingPool);

        let now = Timestamp::now_seconds();
        let unlock_time = (now + lock_duration) / WEEK * WEEK;

        assert!((unlock_time - now) <= MAX_TIME, ERR_DURATION_MORE_THAN_MAX_TIME);

        pool.token_id_counter = pool.token_id_counter + 1;

        let m_slope = Table::borrow_mut_with_default(&mut pool.m_slope, unlock_time, 0);

        let coins_value = Coin::value(&coins);
        let u_slope = coins_value / MAX_TIME;
        let u_bias = u_slope * (unlock_time - now);

        let last_point = Table::borrow_mut(&mut pool.point_history, pool.current_epoch);
        last_point.bias = last_point.bias + u_bias;
        last_point.slope = last_point.slope + u_slope;

        *m_slope = *m_slope + u_slope;

        let nft = NFT {
            token_id: pool.token_id_counter,
            stake: coins,
            unlock_time,
            bias: u_bias,
            slope: u_slope,
        };

        update_internal(pool);

        nft
    }

    // Get staked supply.
    public fun supply(): u64 acquires StakingPool {
        let pool = borrow_global<StakingPool>(@StakingPool);
        let last_point = *Table::borrow(&pool.point_history, pool.current_epoch);

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

            last_point.bias = reduce_bias(&last_point, (t_i - last_point.ts));

            if (t_i == now) {
                break
            };

            last_point.slope = last_point.slope - m_slope;
            last_point.ts = t_i;
        };

        last_point.bias
    }

    // Update history public func.
    public fun update() acquires StakingPool {
        let pool = borrow_global_mut<StakingPool>(@StakingPool);

        update_internal(pool);
    }

    // Update history internal.
    fun update_internal(pool: &mut StakingPool) {
        let last_point = *Table::borrow(&pool.point_history, pool.current_epoch);
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

            last_point.bias = reduce_bias(&last_point, (t_i - last_checkpoint));
            last_point.slope = last_point.slope - m_slope;

            last_checkpoint = t_i;
            last_point.ts = t_i;
            epoch = epoch + 1;

            if (t_i == now) {
                break
            } else {
                Table::add(&mut pool.point_history, epoch, last_point);
            };
        };

        pool.current_epoch = epoch;

        if (!Table::contains(&pool.point_history, pool.current_epoch)) {
            Table::add(&mut pool.point_history, pool.current_epoch, last_point);
        } else {
            let point = Table::borrow_mut(&mut pool.point_history, pool.current_epoch);

            point.slope = last_point.slope;
            point.bias = last_point.bias;
            point.ts = last_point.ts;
        };
    }

    // Reducing bias, should return 0 if can't minus.
    fun reduce_bias(point: &Point, time_diff: u64): u64 {
        let r = point.slope * time_diff;

        if (point.bias < r) {
            0
        } else {
            point.bias - r
        }
    }

    // Returns m_slop from m_slope or 0.
    fun get_m_slope(pool: &StakingPool, timestamp: u64): u64 {
        if (Table::contains(&pool.m_slope, timestamp)) {
            *Table::borrow(&pool.m_slope, timestamp)
        } else {
            0
        }
    }

    // Get current epoch.
    public fun get_current_epoch(): u64 acquires StakingPool {
        borrow_global<StakingPool>(@StakingPool).current_epoch
    }

    // Get position id.
    public fun get_id(nft: &NFT): u64 {
        nft.token_id
    }

    // Returns staked value.
    public fun get_staked_value(nft: &NFT): u64 {
        Coin::value(&nft.stake)
    }

    // Returns unlock time.
    public fun get_unlock_time(nft: &NFT): u64 {
        nft.unlock_time
    }

    #[test_only]
    use AptosFramework::Genesis;
    #[test_only]
    use MultiSwap::Liquid;
    #[test_only]
    use AptosFramework::Coin::register_internal;
    #[test_only]
    use Std::Debug;

    #[test_only]
    struct NFTs has key {
        nfts: Table<u64, NFT>,
    }

    #[test_only]
    public fun get_history_point(epoch: u64): Point acquires StakingPool {
        let pool = borrow_global<StakingPool>(@StakingPool);

        assert!(Table::contains(&pool.point_history, epoch), 201);

        *Table::borrow(&pool.point_history, epoch)
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    public fun end_to_end(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) acquires StakingPool {
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

        assert!(nft.slope == (to_stake_val / MAX_TIME), 3);
        assert!(nft.bias == (nft.slope * (until - now)), 4);

        current_epoch = get_current_epoch();
        assert!(current_epoch == 1, 5);

        let new_time = (now + WEEK) * 1000000;
        Timestamp::update_global_time_for_test(new_time);
        update();
        current_epoch = get_current_epoch();
        assert!(current_epoch == 2, 6);
        point = get_history_point(current_epoch);
        Debug::print(&point);
        assert!(point.bias == 0, 7);
        assert!(point.slope == 0, 8);
        assert!(point.ts == WEEK, 9);

        let nfts = Table::new<u64, NFT>();
        Table::add(&mut nfts, nft.token_id, nft);

        move_to(&staker, NFTs {
            nfts
        });
    }

}
