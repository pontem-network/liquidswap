/// Inflation rewards minter for VE.
module MultiSwap::Minter {
    use Std::Signer;

    use AptosFramework::Coin;
    use AptosFramework::Coin::MintCapability;
    use AptosFramework::Timestamp;

    use MultiSwap::CoinHelper;
    use MultiSwap::Distribution;
    use MultiSwap::Liquid::LAMM;
    use MultiSwap::Math;
    use MultiSwap::VE;

    // Errors.

    /// When config already exists.
    const ERR_CONFIG_EXISTS: u64 = 100;

    /// When wrong account trying to initialize.
    const ERR_WRONG_INITIALIZER: u64 = 101;

    /// When week hasn't passed yet to do mint rewards.
    const ERR_WEEK_HASNT_PASSED: u64 = 102;

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

        assert!(now >= config.active_period + WEEK, ERR_WEEK_HASNT_PASSED);
        config.active_period = now / WEEK * WEEK;

        let weekly_emission = calculate_emission(config.weekly_emission);
        let rewards = Coin::mint<LAMM>(weekly_emission, &config.mint_cap);

        // we should move rewards to another contract to distribute.
        config.weekly_emission = weekly_emission;

        Distribution::checkpoint(rewards);
    }

    /// Get circulating supply (LAMM supply - VE supply).
    fun circulating_supply(): u64 {
        let r = CoinHelper::supply<LAMM>() - (VE::supply() as u128);
        (r as u64)
    }

    /// Get current emission.
    fun calculate_emission(weekly_emission: u64): u64 {
        let emission =
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
    use AptosFramework::Coin::register_internal;
    #[test_only]
    use AptosFramework::Genesis;
    #[test_only]
    use AptosFramework::Table;
    #[test_only]
    use AptosFramework::Table::Table;
    #[test_only]
    use MultiSwap::Liquid;

    #[test_only]
    fun get_active_period(): u64 acquires MinterConfig {
        borrow_global<MinterConfig>(@StakingPool).active_period
    }

    #[test_only]
    fun get_weekly_emission(): u64 acquires MinterConfig {
        borrow_global<MinterConfig>(@StakingPool).weekly_emission
    }

    #[test_only]
    struct NFTs has key {
        nfts: Table<u64, VE::VE_NFT>,
    }

    #[test_only]
    fun initialize_test(core: &signer, staking_admin: &signer, multi_swap: &signer, staker: &signer) {
        Genesis::setup(core);

        Liquid::initialize(multi_swap);
        VE::initialize(staking_admin);

        let to_mint_val = 20000000000;
        let staker_addr = Signer::address_of(staker);
        register_internal<LAMM>(staker);
        Liquid::mint_internal(multi_swap, staker_addr, to_mint_val);
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    fun test_initialize(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) acquires MinterConfig {
        initialize_test(&core, &staking_admin, &multi_swap, &staker);
        let mint_cap = Liquid::get_mint_cap(&multi_swap);

        let weekly_emission = 2000000000;
        initialize(&staking_admin, weekly_emission, mint_cap);

        assert!(get_weekly_emission() == weekly_emission, 0);
        assert!(get_active_period() == Timestamp::now_seconds() / WEEK * WEEK, 1);
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    #[expected_failure(abort_code = 100)]
    fun test_initialize_fail_exists(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) {
        initialize_test(&core, &staking_admin, &multi_swap, &staker);
        let mint_cap = Liquid::get_mint_cap(&multi_swap);

        initialize(&staking_admin, 1, mint_cap);
        initialize(&staking_admin, 1, mint_cap);
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    #[expected_failure(abort_code = 101)]
    fun test_initialize_fail_wrong_account(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) {
        initialize_test(&core, &staking_admin, &multi_swap, &staker);
        let mint_cap = Liquid::get_mint_cap(&multi_swap);

        initialize(&multi_swap, 1, mint_cap);
    }

    // test initialize fails.
    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    fun test_calculate_emission(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) {
        initialize_test(&core, &staking_admin, &multi_swap, &staker);

        let emission = calculate_emission(2000000000);
        assert!(emission == 1960000000, 0);

        let to_stake_val = 20000000000;
        let to_stake = Coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft = VE::stake(to_stake, WEEK * 208);

        emission = calculate_emission(2000000000);
        assert!(emission == 12137574, 1);

        // emission before we start use minimum emission
        emission = calculate_emission(40816392);
        assert!(emission == 247705, 2);

        let new_time = (Timestamp::now_seconds() + WEEK / 2) * 1000000;
        Timestamp::update_global_time_for_test(new_time);

        emission = calculate_emission(2000000000);
        assert!(emission == 16819936, 2);

        let nfts = Table::new<u64, VE::VE_NFT>();
        Table::add(&mut nfts, VE::get_nft_id(&nft), nft);

        move_to(&staker, NFTs {
            nfts
        });
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    fun test_circulating_supply(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) {
        initialize_test(&core, &staking_admin, &multi_swap, &staker);

        let circulating_supply = circulating_supply();
        assert!(circulating_supply == 20000000000, 0);

        let to_stake_val = 10000000000;
        let to_stake = Coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft = VE::stake(to_stake, WEEK * 208);

        circulating_supply = circulating_supply();
        assert!(circulating_supply == 10061926400, 1); // It's not exactly 0 because of division round issues.

        let nfts = Table::new<u64, VE::VE_NFT>();
        Table::add(&mut nfts, VE::get_nft_id(&nft), nft);

        move_to(&staker, NFTs {
            nfts
        });
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    fun test_mint_rewards(
        core: signer,
        staking_admin: signer,
        multi_swap: signer,
        staker: signer
    ) acquires MinterConfig {
        initialize_test(&core, &staking_admin, &multi_swap, &staker);
        Distribution::initialize(&staking_admin);

        let mint_cap = Liquid::get_mint_cap(&multi_swap);

        let weekly_emission = 2000000000;
        initialize(&staking_admin, weekly_emission, mint_cap);

        let to_stake_val = 10000000000;
        let to_stake = Coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft = VE::stake(to_stake, WEEK * 208);

        let new_time = (Timestamp::now_seconds() + WEEK) * 1000000;
        Timestamp::update_global_time_for_test(new_time);

        assert!(Distribution::get_rewards_value() == 0, 0);
        mint_rewards();
        let rewards_value = Distribution::get_rewards_value();
        assert!(rewards_value == 990751148, 1);
        assert!(get_weekly_emission() == 990751148, 2);
        assert!(get_active_period() == Timestamp::now_seconds() / WEEK * WEEK, 3);

        let nfts = Table::new<u64, VE::VE_NFT>();
        Table::add(&mut nfts, VE::get_nft_id(&nft), nft);

        move_to(&staker, NFTs {
            nfts
        });
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    #[expected_failure(abort_code = 102)]
    fun test_mint_rewards_fail(
        core: signer,
        staking_admin: signer,
        multi_swap: signer,
        staker: signer
    ) acquires MinterConfig {
        initialize_test(&core, &staking_admin, &multi_swap, &staker);
        Distribution::initialize(&staking_admin);

        let mint_cap = Liquid::get_mint_cap(&multi_swap);

        let weekly_emission = 2000000000;
        initialize(&staking_admin, weekly_emission, mint_cap);

        mint_rewards();
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    fun end_to_end(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) acquires MinterConfig {
        initialize_test(&core, &staking_admin, &multi_swap, &staker);
        Distribution::initialize(&staking_admin);

        let mint_cap = Liquid::get_mint_cap(&multi_swap);

        let weekly_emission = 2000000000;
        initialize(&staking_admin, weekly_emission, mint_cap);

        let now = Timestamp::now_seconds();
        assert!(get_active_period() == now / WEEK * WEEK, 0);
        assert!(get_weekly_emission() == weekly_emission, 1);

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

        let staking_rewards = VE::unstake(nft, true);
        assert!(Coin::value(&staking_rewards) == (1960000000 + to_stake_val), 7);
        Coin::deposit(Signer::address_of(&staker), staking_rewards);
    }
}