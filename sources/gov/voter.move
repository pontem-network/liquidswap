module liquidswap::voter {
    use std::string::String;
    use std::vector;

    use aptos_framework::coin::{Self, Coin};
    use aptos_std::table::{Self, Table};

    use gov_admin::iter_table::{Self, IterTable};
    use liquidswap::liquid::LAMM;
    use liquidswap::liquidity_pool;
    use liquidswap::ve::{Self, VE_NFT};

    struct PoolId has copy, drop, store {
        pool_address: address,
        x_symbol: String,
        y_symbol: String,
        lp_symbol: String,
    }

    struct Voter has key {
        total_vote: u64,
        // token_id -> total stake
        total_voted_by_nft: Table<u64, u64>,
        // pool_id -> total voted
        total_voted_by_pool: Table<PoolId, u64>,
        // pool_id -> table<token_id, stake>
        items: IterTable<PoolId, IterTable<u64, u64>>,
        // token_id -> coins
        rewards: Table<u64, Coin<LAMM>>
    }

    public fun initialize(gov_admin: &signer) {
        move_to(gov_admin, Voter {
            total_vote: 0,
            total_voted_by_nft: table::new(),
            total_voted_by_pool: table::new(),
            items: iter_table::new(),
            rewards: table::new()
        });
    }

    public fun vote_for_liquidity_pool<X, Y, LP>(pool_addr: address, ve_nft: &VE_NFT, vote_stake: u64) acquires Voter {
        let pool_voting_id = get_liquidity_pool_id<X, Y, LP>(pool_addr);
        let ve_token_id = ve::get_nft_id(ve_nft);
        let ve_total_stake = ve::get_nft_staked_value(ve_nft);

        let votes = borrow_global_mut<Voter>(@gov_admin);
        let ve_voted_stake = table::borrow_mut_with_default(&mut votes.total_voted_by_nft, ve_token_id, 0);
        let ve_remaining_stake = ve_total_stake - *ve_voted_stake;
        assert!(vote_stake >= ve_remaining_stake, 2);

        if (!iter_table::contains(&votes.items, pool_voting_id)) {
            iter_table::add(&mut votes.items, pool_voting_id, iter_table::new());
        };
        let pool_votes = iter_table::borrow_mut(&mut votes.items, pool_voting_id);
        let pool_nft_vote = iter_table::borrow_mut_with_default(pool_votes, ve_token_id, 0);
        *pool_nft_vote = *pool_nft_vote + vote_stake;

        *ve_voted_stake = *ve_voted_stake + vote_stake;

        let pool_total_vote = table::borrow_mut_with_default(
            &mut votes.total_voted_by_pool,
            pool_voting_id,
            0
        );
        *pool_total_vote = *pool_total_vote + vote_stake;
    }

    public fun distribute_rewards(rewards: Coin<LAMM>) acquires Voter {
        let votes = borrow_global_mut<Voter>(@gov_admin);
        let total_rewards = coin::value(&rewards);

        let pools = iter_table::keys(&votes.items);
        let i = 0;
        while (i < vector::length(pools)) {
            let pool_id = *vector::borrow(pools, i);
            let pool_total_vote = if (table::contains(&votes.total_voted_by_pool, pool_id)) {
                *table::borrow(&votes.total_voted_by_pool, pool_id)
            } else {
                0
            };
            let pool_rewards_amount = total_rewards * pool_total_vote / votes.total_vote;
            let pool_rewards = coin::extract(&mut rewards, pool_rewards_amount);
            let pool_weights = iter_table::borrow(&votes.items, pool_id);
            // TODO: now distribute over Votes.rewards table for users using `pool_weights` (see keys() method in the underlying table)
            i = i + 1;
        }
    }

    fun get_liquidity_pool_id<X, Y, LP>(pool_addr: address): PoolId {
        assert!(liquidity_pool::pool_exists_at<X, Y, LP>(pool_addr), 1);
        PoolId {
            pool_address: pool_addr,
            x_symbol: coin::symbol<X>(),
            y_symbol: coin::symbol<Y>(),
            lp_symbol: coin::symbol<LP>(),
        }
    }
}
