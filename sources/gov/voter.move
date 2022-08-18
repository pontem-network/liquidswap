module liquidswap::voter {
    use std::option;

    use aptos_framework::coin::Coin;
    use aptos_std::iterable_table::{Self, IterableTable};
    use aptos_std::table::{Self, Table};

    use liquidswap::gauge::PoolId;
    use liquidswap::ve::{Self, VE_NFT};
    use liquidswap::liquid::LAMM;
    use liquidswap::gauge;

    struct Votes has key {
        total_vote: u64,
        // pool_id -> total voted
        total_voted_by_pool: Table<PoolId, u64>,
        // pool_id -> table<token_id, stake>
        items: IterableTable<PoolId, IterableTable<u64, u64>>,
    }

    public fun initialize(gov_admin: &signer) {
        move_to(gov_admin, Votes {
            total_vote: 0,
            total_voted_by_pool: table::new(),
            items: iterable_table::new(),
        });
    }

    public fun vote(ve_nft: &VE_NFT, weights: IterableTable<PoolId, u64>) acquires Votes {
        let total_weight = 0;
        let key = iterable_table::head_key(&weights);
        while (option::is_some(&key)) {
            let (weight, _, next) =
                iterable_table::borrow_iter(&weights, *option::borrow(&key));
            total_weight = total_weight + *weight;
            key = next;
        };

        let ve_voting_power = ve::get_nft_voting_power(ve_nft);
        key = iterable_table::head_key(&weights);
        while (option::is_some(&key)) {
            let (weight, _, next) =
                iterable_table::borrow_iter(&weights, *option::borrow(&key));
            let pool_id = *option::borrow(&key);
            let vote_stake = *weight * ve_voting_power / total_weight;
            vote_for_pool_internal(ve_nft, pool_id, vote_stake);
            key = next;
        };
        iterable_table::destroy_empty(weights);
    }

    fun vote_for_pool_internal(ve_nft: &VE_NFT, pool_id: PoolId, vote_stake: u64) acquires Votes {
        let votes = borrow_global_mut<Votes>(@gov_admin);
        let ve_token_id = ve::get_nft_id(ve_nft);

        if (!iterable_table::contains(&votes.items, pool_id)) {
            iterable_table::add(&mut votes.items, pool_id, iterable_table::new());
        };
        let pool_votes = iterable_table::borrow_mut(&mut votes.items, pool_id);
        let pool_nft_vote = iterable_table::borrow_mut_with_default(pool_votes, ve_token_id, 0);
        *pool_nft_vote = vote_stake;

        let pool_total_vote = table::borrow_mut_with_default(
            &mut votes.total_voted_by_pool,
            pool_id,
            0
        );
        *pool_total_vote = *pool_total_vote + vote_stake;
    }

    public fun deposit(pool_id: PoolId, amount: Coin<LAMM>) {
        gauge::add_rewards(pool_id, amount);
    }

    public fun claim(ve_nft: &VE_NFT, pool_id: PoolId): Coin<LAMM> acquires Votes {
        let votes = borrow_global_mut<Votes>(@gov_admin);
        assert!(table::contains(&votes.total_voted_by_pool, pool_id), 1);
        let total_pool_votes = table::borrow(&votes.total_voted_by_pool, pool_id);

        let ve_token_id = ve::get_nft_id(ve_nft);
        let item = iterable_table::borrow(&votes.items, pool_id);
        let token_votes = iterable_table::borrow(item, ve_token_id);
        gauge::withdraw_rewards(pool_id, *token_votes, *total_pool_votes)
    }
}
