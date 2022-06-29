/// The current module contains pre-deplopyed scripts for Multi Swap.
module MultiSwap::Scripts {
    use Std::Signer;

    use AptosFramework::Coin;

    use MultiSwap::Router;

    /// Register a new liquidity pool for `X`/`Y` pair.
    public(script) fun register_pool<X, Y, LP>(account: signer, correlation_curve_type: u8) {
        Router::register_liquidity_pool<X, Y, LP>(&account, correlation_curve_type);
    }

    /// Register a new liquidity pool `X`/`Y` and immediately add liquidity.
    /// * `coin_x_val` - amount of coin `X` to add as liquidity.
    /// * `coin_x_val_min` - minimum amount of coin `X` to add as liquidity (slippage).
    /// * `coin_y_val` - minimum amount of coin `Y` to add as liquidity.
    /// * `coin_y_val_min` - minimum amount of coin `Y` to add as liquidity (slippage).
    public(script) fun register_pool_with_liquidity<X, Y, LP>(
        account: signer,
        correlation_curve_type: u8,
        coin_x_val: u64,
        coin_x_val_min: u64,
        coin_y_val: u64,
        coin_y_val_min: u64
    ) {
        let acc_addr = Signer::address_of(&account);
        Router::register_liquidity_pool<X, Y, LP>(&account, correlation_curve_type);

        add_liquidity<X, Y, LP>(
            account,
            acc_addr,
            coin_x_val,
            coin_x_val_min,
            coin_y_val,
            coin_y_val_min,
        );
    }

    /// Add liquidity to pool `X`/`Y` with liquidity coin `LP`.
    /// * `pool_addr` - address of account registered pool.
    /// * `coin_x_val` - amount of coin `X` to add as liquidity.
    /// * `coin_x_val_min` - minimum amount of coin `X` to add as liquidity (slippage).
    /// * `coin_y_val` - minimum amount of coin `Y` to add as liquidity.
    /// * `coin_y_val_min` - minimum amount of coin `Y` to add as liquidity (slippage).
    public(script) fun add_liquidity<X, Y, LP>(
        account: signer,
        pool_addr: address,
        coin_x_val: u64,
        coin_x_val_min: u64,
        coin_y_val: u64,
        coin_y_val_min: u64
    ) {
        let coin_x = Coin::withdraw<X>(&account, coin_x_val);
        let coin_y = Coin::withdraw<Y>(&account, coin_y_val);

        let (coin_x_remainder, coin_y_remainder, lp_coins) =
            Router::add_liquidity<X, Y, LP>(
                pool_addr,
                coin_x,
                coin_x_val_min,
                coin_y,
                coin_y_val_min
            );

        let account_addr = Signer::address_of(&account);

        if (!Coin::is_account_registered<LP>(account_addr)) {
            Coin::register_internal<LP>(&account);
        };

        Coin::deposit(account_addr, coin_x_remainder);
        Coin::deposit(account_addr, coin_y_remainder);
        Coin::deposit(account_addr, lp_coins);
    }

    /// Remove (burn) liquidity coins `LP`, get `X` and`Y` coins back.
    /// * `pool_addr` - address of account registered pool.
    /// * `lp_val` - amount of `LP` coins to burn.
    public(script) fun remove_liquidity<X, Y, LP>(
        account: signer,
        pool_addr: address,
        lp_val: u64,
        min_x_out_val: u64,
        min_y_out_val: u64,
    ) {
        let lp_coins = Coin::withdraw<LP>(&account, lp_val);

        let (coin_x, coin_y) = Router::remove_liquidity<X, Y, LP>(
            pool_addr,
            lp_coins,
            min_x_out_val,
            min_y_out_val
        );

        let account_addr = Signer::address_of(&account);
        Coin::deposit(account_addr, coin_x);
        Coin::deposit(account_addr, coin_y);
    }

    /// Swap exact coin `X` for at least minimum coin `Y`.
    /// * `pool_addr` - address of account registered pool.
    /// * `coin_val` - amount of coins `X` to swap.
    /// * `coin_out_min_val` - minimum expected amount of coins `Y` to get.
    public(script) fun swap<X, Y, LP>(
        account: signer,
        pool_addr: address,
        coin_val: u64,
        coin_out_min_val: u64
    ) {
        let coin_x = Coin::withdraw<X>(&account, coin_val);

        let coin_y = Router::swap_exact_coin_for_coin<X, Y, LP>(pool_addr, coin_x, coin_out_min_val);

        let account_addr = Signer::address_of(&account);
        Coin::deposit(account_addr, coin_y);
    }

    /// Swap maximum coin `X` for exact coin `Y`.
    /// * `pool_addr` - address of account registered pool.
    /// * `coin_out` - how much of coins `Y` should be returned.
    /// * `coin_max_val` - how much of coins `X` can be used to get `Y` coin.
    public(script) fun swap_into<X, Y, LP>(
        account: signer,
        pool_addr: address,
        coin_val_max: u64,
        coin_out: u64
    ) {
        let coin_x = Coin::withdraw<X>(&account, coin_val_max);

        let (coin_x, coin_y) = Router::swap_coin_for_exact_coin<X, Y, LP>(
            pool_addr,
            coin_x,
            coin_out
        );

        let account_addr = Signer::address_of(&account);
        Coin::deposit(account_addr, coin_x);
        Coin::deposit(account_addr, coin_y);
    }
}
