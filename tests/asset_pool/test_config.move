/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
#[test_only]
module dfmm_framework::config_test  {

    use std::signer;
    use dfmm_framework::config;
    use supra_framework::chain_id;


    #[test(deployer = @dfmm_framework, user1 = @0x123, dfmm_admin = @0x46541ee138920e00595c0af4aa04f1e248d22af6c6e90e834b13b04ce9b55cec)]
    fun test_set_admin(deployer: &signer, user1: &signer, dfmm_admin: &signer) {
        config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        let user1_address = signer::address_of(user1);

        // grant admin
        config::set_admin_role(deployer, user1_address, true);
        assert!(config::is_admin(user1_address), 1); // one more admin
        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is still an admin

        config::assert_admin(user1); // no error
        config::assert_admin(dfmm_admin); // no error, admin acc from `named address`

        // revoke admin
        config::set_admin_role(deployer, user1_address, false);
        assert!(!config::is_admin(user1_address), 1); // revoked
        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is still an admin
    }

    #[test(deployer = @dfmm_framework, user1 = @0x123, dfmm_admin = @0x46541ee138920e00595c0af4aa04f1e248d22af6c6e90e834b13b04ce9b55cec)]
    fun test_set_owner(deployer: &signer, user1: &signer, dfmm_admin: &signer) {
        config::init_for_test(deployer);

        assert!(config::is_owner(signer::address_of(deployer)), 1); // deployer is an admin initially
        let user1_address = signer::address_of(user1);

        // grant owner
        config::set_owner_role(deployer, user1_address, true);
        assert!(config::is_owner(user1_address), 1); // one more owner
        assert!(config::is_owner(signer::address_of(deployer)), 1); // deployer is still an owner

        config::assert_owner(user1); // no error

        // revoke owner
        config::set_owner_role(deployer, user1_address, false);
        assert!(!config::is_owner(user1_address), 1); // revoked
        assert!(config::is_owner(signer::address_of(deployer)), 1); // deployer is still an owner
    }    

    #[test(deployer = @dfmm_framework, user1 = @0x123)]
    #[expected_failure(abort_code = 327681)] // rbac module
    fun test_assert_admin(deployer: &signer, user1: &signer) {
        config::init_for_test(deployer);
        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        config::assert_admin(deployer); // no error
        config::assert_admin(user1); // error
    }

    #[test(deployer = @dfmm_framework, user1 = @0x123)]
    #[expected_failure(abort_code = 327681)] // rbac module
    fun test_assert_owner(deployer: &signer, user1: &signer) {
        config::init_for_test(deployer);
        assert!(config::is_owner(signer::address_of(deployer)), 1); // deployer is an owner initially
        config::assert_owner(deployer); // no error
        config::assert_owner(user1); // error
    }

    #[test(deployer = @dfmm_framework)]
    fun test_default_route_addresses(deployer: &signer) {
        config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        // default routes : withdrawal_address, service_fees_address, rewards distribution = deployer
        let deployer_address = signer::address_of(deployer);
        assert!(deployer_address == config::get_withdrawal_address(), 1);
        assert!(deployer_address == config::get_service_fees_address(), 1);
        assert!(deployer_address == config::get_rewards_distribution_address(), 1);
    }

    #[test(deployer = @dfmm_framework)]
    fun test_apply_route_addresses(deployer: &signer) {
        config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        // default routes : withdrawal_address, service_fees_address, rewards distribution = deployer
        let deployer_address = signer::address_of(deployer);
        assert!(deployer_address == config::get_withdrawal_address(), 1);
        assert!(deployer_address == config::get_service_fees_address(), 1);
        assert!(deployer_address == config::get_rewards_distribution_address(), 1);

        config::set_withdrawal_address(deployer, @0x123);
        config::set_service_fees_address(deployer, @0x234);
        config::set_rewards_distribution_address(deployer, @0x345);

        assert!(@0x123 == config::get_withdrawal_address(), 1);
        assert!(@0x234 == config::get_service_fees_address(), 1);
        assert!(@0x345 == config::get_rewards_distribution_address(), 1);
    }

    #[test(deployer = @dfmm_framework, user1 = @0x123)]
    fun test_set_delegation_pools(deployer: &signer, user1: &signer) {
        config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        let user1_address = signer::address_of(user1);

        // grant admin_delegation_pools
        config::set_delegation_pools_role(deployer, user1_address, true);
        assert!(config::is_admin_delegation_pools(user1_address), 1); // role is granted

        config::assert_delegation_pools(user1); // no error

        // revoke admin_delegation_pools
        config::set_delegation_pools_role(deployer, user1_address, false);
        assert!(!config::is_admin_delegation_pools(user1_address), 1); // role is revoked
    }


    #[test(deployer = @dfmm_framework)]
    fun test_set_allocate_rewards_flags(deployer: &signer) {
        config::init_for_test(deployer);

        let is_allocate_rewards = config::is_allocate_rewards();
        assert!(is_allocate_rewards, 1);
        // change
        config::set_allocate_rewards(deployer, false);
        assert!(!config::is_allocate_rewards(), 1);
        config::set_allocate_rewards(deployer, true);
        assert!(config::is_allocate_rewards(), 1);
    }


    #[test(deployer = @dfmm_framework, supra = @0x1)]
    #[expected_failure(abort_code = 327682, location = config )] // error::permission_denied(EREWARDS_ALLOCATION_NOT_ALLOWED));
    fun test_assert_allocate_rewards(deployer: &signer, supra: &signer) {
        config::init_for_test(deployer);
        chain_id::initialize_for_test(supra, 8);// supra
        config::set_allocate_rewards(deployer, false);
        let is_allocate_rewards = config::is_allocate_rewards();
        assert!(!is_allocate_rewards, 1);// disabled
        config::assert_allocate_rewards(); // error is expected
    }

    #[test(deployer = @dfmm_framework, user1 = @0x123, user2 = @0x234)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_set_delegation_pools_unauthorized(deployer: &signer, user1: &signer, user2: &signer) {
        config::init_for_test(deployer);
        // error
        config::set_delegation_pools_role(user2, signer::address_of(user1), true);
    }

    #[test(deployer = @dfmm_framework, user1 = @0x123)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_set_allocate_rewards_unauthorized(deployer: &signer, user1: &signer) {
        config::init_for_test(deployer);
        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        // error
        config::set_allocate_rewards(user1, false);
    }

    #[test(deployer = @dfmm_framework, user1 = @0x123, user2 = @0x234)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_set_admin_unauthorized(deployer: &signer, user1: &signer, user2: &signer) {
        config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially

        // change admin, error
        config::set_admin_role(user2, signer::address_of(user1), true);
    }

    #[test(deployer = @dfmm_framework, user1 = @0x123, user2 = @0x234)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied
    fun test_set_owner_unauthorized(deployer: &signer, user1: &signer, user2: &signer) {
        config::init_for_test(deployer);
        assert!(config::is_owner(signer::address_of(deployer)), 1); // deployer is an owner
        // set owner, error
        config::set_owner_role(user2, signer::address_of(user1), true);
    }

    #[test(deployer = @dfmm_framework)]
    fun test_set_params(deployer: &signer) {
        config::init_for_test(deployer);
        config::set_parameters(deployer, 4,5, 50, 25, 6,7,8,9,10,11,12, 13);

        let (min_collateralisation,
            length_of_epoch, length_of_lockup_cycle, number_of_epoch_in_apy, max_collateralisation_first, max_collateralisation_second,
            reward_reduction_rate,
            pool_max_delegation_cap,
            smallest_portion_of_distributable_rewards,
            threshold_rewards_to_distribute,
            min_frequency_rewards_allocation,
            number_of_epoch_in_cycle
        ) = config::get_mut_params();

        assert!(min_collateralisation == 4, 1);
        assert!(length_of_epoch == 5, 1);
        assert!(length_of_lockup_cycle == 50, 1);
        assert!(number_of_epoch_in_apy == 25, 1);

        assert!(max_collateralisation_first == 6, 1);
        assert!(max_collateralisation_second == 7, 1);
        assert!(reward_reduction_rate == 8, 1);
        assert!(pool_max_delegation_cap == 9, 1);
        assert!(smallest_portion_of_distributable_rewards == 10, 1);
        assert!(threshold_rewards_to_distribute == 11, 1);
        assert!(min_frequency_rewards_allocation == 12, 1);
        assert!(number_of_epoch_in_cycle == 13, 1);
    }

    #[test(deployer = @dfmm_framework)]
    #[expected_failure(abort_code = 196611, location = config )] // error::invalid_state(EVALUE_EXCEEDED)
    fun test_set_params_too_big_rate_1(deployer: &signer) {
        config::init_for_test(deployer);
        //reward_reduction_rate is too big
        config::set_parameters(deployer, 4,5,50,25, 6,7,18000,9,10,11, 12, 3);
    }

    #[test(deployer = @dfmm_framework)]
    #[expected_failure(abort_code = 196612, location = config )] // error::invalid_state(EVALUE_EXCEEDED)
    fun test_set_params_too_big_rate_2(deployer: &signer) {
        config::init_for_test(deployer);
        //smallest_portion_of_distributable_rewards is too big
        config::set_parameters(deployer, 4,5,50,25, 6,7,8,9,20000,11, 12, 3);
    }
}