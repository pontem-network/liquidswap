#[test_only]
module MultiSwap::StableCurveTests {
    use MultiSwap::StableCurve;
    use U256::U256;
    use Std::Debug;

    #[test]
    fun test_lp_value_compute() {
        // 0.3 ^ 3 * 0.5 + 0.5 ^ 3 * 0.3 = 0.051 (12 decimals)
        let lp_value = StableCurve::lp_value(300000, 1000000, 500000, 1000000);
        assert!(
             U256::as_u128(lp_value) == 5100000,
            1
        );

        lp_value = StableCurve::lp_value(
            500000899318256,
            1000000,
            25000567572582123,
            1000000000000
        );

        Debug::print(&U256::as_u128(lp_value));
        assert!(U256::as_u128(lp_value) == 312508781701599715772530613362069248234, 2);
    }
}
