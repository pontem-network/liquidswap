#[test_only]
module AptosSwap::SafeMathTests {
    use AptosSwap::SafeMath;

    #[test]
    fun test_mul_div() {
        let a = SafeMath::mul_div(18446744073709551615, 18446744073709551615, 18446744073709551615);
        assert!(a == 18446744073709551615, 0);

        a = SafeMath::mul_div(100, 20, 100);
        assert!(a == 20, 1);
    }

    #[test]
    #[expected_failure(abort_code = 25607)]
    fun test_mul_div_zero() {
        let _ = SafeMath::mul_div(10, 20, 0);
    }

    #[test]
    fun test_mul_to_u128() {
        let a: u128 = SafeMath::mul_to_u128(18446744073709551615, 18446744073709551615);
        assert!(a == 340282366920938463426481119284349108225, 0);
    }

    #[test]
    fun test_sqrt() {
        let s = SafeMath::sqrt(9);
        assert!(s == 3, 0);

        s = SafeMath::sqrt(0);
        assert!(s == 0, 1);

        s = SafeMath::sqrt(1);
        assert!(s == 1, 2);

        s = SafeMath::sqrt(2);
        assert!(s == 1, 2);

        s = SafeMath::sqrt(3);
        assert!(s == 1, 3);

        s = SafeMath::sqrt(18446744073709551615);
        assert!(s == 4294967295, 4);
    }
}