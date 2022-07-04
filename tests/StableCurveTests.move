#[test_only]
module MultiSwap::StableCurveTests {
    use MultiSwap::StableCurve;

    #[test]
    fun test_lp_value_compute() {
        // 0.3 ^ 3 * 0.5 + 0.5 ^ 3 * 0.3 = 0.051 (12 decimals)
        assert!(
            StableCurve::lp_value(300000, 6, 500000, 6) == 51000000000,
            1
        );
    }

    #[test]
    fun test_pow_10() {
        assert!(StableCurve::pow_10(0) == 1, 1);
        assert!(StableCurve::pow_10(1) == 10, 2);
        assert!(StableCurve::pow_10(2) == 100, 3);
        assert!(StableCurve::pow_10(5) == 100000, 4);
        assert!(StableCurve::pow_10(10) == 10000000000, 5);
    }

    #[test]
    fun test_coin_out() {

    }
}
