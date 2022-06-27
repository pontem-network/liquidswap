#[test_only]
module MultiSwap::StakingTests {
    use Std::Signer;
    use Std::Debug;

    use AptosFramework::Genesis;
    use AptosFramework::Timestamp;
    use AptosFramework::Coin;
    use AptosFramework::Table::{Self, Table};

    use MultiSwap::Liquid;
    use MultiSwap::Staking::{Self, Position};
    use MultiSwap::Liquid::LAMM;

    const SECONDS_IN_WEEK: u64 = 604800u64;
    const SECONDS_IN_MONTH: u64 = 2630000u64;
    const SECONDS_IN_YEAR: u64 = 31536000u64;
    const SECONDS_IN_FOUR_YEAR: u64 = 126144000u64;

    struct Positions has key {
        positions: Table<u128, Position>,
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap)]
    public fun test_create_pool(core: signer, staking_admin: signer, multi_swap: signer) {
        Genesis::setup(&core);
        Liquid::initialize(&multi_swap);

        let mint_cap = Liquid::get_mint_cap(&multi_swap);
        let period = Timestamp::now_seconds() / 604800u64 * 604800u64;

        Staking::create_pool(&staking_admin, mint_cap);
        assert!(Staking::get_total_staked() == 0, 0);
        assert!(Staking::get_period() == period, 1);
    }

    #[test(core = @CoreResources, multi_swap = @MultiSwap)]
    #[expected_failure(abort_code = 105)]
    public fun test_create_pool_from_non_staking_admin(core: signer, multi_swap: signer) {
        Genesis::setup(&core);
        Liquid::initialize(&multi_swap);

        let mint_cap = Liquid::get_mint_cap(&multi_swap);

        Staking::create_pool(&multi_swap, mint_cap);
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap)]
    #[expected_failure(abort_code = 103)]
    public fun test_create_pool_if_it_already_exists(core: signer, staking_admin: signer, multi_swap: signer) {
        Genesis::setup(&core);
        Liquid::initialize(&multi_swap);

        let mint_cap = Liquid::get_mint_cap(&multi_swap);

        Staking::create_pool(&staking_admin, mint_cap);
        Staking::create_pool(&staking_admin, mint_cap);
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    public fun test_stake(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) {
        Genesis::setup(&core);
        Liquid::initialize(&multi_swap);

        let mint_cap = Liquid::get_mint_cap(&multi_swap);
        Staking::create_pool(&staking_admin, mint_cap);

        let to_mint = 10000000000;
        Coin::register_internal<LAMM>(&staker);
        Liquid::mint(&multi_swap, Signer::address_of(&staker), to_mint);

        let stake = Coin::withdraw<LAMM>(&staker, to_mint);
        let position = Staking::stake(stake, 0);

        let id = Staking::get_position_id(&position);
        assert!(id == 0, 0);
        let staked_value = Staking::get_staked_value(&position);
        assert!(staked_value == to_mint, 1);
        let created_at = Staking::get_created_at(&position);
        assert!(created_at == Timestamp::now_seconds(), 2);
        let till = Staking::get_staked_until(&position);
        assert!(till == Timestamp::now_seconds() + SECONDS_IN_WEEK, 3);
        let total_staked = Staking::get_total_staked();
        assert!(total_staked == to_mint, 4);

        let positions = Table::new<u128, Position>();
        Table::add(&mut positions, id, position);
        move_to(&staker, Positions {
            positions,
        });
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    public fun test_stake_check_id_increasing(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) {
        Genesis::setup(&core);
        Liquid::initialize(&multi_swap);

        let mint_cap = Liquid::get_mint_cap(&multi_swap);
        Staking::create_pool(&staking_admin, mint_cap);

        let to_mint = 10000000000;
        Coin::register_internal<LAMM>(&staker);
        Liquid::mint(&multi_swap, Signer::address_of(&staker), to_mint);

        let stake1 = Coin::withdraw<LAMM>(&staker, to_mint / 2);
        let pos1 = Staking::stake(stake1, 0);

        let stake2 = Coin::withdraw<LAMM>(&staker, to_mint / 2);
        let pos2 = Staking::stake(stake2, 0);

        let id1 = Staking::get_position_id(&pos1);
        assert!(id1 == 0, 0);
        let id2 = Staking::get_position_id(&pos2);
        assert!(id2 == 1, 1);
        let total_staked = Staking::get_total_staked();
        assert!(total_staked == to_mint, 2);

        let positions = Table::new<u128, Position>();
        Table::add(&mut positions, id1, pos1);
        Table::add(&mut positions, id2, pos2);

        move_to(&staker, Positions {
            positions,
        });
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap, staker = @TestStaker)]
    #[expected_failure(abort_code = 104)]
    public fun test_stake_less_than_minimum(core: signer, staking_admin: signer, multi_swap: signer, staker: signer) {
        Genesis::setup(&core);
        Liquid::initialize(&multi_swap);

        let mint_cap = Liquid::get_mint_cap(&multi_swap);
        Staking::create_pool(&staking_admin, mint_cap);

        let to_mint = 1;
        Coin::register_internal<LAMM>(&staker);
        Liquid::mint(&multi_swap, Signer::address_of(&staker), to_mint);

        let stake = Coin::withdraw<LAMM>(&staker, to_mint);
        let position = Staking::stake(stake, 0);
        let id = Staking::get_position_id(&position);

        let positions = Table::new<u128, Position>();
        Table::add(&mut positions, id, position);

        move_to(&staker, Positions {
            positions,
        });
    }

    #[test]
    public fun test_calc_weekly_emission() {
        let supply = 25347015000000;
        let weekly = 2000000000000;
        let staked = 10500000000000;

        let circulating_supply = supply - staked;

        let emission = Staking::calc_weekly_emission_for_test(weekly, supply, circulating_supply);
        Debug::print(&emission);
        assert!(emission == 1148070074523, 0);

        weekly = 1;
        emission = Staking::calc_weekly_emission_for_test(weekly, supply, circulating_supply);
        assert!(emission == circulating_supply * 2 / 1000, 2);
    }

    #[test]
    public fun test_get_duration_in_seconds() {
        let a = Staking::get_duration_in_seconds_for_test(0);
        assert!(a == SECONDS_IN_WEEK, 0);

        a = Staking::get_duration_in_seconds_for_test(1);
        assert!(a == SECONDS_IN_MONTH, 1);

        a = Staking::get_duration_in_seconds_for_test(2);
        assert!(a == SECONDS_IN_YEAR, 2);

        a = Staking::get_duration_in_seconds_for_test(3);
        assert!(a == SECONDS_IN_FOUR_YEAR, 3);
    }

    #[test]
    #[expected_failure(abort_code = 100)]
    public fun test_get_duration_in_seconds_wrong_duration() {
        let _ = Staking::get_duration_in_seconds_for_test(4);
    }

    // TODO: test update.
}