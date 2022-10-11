/// Router for Liquidity Pool, similar to Uniswap router.
module liquidswap::router {
    // !!! FOR AUDITOR!!!
    // Look at math part of this contract.
    use aptos_framework::coin::{Coin, Self};

    use liquidswap::coin_helper::{Self, supply};
    use liquidswap::curves;
    use liquidswap::math;
    use liquidswap::stable_curve;
    use liquidswap::liquidity_pool;
    use liquidswap_lp::lp_coin::LP;

    // Errors codes.

    /// Wrong amount used.
    const ERR_WRONG_AMOUNT: u64 = 200;
    /// Wrong reserve used.
    const ERR_WRONG_RESERVE: u64 = 201;
    /// Wrong order of coin parameters.
    const ERR_WRONG_COIN_ORDER: u64 = 208;
    /// Insufficient amount in Y reserves.
    const ERR_INSUFFICIENT_Y_AMOUNT: u64 = 202;
    /// Insufficient amount in X reserves.
    const ERR_INSUFFICIENT_X_AMOUNT: u64 = 203;
    /// Overlimit of X coins to swap.
    const ERR_OVERLIMIT_X: u64 = 204;
    /// Amount out less than minimum.
    const ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM: u64 = 205;
    /// Needed amount in great than maximum.
    const ERR_COIN_VAL_MAX_LESS_THAN_NEEDED: u64 = 206;
    /// Marks the unreachable place in code
    const ERR_UNREACHABLE: u64 = 207;

    // Public functions.

    /// Register new liquidity pool for `X`/`Y` pair on signer address with `LP` coin.
    ///
    /// Note: X, Y generic coin parameters must be sorted.
    public fun register_pool<X, Y, Curve>(account: &signer) {
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_COIN_ORDER);
        liquidity_pool::register<X, Y, Curve>(account);
    }

    /// Add liquidity to pool `X`/`Y` with rationality checks.
    /// * `coin_x` - coin X to add as liquidity.
    /// * `min_coin_x_val` - minimum amount of coin X to add as liquidity.
    /// * `coin_y` - coin Y to add as liquidity.
    /// * `min_coin_y_val` - minimum amount of coin Y to add as liquidity.
    /// Returns remainders of coins X and Y, and LP coins: `(Coin<X>, Coin<Y>, Coin<LP<X, Y, Curve>>)`.
    ///
    /// Note: X, Y generic coin parameters must be sorted.
    public fun add_liquidity<X, Y, Curve>(
        coin_x: Coin<X>,
        min_coin_x_val: u64,
        coin_y: Coin<Y>,
        min_coin_y_val: u64,
    ): (Coin<X>, Coin<Y>, Coin<LP<X, Y, Curve>>) {
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_COIN_ORDER);

        let coin_x_val = coin::value(&coin_x);
        let coin_y_val = coin::value(&coin_y);

        assert!(coin_x_val >= min_coin_x_val, ERR_INSUFFICIENT_X_AMOUNT);
        assert!(coin_y_val >= min_coin_y_val, ERR_INSUFFICIENT_Y_AMOUNT);

        let (optimal_x, optimal_y) =
            calc_optimal_coin_values<X, Y, Curve>(
                coin_x_val,
                coin_y_val,
                min_coin_x_val,
                min_coin_y_val
            );

        let coin_x_opt = coin::extract(&mut coin_x, optimal_x);
        let coin_y_opt = coin::extract(&mut coin_y, optimal_y);

        let lp_coins = liquidity_pool::mint<X, Y, Curve>(coin_x_opt, coin_y_opt);
        (coin_x, coin_y, lp_coins)
    }

    /// Burn liquidity coins `LP` and get coins `X` and `Y` back.
    /// * `lp_coins` - `LP` coins to burn.
    /// * `min_x_out_val` - minimum amount of `X` coins must be out.
    /// * `min_y_out_val` - minimum amount of `Y` coins must be out.
    /// Returns both `Coin<X>` and `Coin<Y>`: `(Coin<X>, Coin<Y>)`.
    ///
    /// Note: X, Y generic coin parameteres should be sorted.
    public fun remove_liquidity<X, Y, Curve>(
        lp_coins: Coin<LP<X, Y, Curve>>,
        min_x_out_val: u64,
        min_y_out_val: u64,
    ): (Coin<X>, Coin<Y>) {
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_COIN_ORDER);

        let (x_out, y_out) = liquidity_pool::burn<X, Y, Curve>(lp_coins);

        assert!(
            coin::value(&x_out) >= min_x_out_val,
            ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM
        );
        assert!(
            coin::value(&y_out) >= min_y_out_val,
            ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM
        );
        (x_out, y_out)
    }

    /// Swap exact amount of coin `X` for coin `Y`.
    /// * `coin_in` - coin X to swap.
    /// * `coin_out_min_val` - minimum amount of coin Y to get out.
    /// Returns `Coin<Y>`.
    public fun swap_exact_coin_for_coin<X, Y, Curve>(
        coin_in: Coin<X>,
        coin_out_min_val: u64,
    ): Coin<Y> {
        let coin_in_val = coin::value(&coin_in);
        let coin_out_val = get_amount_out<X, Y, Curve>(coin_in_val);

        assert!(
            coin_out_val >= coin_out_min_val,
            ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM,
        );

        let coin_out = swap_coin_for_coin_unchecked<X, Y, Curve>(coin_in, coin_out_val);
        coin_out
    }

    /// Swap max coin amount `X` for exact coin `Y`.
    /// * `coin_max_in` - maximum amount of coin X to swap to get `coin_out_val` of coins Y.
    /// * `coin_out_val` - exact amount of coin Y to get.
    /// Returns remainder of `coin_max_in` as `Coin<X>` and `Coin<Y>`: `(Coin<X>, Coin<Y>)`.
    public fun swap_coin_for_exact_coin<X, Y, Curve>(
        coin_max_in: Coin<X>,
        coin_out_val: u64,
    ): (Coin<X>, Coin<Y>) {
        let coin_in_val_needed = get_amount_in<X, Y, Curve>(coin_out_val);

        let coin_val_max = coin::value(&coin_max_in);
        assert!(
            coin_in_val_needed <= coin_val_max,
            ERR_COIN_VAL_MAX_LESS_THAN_NEEDED
        );

        let coin_in = coin::extract(&mut coin_max_in, coin_in_val_needed);
        let coin_out = swap_coin_for_coin_unchecked<X, Y, Curve>(coin_in, coin_out_val);

        (coin_max_in, coin_out)
    }

    /// Swap coin `X` for coin `Y` WITHOUT CHECKING input and output amount.
    /// So use the following function only on your own risk.
    /// * `coin_in` - coin X to swap.
    /// * `coin_out_val` - amount of coin Y to get out.
    /// Returns `Coin<Y>`.
    public fun swap_coin_for_coin_unchecked<X, Y, Curve>(
        coin_in: Coin<X>,
        coin_out_val: u64,
    ): Coin<Y> {
        let (zero, coin_out);
        if (coin_helper::is_sorted<X, Y>()) {
            (zero, coin_out) = liquidity_pool::swap<X, Y, Curve>(coin_in, 0, coin::zero(), coin_out_val);
        } else {
            (coin_out, zero) = liquidity_pool::swap<Y, X, Curve>(coin::zero(), coin_out_val, coin_in, 0);
        };
        coin::destroy_zero(zero);

        coin_out
    }

    // Getters.

    /// Get decimals scales for stable curve, for uncorrelated curve would return zeros.
    /// Returns `X` and `Y` coins decimals scales.
    public fun get_decimals_scales<X, Y, Curve>(): (u64, u64) {
        if (coin_helper::is_sorted<X, Y>()) {
            liquidity_pool::get_decimals_scales<X, Y, Curve>()
        } else {
            let (y, x) = liquidity_pool::get_decimals_scales<Y, X, Curve>();
            (x, y)
        }
    }

    /// Get current cumulative prices in liquidity pool `X`/`Y`.
    /// Returns (X price, Y price, block_timestamp).
    public fun get_cumulative_prices<X, Y, Curve>(): (u128, u128, u64) {
        if (coin_helper::is_sorted<X, Y>()) {
            liquidity_pool::get_cumulative_prices<X, Y, Curve>()
        } else {
            let (y, x, t) = liquidity_pool::get_cumulative_prices<Y, X, Curve>();
            (x, y, t)
        }
    }

    /// Get reserves of liquidity pool (`X` and `Y`).
    /// Returns current reserves (`X`, `Y`).
    public fun get_reserves_size<X, Y, Curve>(): (u64, u64) {
        if (coin_helper::is_sorted<X, Y>()) {
            liquidity_pool::get_reserves_size<X, Y, Curve>()
        } else {
            let (y_res, x_res) = liquidity_pool::get_reserves_size<Y, X, Curve>();
            (x_res, y_res)
        }
    }

    /// Get fee for specific pool together with denominator (numerator, denominator).
    public fun get_fees_config<X, Y, Curve>(): (u64, u64) {
        if (coin_helper::is_sorted<X, Y>()) {
            liquidity_pool::get_fees_config<X, Y, Curve>()
        } else {
            liquidity_pool::get_fees_config<Y, X, Curve>()
        }
    }

    /// Get fee for specific pool.
    public fun get_fee<X, Y, Curve>(): u64 {
        if (coin_helper::is_sorted<X, Y>()) {
            liquidity_pool::get_fee<X, Y, Curve>()
        } else {
            liquidity_pool::get_fee<Y, X, Curve>()
        }
    }

    /// Get DAO fee for specific pool together with denominator (numerator, denominator).
    public fun get_dao_fees_config<X, Y, Curve>(): (u64, u64) {
        if (coin_helper::is_sorted<X, Y>()) {
            liquidity_pool::get_dao_fees_config<X, Y, Curve>()
        } else {
            liquidity_pool::get_dao_fees_config<Y, X, Curve>()
        }
    }

    /// Get DAO fee for specific pool.
    public fun get_dao_fee<X, Y, Curve>(): u64 {
        if (coin_helper::is_sorted<X, Y>()) {
            liquidity_pool::get_dao_fee<X, Y, Curve>()
        } else {
            liquidity_pool::get_dao_fee<Y, X, Curve>()
        }
    }

    /// Check swap for pair `X` and `Y` exists.
    /// If pool exists returns true, otherwise false.
    public fun is_swap_exists<X, Y, Curve>(): bool {
        if (coin_helper::is_sorted<X, Y>()) {
            liquidity_pool::is_pool_exists<X, Y, Curve>()
        } else {
            liquidity_pool::is_pool_exists<Y, X, Curve>()
        }
    }

    // Math.

    /// Calculate optimal amounts of `X`, `Y` coins to add as a new liquidity.
    /// * `x_desired` - provided value of coins `X`.
    /// * `y_desired` - provided value of coins `Y`.
    /// * `x_min` - minimum of coins X expected.
    /// * `y_min` - minimum of coins Y expected.
    /// Returns both `X` and `Y` coins amounts.
    public fun calc_optimal_coin_values<X, Y, Curve>(
        x_desired: u64,
        y_desired: u64,
        x_min: u64,
        y_min: u64
    ): (u64, u64) {
        let (reserves_x, reserves_y) = get_reserves_size<X, Y, Curve>();

        if (reserves_x == 0 && reserves_y == 0) {
            return (x_desired, y_desired)
        } else {
            let y_returned = convert_with_current_price(x_desired, reserves_x, reserves_y);
            if (y_returned <= y_desired) {
                // amount of `y` received from `x_desired` on a current price is less than `y_desired`
                assert!(y_returned >= y_min, ERR_INSUFFICIENT_Y_AMOUNT);
                return (x_desired, y_returned)
            } else {
                // not enough in `y_desired`, use it as a cap
                let x_returned = convert_with_current_price(y_desired, reserves_y, reserves_x);
                // ERR_OVERLIMIT_X should never occur here, added just in case
                assert!(x_returned <= x_desired, ERR_OVERLIMIT_X);
                assert!(x_returned >= x_min, ERR_INSUFFICIENT_X_AMOUNT);
                return (x_returned, y_desired)
            }
        }
    }

    /// Return amount of liquidity (LP) need for `coin_in`.
    /// * `coin_in` - amount to swap.
    /// * `reserve_in` - reserves of coin to swap.
    /// * `reserve_out` - reserves of coin to get.
    public fun convert_with_current_price(coin_in: u64, reserve_in: u64, reserve_out: u64): u64 {
        assert!(coin_in > 0, ERR_WRONG_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERR_WRONG_RESERVE);

        // exchange_price = reserve_out / reserve_in_size
        // amount_returned = coin_in_val * exchange_price
        let res = math::mul_div(coin_in, reserve_out, reserve_in);
        (res as u64)
    }

    /// Convert `LP` coins to `X` and `Y` coins, useful to calculate amount the user recieve after removing liquidity.
    /// * `lp_to_burn_val` - amount of `LP` coins to burn.
    /// Returns both `X` and `Y` coins amounts.
    public fun get_reserves_for_lp_coins<X, Y, Curve>(
        lp_to_burn_val: u64
    ): (u64, u64) {
        let (x_reserve, y_reserve) = get_reserves_size<X, Y, Curve>();
        let lp_coins_total = supply<LP<X, Y, Curve>>();

        let x_to_return_val = math::mul_div_u128((lp_to_burn_val as u128), (x_reserve as u128), lp_coins_total);
        let y_to_return_val = math::mul_div_u128((lp_to_burn_val as u128), (y_reserve as u128), lp_coins_total);

        assert!(x_to_return_val > 0 && y_to_return_val > 0, ERR_WRONG_AMOUNT);

        (x_to_return_val, y_to_return_val)
    }

    /// Get amount out for `amount_in` of X coins (see generic).
    /// So if Coins::USDC is X and Coins::USDT is Y, it will get amount of USDT you will get after swap `amount_x` USDC.
    /// !Important!: This function can eat a lot of gas if you querying it for stable curve pool, so be aware.
    /// We recommend to do implement such kind of logic offchain.
    /// * `amount_x` - amount to swap.
    /// Returns amount of `Y` coins getting after swap.
    public fun get_amount_out<X, Y, Curve>(amount_in: u64): u64 {
        let (reserve_x, reserve_y) = get_reserves_size<X, Y, Curve>();
        let (scale_x, scale_y) = get_decimals_scales<X, Y, Curve>();
        get_coin_out_with_fees<X, Y, Curve>(
            amount_in,
            reserve_x,
            reserve_y,
            scale_x,
            scale_y,
        )
    }

    /// Get amount in for `amount_out` of X coins (see generic).
    /// So if Coins::USDT is X and Coins::USDC is Y, you pass how much USDC you want to get and
    /// it returns amount of USDT you have to swap (include fees).
    /// !Important!: This function can eat a lot of gas if you querying it for stable curve pool, so be aware.
    /// We recommend to do implement such kind of logic offchain.
    /// * `amount_x` - amount to swap.
    /// Returns amount of `X` coins needed.
    public fun get_amount_in<X, Y, Curve>(amount_out: u64): u64 {
        let (reserve_x, reserve_y) = get_reserves_size<X, Y, Curve>();
        let (scale_x, scale_y) = get_decimals_scales<X, Y, Curve>();
        get_coin_in_with_fees<X, Y, Curve>(
            amount_out,
            reserve_y,
            reserve_x,
            scale_y,
            scale_x,
        )
    }

    // Private functions (contains part of math).

    /// Get coin amount out by passing amount in (include fees). Pass all data manually.
    /// * `coin_in` - exactly amount of coins to swap.
    /// * `reserve_in` - reserves of coin we are going to swap.
    /// * `reserve_out` - reserves of coin we are going to get.
    /// * `scale_in` - 10 pow by decimals amount of coin we going to swap.
    /// * `scale_out` - 10 pow by decimals amount of coin we going to get.
    /// Returns amount of coins out after swap.
    fun get_coin_out_with_fees<X, Y, Curve>(
        coin_in: u64,
        reserve_in: u64,
        reserve_out: u64,
        scale_in: u64,
        scale_out: u64,
    ): u64 {
        let (fee_pct, fee_scale) = get_fees_config<X, Y, Curve>();
        let fee_multiplier = fee_scale - fee_pct;

        if (curves::is_stable<Curve>()) {
            let coin_in_val_scaled = math::mul_to_u128(coin_in, fee_multiplier);
            let coin_in_val_after_fees = if (coin_in_val_scaled % (fee_scale as u128) != 0) {
                (coin_in_val_scaled / (fee_scale as u128)) + 1
            } else {
                coin_in_val_scaled / (fee_scale as u128)
            };

            (stable_curve::coin_out(
                (coin_in_val_after_fees as u128),
                scale_in,
                scale_out,
                (reserve_in as u128),
                (reserve_out as u128)
            ) as u64)
        } else if (curves::is_uncorrelated<Curve>()) {
            let coin_in_val_after_fees = coin_in * fee_multiplier;
            let new_reserve_in = reserve_in * fee_scale + coin_in_val_after_fees;

            // Multiply coin_in by the current exchange rate:
            // current_exchange_rate = reserve_out / reserve_in
            // amount_in_after_fees * current_exchange_rate -> amount_out
            math::mul_div(coin_in_val_after_fees,
                reserve_out,
                new_reserve_in)
        } else {
            abort ERR_UNREACHABLE
        }
    }

    /// Get coin amount in by amount out. Pass all data manually.
    /// * `coin_out` - exactly amount of coins we want to get.
    /// * `reserve_out` - reserves of coin we are going to get.
    /// * `reserve_in` - reserves of coin we are going to swap.
    /// * `scale_in` - 10 pow by decimals amount of coin we swap.
    /// * `scale_out` - 10 pow by decimals amount of coin we get.
    ///
    /// This computation is a reverse of get_coin_out formula for uncorrelated assets:
    ///     y = x * (fee_scale - fee_pct) * ry / (rx + x * (fee_scale - fee_pct))
    ///
    /// solving it for x returns this formula:
    ///     x = y * rx / ((ry - y) * (fee_scale - fee_pct)) or
    ///     x = y * rx * (fee_scale) / ((ry - y) * (fee_scale - fee_pct)) which implemented in this function
    ///
    ///  For stable curve math described in `coin_in` func into `../libs/StableCurve.move`.
    ///
    /// Returns amount of coins needed for swap.
    fun get_coin_in_with_fees<X, Y, Curve>(
        coin_out: u64,
        reserve_out: u64,
        reserve_in: u64,
        scale_out: u64,
        scale_in: u64,
    ): u64 {
        let (fee_pct, fee_scale) = get_fees_config<X, Y, Curve>();
        let fee_multiplier = fee_scale - fee_pct;

        if (curves::is_stable<Curve>()) {
            // !!!FOR AUDITOR!!!
            // Double check it.
            let coin_in = (stable_curve::coin_in(
                (coin_out as u128),
                scale_out,
                scale_in,
                (reserve_out as u128),
                (reserve_in as u128),
            ) as u64) + 1;

            (coin_in * fee_scale / fee_multiplier) + 1
        } else if (curves::is_uncorrelated<Curve>()) {
            let new_reserves_out = (reserve_out - coin_out) * fee_multiplier;

            // coin_out * reserve_in * fee_scale / new reserves out
            let coin_in = math::mul_div(
                coin_out, // y
                reserve_in * fee_scale,
                new_reserves_out
            ) + 1;
            coin_in
        } else {
            abort ERR_UNREACHABLE
        }
    }

    #[test_only]
    public fun current_price<X, Y, Curve>(): u128 {
        let (x_reserve, y_reserve) = get_reserves_size<X, Y, Curve>();
        ((x_reserve / y_reserve) as u128)
    }
}
