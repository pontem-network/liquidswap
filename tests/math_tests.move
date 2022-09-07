#[test_only]
module liquidswap::math_tests {
    use liquidswap::math;

    const MAX_u64: u64 = 18446744073709551615;
    const MAX_u128: u128 = 340282366920938463463374607431768211455;

    #[test]
    fun test_mul_div() {
        let a = math::mul_div(MAX_u64, MAX_u64, MAX_u64);
        assert!(a == MAX_u64, 0);

        a = math::mul_div(100, 20, 100);
        assert!(a == 20, 1);
    }

    #[test]
    fun test_mul_div_u128() {
        let a = math::mul_div_u128((MAX_u64 as u128), (MAX_u64 as u128), (MAX_u64 as u128));
        assert!(a == MAX_u64, 0);

        a = math::mul_div_u128((MAX_u64 as u128) * 2, 2, (MAX_u64 as u128));
        assert!(a == 4, 1);

        a = math::mul_div_u128(100, 20, 100);
        assert!(a == 20, 2);
    }

    #[test]
    #[expected_failure(abort_code = 2000)]
    fun test_mul_div_zero() {
        let _ = math::mul_div(10, 20, 0);
    }

    #[test]
    #[expected_failure(abort_code = 2000)]
    fun test_mul_div_u128_zero() {
        let _ = math::mul_div_u128(10, 20, 0);
    }

    #[test]
    fun test_mul_to_u128() {
        let a: u128 = math::mul_to_u128(MAX_u64, MAX_u64);
        assert!(a == 340282366920938463426481119284349108225, 0);
    }

    #[test]
    fun test_sqrt() {
        let s = math::sqrt(9);
        assert!(s == 3, 0);

        s = math::sqrt(0);
        assert!(s == 0, 1);

        s = math::sqrt(1);
        assert!(s == 1, 2);

        s = math::sqrt(2);
        assert!(s == 1, 3);

        s = math::sqrt(3);
        assert!(s == 1, 4);

        s = math::sqrt(18446744073709551615);
        assert!(s == 4294967295, 5);

        s = math::sqrt(340282366920938463426481119284349108225);
        assert!(s == MAX_u64, 6);
    }

    #[test]
    fun test_pow_10() {
        assert!(math::pow_10(0) == 1, 1);
        assert!(math::pow_10(1) == 10, 2);
        assert!(math::pow_10(2) == 100, 3);
        assert!(math::pow_10(5) == 100000, 4);
        assert!(math::pow_10(10) == 10000000000, 5);
    }

    #[test]
    fun test_overflow_add() {
        let a = math::overflow_add(1, MAX_u128);
        assert!(a == 0, 0);

        let a = math::overflow_add(MAX_u128, 1);
        assert!(a == 0, 1);

        let a = math::overflow_add(MAX_u128, MAX_u128);
        assert!(a == 340282366920938463463374607431768211454, 2);

        let a = math::overflow_add(0, 0);
        assert!(a == 0, 3);

        let a = math::overflow_add(100, 50);
        assert!(a == 150, 4);

        let a = math::overflow_add(18446744073709551615, 1);
        assert!(a == 18446744073709551615 + 1, 5);

        let a = math::overflow_add(MAX_u128 / 2, MAX_u128 / 2);
        assert!(a == MAX_u128 - 1, 6);

        let a = math::overflow_add(224586362167819385885827240904967019560, 187155301806516154904856034087472516300);
        assert!(a == 71459297053397077327308667560671324404, 7);

        let a = math::overflow_add(0, 1);
        assert!(a == 1, 8);

        let a = math::overflow_add(1, 0);
        assert!(a == 1, 9);
    }
}
