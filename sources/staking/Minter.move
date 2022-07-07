module MultiSwap::Minter {
    use Std::Signer;

    use AptosFramework::Timestamp;
    use AptosFramework::Coin::{MintCapability, Coin, value};
    use AptosFramework::Coin;

    use MultiSwap::CoinHelper;
    use MultiSwap::Liquid::LAMM;
    use MultiSwap::VE;
    use MultiSwap::Math;

    const ERR_CONFIG_EXISTS: u64 = 100;
    const ERR_WRONG_INITIALIZER: u64 = 101;

    // One week in seconds.
    const WEEK: u64 = 604800;

    // Current minter config.
    struct MinterConfig has key {
        mint_cap: MintCapability<LAMM>,
        weekly_emission: u64,
        active_period: u64,

        // just for now we storing it here
        rewards: Coin<LAMM>,
    }

    // Initialization function.
    public fun initialize(account: &signer, weekly_emission: u64, mint_cap: MintCapability<LAMM>) {
        assert!(!exists<MinterConfig>(@StakingPool), ERR_CONFIG_EXISTS);
        assert!(Signer::address_of(account) == @StakingPool, ERR_WRONG_INITIALIZER);

        move_to(account, MinterConfig {
            mint_cap,
            weekly_emission,
            active_period: Timestamp::now_seconds() / WEEK * WEEK,
            rewards: Coin::zero<LAMM>(),
        })
    }

    fun circulating_supply(): u64 {
        CoinHelper::supply<LAMM>() - VE::supply()
    }

    fun calculate_emission(weekly_emission: u64): u64 {
        let e=
            Math::mul_to_u128(weekly_emission, 98) * (circulating_supply() as u128)
            / 100
            / (CoinHelper::supply<LAMM>() as u128);
        (e as u64)
    }

    fun circulating_emission(): u64 {
        let e = Math::mul_to_u128(circulating_supply(), 2) / 1000;
        (e as u64)
    }

    fun calc_weekly_emission(weekly_emission: u64): u64 {
        let e1 = calculate_emission(weekly_emission);
        let e2 = circulating_emission();

        if (e1 > e2) {
            e1
        } else {
            e2
        }
    }

    public fun mint_rewards() acquires MinterConfig {
        let config = borrow_global_mut<MinterConfig>(@StakingPool);
        let now = Timestamp::now_seconds();

        if (now >= config.active_period + WEEK) {
            config.active_period = now / WEEK * WEEK;

            let w_e = calc_weekly_emission(config.weekly_emission);

            let coins = Coin::mint<LAMM>(w_e, &config.mint_cap);
            Coin::merge(&mut config.rewards, coins);

            // we should move rewards to another contract to distribute.
            config.weekly_emission = w_e;
        }
    }

    public fun get_rewards_value(): u64 acquires MinterConfig {
        let config = borrow_global<MinterConfig>(@StakingPool);
        value(&config.rewards)
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
    use AptosFramework::Table::Table;
    #[test_only]
    use AptosFramework::Table;
    #[test_only]
    use AptosFramework::Coin::register_internal;

    #[test_only]
    struct NFTs has key {
        nfts: Table<u64, VE::NFT>,
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    public fun end_to_end(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) acquires MinterConfig {
        Genesis::setup(&core);

        Liquid::initialize(&multi_swap);
        VE::initialize(&staking_admin);

        let mint_cap = Liquid::get_mint_cap(&multi_swap);

        let w_e = 2000000000;
        initialize(&staking_admin, w_e, mint_cap);

        let now = Timestamp::now_seconds();
        assert!(get_active_period() == now / WEEK * WEEK, 0);
        assert!(get_weekly_emission() == w_e, 1);

        let to_mint_val = 10000000000;
        register_internal<LAMM>(&staker);
        Liquid::mint(&multi_swap, Signer::address_of(&staker), to_mint_val);

        let to_stake_val = 1000000000;
        let to_stake = Coin::withdraw<LAMM>(&staker, to_stake_val);

        let nft = VE::stake(to_stake, WEEK);

        let new_time = (now + WEEK) * 1000000;
        Timestamp::update_global_time_for_test(new_time);

        mint_rewards();
        let new_weekly_emission = get_rewards_value();
        assert!(get_active_period() == (new_time / 1000000) / WEEK * WEEK, 2);
        assert!(get_rewards_value() == 1960000000, 3);
        assert!(get_weekly_emission() == new_weekly_emission, 4);

        let nfts = Table::new<u64, VE::NFT>();
        Table::add(&mut nfts, VE::get_id(&nft), nft);

        move_to(&staker, NFTs {
            nfts
        });
    }
}