#[test_only]
module liquidswap::global_config_tests {
    use liquidswap::global_config;
    use liquidswap::curves::{Uncorrelated, Stable};
    use aptos_framework::account;

    struct InvalidCurve {}

    fun fee_admin(): signer {
        account::create_account_for_test(@fee_admin)
    }

    #[test(dao_admin = @dao_admin, test_coin_admin = @test_coin_admin)]
    fun test_dao_admin(dao_admin: signer, test_coin_admin: signer) {
        global_config::initialize_for_test();

        assert!(global_config::get_dao_admin() == @dao_admin, 0);

        global_config::set_dao_admin(&dao_admin, @test_coin_admin);
        assert!(global_config::get_dao_admin() == @test_coin_admin, 1);

        global_config::set_dao_admin(&test_coin_admin, @dao_admin);
        assert!(global_config::get_dao_admin() == @dao_admin, 2);
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_dao_admin_fail_if_config_is_not_initialized() {
        global_config::get_dao_admin();
    }

    #[test(dao_admin = @dao_admin)]
    #[expected_failure(abort_code = 300)]
    fun test_set_dao_admin_fail_if_config_is_not_initialized(dao_admin: signer) {
        global_config::set_dao_admin(&dao_admin, @test_coin_admin);
    }

    #[test(dao_admin = @dao_admin)]
    #[expected_failure(abort_code = 301)]
    fun test_set_dao_admin_fail_if_user_is_not_dao_admin(dao_admin: signer) {
        global_config::initialize_for_test();

        global_config::set_dao_admin(&dao_admin, @test_coin_admin);
        assert!(global_config::get_dao_admin() == @test_coin_admin, 0);

        global_config::set_dao_admin(&dao_admin, @test_coin_admin);
    }

    #[test(emergency_admin = @emergency_admin, test_coin_admin = @test_coin_admin)]
    fun test_emergency_admin(emergency_admin: signer, test_coin_admin: signer) {
        global_config::initialize_for_test();

        assert!(global_config::get_emergency_admin() == @emergency_admin, 0);

        global_config::set_emergency_admin(&emergency_admin, @test_coin_admin);
        assert!(global_config::get_emergency_admin() == @test_coin_admin, 1);

        global_config::set_emergency_admin(&test_coin_admin, @emergency_admin);
        assert!(global_config::get_emergency_admin() == @emergency_admin, 2);
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_emergency_admin_fail_if_config_is_not_initialized() {
        global_config::get_emergency_admin();
    }

    #[test(emergency_admin = @emergency_admin)]
    #[expected_failure(abort_code = 300)]
    fun test_set_emergency_admin_fail_if_config_is_not_initialized(emergency_admin: signer) {
        global_config::set_emergency_admin(&emergency_admin, @test_coin_admin);
    }

    #[test(emergency_admin = @emergency_admin)]
    #[expected_failure(abort_code = 301)]
    fun test_set_emergency_admin_fail_if_user_is_not_emergency_admin(emergency_admin: signer) {
        global_config::initialize_for_test();

        global_config::set_emergency_admin(&emergency_admin, @test_coin_admin);
        assert!(global_config::get_emergency_admin() == @test_coin_admin, 0);

        global_config::set_emergency_admin(&emergency_admin, @test_coin_admin);
    }

    #[test(fee_admin = @fee_admin, test_coin_admin = @test_coin_admin)]
    fun test_fee_admin(fee_admin: signer, test_coin_admin: signer) {
        global_config::initialize_for_test();

        assert!(global_config::get_fee_admin() == @fee_admin, 0);

        global_config::set_fee_admin(&fee_admin, @test_coin_admin);
        assert!(global_config::get_fee_admin() == @test_coin_admin, 1);

        global_config::set_fee_admin(&test_coin_admin, @fee_admin);
        assert!(global_config::get_fee_admin() == @fee_admin, 2);
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_fee_admin_fail_if_config_is_not_initialized() {
        global_config::get_fee_admin();
    }

    #[test(fee_admin = @fee_admin)]
    #[expected_failure(abort_code = 300)]
    fun test_set_fee_admin_fail_if_config_is_not_initialized(fee_admin: signer) {
        global_config::set_fee_admin(&fee_admin, @test_coin_admin);
    }

    #[test(fee_admin = @fee_admin)]
    #[expected_failure(abort_code = 301)]
    fun test_set_fee_admin_fail_if_user_is_not_fee_admin(fee_admin: signer) {
        global_config::initialize_for_test();

        global_config::set_fee_admin(&fee_admin, @test_coin_admin);
        assert!(global_config::get_fee_admin() == @test_coin_admin, 0);

        global_config::set_fee_admin(&fee_admin, @test_coin_admin);
    }

    #[test(fee_admin = @fee_admin)]
    fun test_default_fee(fee_admin: signer) {
        global_config::initialize_for_test();

        assert!(global_config::get_default_fee<Uncorrelated>() == 30, 0);
        assert!(global_config::get_default_fee<Stable>() == 4, 1);
        assert!(global_config::get_default_dao_fee() == 33, 2);

        global_config::set_default_fee<Uncorrelated>(&fee_admin, 25);
        assert!(global_config::get_default_fee<Uncorrelated>() == 25, 3);
        global_config::set_default_fee<Stable>(&fee_admin, 15);
        assert!(global_config::get_default_fee<Stable>() == 15, 4);

        global_config::set_default_dao_fee(&fee_admin, 30);
        assert!(global_config::get_default_dao_fee() == 30, 5);
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_default_fee_fail_if_config_is_not_initialized() {
        global_config::get_default_fee<Uncorrelated>();
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_default_dao_fee_fail_if_config_is_not_initialized() {
        global_config::get_default_dao_fee();
    }

    #[test(fee_admin = @fee_admin)]
    #[expected_failure(abort_code = 300)]
    fun test_set_default_fee_fail_if_config_is_not_initialized(fee_admin: signer) {
        global_config::set_default_fee<Uncorrelated>(&fee_admin, 20);
    }

    #[test(dao_admin = @dao_admin)]
    #[expected_failure(abort_code = 300)]
    fun test_set_default_dao_fee_fail_if_config_is_not_initialized(dao_admin: signer) {
        global_config::set_default_dao_fee(&dao_admin, 20);
    }

    #[test(fee_admin = @fee_admin)]
    #[expected_failure(abort_code = 301)]
    fun test_set_default_fee_fail_if_user_is_not_fee_admin(fee_admin: signer) {
        global_config::initialize_for_test();

        global_config::set_fee_admin(&fee_admin, @test_coin_admin);
        assert!(global_config::get_fee_admin() == @test_coin_admin, 0);

        global_config::set_default_fee<Uncorrelated>(&fee_admin, 20);
    }

    #[test(fee_admin = @fee_admin)]
    #[expected_failure(abort_code = 301)]
    fun test_set_default_dao_fee_fail_if_user_is_not_fee_admin(fee_admin: signer) {
        global_config::initialize_for_test();

        global_config::set_fee_admin(&fee_admin, @test_coin_admin);
        assert!(global_config::get_fee_admin() == @test_coin_admin, 0);

        global_config::set_default_dao_fee(&fee_admin, 20);
    }

    #[test(fee_admin = @fee_admin)]
    #[expected_failure(abort_code = 302)]
    fun test_set_default_fee_fail_if_invalid_amount_of_fee(fee_admin: signer) {
        global_config::initialize_for_test();

        global_config::set_default_fee<Uncorrelated>(&fee_admin, 101);
    }

    #[test(fee_admin = @fee_admin)]
    #[expected_failure(abort_code = 302)]
    fun test_set_default_dao_fee_fail_if_invalid_amount_of_fee(fee_admin: signer) {
        global_config::initialize_for_test();

        global_config::set_default_dao_fee(&fee_admin, 101);
    }

    #[test]
    #[expected_failure(abort_code = 10001)]
    fun test_cannot_set_default_fee_for_invalid_curve() {
        global_config::initialize_for_test();

        let fee_admin = fee_admin();
        global_config::set_default_fee<InvalidCurve>(&fee_admin, 100);
    }

    #[test]
    #[expected_failure(abort_code = 10001)]
    fun test_cannot_get_default_fee_for_invalid_curve() {
        global_config::initialize_for_test();

        let _ = global_config::get_default_fee<InvalidCurve>();
    }
}

