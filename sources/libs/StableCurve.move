module MultiSwap::StableCurve {
    /// coins with more than this number of decimals will have a precision loss for the curve computation
    const DECIMALS_LIMIT: u64 = 12;
    // 10^12
    const ONE_E_12: u128 = 1000000000000;
    // 10^6
    const ONE_E_6: u128 = 1000000;

    public fun lp_value(x_coin: u128, x_decimals: u64, y_coin: u128, y_decimals: u64): u128 {
        // formula: x^3 * y + y^3 * x
        // get coins to one dimension to avoid losing data dividing by denominator later
        let x_scale = pow_10(DECIMALS_LIMIT - x_decimals);
        let _x = x_coin * x_scale;
        let y_scale = pow_10(DECIMALS_LIMIT - y_decimals);
        let _y = y_coin * y_scale;
        // downscale to avoid integer overflow
        let a = (_x * _y) / ONE_E_12;
        let b = (_x * _x) / ONE_E_12 + (_y * _y) / ONE_E_12;
        ((a / ONE_E_6) * (b / ONE_E_6))
    }

    public fun coin_out(coin_in: u128, decimals_in: u64, decimals_out: u64, reserve_in: u128, reserve_out: u128): u128 {
        let xy = lp_value(reserve_in, decimals_in, reserve_out, decimals_out);
        let reserve_in_scaled = reserve_in * pow_10(DECIMALS_LIMIT - decimals_in);
        let reserve_out_scaled = reserve_out * pow_10(DECIMALS_LIMIT - decimals_out);
        let amountIn = coin_in * pow_10(DECIMALS_LIMIT - decimals_in);
        let y = reserve_out_scaled - get_y(amountIn + reserve_in_scaled, xy, reserve_out_scaled);
        y * pow_10(decimals_out) / ONE_E_12
    }

    public fun pow_10(degree: u64): u128 {
        let res = 1;
        let i = 0;
        while (i < degree) {
            res = res * 10;
            i = i + 1;
        };
        res
    }

    fun get_y(x0: u128, xy: u128, y: u128): u128 {
        let i = 0;
        while (i < 255) {
            let y_prev = y;

            let k = f(x0, y);
            if (k < xy) {
                let dy = (xy - k) * ONE_E_12 / d(x0, y);
                y = y + dy;
            } else {
                let dy = (k - xy) * ONE_E_12 / d(x0, y);
                y = y - dy;
            };

            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y
                };
            } else {
                if (y_prev - y <= 1) {
                    return y
                }
            };

            i = i + 1;
        };
        y
    }

    fun f(x0: u128, y: u128): u128 {
        // x0 * y^3 + x0^3 * y
        x0 * (y * y / ONE_E_12 * y / ONE_E_12) + (x0 * x0 / ONE_E_12 * x0 / ONE_E_12) * y / ONE_E_12
    }

    fun d(x0: u128, y: u128): u128 {
        // 3 * x0 * y^2 + x^3
        3 * x0 * (y * y / ONE_E_12) / ONE_E_12 + x0 * x0 / ONE_E_12 * x0 / ONE_E_12
    }
}
