/// Implementation of math functions needed for Multi Swap.
module liquidswap::math {
    // Errors codes.

    /// When trying to divide by zero.
    const ERR_DIVIDE_BY_ZERO: u64 = 2000;

    // Constants.

    /// Maximum of u64 number.
    const MAX_U64: u128 = 18446744073709551615;

    /// Maximum of u128 number.
    const MAX_U128: u128 = 340282366920938463463374607431768211455;

    /// Adds two u128 and makes overflow possible.
    public fun overflow_add(a: u128, b: u128): u128 {
        let r = MAX_U128 - b;
        if (r < a) {
            return a - r - 1
        };
        r = MAX_U128 - a;
        if (r < b) {
            return b - r - 1
        };

        a + b
    }

    /// Implements: `x` * `y` / `z`.
    public fun mul_div(x: u64, y: u64, z: u64): u64 {
        assert!(z != 0, ERR_DIVIDE_BY_ZERO);
        let r = (x as u128) * (y as u128) / (z as u128);
        (r as u64)
    }

    /// Implements: `x` * `y` / `z`.
    public fun mul_div_u128(x: u128, y: u128, z: u128): u64 {
        assert!(z != 0, ERR_DIVIDE_BY_ZERO);
        let r = x * y / z;
        (r as u64)
    }

    /// Multiple two u64 and get u128, e.g. ((`x` * `y`) as u128).
    public fun mul_to_u128(x: u64, y: u64): u128 {
        (x as u128) * (y as u128)
    }

    /// Get square root of `y`.
    /// Babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    public fun sqrt(y: u128): u64 {
        if (y < 4) {
            if (y == 0) {
                0u64
            } else {
                1u64
            }
        } else {
            let z = y;
            let x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            };
            (z as u64)
        }
    }

    /// Returns 10^degree.
    public fun pow_10(degree: u8): u64 {
        let res = 1;
        let i = 0;
        while ({
            spec {
                invariant res == spec_pow(10, i);
                invariant 0 <= i && i <= degree;
            };
            i < degree
        }) {
            res = res * 10;
            i = i + 1;
        };
        res
    }

    public fun min_u64(a: u64, b: u64): u64 {
        if (a < b) a else b
    }
}
