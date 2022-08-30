module liquidswap::voter {
    use std::signer;

    use aptos_framework::coin::{Coin};
    use aptos_framework::timestamp;
    use aptos_std::iterable_table::{Self, IterableTable};
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info::{Self, TypeInfo};

    use liquidswap::bribe;
    use liquidswap::liquidity_pool;
    use liquidswap::ve::{Self, VE_NFT};

    const WEEK: u64 = 604800;

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
        last_vote: u64,
    }

    struct PoolConfig has store {
        weights: IterableTable<u64, u64>,               // token_id -> weight
    }

    struct Voter has key {
        pools: Table<PoolId, PoolConfig>,
        tokens: Table<u64, TokenCofig>,                 // token_id -> nft
    }

    public fun initialize(gov_admin: &signer) {
        assert!(!exists<Voter>(@gov_admin), ERR_ALREADY_EXISTS);
        assert!(signer::address_of(gov_admin) == @gov_admin, ERR_WRONG_INITIALIZER);

        move_to(gov_admin, Voter {
            pools: table::new(),
            tokens: table::new(),
        });
    }

    public fun vote<X, Y, LP>(pool_addr: address, ve_nft: &VE_NFT, weight: u64) acquires Voter {
        assert!(exists<Voter>(@gov_admin), ERR_NOT_REGISTERED);

        let voter = borrow_global_mut<Voter>(@gov_admin);
        let pool_id = get_liquidity_pool_id<X, Y, LP>(pool_addr);

        if (!table::contains(&mut voter.pools, pool_id)) {
            table::add(&mut voter.pools, pool_id, PoolConfig {
                weights: iterable_table::new(),
            });
        };

        let ve_token_id = ve::get_nft_id(ve_nft);
        let pool_config = table::borrow_mut(&mut voter.pools, pool_id);

        // The old vote weight is overwritten by the new one.
        let old_weight = iterable_table::borrow_mut_with_default(
            &mut pool_config.weights,
            ve_token_id,
            0
        );
        let token_config = table::borrow_mut_with_default(
            &mut voter.tokens,
            ve_token_id,
            zero_token_config()
        );
        token_config.total_weight = token_config.total_weight - *old_weight + weight;
        *old_weight = weight;

        let point_token = ve::get_nft_history_point(ve_nft, ve::get_nft_epoch(ve_nft));
        let votes = ve::get_voting_power(&point_token) * weight / token_config.total_weight;
        bribe::deposit<X, Y, LP>(pool_addr, ve_nft, votes);
    }

    public fun claim_bribe<X, Y, LP>(pool_addr: address, ve_nft: &VE_NFT): (Coin<X>, Coin<Y>) {
        bribe::get_reward<X, Y, LP>(pool_addr, ve_nft)
    }

    fun zero_token_config(): TokenCofig {
        let t = timestamp::now_seconds();
        TokenCofig {
            total_weight: 0,
            last_vote: t,
        }
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
