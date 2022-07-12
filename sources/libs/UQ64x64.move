/// Implementation of FixedPoint u64.
module MultiSwap::UQ64x64 {
    use Std::Errors;

    // Error codes.

    /// When can't cast `UQ64x64` to u64.
    const ERR_U64_OVERFLOW: u64 = 1001;

    /// When divide by zero attempted.
    const ERR_DIVIDE_BY_ZERO: u64 = 1002;

    // Constants.

    const Q64: u128 = 18446744073709551615u128;

    /// When a and b are equals.
    const EQUAL: u8 = 0;

    /// When a is less than b equals.
    const LESS_THAN: u8 = 1;

    /// When a is greater than b.
    const GREATER_THAN: u8 = 2;

    /// The resource to store `UQ64x64`.
    struct UQ64x64 has copy, store, drop {
        v: u128
    }

    /// Encode `u64` to `UQ64x64`
    public fun encode(x: u64): UQ64x64 {
        let v = (x as u128) * Q64;
        UQ64x64{ v }
    }

    /// Decode a `UQ64x64` into a `u64` by truncating after the radix point.
    public fun decode(uq: UQ64x64): u64 {
        ((uq.v / Q64) as u64)
    }

    /// Get `u128` from UQ64x64
    public fun to_u128(uq: UQ64x64): u128 {
        uq.v
    }

    /// Multiply a `UQ64x64` by a `u64`, returning a `UQ64x64`
    public fun mul(uq: UQ64x64, y: u64): UQ64x64 {
        // vm would direct abort when overflow occured
        let v = uq.v * (y as u128);

        UQ64x64{ v }
    }

    /// Divide a `UQ64x64` by a `u128`, returning a `UQ64x64`.
    public fun div(uq: UQ64x64, y: u64): UQ64x64 {
        assert!(y != 0, Errors::invalid_argument(ERR_DIVIDE_BY_ZERO));

        let v = uq.v / (y as u128);
        UQ64x64{ v }
    }

    /// Returns a `UQ64x64` which represents the ratio of the numerator to the denominator.
    public fun fraction(numerator: u64, denominator: u64): UQ64x64 {
        assert!(denominator != 0, Errors::invalid_argument(ERR_DIVIDE_BY_ZERO));

        let r = (numerator as u128) * Q64;
        let v = r / (denominator as u128);

        UQ64x64{ v }
    }

    /// Compare two `UQ64x64` numbers.
    public fun compare(left: &UQ64x64, right: &UQ64x64): u8 {
        if (left.v == right.v) {
            return EQUAL
        } else if (left.v < right.v) {
            return LESS_THAN
        } else {
            return GREATER_THAN
        }
    }

    /// Check if `UQ64x64` is zero
    public fun is_zero(uq: &UQ64x64): bool {
        uq.v == 0
    }
}
