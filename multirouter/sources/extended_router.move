module multirouter::router {
    use std::signer;
    use aptos_framework::coin;

    use liquidswap::coin_helper;
    use liquidswap::liquidity_pool;
    use liquidswap::router_v2;

    /// Insufficient amount .
    const ERR_INSUFFICIENT_AMOUNT: u64 = 4000;

    /// Swap coin `X` for coin `Y` WITHOUT CHECKING input and output amount.
    /// It requires paths and curves from `X` to `Z` and the length is 2.
    /// `X` -> `Z` -> `Y`
    /// And `C1` and `C2` will be used as curves.
    /// So use the following function only on your own risk.
    /// * `account` - signer of user.
    /// * `coin_in_val` - amount of coin X to swap.
    /// * `coin_out_val` - amount of coin Y to get out.
    public entry fun swap_coin_for_coin_unchecked_x2<X, Z, Y, C1, C2>(
        account: &signer,
        coin_in_val: u64,
        coin_out_val: u64,
    ) {
        // First we should get get_amount_in for Z.
        let coin_z_needed = router_v2::get_amount_in<Z, Y, C2>(coin_out_val);
        let coin_x_needed = router_v2::get_amount_in<X, Z, C1>(coin_z_needed);

        assert!(coin_in_val <= coin_x_needed, ERR_INSUFFICIENT_AMOUNT);

        // Now we need to extract amount of X from the user.
        let coin_in = coin::withdraw<X>(account, coin_x_needed);

        // Doing swap.
        let coin_out_1 = if (coin_helper::is_sorted<X, Z>()) {
            let (zero, coin_out) = liquidity_pool::swap<X, Z, C1>(coin_in, 0, coin::zero(), coin_z_needed);
            coin::destroy_zero(zero);
            coin_out
        } else {
            let (coin_out, zero) = liquidity_pool::swap<Z, X, C1>(coin::zero(), coin_z_needed, coin_in, 0);
            coin::destroy_zero(zero);
            coin_out
        };

        let coin_out = if (coin_helper::is_sorted<Z, Y>()) {
            let (zero, coin_out) = liquidity_pool::swap<Z, Y, C2>(coin_out_1, 0, coin::zero(), coin_out_val);
            coin::destroy_zero(zero);
            coin_out
        } else {
            let (coin_out, zero) = liquidity_pool::swap<Y, Z, C2>(coin::zero(), coin_out_val, coin_out_1, 0);
            coin::destroy_zero(zero);
            coin_out
        };

        let account_addr = signer::address_of(account);
        if (!coin::is_account_registered<Y>(account_addr)) {
            coin::register<Y>(account);
        };
        coin::deposit(account_addr, coin_out);
    }

    /// Swap coin `X` for coin `Y` WITHOUT CHECKING input and output amount.
    /// It requires paths and curves from `X` to `Y` and the length is 3.
    /// `X` -> `Z` -> `W` -> `Y`
    /// So use the following function only on your own risk.
    /// And `C1` and `C2`, `C3` will be used as curves.
    /// * `account` - signer of user.
    /// * `coin_in_val` - amount of coin X to swap.
    /// * `coin_out_val` - amount of coin Y to get out.
    public entry fun swap_coin_for_coin_unchecked_x3<X, Z, W, Y, C1, C2, C3>(
        account: &signer,
        coin_in_val: u64,
        coin_out_val: u64,
    ) {
        let coin_w_needed = router_v2::get_amount_in<W, Y, C3>(coin_out_val);
        let coin_z_needed = router_v2::get_amount_in<Z, W, C2>(coin_w_needed);
        let coin_x_needed = router_v2::get_amount_in<X, Z, C1>(coin_z_needed);

        assert!(coin_in_val <= coin_x_needed, ERR_INSUFFICIENT_AMOUNT);

        let coin_in = coin::withdraw<X>(account, coin_x_needed);

        let coin_out_2 = if (coin_helper::is_sorted<X, Z>()) {
            let (zero, coin_out) = liquidity_pool::swap<X, Z, C1>(coin_in, 0, coin::zero(), coin_z_needed);
            coin::destroy_zero(zero);
            coin_out
        } else {
            let (coin_out, zero) = liquidity_pool::swap<Z, X, C1>(coin::zero(), coin_z_needed, coin_in, 0);
            coin::destroy_zero(zero);
            coin_out
        };

        let coin_out_1 = if (coin_helper::is_sorted<Z, W>()) {
            let (zero, coin_out) = liquidity_pool::swap<Z, W, C2>(coin_out_2, 0, coin::zero(), coin_w_needed);
            coin::destroy_zero(zero);
            coin_out
        } else {
            let (coin_out, zero) = liquidity_pool::swap<W, Z, C2>(coin::zero(), coin_w_needed, coin_out_2, 0);
            coin::destroy_zero(zero);
            coin_out
        };

        let coin_out = if (coin_helper::is_sorted<W, Y>()) {
            let (zero, coin_out) = liquidity_pool::swap<W, Y, C3>(coin_out_1, 0, coin::zero(), coin_out_val);
            coin::destroy_zero(zero);
            coin_out
        } else {
            let (coin_out, zero) = liquidity_pool::swap<Y, W, C3>(coin::zero(), coin_out_val, coin_out_1, 0);
            coin::destroy_zero(zero);
            coin_out
        };

        let account_addr = signer::address_of(account);
        if (!coin::is_account_registered<Y>(account_addr)) {
            coin::register<Y>(account);
        };
        coin::deposit(account_addr, coin_out);
    }

    /// Swap coin `X` for coin `Y` WITHOUT CHECKING input and output amount.
    /// It requires paths and curves from `X` to `Y` and the length is 4.
    /// `X` -> `Z` -> `W` -> `V` -> `Y`
    /// And `C1` and `C2`, `C3`, `C4`, will be used as curves.
    /// So use the following function only on your own risk.
    /// * `account` - signer of user.
    /// * `coin_in_val` - amount of coin X to swap.
    /// * `coin_out_val` - amount of coin Y to get out.
    public entry fun swap_coin_for_coin_unchecked_x4<X, Z, W, V, Y, C1, C2, C3, C4>(
        account: &signer,
        coin_in_val: u64,
        coin_out_val: u64,
    ) {
        let coin_v_needed = router_v2::get_amount_in<V, Y, C4>(coin_out_val);
        let coin_w_needed = router_v2::get_amount_in<W, V, C3>(coin_v_needed);
        let coin_z_needed = router_v2::get_amount_in<Z, W, C2>(coin_w_needed);
        let coin_x_needed = router_v2::get_amount_in<X, Z, C1>(coin_z_needed);

        assert!(coin_in_val <= coin_x_needed, ERR_INSUFFICIENT_AMOUNT);

        let coin_in = coin::withdraw<X>(account, coin_x_needed);

        let coin_out_3 = if (coin_helper::is_sorted<X, Z>()) {
            let (zero, coin_out) = liquidity_pool::swap<X, Z, C1>(coin_in, 0, coin::zero(), coin_z_needed);
            coin::destroy_zero(zero);
            coin_out
        } else {
            let (coin_out, zero) = liquidity_pool::swap<Z, X, C1>(coin::zero(), coin_z_needed, coin_in, 0);
            coin::destroy_zero(zero);
            coin_out
        };

        let coin_out_2 = if (coin_helper::is_sorted<Z, W>()) {
            let (zero, coin_out) = liquidity_pool::swap<Z, W, C2>(coin_out_3, 0, coin::zero(), coin_w_needed);
            coin::destroy_zero(zero);
            coin_out
        } else {
            let (coin_out, zero) = liquidity_pool::swap<W, Z, C2>(coin::zero(), coin_w_needed, coin_out_3, 0);
            coin::destroy_zero(zero);
            coin_out
        };

        let coin_out_1 = if (coin_helper::is_sorted<W, V>()) {
            let (zero, coin_out) = liquidity_pool::swap<W, V, C3>(coin_out_2, 0, coin::zero(), coin_v_needed);
            coin::destroy_zero(zero);
            coin_out
        } else {
            let (coin_out, zero) = liquidity_pool::swap<V, W, C3>(coin::zero(), coin_v_needed, coin_out_2, 0);
            coin::destroy_zero(zero);
            coin_out
        };

        let coin_out = if (coin_helper::is_sorted<V, Y>()) {
            let (zero, coin_out) = liquidity_pool::swap<V, Y, C4>(coin_out_1, 0, coin::zero(), coin_out_val);
            coin::destroy_zero(zero);
            coin_out
        } else {
            let (coin_out, zero) = liquidity_pool::swap<Y, V, C4>(coin::zero(), coin_out_val, coin_out_1, 0);
            coin::destroy_zero(zero);
            coin_out
        };

        let account_addr = signer::address_of(account);
        if (!coin::is_account_registered<Y>(account_addr)) {
            coin::register<Y>(account);
        };
        coin::deposit(account_addr, coin_out);
    }
}