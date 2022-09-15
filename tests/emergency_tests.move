#[test_only]
module liquidswap::emergency_tests {
    use liquidswap::emergency;

    #[test(emergency_acc = @emergency_admin)]
    public fun test_end_to_end(emergency_acc: signer) {
        emergency::assert_no_emergency();
        assert!(emergency::is_emergency() == false, 0);

        emergency::pause(&emergency_acc);
        assert!(emergency::is_emergency() == true, 1);
        emergency::resume(&emergency_acc);
        emergency::assert_no_emergency();

        assert!(emergency::is_emergency() == false, 2);

        emergency::pause(&emergency_acc);

        assert!(emergency::is_disabled() == false, 3);
        emergency::disable_forever(&emergency_acc);
        assert!(emergency::is_disabled() == true, 4);
    }

    #[test(emergency_acc = @0x13)]
    #[expected_failure(abort_code = 4000)]
    public fun test_wrong_account_fails(emergency_acc: signer) {
        emergency::pause(&emergency_acc);
    }

    #[test(emergency_acc = @emergency_admin)]
    #[expected_failure(abort_code = 4001)]
    public fun test_emergency_second_time_fails(emergency_acc: signer) {
        emergency::pause(&emergency_acc);
        emergency::pause(&emergency_acc);
    }

    #[test(emergency_acc = @emergency_admin, tmp = @0x13)]
    #[expected_failure(abort_code = 4000)]
    public fun test_resume_wrong_account_fails(emergency_acc: signer, tmp: signer) {
        emergency::pause(&emergency_acc);
        assert!(emergency::is_emergency() == true, 1);
        emergency::resume(&tmp);
    }

    #[test(emergency_acc = @emergency_admin)]
    #[expected_failure(abort_code = 4003)]
    public fun test_resume_fails(emergency_acc: signer) {
        emergency::resume(&emergency_acc);
    }

    #[test(emergency_acc = @emergency_admin)]
    #[expected_failure(abort_code = 4001)]
    public fun test_emergency_assert_fails(emergency_acc: signer) {
        emergency::pause(&emergency_acc);
        emergency::assert_no_emergency();
    }

    #[test]
    public fun test_emergency_assert() {
        emergency::assert_no_emergency();
    }

    #[test(emergency_acc = @emergency_admin)]
    public fun test_is_emergency(emergency_acc: signer) {
        emergency::pause(&emergency_acc);
        assert!(emergency::is_emergency() == true, 0);
        emergency::resume(&emergency_acc);
        assert!(emergency::is_emergency() == false, 1);
    }

    #[test(emergency_acc = @emergency_admin)]
    public fun test_disable(emergency_acc: signer) {
        assert!(emergency::is_disabled() == false, 0);
        emergency::disable_forever(&emergency_acc);
        assert!(emergency::is_disabled() == true, 1);
    }

    #[test(emergency_acc = @emergency_admin)]
    public fun test_disable_during_pause(emergency_acc: signer) {
        assert!(emergency::is_disabled() == false, 0);
        emergency::pause(&emergency_acc);
        emergency::disable_forever(&emergency_acc);
        assert!(emergency::is_disabled() == true, 1);
    }

    #[test(emergency_acc = @emergency_admin)]
    #[expected_failure(abort_code = 4002)]
    public fun test_resume_after_disable_fails(emergency_acc: signer) {
        emergency::pause(&emergency_acc);
        emergency::disable_forever(&emergency_acc);
        emergency::resume(&emergency_acc);
    }

    #[test(emergency_acc = @emergency_admin)]
    #[expected_failure(abort_code = 4002)]
    public fun test_pause_after_disable_fails(emergency_acc: signer) {
        emergency::disable_forever(&emergency_acc);
        emergency::pause(&emergency_acc);
    }

    #[test(emergency_acc = @emergency_admin)]
    #[expected_failure(abort_code = 4002)]
    public fun test_disable_fails(emergency_acc: signer) {
        emergency::disable_forever(&emergency_acc);
        emergency::disable_forever(&emergency_acc);
    }

    #[test(emergency_acc = @0x13)]
    #[expected_failure(abort_code = 4000)]
    public fun test_disable_wrong_account_fails(emergency_acc: signer) {
        emergency::disable_forever(&emergency_acc);
    }
}
