#[test_only]
module liquidswap::config_tests {
    use liquidswap::config;
    use liquidswap::curves::{Uncorrelated, Stable};
    use aptos_framework::account;

    struct InvalidCurve {}

    fun fee_admin(): signer {
        account::create_account_for_test(@fee_admin)
    }

    #[test(dao_admin = @dao_admin, test_coin_admin = @test_coin_admin)]
    fun test_dao_admin(dao_admin: signer, test_coin_admin: signer) {
        config::initialize_for_test();

        assert!(config::get_dao_admin() == @dao_admin, 0);

        config::set_dao_admin(&dao_admin, @test_coin_admin);
        assert!(config::get_dao_admin() == @test_coin_admin, 1);

        config::set_dao_admin(&test_coin_admin, @dao_admin);
        assert!(config::get_dao_admin() == @dao_admin, 2);
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_dao_admin_fail_if_config_is_not_initialized() {
        config::get_dao_admin();
    }

    #[test(dao_admin = @dao_admin)]
    #[expected_failure(abort_code = 300)]
    fun test_set_dao_admin_fail_if_config_is_not_initialized(dao_admin: signer) {
        config::set_dao_admin(&dao_admin, @test_coin_admin);
    }

    #[test(dao_admin = @dao_admin)]
    #[expected_failure(abort_code = 301)]
    fun test_set_dao_admin_fail_if_user_is_not_dao_admin(dao_admin: signer) {
        config::initialize_for_test();

        config::set_dao_admin(&dao_admin, @test_coin_admin);
        assert!(config::get_dao_admin() == @test_coin_admin, 0);

        config::set_dao_admin(&dao_admin, @test_coin_admin);
    }

    #[test(emergency_admin = @emergency_admin, test_coin_admin = @test_coin_admin)]
    fun test_emergency_admin(emergency_admin: signer, test_coin_admin: signer) {
        config::initialize_for_test();

        assert!(config::get_emergency_admin() == @emergency_admin, 0);

        config::set_emergency_admin(&emergency_admin, @test_coin_admin);
        assert!(config::get_emergency_admin() == @test_coin_admin, 1);

        config::set_emergency_admin(&test_coin_admin, @emergency_admin);
        assert!(config::get_emergency_admin() == @emergency_admin, 2);
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_emergency_admin_fail_if_config_is_not_initialized() {
        config::get_emergency_admin();
    }

    #[test(emergency_admin = @emergency_admin)]
    #[expected_failure(abort_code = 300)]
    fun test_set_emergency_admin_fail_if_config_is_not_initialized(emergency_admin: signer) {
        config::set_emergency_admin(&emergency_admin, @test_coin_admin);
    }

    #[test(emergency_admin = @emergency_admin)]
    #[expected_failure(abort_code = 301)]
    fun test_set_emergency_admin_fail_if_user_is_not_emergency_admin(emergency_admin: signer) {
        config::initialize_for_test();

        config::set_emergency_admin(&emergency_admin, @test_coin_admin);
        assert!(config::get_emergency_admin() == @test_coin_admin, 0);

        config::set_emergency_admin(&emergency_admin, @test_coin_admin);
    }

    #[test(fee_admin = @fee_admin, test_coin_admin = @test_coin_admin)]
    fun test_fee_admin(fee_admin: signer, test_coin_admin: signer) {
        config::initialize_for_test();

        assert!(config::get_fee_admin() == @fee_admin, 0);

        config::set_fee_admin(&fee_admin, @test_coin_admin);
        assert!(config::get_fee_admin() == @test_coin_admin, 1);

        config::set_fee_admin(&test_coin_admin, @fee_admin);
        assert!(config::get_fee_admin() == @fee_admin, 2);
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_fee_admin_fail_if_config_is_not_initialized() {
        config::get_fee_admin();
    }

    #[test(fee_admin = @fee_admin)]
    #[expected_failure(abort_code = 300)]
    fun test_set_fee_admin_fail_if_config_is_not_initialized(fee_admin: signer) {
        config::set_fee_admin(&fee_admin, @test_coin_admin);
    }

    #[test(fee_admin = @fee_admin)]
    #[expected_failure(abort_code = 301)]
    fun test_set_fee_admin_fail_if_user_is_not_fee_admin(fee_admin: signer) {
        config::initialize_for_test();

        config::set_fee_admin(&fee_admin, @test_coin_admin);
        assert!(config::get_fee_admin() == @test_coin_admin, 0);

        config::set_fee_admin(&fee_admin, @test_coin_admin);
    }

    #[test(fee_admin = @fee_admin, dao_admin = @dao_admin)]
    fun test_default_fee(fee_admin: signer, dao_admin: signer) {
        config::initialize_for_test();

        assert!(config::get_default_fee<Uncorrelated>() == 30, 0);
        assert!(config::get_default_fee<Stable>() == 4, 1);
        assert!(config::get_default_dao_fee() == 33, 2);

        config::set_default_fee<Uncorrelated>(&fee_admin, 25);
        assert!(config::get_default_fee<Uncorrelated>() == 25, 3);
        config::set_default_fee<Stable>(&fee_admin, 15);
        assert!(config::get_default_fee<Stable>() == 15, 4);

        config::set_default_dao_fee(&dao_admin, 30);
        assert!(config::get_default_dao_fee() == 30, 5);
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_default_fee_fail_if_config_is_not_initialized() {
        config::get_default_fee<Uncorrelated>();
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_default_dao_fee_fail_if_config_is_not_initialized() {
        config::get_default_dao_fee();
    }

    #[test(fee_admin = @fee_admin)]
    #[expected_failure(abort_code = 300)]
    fun test_set_default_fee_fail_if_config_is_not_initialized(fee_admin: signer) {
        config::set_default_fee<Uncorrelated>(&fee_admin, 20);
    }

    #[test(dao_admin = @dao_admin)]
    #[expected_failure(abort_code = 300)]
    fun test_set_default_dao_fee_fail_if_config_is_not_initialized(dao_admin: signer) {
        config::set_default_dao_fee(&dao_admin, 20);
    }

    #[test(fee_admin = @fee_admin)]
    #[expected_failure(abort_code = 301)]
    fun test_set_default_fee_fail_if_user_is_not_fee_admin(fee_admin: signer) {
        config::initialize_for_test();

        config::set_fee_admin(&fee_admin, @test_coin_admin);
        assert!(config::get_fee_admin() == @test_coin_admin, 0);

        config::set_default_fee<Uncorrelated>(&fee_admin, 20);
    }

    #[test(dao_admin = @dao_admin)]
    #[expected_failure(abort_code = 301)]
    fun test_set_default_dao_fee_fail_if_user_is_not_dao_admin(dao_admin: signer) {
        config::initialize_for_test();

        config::set_dao_admin(&dao_admin, @test_coin_admin);
        assert!(config::get_dao_admin() == @test_coin_admin, 0);

        config::set_default_dao_fee(&dao_admin, 20);
    }

    #[test(fee_admin = @fee_admin)]
    #[expected_failure(abort_code = 302)]
    fun test_set_default_fee_fail_if_invalid_amount_of_fee(fee_admin: signer) {
        config::initialize_for_test();

        config::set_default_fee<Uncorrelated>(&fee_admin, 36);
    }

    #[test(dao_admin = @dao_admin)]
    #[expected_failure(abort_code = 302)]
    fun test_set_default_dao_fee_fail_if_invalid_amount_of_fee(dao_admin: signer) {
        config::initialize_for_test();

        config::set_default_dao_fee(&dao_admin, 101);
    }

    #[test]
    #[expected_failure(abort_code = 10001)]
    fun test_cannot_set_default_fee_for_invalid_curve() {
        config::initialize_for_test();

        let fee_admin = fee_admin();
        config::set_default_fee<InvalidCurve>(&fee_admin, 100);
    }

    #[test]
    #[expected_failure(abort_code = 10001)]
    fun test_cannot_get_default_fee_for_invalid_curve() {
        config::initialize_for_test();

        let _ = config::get_default_fee<InvalidCurve>();
    }
}

