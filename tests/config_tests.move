#[test_only]
module liquidswap::config_tests {
    use aptos_framework::account;

    use liquidswap::config;

    #[test]
    fun test_dao_admin() {
        config::initialize_for_test();

        assert!(config::get_dao_admin() == @dao_admin, 0);

        let dao_admin = account::create_account_for_test(@dao_admin);
        config::set_dao_admin(&dao_admin, @test_coin_admin);
        assert!(config::get_dao_admin() == @test_coin_admin, 1);

        let test_coin_admin = account::create_account_for_test(@test_coin_admin);
        config::set_dao_admin(&test_coin_admin, @dao_admin);
        assert!(config::get_dao_admin() == @dao_admin, 2);
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_dao_admin_fail_if_config_is_not_initialized() {
        config::get_dao_admin();
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_set_dao_admin_fail_if_config_is_not_initialized() {
        let dao_admin = account::create_account_for_test(@dao_admin);
        config::set_dao_admin(&dao_admin, @test_coin_admin);
    }

    #[test]
    #[expected_failure(abort_code = 301)]
    fun test_set_dao_admin_fail_if_user_is_not_dao_admin() {
        config::initialize_for_test();

        let dao_admin = account::create_account_for_test(@dao_admin);
        config::set_dao_admin(&dao_admin, @test_coin_admin);
        assert!(config::get_dao_admin() == @test_coin_admin, 0);

        config::set_dao_admin(&dao_admin, @test_coin_admin);
    }

    #[test]
    fun test_emergency_admin() {
        config::initialize_for_test();

        assert!(config::get_emergency_admin() == @emergency_admin, 0);

        let emergency_admin = account::create_account_for_test(@emergency_admin);
        config::set_emergency_admin(&emergency_admin, @test_coin_admin);
        assert!(config::get_emergency_admin() == @test_coin_admin, 1);

        let test_coin_admin = account::create_account_for_test(@test_coin_admin);
        config::set_emergency_admin(&test_coin_admin, @emergency_admin);
        assert!(config::get_emergency_admin() == @emergency_admin, 2);
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_emergency_admin_fail_if_config_is_not_initialized() {
        config::get_emergency_admin();
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_set_emergency_admin_fail_if_config_is_not_initialized() {
        let emergency_admin = account::create_account_for_test(@emergency_admin);
        config::set_emergency_admin(&emergency_admin, @test_coin_admin);
    }

    #[test]
    #[expected_failure(abort_code = 301)]
    fun test_set_emergency_admin_fail_if_user_is_not_emergency_admin() {
        config::initialize_for_test();

        let emergency_admin = account::create_account_for_test(@emergency_admin);
        config::set_emergency_admin(&emergency_admin, @test_coin_admin);
        assert!(config::get_emergency_admin() == @test_coin_admin, 0);

        config::set_emergency_admin(&emergency_admin, @test_coin_admin);
    }

    #[test]
    fun test_fee_admin() {
        config::initialize_for_test();

        assert!(config::get_fee_admin() == @fee_admin, 0);

        let fee_admin = account::create_account_for_test(@fee_admin);
        config::set_fee_admin(&fee_admin, @test_coin_admin);
        assert!(config::get_fee_admin() == @test_coin_admin, 1);

        let test_coin_admin = account::create_account_for_test(@test_coin_admin);
        config::set_fee_admin(&test_coin_admin, @fee_admin);
        assert!(config::get_fee_admin() == @fee_admin, 2);
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_fee_admin_fail_if_config_is_not_initialized() {
        config::get_fee_admin();
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_set_fee_admin_fail_if_config_is_not_initialized() {
        let fee_admin = account::create_account_for_test(@fee_admin);
        config::set_fee_admin(&fee_admin, @test_coin_admin);
    }

    #[test]
    #[expected_failure(abort_code = 301)]
    fun test_set_fee_admin_fail_if_user_is_not_fee_admin() {
        config::initialize_for_test();

        let fee_admin = account::create_account_for_test(@fee_admin);
        config::set_fee_admin(&fee_admin, @test_coin_admin);
        assert!(config::get_fee_admin() == @test_coin_admin, 0);

        config::set_fee_admin(&fee_admin, @test_coin_admin);
    }
}
