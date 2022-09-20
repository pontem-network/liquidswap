#[test_only]
module liquidswap::admins_tests {
    use aptos_framework::account;

    use liquidswap::admins;

    #[test]
    fun test_dao_admin() {
        admins::initialize_for_test();

        assert!(admins::get_dao_admin() == @dao_admin, 0);

        let dao_admin = account::create_account_for_test(@dao_admin);
        admins::set_dao_admin(&dao_admin, @test_coin_admin);
        assert!(admins::get_dao_admin() == @test_coin_admin, 2);
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_dao_admin_fail_if_config_is_not_initialized() {
        admins::get_dao_admin();
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_set_dao_admin_fail_if_config_is_not_initialized() {
        let dao_admin = account::create_account_for_test(@dao_admin);
        admins::set_dao_admin(&dao_admin, @test_coin_admin);
    }

    #[test]
    #[expected_failure(abort_code = 301)]
    fun test_set_dao_admin_fail_if_user_is_not_dao_admin() {
        admins::initialize_for_test();

        let dao_admin = account::create_account_for_test(@dao_admin);
        admins::set_dao_admin(&dao_admin, @test_coin_admin);
        assert!(admins::get_dao_admin() == @test_coin_admin, 0);

        let test_coin_admin = account::create_account_for_test(@test_coin_admin);
        admins::set_dao_admin(&test_coin_admin, @dao_admin);
        assert!(admins::get_dao_admin() == @dao_admin, 1);

        admins::set_dao_admin(&test_coin_admin, @dao_admin);
    }

    #[test]
    fun test_emergency_admin() {
        admins::initialize_for_test();

        assert!(admins::get_emergency_admin() == @emergency_admin, 1);

        let emergency_admin = account::create_account_for_test(@emergency_admin);
        admins::set_emergency_admin(&emergency_admin, @test_coin_admin);
        assert!(admins::get_emergency_admin() == @test_coin_admin, 3);
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_get_emergency_admin_fail_if_config_is_not_initialized() {
        admins::get_emergency_admin();
    }

    #[test]
    #[expected_failure(abort_code = 300)]
    fun test_set_emergency_admin_fail_if_config_is_not_initialized() {
        let emergency_admin = account::create_account_for_test(@emergency_admin);
        admins::set_emergency_admin(&emergency_admin, @test_coin_admin);
    }

    #[test]
    #[expected_failure(abort_code = 301)]
    fun test_set_emergency_admin_fail_if_user_is_not_emergency_admin() {
        admins::initialize_for_test();

        let emergency_admin = account::create_account_for_test(@emergency_admin);
        admins::set_emergency_admin(&emergency_admin, @test_coin_admin);
        assert!(admins::get_emergency_admin() == @test_coin_admin, 0);

        let test_coin_admin = account::create_account_for_test(@test_coin_admin);
        admins::set_emergency_admin(&test_coin_admin, @emergency_admin);
        assert!(admins::get_emergency_admin() == @emergency_admin, 1);

        admins::set_emergency_admin(&test_coin_admin, @emergency_admin);
    }
}
