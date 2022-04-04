address AptosSwap {
module FixedPoint128 {
    use Std::Errors;
    use Std::U256::{Self, U256};

    const RESOLUTION: u8 = 128;
    const Q128: u128 = 340282366920938463463374607431768211455u128; // 2**128
    const Q256_HEX: vector<u8> = x"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"; // 2**256
    const LOWER_MASK: u128 = 340282366920938463463374607431768211455u128; // decimal of UQ128x128 (lower 128 bits), equal to 0xffffffffffffffffffffffffffffffff
    const U128_MAX: u128 = 340282366920938463463374607431768211455u128;
    const U64_MAX: u128 = 18446744073709551615u128;

    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

    const ERR_U128_OVERFLOW: u64 = 1001;
    const ERR_DIVIDE_BY_ZERO: u64 = 1002;

    // range: [0, 2**128 - 1]
    // resolution: 1 / 2**128
    struct UQ128x128 has copy, store, drop {
        v: U256
    }


//    public fun Q256(): U256 {
//        U256::from_big_endian(Q256_HEX)
//    }

    // encode a u128 as a UQ128x128
    // U256 type has no bitwise shift operators yet, instead of realize by mul Q128
    public fun encode(x: u128): UQ128x128 {
        // never overflow
        let v: U256 = U256::mul(U256::from_u128(x), U256::from_u128(Q128));
        UQ128x128 { v }
    }

    // encode a u256 as a UQ128x128
    public fun encode_u256(v: U256, is_scale: bool): UQ128x128 {
        if (is_scale) {
            v = U256::mul(v, U256::from_u128(Q128));
        };
        UQ128x128 {
            v: v
        }
    }

    // decode a UQ128x128 into a u128 by truncating after the radix point
    public fun decode(uq: UQ128x128): u128 {
        U256::as_u128(U256::div(*&uq.v, U256::from_u128(Q128)))
    }


    // multiply a UQ128x128 by a u128, returning a UQ128x128
    // abort on overflow
    public fun mul(uq: UQ128x128, y: u128): UQ128x128 {
        // vm would direct abort when overflow occured
        let v: U256 = U256::mul(*&uq.v, U256::from_u128(y));
        UQ128x128 {
            v: v
        }
    }

//    #[test]
//    /// U128_MAX * U128_MAX < U256_MAX
//    public fun test_u256_mul_not_overflow() {
//        let u256_max:U256 = Q256();
//        let u128_max = U256::from_u128(U128_MAX);
//        let u128_mul_u128_max = U256::mul(copy u128_max, copy u128_max);
//        let order = U256::compare(&u256_max, &u128_mul_u128_max);
//        assert!(order == GREATER_THAN, 1100);
//
//    }

    // divide a UQ128x128 by a u128, returning a UQ128x128
    public fun div(uq: UQ128x128, y: u128): UQ128x128 {
        if ( y == 0) {
            abort Errors::invalid_argument(ERR_DIVIDE_BY_ZERO)
        };
        let v: U256 = U256::div(*&uq.v, U256::from_u128(y));
        UQ128x128 {
            v: v
        }
    }

    public fun to_u256(uq: UQ128x128): U256 {
        *&uq.v
    }


    // returns a UQ128x128 which represents the ratio of the numerator to the denominator
    public fun fraction(numerator: u128, denominator: u128): UQ128x128 {
        let r: U256 = U256::mul(U256::from_u128(numerator), U256::from_u128(Q128));
        let v: U256 = U256::div(r, U256::from_u128(denominator));
        UQ128x128 {
            v: v
        }
    }

    public fun to_safe_u128(x: U256): u128 {
        let u128_max = U256::from_u128(U128_MAX);
        let cmp_order = U256::compare(&x, &u128_max);
        if (cmp_order == GREATER_THAN) {
            abort Errors::invalid_argument(ERR_U128_OVERFLOW)
        };
        U256::as_u128(x)
    }

    public fun compare(left: UQ128x128, right: UQ128x128): u8 {
        U256::compare(&left.v, &right.v)
    }

    public fun is_zero(uq: UQ128x128): bool {
        let r = U256::compare(&uq.v, &U256::zero());
        if (r == 0) {
            true
        } else {
            false
        }
    }

}
}

