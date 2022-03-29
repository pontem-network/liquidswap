/// Helper module to do u64 arith.
module Std::Arith {
    /// split u64 to (high, low)
    public fun split_u64(i: u64): (u64, u64) {
        (i >> 32, i & 0xFFFFFFFF)
    }

    /// combine (high, low) to u64,
    /// any lower bits of `high` will be erased, any higher bits of `low` will be erased.
    public fun combine_u64(hi: u64, lo: u64): u64 {
        (hi << 32) | (lo & 0xFFFFFFFF)
    }

    /// a + b, with carry
    public fun adc(a: u64, b: u64, carry: &mut u64): u64 {
        let (a1, a0) = split_u64(a);
        let (b1, b0) = split_u64(b);
        let (c, r0) = split_u64(a0 + b0 + *carry);
        let (c, r1) = split_u64(a1 + b1 + c);
        *carry = c;
        combine_u64(r1, r0)
    }

    /// a - b, with borrow
    public fun sbb(a: u64, b: u64, borrow: &mut u64): u64 {
        let (a1, a0) = split_u64(a);
        let (b1, b0) = split_u64(b);
        let (b, r0) = split_u64((1 << 32) + a0 - b0 - *borrow);
        let borrowed = if (b == 0) { 1 } else { 0 };
        let (b, r1) = split_u64((1 << 32) + a1 - b1 - borrowed);
        *borrow = if (b == 0) { 1 } else { 0 };

        combine_u64(r1, r0)
    }
}
