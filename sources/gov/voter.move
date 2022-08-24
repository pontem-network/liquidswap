module liquidswap::voter {
    use std::option;
    use std::signer;

    use aptos_framework::coin::Coin;
    use aptos_std::iterable_table::{Self, IterableTable};
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info::{Self, TypeInfo};

    use liquidswap::gauge;
    use liquidswap::liquid::LAMM;
    use liquidswap::liquidity_pool;
    use liquidswap::ve::{Self, VE_NFT};
    use liquidswap::bribe;

    const ERR_WRONG_INITIALIZER: u64 = 100;
    const ERR_ALREADY_EXISTS: u64 = 101;
    const ERR_NOT_REGISTERED: u64 = 102;

    // TODO: can be replaced with hash?
    struct PoolId has copy, drop, store {
        pool_address: address,
        x_type_info: TypeInfo,
        y_type_info: TypeInfo,
        lp_type_info: TypeInfo,
    }

    struct Voter has key {
        total_vote: u64,
        weights: Table<PoolId, IterableTable<u64, u64>>,// pool_id->token_id->weight
        total_weight_per_toekn: Table<u64, u64>,        // token_id->total_weight
        voting_powers: Table<u64, u64>,                 // token_id->voting_power
    }

    public fun initialize(gov_admin: &signer) {
        assert!(!exists<Voter>(@gov_admin), ERR_ALREADY_EXISTS);
        assert!(signer::address_of(gov_admin) == @gov_admin, ERR_WRONG_INITIALIZER);

        move_to(gov_admin, Voter {
            total_vote: 0,
            weights: table::new<PoolId, IterableTable<u64, u64>>(),
            total_weight_per_toekn: table::new<u64, u64>(),
            voting_powers: table::new<u64, u64>(),
        });
    }

    public fun vote<X, Y, LP>(pool_addr: address, ve_nft: &VE_NFT, weight: u64) acquires Voter {
        assert!(exists<Voter>(pool_addr), ERR_NOT_REGISTERED);

        let voter = borrow_global_mut<Voter>(@gov_admin);
        let pool_id = get_liquidity_pool_id<X, Y, LP>(pool_addr);

        if (!table::contains(&mut voter.weights, pool_id)) {
            table::add(&mut voter.weights, pool_id, iterable_table::new<u64, u64>());
        };

        let ve_token_id = ve::get_nft_id(ve_nft);
        let weights_per_token = table::borrow_mut(&mut voter.weights, pool_id);
        let prev_weight = iterable_table::borrow_mut_with_default(weights_per_token, ve_token_id, 0);

        let total_weight = table::borrow_mut_with_default(
            &mut voter.total_weight_per_toekn,
            ve_token_id,
            0
        );
        *total_weight = *total_weight - *prev_weight + weight;

        *prev_weight = weight;

        let voting_power = table::borrow_mut_with_default(
            &mut voter.voting_powers,
            ve_token_id,
            0
        );
        *voting_power = ve::get_nft_voting_power(ve_nft);
    }

    public fun claim_gauge<X, Y, LP>(pool_addr: address, ve_nft: &VE_NFT): Coin<LAMM> acquires Voter {
        let (token_votes, total_votes) = get_votes<X, Y, LP>(pool_addr, ve_nft);
        gauge::withdraw_reward<X, Y, LP>(pool_addr, token_votes, total_votes)
    }

    public fun claim_bribe<X, Y, LP>(pool_addr: address, ve_nft: &VE_NFT): (Coin<X>, Coin<Y>) acquires Voter {
        let (token_votes, total_votes) = get_votes<X, Y, LP>(pool_addr, ve_nft);
        bribe::withdraw_reward<X, Y, LP>(pool_addr, token_votes, total_votes)
    }

    fun get_votes<X, Y, LP>(pool_addr: address, ve_nft: &VE_NFT): (u64, u64) acquires Voter {
        assert!(exists<Voter>(pool_addr), ERR_NOT_REGISTERED);

        let voter = borrow_global_mut<Voter>(@gov_admin);
        let pool_id = get_liquidity_pool_id<X, Y, LP>(pool_addr);

        assert!(table::contains(&voter.weights, pool_id), 1);

        let ve_token_id = ve::get_nft_id(ve_nft);
        let weights_per_token = table::borrow(&voter.weights, pool_id);

        let total_votes = 0;
        let token_votes = 0;
        let key = iterable_table::head_key(weights_per_token);
        while (option::is_some(&key)) {
            let token_id = *option::borrow(&key);
            let (weight, _, next) = iterable_table::borrow_iter(weights_per_token, token_id);
            let voting_power = table::borrow(&voter.voting_powers, token_id);
            let total_weight = table::borrow(&voter.total_weight_per_toekn, token_id);
            let votes = *voting_power * *weight / *total_weight;
            total_votes = total_votes + votes;
            if (token_id == ve_token_id) token_votes = votes;
            key = next;
        };

        (token_votes, total_votes)
    }

     public fun get_liquidity_pool_id<X, Y, LP>(pool_addr: address): PoolId {
         assert!(liquidity_pool::pool_exists_at<X, Y, LP>(pool_addr), 1);
         PoolId {
             pool_address: pool_addr,
             x_type_info: type_info::type_of<X>(),
             y_type_info: type_info::type_of<Y>(),
             lp_type_info: type_info::type_of<LP>(),
         }
    }
}
