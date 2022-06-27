#[test_only]
module MultiSwap::StakingTests {
    use Std::Signer;
    use Std::Debug;

    use AptosFramework::Genesis;
    use AptosFramework::Coin;
    use AptosFramework::Table::{Self, Table};

    use MultiSwap::Liquid;
    use MultiSwap::Staking::{Self, Position};
    use MultiSwap::Liquid::LAMM;

    struct Positions has key {
        positions: Table<u128, Position>,
    }

    #[test(core = @CoreResources, staking_admin = @StakingPool, multi_swap = @MultiSwap)]
    public fun test_create_pool(core: signer, staking_admin: signer, multi_swap: signer) {
        Genesis::setup(&core);
        Liquid::initialize(&multi_swap);

        let mint_cap = Liquid::get_mint_cap(&multi_swap);

        Staking::create_pool(&staking_admin, mint_cap);
        assert!(Staking::get_total_staked() == 0, 0);
        assert!(Staking::get_period() == 0, 1);
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
        let created_at_period = Staking::get_created_at_period(&position);
        assert!(created_at_period == 0, 2);
        let last_period_paid = Staking::get_last_period_paid(&position);
        assert!(last_period_paid == 0, 3);
        let staked_for_periods = Staking::get_staked_for_periods(&position);
        assert!(staked_for_periods == 1, 4);
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

    // TODO: test update.
}