module MultiSwap::Minter {
    use Std::Signer;

    use AptosFramework::Timestamp;
    use AptosFramework::Coin::{MintCapability};
    use AptosFramework::Coin;

    use MultiSwap::CoinHelper;
    use MultiSwap::Liquid::LAMM;
    use MultiSwap::VE;
    use MultiSwap::Distribution;
    use MultiSwap::Math;

    // Errors.

    /// When config already exists.
    const ERR_CONFIG_EXISTS: u64 = 100;

    /// When wrong account trying to initialize.
    const ERR_WRONG_INITIALIZER: u64 = 101;

    // One week in seconds.
    const WEEK: u64 = 604800;

    /// Represents minter configuration.
    struct MinterConfig has key {
        mint_cap: MintCapability<LAMM>,
        weekly_emission: u64,
        active_period: u64,
    }

    /// Initialize minter configuration.
    /// `weekly_emission` - initial emission of LAMM coins per week.
    /// `mint_cap` - mint capability of LAMM coin.
    public fun initialize(account: &signer, weekly_emission: u64, mint_cap: MintCapability<LAMM>) {
        assert!(!exists<MinterConfig>(@StakingPool), ERR_CONFIG_EXISTS);
        assert!(Signer::address_of(account) == @StakingPool, ERR_WRONG_INITIALIZER);

        move_to(account, MinterConfig {
            mint_cap,
            weekly_emission,
            active_period: Timestamp::now_seconds() / WEEK * WEEK,
        })
    }

    /// Mint rewards weekly.
    public fun mint_rewards() acquires MinterConfig {
        let config = borrow_global_mut<MinterConfig>(@StakingPool);
        let now = Timestamp::now_seconds();

        if (now >= config.active_period + WEEK) {
            config.active_period = now / WEEK * WEEK;

            let w_e = calculate_emission(config.weekly_emission);

            let rewards = Coin::mint<LAMM>(w_e, &config.mint_cap);

            // we should move rewards to another contract to distribute.
            config.weekly_emission = w_e;

            Distribution::checkpoint(rewards);
        }
    }

    /// Get circulating supply (LAMM supply - VE supply).
    fun circulating_supply(): u64 {
        CoinHelper::supply<LAMM>() - VE::supply()
    }

    /// Get current emission.
    fun calculate_emission(weekly_emission: u64): u64 {
        let emission=
            Math::mul_to_u128(weekly_emission, 98) * (circulating_supply() as u128)
            / 100
            / (CoinHelper::supply<LAMM>() as u128);

        let minimum_emission = Math::mul_to_u128(circulating_supply(), 2) / 1000;

        // Choose between minimum emission and emission.
        if (emission < minimum_emission) {
            (minimum_emission as u64)
        } else {
            (emission as u64)
        }
    }

    #[test_only]
    fun get_active_period(): u64 acquires MinterConfig {
        borrow_global<MinterConfig>(@StakingPool).active_period
    }

    #[test_only]
    fun get_weekly_emission(): u64 acquires MinterConfig {
        borrow_global<MinterConfig>(@StakingPool).weekly_emission
    }

    #[test_only]
    use AptosFramework::Genesis;
    #[test_only]
    use MultiSwap::Liquid;
    #[test_only]
    use AptosFramework::Coin::register_internal;

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    public fun end_to_end(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) acquires MinterConfig {
        Genesis::setup(&core);

        Liquid::initialize(&multi_swap);
        VE::initialize(&staking_admin);
        Distribution::initialize(&staking_admin);

        let mint_cap = Liquid::get_mint_cap(&multi_swap);

        let w_e = 2000000000;
        initialize(&staking_admin, w_e, mint_cap);

        let now = Timestamp::now_seconds();
        assert!(get_active_period() == now / WEEK * WEEK, 0);
        assert!(get_weekly_emission() == w_e, 1);

        let to_mint_val = 10000000000;
        let staker_addr = Signer::address_of(&staker);
        register_internal<LAMM>(&staker);
        Liquid::mint(&multi_swap, staker_addr, to_mint_val);

        let to_stake_val = 1000000000;
        let to_stake = Coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft = VE::stake(to_stake, WEEK);

        let new_time = (now + WEEK) * 1000000;
        Timestamp::update_global_time_for_test(new_time);

        mint_rewards();
        assert!(get_active_period() == (new_time / 1000000) / WEEK * WEEK, 2);
        assert!(get_weekly_emission() == 1960000000, 3);

        Distribution::claim(&mut nft);
        let reward_value = VE::get_nft_staked_value(&nft) - to_stake_val;
        assert!(reward_value == 1960000000, 4);

        Distribution::claim(&mut nft);
        let reward_value = VE::get_nft_staked_value(&nft) - to_stake_val;
        assert!(reward_value == 1960000000, 5);

        let new_time = (Timestamp::now_seconds() + WEEK) * 1000000;
        Timestamp::update_global_time_for_test(new_time);

        mint_rewards();
        Distribution::claim(&mut nft);
        let reward_value = VE::get_nft_staked_value(&nft) - to_stake_val;
        assert!(reward_value == 1960000000, 6);

        let staking_rewards = VE::unstake(nft);
        assert!(Coin::value(&staking_rewards) == (1960000000 + to_stake_val), 7);
        Coin::deposit(staker_addr, staking_rewards);

        VE::update();
    }
}