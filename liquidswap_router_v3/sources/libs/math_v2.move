/// Implements additional math for router v3.
module liquidswap::math_v2 {
    // Errors codes.

    /// When trying to divide by zero.
    const ERR_DIVIDE_BY_ZERO: u64 = 2000;
    /// When overflow u64
    const ERR_OVERFLOW_U64: u64 = 2001;

    // Constants.

    /// Maximum of u64 number.
    const MAX_U64: u128 = 18446744073709551615;

    /// Implements: (`x` * `y` - 1) / `z` + 1.
    /// Rounds up return value
    public fun mul_div_up_u128(x: u128, y: u128, z: u128): u64 {
        assert!(z != 0, ERR_DIVIDE_BY_ZERO);
        let r = (x * y - 1) / z + 1;
        assert!(r <= MAX_U64, ERR_OVERFLOW_U64);
        (r as u64)
    }
    spec mul_div_up_u128 {
        aborts_if z == 0 with ERR_DIVIDE_BY_ZERO;
        aborts_if x * y - 1 > MAX_U128;
        aborts_if (x * y - 1) / z + 1 > MAX_U64;
        ensures result == (x * y - 1) / z + 1;
    }

    #[test]
    fun test_mul_div_up_u128() {
        let a = mul_div_up_u128(MAX_U64, MAX_U64, MAX_U64);
        assert!(a == (MAX_U64 as u64), 0);

        a = mul_div_up_u128(MAX_U64 * 2, 2, MAX_U64);
        assert!(a == 4, 1);

        a = mul_div_up_u128(100, 20, 99);
        assert!(a == 21, 2);
    }

    #[test]
    #[expected_failure(abort_code = 2000)]
    fun test_mul_div_up_u128_zero() {
        let _ = mul_div_up_u128(10, 20, 0);
    }
}
