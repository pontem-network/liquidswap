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

    // TODO: change minimum stake later.
    const MINIMUM_STAKE_VALUE: u64 = 1000000;

    // TODO: change weekly inflation later.
    const WEEKLY_INFLATION: u64 = 2000000000000;

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

    /// One week in seconds.
    const WEEK_IN_SECONDS: u64 = 604800u64;
    /// One month in seconds.
    const MONTH_IN_SECONDS: u64 = 2630000u64;
    /// One year in seconds.
    const YEAR_IN_SECONDS: u64 = 31536000u64;
    /// Four years in seconds.
    const FOUR_YEAR_IN_SECONDS: u64 = 126144000u64;

    // Staking pool resource.
    struct StakingPool has key {
        mint_cap: MintCapability<LAMM>,

        minted_at: u64,
        total_staked: u64,

        rewards: Coin<LAMM>,

        id_counter: u128,
    }

    // Staking position.
    struct LiqPos has key, store {
        id: u128,
        created_at: u64,
        till: u64,
        stake: Coin<LAMM>,
    }

    public fun create_pool(account: &signer, mint_cap: MintCapability<LAMM>) {
        assert!(!exists<StakingPool>(@StakingPool), ERR_POOL_EXISTS);
        assert!(Signer::address_of(account) == @StakingPool, ERR_WRONG_STAKING_POOL_ADDR);

        move_to(account, StakingPool {
            mint_cap,
            minted_at: Timestamp::now_seconds(),
            total_staked: 0,
            rewards: Coin::zero<LAMM>(),
            id_counter: 0,
        })
    }

    /// Stake your LAMM coins and get staked position.
    /// * `stake` - LAMM coins to stake.
    /// * `duration` - number from zero till 3 (e.g. enum) represents lock period (see durations constants).
    /// Returns locked stake position.
    public fun stake(stake: Coin<LAMM>, duration: u8): LiqPos acquires StakingPool {
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

        LiqPos {
            id,
            created_at,
            till,
            stake,
        }
    }

    // TODO: rework it.
    public fun unstake(to_unstake: LiqPos): Coin<LAMM> acquires StakingPool {
        // TODO: error
        assert!(to_unstake.till >= Timestamp::now_seconds(), ERR_EARLY_UNLOCK);

        let staking_pool = borrow_global_mut<StakingPool>(@StakingPool);

        // TODO: we should rewards staker.

        let LiqPos { stake, id: _, created_at: _, till: _ } = to_unstake;

        staking_pool.total_staked = staking_pool.total_staked - Coin::value(&stake);
        stake
    }

    // We should mint new coins if week passed.
    // Should be executed weekly.
    // Anyone can call it any time.
    public fun update<CoinType>() acquires StakingPool {
        assert!(exists<StakingPool>(@StakingPool), ERR_POOL_DOESNT_EXIST);

        let staking_pool = borrow_global_mut<StakingPool>(@StakingPool);

        if (Timestamp::now_seconds() - staking_pool.minted_at >= WEEK_IN_SECONDS) {
            // TODO: rewrite with periods.

            // Main issue here - what to do if more than one week passed and nobody called function.
            // Yet it shouldn't happen at all, yet let me look how Solidly handle it.
            let supply = CoinHelper::supply<LAMM>();
            let circulation_supply = supply - staking_pool.total_staked;

            let emission = calc_weekly_emission(supply, circulation_supply);
            let rewards = Coin::mint<LAMM>(emission, &staking_pool.mint_cap);

            // TODO: really rewards should be splitted between stakers and LP providers, but for now we just deposit it.
            Coin::merge(&mut staking_pool.rewards, rewards);

            // TODO: only rewards which going to stakers should be updated here?
            staking_pool.total_staked = staking_pool.total_staked + emission;

            staking_pool.minted_at = staking_pool.minted_at + WEEK_IN_SECONDS;
        }
    }

    // Getter functions

    /// Get staked value stored in stake position.
    /// * `liq_pos` - reference to staking position.
    public fun get_staked_value(liq_pos: &LiqPos): u64  {
        // TODO: we should take into account that staked position increasing over time (each week).
        Coin::value(&liq_pos.stake)
    }

    /// Get staking position id.
    /// * `liq_pos` - reference to staking position.
    public fun get_id(liq_pos: &LiqPos): u128 {
        liq_pos.id
    }

    /// Get locked till timestamp of staking position.
    /// * `liq_pos` - reference to staking position.
    public fun get_staked_until(liq_pos: &LiqPos): u64 {
        liq_pos.till
    }

    /// Get timestamp when staking position created.
    /// * `liq_pos` - reference to staking position.
    public fun get_created_at(liq_pos: &LiqPos): u64 {
        liq_pos.created_at
    }

    // Private functions.

    /// Calculates weekly emission of LAMM coins.
    /// * `supply` - total supply of LAMM coins.
    /// * `circulation_supply` - is amount of LAMM coins in circulation (that ones which not staked).
    /// Returns amount of LAMM coins to mint during weekly emission.
    fun calc_weekly_emission(supply: u64, circulation_supply: u64): u64 {
        // The math is safe as we are using u128 for large camputations
        // and than return back to u64 (as all coins are u64).
        let emission =
            Math::mul_to_u128(WEEKLY_INFLATION, 98) * (circulation_supply as u128) / 100u128 / (supply as u128);
        (emission as u64)
    }

    /// Convert `duration` (enum) to seconds.
    /// * `duration` - number from zero till 3 (e.g. enum) represents lock period (see durations constants).
    /// Returns duration in seconds.
    fun get_duration_in_seconds(duration: u8): u64 {
        if (duration == D_WEEK) {
            WEEK_IN_SECONDS
        } else if (duration == D_MONTH) {
            MONTH_IN_SECONDS
        } else if (duration == D_YEAR) {
            YEAR_IN_SECONDS
        } else if (duration == D_FOUR_YEARS) {
            FOUR_YEAR_IN_SECONDS
        } else {
            abort ERR_WRONG_DURATION
        }
    }
}
