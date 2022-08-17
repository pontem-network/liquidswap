module dao_admin::dao_deposit {
    use std::signer;

    use aptos_framework::coin::{Self, Coin};
    use liquidswap::dao_storage;

    struct Deposit<phantom CoinType> has key { coin: Coin<CoinType> }

    public entry fun withdraw_coins_from_pool<X, Y, LP>(
        dao_admin: &signer,
        pool_address: address,
        coin_x_val: u64,
        coin_y_val: u64
    ) acquires Deposit {
        assert!(signer::address_of(dao_admin) == @dao_admin, 1);
        let (dao_x, dao_y) = dao_storage::withdraw<X, Y, LP>(
            dao_admin,
            pool_address,
            coin_x_val,
            coin_y_val
        );
        deposit_coins(dao_admin, dao_x);
        deposit_coins(dao_admin, dao_y);
    }

    fun deposit_coins<CoinType>(dao_admin: &signer, coin: Coin<CoinType>) acquires Deposit {
        assert!(signer::address_of(dao_admin) == @dao_admin, 1);
        if (!exists<Deposit<CoinType>>(@dao_admin)) {
            move_to(dao_admin, Deposit<CoinType> { coin: coin::zero() });
        };
        let deposit = borrow_global_mut<Deposit<CoinType>>(@dao_admin);
        coin::merge(&mut deposit.coin, coin);
    }

    public fun get_coin_deposit_size<CoinType>(): u64 acquires Deposit {
        assert!(exists<Deposit<CoinType>>(@dao_admin), 2);
        let deposit = borrow_global<Deposit<CoinType>>(@dao_admin);
        coin::value(&deposit.coin)
    }
}
