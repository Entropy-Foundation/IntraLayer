/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
#[test_only]
module dfmm_framework::asset_config_test  {

    use std::signer;
    use std::string::{Self};
    use supra_framework::chain_id;
    use supra_framework::supra_coin::SupraCoin;

    use dfmm_framework::config;
    use dfmm_framework::asset_config;
    use dfmm_framework::poel;
    use dfmm_framework::asset_util;
    use dfmm_framework::test_util;

    const CHAIN_ID:u8 = 6;

    #[test(deployer = @dfmm_framework)]
    fun test_set_withdraw_delay(deployer: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        assert!(asset_config::get_withdraw_delay() == 604800, 1); // def value, 1 week
    }

    #[test(deployer = @dfmm_framework)]
    fun test_enable_disable_deposit(deployer: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        assert!(asset_config::is_deposit_enabled(), 1); // method init_for_test sets the deposit enabled
        assert!(asset_config::is_withdraw_enabled(), 1); // method init_for_test sets the withdraw enabled

        asset_config::disable_deposit(deployer);
        assert!(!asset_config::is_deposit_enabled(), 1);

        asset_config::enable_deposit(deployer);
        assert!(asset_config::is_deposit_enabled(), 1);
    }

    #[test(deployer = @dfmm_framework)]
    #[expected_failure(abort_code = 196609, location = asset_config )] // EALREADY_ENABLED
    fun test_already_enabled_deposit(deployer: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        assert!(asset_config::is_deposit_enabled(), 1); // method init_for_test sets the deposit enabled
        assert!(asset_config::is_withdraw_enabled(), 1); // method init_for_test sets the withdraw enabled

        asset_config::enable_deposit(deployer); // error, already
    }

    #[test(deployer = @dfmm_framework)]
    #[expected_failure(abort_code = 196610, location = asset_config )] // EALREADY_DISABLED
    fun test_already_disabled_deposit(deployer: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        assert!(asset_config::is_deposit_enabled(), 1); // method init_for_test sets the deposit enabled
        assert!(asset_config::is_withdraw_enabled(), 1); // method init_for_test sets the withdraw enabled

        asset_config::disable_deposit(deployer);
        assert!(!asset_config::is_deposit_enabled(), 1);
        asset_config::disable_deposit(deployer); // error
    }    

    #[test(deployer = @dfmm_framework,  user1 = @0x123)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_enable_deposit_unauthorized(deployer: &signer, user1: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        assert!(asset_config::is_deposit_enabled(), 1); // method init_for_test sets the deposit enabled
        asset_config::disable_deposit(deployer);
        assert!(!asset_config::is_deposit_enabled(), 1); 
        asset_config::enable_deposit(user1); // error
    }

    #[test(deployer = @dfmm_framework,  user1 = @0x123)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_disable_deposit_unauthorized(deployer: &signer, user1: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        assert!(asset_config::is_deposit_enabled(), 1); // method init_for_test sets the deposit enabled
        // not allowed
        asset_config::disable_deposit(user1);
    }    

    #[test(deployer = @dfmm_framework)]
    fun test_enable_disable_withdraw(deployer: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        assert!(asset_config::is_deposit_enabled(), 1); // method init_for_test sets the deposit enabled
        assert!(asset_config::is_withdraw_enabled(), 1); // method init_for_test sets the withdraw enabled

        asset_config::disable_withdraw(deployer);
        assert!(!asset_config::is_withdraw_enabled(), 1);

        asset_config::enable_withdraw(deployer);
        assert!(asset_config::is_withdraw_enabled(), 1);
    }

    #[test(deployer = @dfmm_framework,  user1 = @0x123)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_disable_withdraw_unauthorized(deployer: &signer, user1: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        assert!(asset_config::is_withdraw_enabled(), 1); // method init_for_test sets the withdraw enabled
        // not allowed
        asset_config::disable_withdraw(user1);
    }

    #[test(deployer = @dfmm_framework,  user1 = @0x123)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_enable_withdraw_unauthorized(deployer: &signer, user1: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially
        assert!(asset_config::is_withdraw_enabled(), 1); // method init_for_test sets the withdraw enabled
        asset_config::disable_withdraw(deployer);
        assert!(!asset_config::is_withdraw_enabled(), 1);
        asset_config::enable_withdraw(user1);// not allowed
    }    

    #[test(deployer = @dfmm_framework)]
    fun test_set_service_fees(deployer: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        let (in_fees, out_fees, out_fees_external) = asset_config::get_service_fees();
        assert!(in_fees == 0, 1);
        assert!(out_fees == 0, 1);
        assert!(out_fees_external == 0, 1);        

        let in_fees1 = 501;
        let out_fees1 = 502;
        let out_fees_external1 = 503;

        let in_fees2 = 301;
        let out_fees2 = 302;
        let out_fees_external2 = 303;

        asset_config::set_service_fees(deployer, in_fees1, out_fees1, out_fees_external1);

        let (in_fees, out_fees, out_fees_external) = asset_config::get_service_fees();
        assert!(in_fees == in_fees1, 1);
        assert!(out_fees == out_fees1, 1);
        assert!(out_fees_external == out_fees_external1, 1);

        asset_config::set_service_fees(deployer, in_fees2, out_fees2, out_fees_external2);
        let (in_fees, out_fees, out_fees_external) = asset_config::get_service_fees();
        assert!(in_fees == in_fees2, 1);
        assert!(out_fees == out_fees2, 1);
        assert!(out_fees_external == out_fees_external2, 1);
    }

    #[test(deployer = @dfmm_framework, user1 = @0x123)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_set_service_fees_unauthorized(deployer: &signer, user1: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        assert!(config::is_admin(signer::address_of(deployer)), 1); // deployer is an admin initially

        asset_config::set_service_fees(user1, 100, 200, 300);
    }


    #[test(deployer = @dfmm_framework, supra =@0x1)]
    fun test_set_fa_deposit_limit(deployer: &signer, supra: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);
        let (asset_sol, _) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");

        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), // key of the asset
            chain_id, // chain id
            9,
            test_util::bridge_address_vec());        
        asset_config::register_fa(deployer, asset_sol);// register fa

        let limit = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == 0, 1);

        let deposit_limit = 500;
        let deposit_limit_2 = 1500;
        let amount = 100;
        asset_config::set_fa_deposit_limit(deployer, asset_sol, deposit_limit);
        let limit = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == deposit_limit, 1);

        asset_config::assert_deposit_fa_limit(asset_sol, amount);
        let limit = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == deposit_limit, 1);

        asset_config::set_fa_deposit_limit(deployer, asset_sol, deposit_limit + deposit_limit_2);
        let limit  = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == deposit_limit + deposit_limit_2, 1);

        asset_config::assert_deposit_fa_limit(asset_sol, amount);
        let limit = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == deposit_limit + deposit_limit_2, 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    #[expected_failure(abort_code = 196620, location = asset_config )] // error::invalid_state(EASSET_DEPOSIT_LIMIT_EXCEEDED));
    fun test_set_fa_deposit_limit_exceeded(deployer: &signer, supra: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);
        let (asset_sol, _) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");

        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), // key of the asset
            chain_id, // chain id
            9,
            test_util::bridge_address_vec());

        asset_config::register_fa(deployer, asset_sol);// register fa

        let limit  = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == 0, 1);

        let deposit_limit = 500;
        let amount = 400;
        let amount_2 = 150;
        asset_config::set_fa_deposit_limit(deployer, asset_sol, deposit_limit);
        let limit = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == deposit_limit, 1);

        asset_config::assert_deposit_fa_limit(asset_sol, amount); // assert is ok, track
        let limit  = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == deposit_limit, 1);

        asset_config::assert_deposit_fa_limit(asset_sol, amount + amount_2); // limit exceeded

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }    

    #[test(deployer = @dfmm_framework,  user1 = @0x123, supra = @0x1)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_set_fa_deposit_limit_unauthorized(deployer: &signer, user1: &signer, supra :&signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);
        let (asset_sol, _) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");

        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), // key of the asset
            chain_id, // chain id
            9,
            test_util::bridge_address_vec());

        asset_config::register_fa(deployer, asset_sol);// register fa
        let limit  = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == 0, 1);

        let deposit_limit = 500;
        asset_config::set_fa_deposit_limit(user1, asset_sol, deposit_limit);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra=@0x1)]
    fun test_set_register_fa(deployer: &signer, supra: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, _) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let (asset_eth, _) = test_util::create_dummy_fa(deployer, b"ETH", b"ETH");

        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), // key of the asset
            chain_id, // chain id
            9,
            test_util::bridge_address_vec());

        poel::create_new_iasset(deployer, b"iETH", b"iETH", 10, 
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/ethereum.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_eth), // key of the asset
            chain_id, // chain id
            9,
            test_util::bridge_address_vec());
        
        asset_config::register_fa(deployer, asset_sol);
        assert!(asset_config::is_fa_supported(asset_sol), 1);

        assert!(!asset_config::is_fa_supported(asset_eth), 1);
        
        asset_config::register_fa(deployer, asset_eth);
        assert!(asset_config::is_fa_supported(asset_eth), 1);

        asset_config::deregister_fa(deployer, asset_sol);
        assert!(!asset_config::is_fa_supported(asset_sol), 1);        
        
        asset_config::deregister_fa(deployer, asset_eth);
        assert!(!asset_config::is_fa_supported(asset_eth), 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra=@0x1)]
    #[expected_failure(abort_code = 196618, location = asset_config )] // invalid_state(EIASSET_NOT_SUPPORTED)
    fun test_set_register_fa_iasset_unregistered(deployer: &signer, supra: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, _) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        
        assert!(!asset_config::is_fa_supported(asset_sol), 1);
        asset_config::register_fa(deployer, asset_sol); // error

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, user1 = @0x123)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_set_register_fa_unauthorized(deployer: &signer, user1: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);

        let (asset_sol, _) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        assert!(!asset_config::is_fa_supported(asset_sol), 1);
        // not authorized
        asset_config::register_fa(user1, asset_sol);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_set_deregister_fa_unauthorized(deployer: &signer, supra: &signer, user1: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, _) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");

        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10, 
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), // key of the asset
            chain_id, // chain id
            9,
            test_util::bridge_address_vec());
        
        asset_config::register_fa(deployer, asset_sol);
        assert!(asset_config::is_fa_supported(asset_sol), 1);

        asset_config::deregister_fa(user1, asset_sol); // error

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra=@0x1)]
    fun test_assert_deposit_fa(deployer: &signer, supra: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, _) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");

        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), // key of the asset
            chain_id, // chain id
            9,
            test_util::bridge_address_vec());
        
        asset_config::register_fa(deployer, asset_sol);
        assert!(asset_config::is_fa_supported(asset_sol), 1);
        asset_config::assert_deposit_fa(asset_sol); // no errors

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra=@0x1)]
    #[expected_failure(abort_code = 196613, location = asset_config )] // invalid_state(EDEPOSIT_NOT_SUPPORTED)
    fun test_assert_deposit_fa_not_supported(deployer: &signer, supra: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, _) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");

        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10, 
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), // key of the asset
            chain_id, // chain id
            9,
            test_util::bridge_address_vec());
        
        asset_config::disable_deposit(deployer);
        asset_config::register_fa(deployer, asset_sol);
        assert!(asset_config::is_fa_supported(asset_sol), 1);
        asset_config::assert_deposit_fa(asset_sol); // error, because fa is registered, but deposit is not enabled

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }


    #[test(deployer = @dfmm_framework, supra=@0x1)]
    fun test_assert_withdraw_fa(deployer: &signer, supra: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, _) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");

        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), // key of the asset
            chain_id, // chain id
            9,
            test_util::bridge_address_vec());
        
        asset_config::register_fa(deployer, asset_sol);
        assert!(asset_config::is_fa_supported(asset_sol), 1);
        asset_config::assert_withdraw_fa(asset_sol); // no errors

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra=@0x1)]
    #[expected_failure(abort_code = 196614, location = asset_config )] // invalid_state(EWITHDRAW_NOT_SUPPORTED)
    fun test_assert_withdraw_fa_not_supported(deployer: &signer, supra: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, _) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");

        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), // key of the asset
            chain_id, // chain id
            9,
            test_util::bridge_address_vec());
        
        asset_config::disable_withdraw(deployer);
        asset_config::register_fa(deployer, asset_sol);
        assert!(asset_config::is_fa_supported(asset_sol), 1);
        asset_config::assert_withdraw_fa(asset_sol); // error, because fa is registered, but withdraw is not enabled

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

}