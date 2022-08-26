module liquidswap::voter {
    use std::option;
    use std::signer;

    use aptos_framework::coin::Coin;
    use aptos_std::iterable_table::{Self, IterableTable};
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info::{Self, TypeInfo};

    use liquidswap::bribe;
    use liquidswap::gauge;
    use liquidswap::liquid::LAMM;
    use liquidswap::liquidity_pool;
    use liquidswap::ve::{Self, VE_NFT};

    const ERR_WRONG_INITIALIZER: u64 = 100;
    const ERR_ALREADY_EXISTS: u64 = 101;
    const ERR_NOT_REGISTERED: u64 = 102;
    const ERR_KEY_NOT_FOUND: u64 = 103;
    const ERR_POOL_DOES_NOT_EXIST: u64 = 104;

    struct PoolId has copy, drop, store {
        pool_address: address,
        x_type_info: TypeInfo,
        y_type_info: TypeInfo,
        lp_type_info: TypeInfo,
    }

    struct TokenCofig has copy, drop, store {
        total_weight: u64,
        history_point: ve::Point,
    }

    struct Voter has key {
        weights: Table<PoolId, IterableTable<u64, u64>>,// pool_id -> token_id -> weight
        tokens: Table<u64, TokenCofig>,                 // token_id -> nft
    }

    public fun initialize(gov_admin: &signer) {
        assert!(!exists<Voter>(@gov_admin), ERR_ALREADY_EXISTS);
        assert!(signer::address_of(gov_admin) == @gov_admin, ERR_WRONG_INITIALIZER);

        move_to(gov_admin, Voter {
            weights: table::new(),
            tokens: table::new()
        });
    }

    public fun vote<X, Y, LP>(pool_addr: address, ve_nft: &VE_NFT, weight: u64) acquires Voter {
        assert!(exists<Voter>(@gov_admin), ERR_NOT_REGISTERED);

        let voter = borrow_global_mut<Voter>(@gov_admin);
        let pool_id = get_liquidity_pool_id<X, Y, LP>(pool_addr);

        if (!table::contains(&mut voter.weights, pool_id)) {
            table::add(&mut voter.weights, pool_id, iterable_table::new());
        };

        let ve_token_id = ve::get_nft_id(ve_nft);
        let weights_per_token = table::borrow_mut(&mut voter.weights, pool_id);

        // The previous vote weight is overwritten by the new one.
        let prev_weight = iterable_table::borrow_mut_with_default(weights_per_token, ve_token_id, 0);
        let config = table::borrow_mut_with_default(&mut voter.tokens, ve_token_id, TokenCofig {
            total_weight: 0,
            history_point: ve::zero_point()
        });
        config.total_weight = config.total_weight - *prev_weight + weight;
        *prev_weight = weight;

        config.history_point = ve::get_nft_history_point(ve_nft, ve::get_nft_epoch(ve_nft));
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

        assert!(table::contains(&voter.weights, pool_id), ERR_KEY_NOT_FOUND);

        let ve_token_id = ve::get_nft_id(ve_nft);
        let weights_per_token = table::borrow(&voter.weights, pool_id);

        let total_votes = 0;
        let token_votes = 0;
        let key = iterable_table::head_key(weights_per_token);
        while (option::is_some(&key)) {
            let token_id = *option::borrow(&key);
            let (weight, _, next) = iterable_table::borrow_iter(weights_per_token, token_id);

            let config = table::borrow(&voter.tokens, token_id);
            let voting_power = ve::get_voting_power(&config.history_point);
            let votes = voting_power * *weight / config.total_weight;
            total_votes = total_votes + votes;
            if (token_id == ve_token_id) token_votes = votes;

            key = next;
        };

        (token_votes, total_votes)
    }

     public fun get_liquidity_pool_id<X, Y, LP>(pool_addr: address): PoolId {
         assert!(liquidity_pool::pool_exists_at<X, Y, LP>(pool_addr), ERR_POOL_DOES_NOT_EXIST);
         PoolId {
             pool_address: pool_addr,
             x_type_info: type_info::type_of<X>(),
             y_type_info: type_info::type_of<Y>(),
             lp_type_info: type_info::type_of<LP>(),
         }
    }
}
