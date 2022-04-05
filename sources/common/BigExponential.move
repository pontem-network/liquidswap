// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

module AptosSwap::BigExponential {
    use Std::Errors;
    use Std::U256::{Self, U256};

    // e18
    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;


    const ERR_EXP_DIVIDE_BY_ZERO: u64 = 101;
    const ERR_U128_OVERFLOW: u64 = 102;

    const EXP_SCALE: u128 = 1000000000000000000;
    const EXP_MAX_SCALE: u64 = 18;
    const U128_MAX: u128 = 340282366920938463463374607431768211455;  //length(U128_MAX)==39

    struct Exp has copy, store, drop {
        mantissa: U256
    }

    public fun exp_scale(): u128 {
        return EXP_SCALE
    }

    public fun exp_scale_limition(): u64 {
        return EXP_MAX_SCALE
    }

    public fun exp_direct(num: u128): Exp {
        Exp{
            mantissa: U256::from_u128(num)
        }
    }

    public fun exp_from_u256(num: U256): Exp {
        Exp{
            mantissa: num
        }
    }

    public fun exp_direct_expand(num: u128): Exp {
        Exp{
            mantissa: mul_u128(num, EXP_SCALE)
        }
    }

    public fun mantissa(a: Exp): U256 {
        *&a.mantissa
    }

    public fun exp(num: u128, denom: u128): Exp {
        // if overflow move will abort
        let scaledNumerator: U256 = mul_u128(num, EXP_SCALE);
        let rational = U256::div(scaledNumerator, U256::from_u128(denom));
        Exp{
            mantissa: rational
        }
    }

    public fun add_u128(a: u128, b: u128): u128 {
        a + b
    }

    public fun add_exp(a: Exp, b: Exp): Exp {
        Exp{
            mantissa: U256::add(*&a.mantissa, *&b.mantissa)
        }
    }

    public fun sub_u128(a: u128, b: u128): u128 {
        a - b
    }

    public fun mul_u128(a: u128, b: u128): U256 {
        if (a == 0 || b == 0) {
            return U256::zero()
        };
        let a_u256 = U256::from_u128(a);
        let b_u256 = U256::from_u128(b);
        U256::mul(a_u256, b_u256)
    }

    public fun div_u128(a: u128, b: u128): u128 {
        if (b == 0) {
            abort Errors::invalid_argument(ERR_EXP_DIVIDE_BY_ZERO)
        };
        if (a == 0) {
            return 0
        };
        a / b
    }

    public fun truncate(exp: Exp): u128 {
        //  return exp.mantissa / EXP_SCALE
        let r_u256 = U256::div(*&exp.mantissa, U256::from_u128(EXP_SCALE));
        let u128_max = U256::from_u128(U128_MAX);
        let cmp_order = U256::compare(&r_u256, &u128_max);
        if (cmp_order == GREATER_THAN) {
            abort Errors::invalid_argument(ERR_U128_OVERFLOW)
        };
        U256::as_u128(r_u256)
    }

    public fun to_safe_u128(x: U256): u128 {
        let u128_max = U256::from_u128(U128_MAX);
        let cmp_order = U256::compare(&x, &u128_max);
        if (cmp_order == GREATER_THAN) {
            abort Errors::invalid_argument(ERR_U128_OVERFLOW)
        };
        U256::as_u128(x)
    }
}
