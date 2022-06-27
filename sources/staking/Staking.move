// Staking contract similar to Solidly, it's work in progress.
module MultiSwap::Staking {
    use Std::Signer;

    use AptosFramework::Timestamp;
    use AptosFramework::Coin::{Self, Coin, MintCapability};

    use MultiSwap::Liquid::LAMM;
    use MultiSwap::CoinHelper;
    use MultiSwap::Math;
    use MultiSwap::TimeHelper::{get_seconds_in_week, get_duration_in_weeks};
    use AptosFramework::Table::{Self, Table};

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

    // Different durations (week, month, etc) in seconds.

    // TODO: convert errors to Std:Error.

    /// The resource describing staking pool.
    struct StakingPool has key {
        /// MintCapability to mint new LAMM coins.
        mint_cap: MintCapability<LAMM>,

        // Sequence number of current period.
        period: u64,

        // Last timestamp when new emission minted.
        last_emission_ts: u64,

        // Current weekly e,ission.
        weekly_emission: u64,

        // Total staked.
        total_staked: u64,

        // Total rewards we have.
        rewards: Coin<LAMM>,

        // ID counter for positions.
        id_counter: u128,

        // Emissions per periods.
        emissions: Table<u64, u64>,
    }

    /// The resource describing staking position.
    struct Position has store {
        id: u128,
        stake: Coin<LAMM>,
        created_at_period: u64,  // At which period position created.
        staked_for_periods: u64, // For how much periods (weeks) position staked.
        last_period_paid: u64, // At which last period position claimed rewards.
    }

    /// Create a new staking pool, the staking pool will be stored on staking admin account.
    /// Only StakingAdmin can call it.
    /// * `mint_cap` - mint capability for LAMM coin.
    public fun create_pool(account: &signer, mint_cap: MintCapability<LAMM>) {
        assert!(!exists<StakingPool>(@StakingPool), ERR_POOL_EXISTS);
        assert!(Signer::address_of(account) == @StakingPool, ERR_WRONG_STAKING_POOL_ADDR);

        let seconds_in_week = get_seconds_in_week();

        move_to(account, StakingPool {
            mint_cap,
            period: 0,
            last_emission_ts: Timestamp::now_seconds() / seconds_in_week * seconds_in_week,
            weekly_emission: 20000000000000, // TODO: update initial weekly emission.
            total_staked: 0,
            rewards: Coin::zero<LAMM>(),
            id_counter: 0,
            emissions: Table::new(),
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

        let duration_in_weeks = get_duration_in_weeks(duration);
        let id = staking_pool.id_counter;

        staking_pool.id_counter = staking_pool.id_counter + 1;
        staking_pool.total_staked = staking_pool.total_staked + stake_value;

        Position{
            id,
            stake,
            created_at_period: staking_pool.period,
            staked_for_periods: duration_in_weeks,
            last_period_paid: staking_pool.period,
        }
    }

    /// Unstake staking position.
    /// * `pos` - staking positon.
    /// Returns staked+rewards LAMM coins.
    public fun unstake(pos: Position): Coin<LAMM> acquires StakingPool {
        // We check everything claimed.
        assert!(pos.last_period_paid == (pos.created_at_period + pos.staked_for_periods), ERR_EARLY_UNLOCK);

        let staking_pool = borrow_global_mut<StakingPool>(@StakingPool);

        let Position {
            stake,
            id: _,
            created_at_period: _,
            staked_for_periods: _,
            last_period_paid: _
        } = pos;

        staking_pool.total_staked = staking_pool.total_staked - Coin::value(&stake);
        stake
    }

    // We should mint new coins if week passed.
    // Should be executed each week.
    // Anyone can call it any time.
    public fun update<CoinType>() acquires StakingPool {
        assert!(exists<StakingPool>(@StakingPool), ERR_POOL_DOESNT_EXIST);

        let staking_pool = borrow_global_mut<StakingPool>(@StakingPool);
        let now = Timestamp::now_seconds();
        let seconds_in_week = get_seconds_in_week();

        if (now >= staking_pool.last_emission_ts + seconds_in_week) {
            staking_pool.period = staking_pool.period + 1;
            staking_pool.last_emission_ts = Timestamp::now_seconds() / seconds_in_week * seconds_in_week;

            let supply = CoinHelper::supply<LAMM>();
            let circulation_supply = supply - staking_pool.total_staked;

            let emission = calc_weekly_emission(staking_pool.weekly_emission, supply, circulation_supply);

            // Probably we don't need growth at alll.
            let growth = calc_growth(staking_pool.total_staked, emission, supply); // ?
            let current_rewards = Coin::value(&staking_pool.rewards); // ?
            let required = emission + growth; // ?.

            // TODO: optimize it to havge less merge/extract?
            let rewards = if (current_rewards < required) {
                let to_mint = required - current_rewards;
                Coin::mint<LAMM>(to_mint, &staking_pool.mint_cap)
            } else {
                Coin::zero<LAMM>()
            };
            Coin::merge(&mut staking_pool.rewards, rewards);

            // As we made periods just a number, so we can ignore, if someone not called
            // this function one time per week, yet, it shouldn't happen at all.
            Table::add(&mut staking_pool.emissions, staking_pool.period, growth);

            // TODO: we should deposit part of rewards to voting contract, see solidly.
            // TODO: only rewards which going to stakers should be updated here?
            //staking_pool.total_staked = staking_pool.total_staked + emission;
            staking_pool.weekly_emission = emission;
        }
    }

    public fun claim_next_period(pos: &mut Position) acquires StakingPool {
        assert!(exists<StakingPool>(@StakingPool), ERR_POOL_DOESNT_EXIST);

        let staking_pool = borrow_global_mut<StakingPool>(@StakingPool);
        let next_period = pos.last_period_paid + 1;

        assert!(next_period - pos.created_at_period < pos.staked_for_periods, 0);

        let _ = Table::borrow(&staking_pool.emissions, next_period);

        // TODO: we should calc distribution here based on emission info above.

        // we should go over periods, starting with time when position staked.
        // periods should be filled correctly.
        pos.last_period_paid = next_period;
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

    /// Get staking position last period when rewarded.
    /// * `liq_pos` - reference to staking position.
    public fun get_last_period_paid(liq_pos: &Position): u64 {
        liq_pos.last_period_paid
    }

    /// Get locked till timestamp of staking position.
    /// * `liq_pos` - reference to staking position.
    public fun get_staked_for_periods(liq_pos: &Position): u64 {
        liq_pos.staked_for_periods
    }

    /// Get timestamp when staking position created.
    /// * `liq_pos` - reference to staking position.
    public fun get_created_at_period(liq_pos: &Position): u64 {
        liq_pos.created_at_period
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

    /// Calculate growth of LAMM coins during emission event.
    /// * `total_staked` - value of staked LAMM coins.
    /// * `minted` - value of minted LAMM coins.
    /// * `total_supply` - total supply of LAMM coins.
    fun calc_growth(total_staked: u64, minted: u64, total_supply: u64): u64 {
        let growth = Math::mul_to_u128(total_staked, minted) / (total_supply as u128);
        (growth as u64)
    }

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

    #[test_only]
    public fun calc_weekly_emission_for_test(weekly: u64, supply: u64, circulating_supply: u64): u64 {
        calc_weekly_emission(weekly, supply, circulating_supply)
    }
}
