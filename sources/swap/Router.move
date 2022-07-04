/// Router for Liquidity Pool, similar to Uniswap router.
module MultiSwap::Router {
    use Std::Errors;

    use AptosFramework::Coin::{Coin, Self};

    use MultiSwap::CoinHelper::{Self, supply};
    use MultiSwap::LiquidityPool;
    use MultiSwap::Math;

    // Errors codes.

    /// Wrong amount used.
    const ERR_WRONG_AMOUNT: u64 = 100;
    /// Wrong reserve used.
    const ERR_WRONG_RESERVE: u64 = 101;
    /// Insuficient amount in Y reserves.
    const ERR_INSUFFICIENT_Y_AMOUNT: u64 = 102;
    /// Insuficient amount in X reserves.
    const ERR_INSUFFICIENT_X_AMOUNT: u64 = 103;
    /// Overlimit of X coins to swap.
    const ERR_OVERLIMIT_X: u64 = 104;
    /// Amount out less than minimum.
    const ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM: u64 = 105;
    /// Needed amount in great than maximum.
    const ERR_COIN_VAL_MAX_LESS_THAN_NEEDED: u64 = 106;

    // Public functions.

    /// Check liquidity pool exists for coins `X` and `Y` at owner address.
    /// * `pool_addr` - pool owner address.
    public fun pool_exists_at<X, Y, LP>(pool_addr: address): bool {
        if (CoinHelper::is_sorted<X, Y>()) {
            LiquidityPool::pool_exists_at<X, Y, LP>(pool_addr)
        } else {
            LiquidityPool::pool_exists_at<Y, X, LP>(pool_addr)
        }
    }

    /// Register new liquidity pool for `X`/`Y` pair on signer address.
    /// * `lp_coin_mint_cap` - LP coin mint capability.
    /// * `lp_coin_burn_cap` - LP coin burn capability.
    public fun register_liquidity_pool<X, Y, LP>(account: &signer, correlation_curve_type: u8) {
        if (CoinHelper::is_sorted<X, Y>()) {
            let (lp_name, lp_symbol) = CoinHelper::generate_lp_name<X, Y>();
            LiquidityPool::register<X, Y, LP>(account, lp_name, lp_symbol, correlation_curve_type);
        } else {
            let (lp_name, lp_symbol) = CoinHelper::generate_lp_name<Y, X>();
            LiquidityPool::register<Y, X, LP>(account, lp_name, lp_symbol, correlation_curve_type);
        }
    }

    /// Add liquidity to pool `X`/`Y` without rationality checks.
    /// Call `calc_required_liquidity` to get optimal amounts first, and only use returned amount for `coin_x` and `coin_y`.
    /// * `pool_addr` - pool owner address.
    /// * `coin_x` - coins X used to add liquidity.
    /// * `coin_y` - coins Y used to add liquidity.
    public fun add_liquidity_inner<X, Y, LP>(pool_addr: address, coin_x: Coin<X>, coin_y: Coin<Y>): Coin<LP> {
        if (CoinHelper::is_sorted<X, Y>()) {
            LiquidityPool::add_liquidity<X, Y, LP>(pool_addr, coin_x, coin_y)
        } else {
            LiquidityPool::add_liquidity<Y, X, LP>(pool_addr, coin_y, coin_x)
        }
    }

    /// Add liquidity to pool `X`/`Y` with rationality checks.
    /// * `pool_addr` - pool owner address.
    /// * `coin_x` - coin X to add as liquidity.
    /// * `min_coin_x_val` - minimum amount of coin X to add as liquidity (slippage).
    /// * `coin_y` - coin Y to add as liquidity.
    /// * `min_coin_y_val` - minimum amount of coin Y to add as liquidity (slippage).
    public fun add_liquidity<X, Y, LP>(
        pool_addr: address,
        coin_x: Coin<X>,
        min_coin_x_val: u64,
        coin_y: Coin<Y>,
        min_coin_y_val: u64
    ): (Coin<X>, Coin<Y>, Coin<LP>) {
        let coin_x_val = Coin::value(&coin_x);
        let coin_y_val = Coin::value(&coin_y);

        let (optimal_x, optimal_y) =
            calc_optimal_coin_values<X, Y, LP>(
                pool_addr,
                coin_x_val,
                coin_y_val,
                min_coin_x_val,
                min_coin_y_val
            );

        let coin_x_opt = Coin::extract(&mut coin_x, optimal_x);
        let coin_y_opt = Coin::extract(&mut coin_y, optimal_y);
        let lp_coins = add_liquidity_inner<X, Y, LP>(pool_addr, coin_x_opt, coin_y_opt);

        (coin_x, coin_y, lp_coins)
    }

    /// Burn liquidity coins `LP` and get coins `X` and `Y` back.
    /// * `pool_addr` - pool owner address.
    /// * `lp_coins` - `LP` coins to burn.
    /// * `min_x_out_val` - minimum amount of `X` coins must be out.
    /// * `min_y_out_val` - minimum amount of `Y` coins must be out.
    /// Returns both coins `X` and `Y`.
    public fun remove_liquidity<X, Y, LP>(
        pool_addr: address,
        lp_coins: Coin<LP>,
        min_x_out_val: u64,
        min_y_out_val: u64
    ): (Coin<X>, Coin<Y>) {
        let (x_out, y_out) = if (CoinHelper::is_sorted<X, Y>()) {
            LiquidityPool::burn_liquidity<X, Y, LP>(pool_addr, lp_coins)
        } else {
            let (y, x) = LiquidityPool::burn_liquidity<Y, X, LP>(pool_addr, lp_coins);
            (x, y)
        };

        assert!(
            Coin::value(&x_out) >= min_x_out_val,
            Errors::invalid_argument(ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM)
        );
        assert!(
            Coin::value(&y_out) >= min_y_out_val,
            Errors::invalid_argument(ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM)
        );

        (x_out, y_out)
    }

    /// Swap exact amount of coin `X` for coin `Y`.
    /// * `pool_addr` - pool owner address.
    /// * `coin_in` - coin X to swap.
    /// * `coin_out_min_val` - minimum amount of coin Y to get out.
    public fun swap_exact_coin_for_coin<X, Y, LP>(
        pool_addr: address,
        coin_in: Coin<X>,
        coin_out_min_val: u64
    ): Coin<Y> {
        let (x_reserve_size, y_reserve_size) = get_reserves_size<X, Y, LP>(pool_addr);

        let coin_in_val = Coin::value(&coin_in);
        let coin_out_val = get_coin_out_with_fees(coin_in_val, x_reserve_size, y_reserve_size);
        assert!(
            coin_out_val >= coin_out_min_val,
            Errors::invalid_argument(ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM),
        );

        let (zero, coin_out);
        if (CoinHelper::is_sorted<X, Y>()) {
            (zero, coin_out) = LiquidityPool::swap<X, Y, LP>(pool_addr, coin_in, 0, Coin::zero(), coin_out_val);
        } else {
            (coin_out, zero) = LiquidityPool::swap<Y, X, LP>(pool_addr, Coin::zero(), coin_out_val, coin_in, 0);
        };
        Coin::destroy_zero(zero);

        coin_out
    }

    /// Swap max coin amount `X` for exact coin `Y`.
    /// * `pool_addr` - pool owner address.
    /// * `coin_max_in` - maximum amount of coin X to swap to get `coin_out_val` of coins Y.
    /// * `coin_out_val` - exact amount of coin Y to get.
    public fun swap_coin_for_exact_coin<X, Y, LP>(
        pool_addr: address,
        coin_max_in: Coin<X>,
        coin_out_val: u64,
    ): (Coin<X>, Coin<Y>) {
        let (x_reserve_size, y_reserve_size) = get_reserves_size<X, Y, LP>(pool_addr);

        let coin_in_val_needed = get_coin_in_with_fees(coin_out_val, y_reserve_size, x_reserve_size);

        let coin_val_max = Coin::value(&coin_max_in);
        assert!(
            coin_in_val_needed <= coin_val_max,
            Errors::invalid_argument(ERR_COIN_VAL_MAX_LESS_THAN_NEEDED)
        );

        let coin_in = Coin::extract(&mut coin_max_in, coin_in_val_needed);

        let (zero, coin_out);
        if (CoinHelper::is_sorted<X, Y>()) {
            (zero, coin_out) = LiquidityPool::swap<X, Y, LP>(pool_addr, coin_in, 0, Coin::zero(), coin_out_val);
        } else {
            (coin_out, zero) = LiquidityPool::swap<Y, X, LP>(pool_addr, Coin::zero(), coin_out_val, coin_in, 0);
        };
        Coin::destroy_zero(zero);

        (coin_max_in, coin_out)
    }

    /// Calculate amounts needed for adding new liquidity for both `X` and `Y`.
    /// * `pool_addr` - pool owner address.
    /// * `x_desired` - desired value of coins `X`.
    /// * `y_desired` - desired value of coins `Y`.
    /// * `x_min` - minimum of coins X expected.
    /// * `y_min` - minimum of coins Y expected.
    public fun calc_optimal_coin_values<X, Y, LP>(
        pool_addr: address,
        x_desired: u64,
        y_desired: u64,
        x_min: u64,
        y_min: u64
    ): (u64, u64) {
        let (reserves_x, reserves_y) = get_reserves_size<X, Y, LP>(pool_addr);

        if (reserves_x == 0 && reserves_y == 0) {
            return (x_desired, y_desired)
        } else {
            let y_returned = convert_with_current_price(x_desired, reserves_x, reserves_y);
            if (y_returned <= y_desired) {
                assert!(y_returned >= y_min, Errors::invalid_argument(ERR_INSUFFICIENT_Y_AMOUNT));
                return (x_desired, y_returned)
            } else {
                let x_returned = convert_with_current_price(y_desired, reserves_y, reserves_x);
                assert!(x_returned <= x_desired, Errors::invalid_argument(ERR_OVERLIMIT_X));
                assert!(x_returned >= x_min, Errors::invalid_argument(ERR_INSUFFICIENT_X_AMOUNT));
                return (x_returned, y_desired)
            }
        }
    }

    /// Get reserves of liquidity pool (`X` and `Y`).
    /// * `pool_addr` - pool owner address.
    /// Returns current reserves.
    public fun get_reserves_size<X, Y, LP>(pool_addr: address): (u64, u64) {
        if (CoinHelper::is_sorted<X, Y>()) {
            LiquidityPool::get_reserves_size<X, Y, LP>(pool_addr)
        } else {
            let (y_res, x_res) = LiquidityPool::get_reserves_size<Y, X, LP>(pool_addr);
            (x_res, y_res)
        }
    }

    /// Get current cumulative prices in liquidity pool `X`/`Y`.
    /// * `pool_addr` - pool owner address.
    public fun get_cumulative_prices<X, Y, LP>(pool_addr: address): (u128, u128, u64) {
        if (CoinHelper::is_sorted<X, Y>()) {
            LiquidityPool::get_cumulative_prices<X, Y, LP>(pool_addr)
        } else {
            let (y, x, t) = LiquidityPool::get_cumulative_prices<Y, X, LP>(pool_addr);
            (x, y, t)
        }
    }

    /// Convert `LP` coins to `X` and `Y` coins, useful to calculate amount the user recieve after removing liquidity.
    /// * `pool_addr` - pool owner address.
    /// * `lp_to_burn_val` - amount of `LP` coins to burn.
    /// Returns both `X` and `Y` coins amounts.
    public fun get_reserves_for_lp_coins<X, Y, LP>(
        pool_addr: address,
        lp_to_burn_val: u64
    ): (u64, u64) {
        let (x_reserve, y_reserve) = get_reserves_size<X, Y, LP>(pool_addr);
        let lp_coins_total = supply<LP>();

        let x_to_return_val = Math::mul_div(lp_to_burn_val, x_reserve, lp_coins_total);
        let y_to_return_val = Math::mul_div(lp_to_burn_val, y_reserve, lp_coins_total);

        assert!(x_to_return_val > 0 && y_to_return_val > 0, Errors::invalid_argument(ERR_WRONG_AMOUNT));

        (x_to_return_val, y_to_return_val)
    }

    /// Get coin amount out by passing amount in (include fees).
    /// * `coin_in` - exactly amount of coins to swap.
    /// * `reserve_in` - reserves of coin we are going to swap.
    /// * `reserve_out` - reserves of coin we are going to get.
    public fun get_coin_out_with_fees(coin_in: u64, reserve_in: u64, reserve_out: u64): u64 {
        let (fee_pct, fee_scale) = LiquidityPool::get_fees_config();
        // 0.997 for 0.3% fee
        let fee_multiplier = fee_scale - fee_pct;
        // x_in * 0.997 (scaled to 1000)
        let coin_in_after_fees = coin_in * fee_multiplier;
        // x_reserve size after adding amount_in (scaled to 1000)
        let new_reserve_in = reserve_in * fee_scale + coin_in_after_fees; // Get new reserve in.
        // Multiply coin_in by the current exchange rate:
        // current_exchange_rate = reserve_out / reserve_in
        // amount_in_after_fees * current_exchange_rate -> amount_out
        let coin_out = Math::mul_div(coin_in_after_fees, // scaled to 1000
            reserve_out,
            new_reserve_in);  // scaled to 1000
        coin_out
    }

    /// Get coin amount in by amount out.
    /// * `coin_out_val` - exactly amount of coins to get.
    /// * `reserve_in_size` - reserves of coin we are going to swap.
    /// * `reserve_out_size` - reserves of coin we are going to get.
    ///
    /// This computation is a reverse of get_coin_out formula:
    ///     y = x * 0.997 * ry / (rx + x * 0.997)
    ///
    /// solving it for x returns this formula:
    ///     x = y * rx / ((ry - y) * 0.997) or
    ///     x = y * rx * 1000 / ((ry - y) * 997) which implemented in this function
    ///
    public fun get_coin_in_with_fees(
        coin_out: u64,
        reserve_out: u64,
        reserve_in: u64
    ): u64 {
        let (fee_pct, fee_scale) = LiquidityPool::get_fees_config();
        // 0.997 for 0.3% fee
        let fee_multiplier = fee_scale - fee_pct;  // 997
        // (reserves_out - coin_out) * 0.997
        let new_reserves_out = (reserve_out - coin_out) * fee_multiplier;
        // coin_out * reserve_in * fee_scale / new reserves out
        let coin_in = Math::mul_div(
            coin_out, // y
            reserve_in * fee_scale, // rx * 1000
            new_reserves_out   // (ry - y) * 997
        ) + 1;
        coin_in
    }

    /// Return amount of liquidity need to for `amount_in`.
    /// * `amount_in` - amount to swap.
    /// * `reserve_in` - reserves of coin to swap.
    /// * `reserve_out` - reserves of coin to get.
    public fun convert_with_current_price(coin_in_val: u64, reserve_in_size: u64, reserve_out_size: u64): u64 {
        assert!(coin_in_val > 0, Errors::invalid_argument(ERR_WRONG_AMOUNT));
        assert!(reserve_in_size > 0 && reserve_out_size > 0, Errors::invalid_argument(ERR_WRONG_RESERVE));

        // exchange_price = reserve_out / reserve_in_size
        // amount_returned = coin_in_val * exchange_price
        let res = Math::mul_div(coin_in_val, reserve_out_size, reserve_in_size);
        (res as u64)
    }

    #[test_only]
    public fun current_price<X, Y, LP>(pool_addr: address): u128 {
        let (x_reserve, y_reserve) = get_reserves_size<X, Y, LP>(pool_addr);
        ((x_reserve / y_reserve) as u128)
    }
}
