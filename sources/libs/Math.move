/// Implementation of math functions needed for Multi Swap.
module MultiSwap::Math {
    use Std::Errors;

    // Errors codes.

    /// When trying to divide by zero.
    const ERR_DIVIDE_BY_ZERO: u64 = 100;

    // Constants.

    /// Maximum of u64 number.
    const U64_MAX: u128 = 18446744073709551615;

    /// Implements: `x` * `y` / `z`.
    /// The func checks for overflows or divide by zero.
    /// Can't overflow.
    public fun mul_div(x: u64, y: u64, z: u64): u64 {
        assert!(z != 0, Errors::invalid_argument(ERR_DIVIDE_BY_ZERO));
        let r = (x as u128) * (y as u128) / (z as u128);
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
    public fun pow_10(degree: u64): u64 {
        let res = 1;
        let i = 0;
        while (i < degree) {
            res = res * 10;
            i = i + 1;
        };

        res
    }
}
