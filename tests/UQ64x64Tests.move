#[test_only]
module MultiSwap::UQ64x64Tests {
    use MultiSwap::UQ64x64;

    #[test]
    fun test_is_zero() {
        let zero = UQ64x64::encode(0);
        assert!(UQ64x64::is_zero(&zero), 0);

        let non_zero = UQ64x64::encode(1);
        assert!(!UQ64x64::is_zero(&non_zero), 1);
    }

    #[test]
    fun test_compare() {
        assert!(UQ64x64::compare(&UQ64x64::encode(100), &UQ64x64::encode(100)) == 0, 0);
        assert!(UQ64x64::compare(&UQ64x64::encode(200), &UQ64x64::encode(100)) == 2, 1);
        assert!(UQ64x64::compare(&UQ64x64::encode(100), &UQ64x64::encode(200)) == 1, 1);
    }

    #[test]
    fun test_encode() {
        let a = UQ64x64::encode(100);
        let b = UQ64x64::decode(a);
        assert!(b == 100, 0);

        a = UQ64x64::encode(18446744073709551615);
        b = UQ64x64::decode(a);
        assert!(b == 18446744073709551615, 1);

        a = UQ64x64::encode(0);
        b = UQ64x64::decode(a);
        assert!(b == 0, 2);
    }

    #[test]
    fun test_mul() {
        let a = UQ64x64::encode(500000);
        let z = UQ64x64::mul(a, 2);
        assert!(UQ64x64::to_u128(z) == 18446744073709551615000000, 0);
        assert!(UQ64x64::decode(z) == 1000000, 1);
    }

    #[test]
    fun test_div() {
        let a  = UQ64x64::encode(256);
        let z = UQ64x64::div(a, 8);
        assert!(UQ64x64::to_u128(z) == 590295810358705651680, 0);
        assert!(UQ64x64::decode(z) == 32, 1);
    }
}