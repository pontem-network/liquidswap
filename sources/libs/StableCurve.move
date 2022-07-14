module MultiSwap::StableCurve {
    use U256::U256::{Self, U256};

    /// coins with more than this number of decimals will have a precision loss for the curve computation
    const DECIMALS_LIMIT: u64 = 12;
    // 10^12
    const ONE_E_8: u128 = 100000000;
    // 10^6
    const ONE_E_6: u128 = 1000000;

    public fun lp_value(x_coin: u128, x_scale: u64, y_coin: u128, y_scale: u64): U256 {
        let x_u256 = U256::from_u128(x_coin);
        let y_u256 = U256::from_u128(y_coin);
        let u2561e8 = U256::from_u128(100000000);

        let x_scale_u256 = U256::from_u64(x_scale);
        let y_scale_u256 = U256::from_u64(y_scale);

        let _x = U256::div(
            U256::mul(x_u256, u2561e8),
            x_scale_u256,
        );

        let _y = U256::div(
            U256::mul(y_u256, u2561e8),
            y_scale_u256,
        );

        let _a = U256::div(
            U256::mul(_x, _y),
            u2561e8,
        );

        // ((_x * _x) / 1e18 + (_y * _y) / 1e18);
        let _b = U256::add(
            U256::div(
                U256::mul(_x, _x),
                u2561e8,
            ),
            U256::div(
                U256::mul(_y, _y),
                u2561e8,
            )
        );

        U256::div(
            U256::mul(_a, _b),
            u2561e8,
        )
    }

    public fun coin_out(_coin_in: u128, _decimals_in: u64, _decimals_out: u64, _reserve_in: u128, _reserve_out: u128): u128 {
        0
    }

//    public fun coin_out(coin_in: u128, decimals_in: u64, decimals_out: u64, reserve_in: u128, reserve_out: u128): u128 {
//        let xy = lp_value(reserve_in, decimals_in, reserve_out, decimals_out);
//        let reserve_in_scaled = reserve_in * pow_10(DECIMALS_LIMIT - decimals_in);
//        let reserve_out_scaled = reserve_out * pow_10(DECIMALS_LIMIT - decimals_out);
//        let amountIn = coin_in * pow_10(DECIMALS_LIMIT - decimals_in);
//        let y = reserve_out_scaled - get_y(amountIn + reserve_in_scaled, xy, reserve_out_scaled);
//        y * pow_10(decimals_out) / ONE_E_12
//    }
//
//
//    fun get_y(x0: u128, xy: u128, y: u128): u128 {
//        let i = 0;
//        while (i < 255) {
//            let y_prev = y;
//
//            let k = f(x0, y);
//            if (k < xy) {
//                let dy = (xy - k) * ONE_E_12 / d(x0, y);
//                y = y + dy;
//            } else {
//                let dy = (k - xy) * ONE_E_12 / d(x0, y);
//                y = y - dy;
//            };
//
//            if (y > y_prev) {
//                if (y - y_prev <= 1) {
//                    return y
//                };
//            } else {
//                if (y_prev - y <= 1) {
//                    return y
//                }
//            };
//
//            i = i + 1;
//        };
//        y
//    }
//
//    fun f(x0: u128, y: u128): u128 {
//        // x0 * y^3 + x0^3 * y
//        x0 * (y * y / ONE_E_12 * y / ONE_E_12) + (x0 * x0 / ONE_E_12 * x0 / ONE_E_12) * y / ONE_E_12
//    }
//
//    fun d(x0: u128, y: u128): u128 {
//        // 3 * x0 * y^2 + x^3
//        3 * x0 * (y * y / ONE_E_12) / ONE_E_12 + x0 * x0 / ONE_E_12 * x0 / ONE_E_12
//    }
}
