module liquidswap::voter {
    use std::option;
    use std::signer;

    use aptos_framework::coin::Coin;
    use aptos_std::iterable_table::{Self, IterableTable};
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info::{Self, TypeInfo};

    use liquidswap::gauge::{Self, Gauge};
    use liquidswap::ve::{Self, VE_NFT};
    use liquidswap::liquid::LAMM;
    use liquidswap::liquidity_pool;

    const ERR_WRONG_INITIALIZER: u64 = 100;

    // TODO: can be replaced with hash?
    struct PoolId has copy, drop, store {
        pool_address: address,
        x_type_info: TypeInfo,
        y_type_info: TypeInfo,
        lp_type_info: TypeInfo,
    }

    struct Voter has key {
        gauges: Table<PoolId, Gauge>,
        total_vote: u64,
    }

    public fun initialize(gov_admin: &signer) {
        assert!(signer::address_of(gov_admin) == @gov_admin, ERR_WRONG_INITIALIZER);
        move_to(gov_admin, Voter {
            gauges: table::new<PoolId, Gauge>(),
            total_vote: 0,
        });
    }

    public fun register<X, Y, LP>(pool_owner: address) acquires Voter {
        let voter = borrow_global_mut<Voter>(@gov_admin);

        // TODO: check pool doesn't exist already.

        let pool_id = get_liquidity_pool_id<X, Y, LP>(pool_owner);
        table::add(&mut voter.gauges, pool_id, gauge::zero_gauge());
    }

    // TODO: replace IterableTable with two vectors imho.
    public fun vote(ve_nft: &VE_NFT, weights: IterableTable<PoolId, u64>) acquires Voter {
        let voter = borrow_global_mut<Voter>(@gov_admin);

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
            let votes = *weight * ve_voting_power / total_weight;

            if(!table::contains(&voter.gauges, pool_id))
                table::add(&mut voter.gauges, pool_id, gauge::zero_gauge());
            let gauge = table::borrow_mut(&mut voter.gauges, pool_id);
            gauge::vote(gauge, ve_nft, votes);

            key = next;
        };
        iterable_table::destroy_empty(weights);
    }

    public fun deposit(pool_id: PoolId, coin_in: Coin<LAMM>) acquires Voter {
        let voter = borrow_global_mut<Voter>(@gov_admin);

        if(!table::contains(&voter.gauges, pool_id))
            table::add(&mut voter.gauges, pool_id, gauge::zero_gauge());

        let gauge = table::borrow_mut(&mut voter.gauges, pool_id);
        gauge::add_rewards(gauge, coin_in);
    }

    public fun claim(pool_id: &PoolId, ve_nft: &VE_NFT): Coin<LAMM> acquires Voter {
        let voter = borrow_global_mut<Voter>(@gov_admin);

        assert!(table::contains(&voter.gauges, *pool_id), 1);

        let gauge = table::borrow_mut(&mut voter.gauges, *pool_id);
        gauge::withdraw_rewards(gauge, ve_nft)
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
