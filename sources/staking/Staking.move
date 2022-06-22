// Staking contract similar to Solidly, it's work in progress.
module MultiSwap::Staking {
    use Std::Signer;

    use AptosFramework::Timestamp;
    use AptosFramework::Coin::{Self, Coin, MintCapability};

    use MultiSwap::Liquid::LAMM;
    use MultiSwap::CoinHelper;
    use MultiSwap::Math;

    // Errors.
    const ERR_WRONG_DURATION: u64 = 100;
    const ERR_EARLY_UNLOCK: u64 = 101;
    const ERR_POOL_DOESNT_EXIST: u64 = 102;
    const ERR_POOL_EXISTS: u64 = 103;
    const ERR_STAKE_LESS_THAN_MIN: u64 = 104;
    const ERR_WRONG_STAKING_POOL_ADDR: u64 = 105;

    // Constants.

    // TODO: events.

    // TODO: change minimum stake later.
    const MINIMUM_STAKE_VALUE: u64 = 1000000;

    // Durations.

    // Describing possible durations as u8 numbers (e.g. similar to enums).
    /// One week.
    const D_WEEK: u8 = 0;
    /// One month.
    const D_MONTH: u8 = 1;
    /// One year.
    const D_YEAR: u8 = 2;
    /// Four years.
    const D_FOUR_YEARS: u8 = 3;

    // Different durations (week, month, etc) in seconds.

    // TODO: convert errors to Std:Error.

    /// One week in seconds.
    const SECONDS_IN_WEEK: u64 = 604800u64;
    /// One month in seconds.
    const SECONDS_IN_MONTH: u64 = 2630000u64;
    /// One year in seconds.
    const SECONDS_IN_YEAR: u64 = 31536000u64;
    /// Four years in seconds.
    const SECONDS_IN_FOUR_YEAR: u64 = 126144000u64;

    /// The resource describing staking pool.
    struct StakingPool has key {
        mint_cap: MintCapability<LAMM>,

        period: u64,

        weekly_emission: u64,
        total_staked: u64,

        rewards: Coin<LAMM>,

        id_counter: u128,
    }

    /// The resource describing staking position.
    struct Position has store {
        id: u128,
        created_at: u64,
        till: u64,
        stake: Coin<LAMM>,
    }

    /// Create a new staking pool, the staking pool will be stored on staking admin account.
    /// Only StakingAdmin can call it.
    /// * `mint_cap` - mint capability for LAMM coin.
    public fun create_pool(account: &signer, mint_cap: MintCapability<LAMM>) {
        assert!(!exists<StakingPool>(@StakingPool), ERR_POOL_EXISTS);
        assert!(Signer::address_of(account) == @StakingPool, ERR_WRONG_STAKING_POOL_ADDR);

        move_to(account, StakingPool {
            mint_cap,
            period: Timestamp::now_seconds() / SECONDS_IN_WEEK * SECONDS_IN_WEEK,
            weekly_emission: 20000000000000, // TODO: update initial weekly emission.
            total_staked: 0,
            rewards: Coin::zero<LAMM>(),
            id_counter: 0,
        })
    }

    /// Stake your LAMM coins and get staked position.
    /// * `stake` - LAMM coins to stake.
    /// * `duration` - number from zero till 3 (e.g. enum) represents lock period (see durations constants).
    /// Returns locked stake position.
    public fun stake(stake: Coin<LAMM>, duration: u8): Position acquires StakingPool {
        assert!(exists<StakingPool>(@StakingPool), ERR_POOL_DOESNT_EXIST);

        let stake_value = Coin::value(&stake);
        assert!(stake_value >= MINIMUM_STAKE_VALUE, ERR_STAKE_LESS_THAN_MIN);

        let staking_pool = borrow_global_mut<StakingPool>(@StakingPool);

        let duration_in_seconds = get_duration_in_seconds(duration);
        let id = staking_pool.id_counter;

        staking_pool.id_counter = staking_pool.id_counter + 1;
        staking_pool.total_staked = staking_pool.total_staked + stake_value;

        let created_at = Timestamp::now_seconds();
        let till = created_at + duration_in_seconds;

        Position{
            id,
            created_at,
            till,
            stake,
        }
    }

    // TODO: claim rewards func.
    public fun unstake(to_unstake: Position): Coin<LAMM> acquires StakingPool {
        assert!(exists<StakingPool>(@StakingPool), ERR_POOL_DOESNT_EXIST);
        assert!(to_unstake.till <= Timestamp::now_seconds(), ERR_EARLY_UNLOCK);

        let staking_pool = borrow_global_mut<StakingPool>(@StakingPool);

        // TODO: we should rewards staker if there is rewards for him.

        let Position { stake, id: _, created_at: _, till: _ } = to_unstake;

        staking_pool.total_staked = staking_pool.total_staked - Coin::value(&stake);
        stake
    }

    // We should mint new coins if week passed.
    // Should be executed weekly.
    // Anyone can call it any time.
    public fun update<CoinType>() acquires StakingPool {
        assert!(exists<StakingPool>(@StakingPool), ERR_POOL_DOESNT_EXIST);

        let staking_pool = borrow_global_mut<StakingPool>(@StakingPool);
        let now = Timestamp::now_seconds();

        if (now >= staking_pool.period + SECONDS_IN_WEEK) {
            staking_pool.period = now / SECONDS_IN_WEEK * SECONDS_IN_WEEK;

            let supply = CoinHelper::supply<LAMM>();
            let circulation_supply = supply - staking_pool.total_staked;

            let emission = calc_weekly_emission(staking_pool.weekly_emission, supply, circulation_supply);
            // TODO: we probably should split weekly emission and weekly growth (see solidly).

            let rewards = Coin::mint<LAMM>(emission, &staking_pool.mint_cap);

            // TODO: really rewards should be splitted between stakers and LP providers, but for now we just deposit it.
            Coin::merge(&mut staking_pool.rewards, rewards);

            // TODO: only rewards which going to stakers should be updated here?
            staking_pool.total_staked = staking_pool.total_staked + emission;
            staking_pool.weekly_emission = emission;
        }
    }

    // Getter functions

    /// Get staked value stored in stake position.
    /// * `liq_pos` - reference to staking position.
    public fun get_staked_value(liq_pos: &Position): u64  {
        Coin::value(&liq_pos.stake)
    }

    /// Get staking position id.
    /// * `liq_pos` - reference to staking position.
    public fun get_position_id(liq_pos: &Position): u128 {
        liq_pos.id
    }

    /// Get locked till timestamp of staking position.
    /// * `liq_pos` - reference to staking position.
    public fun get_staked_until(liq_pos: &Position): u64 {
        liq_pos.till
    }

    /// Get timestamp when staking position created.
    /// * `liq_pos` - reference to staking position.
    public fun get_created_at(liq_pos: &Position): u64 {
        liq_pos.created_at
    }

    /// Get total staked amount in staking pool.
    public fun get_total_staked(): u64 acquires StakingPool {
        borrow_global<StakingPool>(@StakingPool).total_staked
    }

    /// Get current period.
    public fun get_period(): u64 acquires StakingPool {
        borrow_global<StakingPool>(@StakingPool).period
    }

    // Private functions.

    /// Calculates weekly emission of LAMM coins.
    /// * `supply` - total supply of LAMM coins.
    /// * `circulation_supply` - is amount of LAMM coins in circulation (that ones which not staked).
    /// Returns amount of LAMM coins to mint during weekly emission.
    fun calc_weekly_emission(weekly_emission: u64, supply: u64,  circulating_supply: u64): u64 {
        // We want emission to be based on staked and circulating supply like initally discussed.
        // E.g. take a ratio of supply and staked coin, use ratio on WEEKLY_INFLATION to determine what's
        // weekly emission.
        // Yet if emission became too low, we still want to have at least some emission (0.2% of circulating supply).

        // In nutshell, emission going down with each new stake and each week, at some stage it will become so low,
        // but we still need to continue reward stakers, so in such case emission will be 0.2% of circulating supply.

        // So first we calculate target emission based on staked and circulating supply,
        // and target with WEEKLY_INFLATION per week.
        let weekly_emission =
            Math::mul_to_u128(weekly_emission, 98) * (circulating_supply as u128) / 100u128 / (supply as u128);

        // Yet we also calculating 0.2% emission in case too much coins staked.
        let circulating_emission = ((circulating_supply * 2 / 1000) as u128);

        // And finally we are choosing which emission to use in the current period.
        let emission = if (weekly_emission >= circulating_emission) {
            weekly_emission
        } else {
            circulating_emission
        };

        (emission as u64)
    }

    /// Convert `duration` (enum) to seconds.
    /// * `duration` - number from zero till 3 (e.g. enum) represents lock period (see durations constants).
    /// Returns duration in seconds.
    fun get_duration_in_seconds(duration: u8): u64 {
        if (duration == D_WEEK) {
            SECONDS_IN_WEEK
        } else if (duration == D_MONTH) {
            SECONDS_IN_MONTH
        } else if (duration == D_YEAR) {
            SECONDS_IN_YEAR
        } else if (duration == D_FOUR_YEARS) {
            SECONDS_IN_FOUR_YEAR
        } else {
            abort ERR_WRONG_DURATION
        }
    }

    #[test_only]
    public fun get_duration_in_seconds_for_test(duration: u8): u64 {
        get_duration_in_seconds(duration)
    }

    #[test_only]
    public fun calc_weekly_emission_for_test(weekly: u64, supply: u64, circulating_supply: u64): u64 {
        calc_weekly_emission(weekly, supply, circulating_supply)
    }
}
