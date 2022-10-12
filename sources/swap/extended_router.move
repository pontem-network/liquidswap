module liquidswap::extended_router {
    // This is the extended router that supports multi path swap.
    use aptos_framework::coin::{Coin, Self};

    use liquidswap::coin_helper::{Self};
    use liquidswap::liquidity_pool;
    use liquidswap::router;

    /// Swap coin `X` for coin `Y` WITHOUT CHECKING input and output amount.
    /// It requires paths and curves from `X` to `Y` and the length is 2.
    /// `X` -> `Z` -> `Y`
    /// And `Curve1` and `Curve2` are the curves for consequent pair pools.
    /// So use the following function only on your own risk.
    /// * `coin_in` - coin X to swap.
    /// * `coin_out_val` - amount of coin Y to get out.
    /// Returns `Coin<Y>`.
    public fun swap_coin_for_coin_unchecked_x2<X, Z, Y, Curve1, Curve2>(
        coin_in: Coin<X>,
        coin_out_val: u64,
    ): Coin<Y> {
        let (zero, coin_out, coin_mid, zero_mid, coin_mid_val);

        if (coin_helper::is_sorted<X, Z>()) {
            coin_mid_val = router::get_amount_out<X, Z, Curve1>(coin::value(&coin_in));
            (zero_mid, coin_mid) = liquidity_pool::swap<X, Z, Curve1>(coin_in, 0, coin::zero(), coin_mid_val);
        } else {
            coin_mid_val = router::get_amount_out<Z, X, Curve1>(coin::value(&coin_in));
            (coin_mid, zero_mid) = liquidity_pool::swap<Z, X, Curve1>(coin::zero(), coin_mid_val, coin_in, 0);
        };

        if (coin_helper::is_sorted<Z, Y>()) {
            (zero, coin_out) = liquidity_pool::swap<Z, Y, Curve2>(coin_mid, 0, coin::zero(), coin_out_val);
        } else {
            (coin_out, zero) = liquidity_pool::swap<Y, Z, Curve2>(coin::zero(), coin_out_val, coin_mid, 0);
        };

        coin::destroy_zero(zero);
        coin::destroy_zero(zero_mid);

        coin_out
    }

    /// Swap coin `X` for coin `Y` WITHOUT CHECKING input and output amount.
    /// It requires paths and curves from `X` to `Y` and the length is 3.
    /// `X` -> `Z` -> `W` -> `Y`
    /// And `Curve1`, `Curve2`, and `Curve3` are the curves for consequent pair pools respectively.
    /// So use the following function only on your own risk.
    /// * `coin_in` - coin X to swap.
    /// * `coin_out_val` - amount of coin Y to get out.
    /// Returns `Coin<Y>`.
    public fun swap_coin_for_coin_unchecked_x3<X, Z, W, Y, Curve1, Curve2, Curve3>(
        coin_in: Coin<X>,
        coin_out_val: u64,
    ): Coin<Y> {
        let (zero, coin_out, coin_mid, zero_mid, coin_mid_val, coin_mid_next, zero_mid_next, coin_mid_next_val);

        coin_mid_val = router::get_amount_out<X, Z, Curve1>(coin::value(&coin_in));
        if (coin_helper::is_sorted<X, Z>()) {
            (zero_mid, coin_mid) = liquidity_pool::swap<X, Z, Curve1>(coin_in, 0, coin::zero(), coin_mid_val);
        } else {
            (coin_mid, zero_mid) = liquidity_pool::swap<Z, X, Curve1>(coin::zero(), coin_mid_val, coin_in, 0);
        };

        coin_mid_next_val = router::get_amount_out<Z, W, Curve2>(coin::value(&coin_mid));
        if (coin_helper::is_sorted<Z, W>()) {
            (zero_mid_next, coin_mid_next) = liquidity_pool::swap<Z, W, Curve2>(coin_mid, 0, coin::zero(), coin_mid_next_val);
        } else {
            (coin_mid_next, zero_mid_next) = liquidity_pool::swap<W, Z, Curve2>(coin::zero(), coin_mid_next_val, coin_mid, 0);
        };

        if (coin_helper::is_sorted<W, Y>()) {
            (zero, coin_out) = liquidity_pool::swap<W, Y, Curve3>(coin_mid_next, 0, coin::zero(), coin_out_val);
        } else {
            (coin_out, zero) = liquidity_pool::swap<Y, W, Curve3>(coin::zero(), coin_out_val, coin_mid_next, 0);
        };

        coin::destroy_zero(zero);
        coin::destroy_zero(zero_mid);
        coin::destroy_zero(zero_mid_next);

        coin_out
    }

    /// Swap coin `X` for coin `Y` WITHOUT CHECKING input and output amount.
    /// It requires paths and curves from `X` to `Y` and the length is 4.
    /// `X` -> `Z` -> `W` -> `V` -> `Y`
    /// And `Curve1`, `Curve2`, `Curve3`, and `Curve4` are the curves for consequent pair pools respectively.
    /// So use the following function only on your own risk.
    /// * `coin_in` - coin X to swap.
    /// * `coin_out_val` - amount of coin Y to get out.
    /// Returns `Coin<Y>`.
    public fun swap_coin_for_coin_unchecked_x4<X, Z, W, V, Y, Curve1, Curve2, Curve3, Curve4>(
        coin_in: Coin<X>,
        coin_out_val: u64,
    ): Coin<Y> {
        let (zero, coin_out, coin_mid, zero_mid, coin_mid_val, coin_mid_next, zero_mid_next, coin_mid_next_val, coin_last, zero_last, coin_last_val);

        coin_mid_val = router::get_amount_out<X, Z, Curve1>(coin::value(&coin_in));
        if (coin_helper::is_sorted<X, Z>()) {
            (zero_mid, coin_mid) = liquidity_pool::swap<X, Z, Curve1>(coin_in, 0, coin::zero(), coin_mid_val);
        } else {
            (coin_mid, zero_mid) = liquidity_pool::swap<Z, X, Curve1>(coin::zero(), coin_mid_val, coin_in, 0);
        };

        coin_mid_next_val = router::get_amount_out<Z, W, Curve2>(coin::value(&coin_mid));
        if (coin_helper::is_sorted<Z, W>()) {
            (zero_mid_next, coin_mid_next) = liquidity_pool::swap<Z, W, Curve2>(coin_mid, 0, coin::zero(), coin_mid_next_val);
        } else {
            (coin_mid_next, zero_mid_next) = liquidity_pool::swap<W, Z, Curve2>(coin::zero(), coin_mid_next_val, coin_mid, 0);
        };

        coin_last_val = router::get_amount_out<W, V, Curve3>(coin::value(&coin_mid_next));
        if (coin_helper::is_sorted<W, V>()) {
            (zero_last, coin_last) = liquidity_pool::swap<W, V, Curve3>(coin_mid_next, 0, coin::zero(), coin_last_val);
        } else {
            (coin_last, zero_last) = liquidity_pool::swap<V, W, Curve3>(coin::zero(), coin_last_val, coin_mid_next, 0);
        };

        if(coin_helper::is_sorted<V, Y>()) {
            (zero, coin_out) = liquidity_pool::swap<V, Y, Curve4>(coin_last, 0, coin::zero(), coin_out_val);
        } else {
            (coin_out, zero) = liquidity_pool::swap<Y, V, Curve4>(coin::zero(), coin_out_val, coin_last, 0);
        };

        coin::destroy_zero(zero);
        coin::destroy_zero(zero_mid);
        coin::destroy_zero(zero_mid_next);
        coin::destroy_zero(zero_last);

        coin_out
    }
}