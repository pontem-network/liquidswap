// Staking contract similar to Solidly, it's work in progress.
module MultiSwap::Staking {
    use Std::Signer;

    use AptosFramework::Timestamp;
    use AptosFramework::Coin::{Self, Coin, MintCapability};

    use MultiSwap::Liquid::LAMM;
    use MultiSwap::CoinHelper;

    // Errors.
    const ERR_WRONG_DURATION: u64 = 100;
    const ERR_EARLY_UNLOCK: u64 = 101;

    // Constants.

    // Durations.
    const D_WEEK: u8 = 0;
    const D_MONTH: u8 = 1;
    const D_YEAR: u8 = 2;
    const D_FOUR_YEARS: u8 = 3;

    const WEEK_IN_SECONDS: u64 = 604800u64;
    const MONTH_IN_SECONDS: u64 = 2630000u64;
    const YEAR_IN_SECONDS: u64 = 31536000u64;
    const FOUR_YEAR_IN_SECONDS: u64 = 126144000u64;

    // TODO: change weekly inflation later.
    const WEEKLY_INFLATION: u64 = 2000000000000;

    // Staking pool.
    struct StakingPool has key {
        mint_cap: MintCapability<LAMM>,

        minted_at: u64,
        total_staked: u64,

        rewards: Coin<LAMM>,
    }

    // Staking position.
    struct LiqPos has key, store {
        staked: Coin<LAMM>,
        created_at: u64,
        till: u64,
    }

    public fun create_pool(account: &signer, mint_cap: MintCapability<LAMM>) {
        // TODO: error here.
        assert!(Signer::address_of(account) != @MultiSwap, 0);

        // TODO: check if exists or throw error.
        move_to(account, StakingPool {
            mint_cap,
            minted_at: Timestamp::now_seconds(),
            total_staked: 0,
            rewards: Coin::zero<LAMM>(),
        })
    }

    public fun stake(to_stake: Coin<LAMM>, duration: u8): LiqPos acquires StakingPool {
        // TODO: check if pool exists.
        let staking_pool = borrow_global_mut<StakingPool>(@MultiSwap);

        staking_pool.total_staked = staking_pool.total_staked + Coin::value(&to_stake);

        let duration_in_seconds = get_duration_in_seconds(duration);
        let created_at = Timestamp::now_seconds();
        let till = created_at + duration_in_seconds;

        LiqPos {
            staked: to_stake,
            created_at,
            till,
        }
    }

    // TODO: add pool?
    public fun unstake(to_unstake: LiqPos): Coin<LAMM> acquires StakingPool {
        // TODO: error
        assert!(to_unstake.till >= Timestamp::now_seconds(), ERR_EARLY_UNLOCK);

        let staking_pool = borrow_global_mut<StakingPool>(@MultiSwap);

        // TODO: we should rewards staker.

        let LiqPos { staked, created_at: _, till: _ } = to_unstake;

        staking_pool.total_staked = staking_pool.total_staked - Coin::value(&staked);
        staked
    }

    // We should mint new coins if week passed.
    // Should be executed weekly.
    // Anyone can call it any time.
    public fun update<CoinType>() acquires StakingPool {
        // TODO: check pool exists.

        let staking_pool = borrow_global_mut<StakingPool>(@MultiSwap);

        if (Timestamp::now_seconds() - staking_pool.minted_at >= WEEK_IN_SECONDS) {
            // TODO: double check, probably we must add period check (or something).
            // Main issue here - what to do if more than one week passed and nobody called function.
            // Yet it shouldn't happen at all, yet let me look how Solidly handle it.
            let supply = CoinHelper::supply<LAMM>();
            let circulation_supply = supply - staking_pool.total_staked;

            let emission = calc_weekly_emission(supply, circulation_supply);
            let rewards = Coin::mint<LAMM>(emission, &staking_pool.mint_cap);

            // TODO: really rewards should be splitted between stakers and LP providers, but for now we just deposit it
            // to temporary storage.
            Coin::merge(&mut staking_pool.rewards, rewards);

            // TODO: only rewards which going to stakers should be updated here.
            staking_pool.total_staked = emission;

            staking_pool.minted_at = staking_pool.minted_at + WEEK_IN_SECONDS;
        }
    }

    // Returns how much tokens we should mint this week.
    fun calc_weekly_emission(supply: u64, circulation_supply: u64): u64 {
        // todo: check it's safe.
        let emission  =
            ((WEEKLY_INFLATION * 98) as u128) * (circulation_supply as u128) / 100u128 / (supply as u128);
        (emission as u64)
    }

    // Convert duration enum like to seconds.
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
