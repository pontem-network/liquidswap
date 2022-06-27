#[test_only]
module MultiSwap::TimeHelperTests {
    use MultiSwap::TimeHelper;

    #[test]
    public fun test_get_duration_in_seconds() {
        let a = TimeHelper::get_duration_in_weeks(0);
        assert!(a == 1, 0);

        a = TimeHelper::get_duration_in_weeks(1);
        assert!(a == 4, 1);

        a = TimeHelper::get_duration_in_weeks(2);
        assert!(a == 52, 2);

        a = TimeHelper::get_duration_in_weeks(3);
        assert!(a == 208, 3);
    }

    #[test]
    #[expected_failure(abort_code = 100)]
    public fun test_get_duration_in_seconds_wrong_duration() {
        let _ = TimeHelper::get_duration_in_weeks(4);
    }
}
