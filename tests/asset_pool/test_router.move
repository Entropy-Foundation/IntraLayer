/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
#[test_only]
module dfmm_framework::asset_router_test  {

    use std::signer;

    use supra_framework::account;
    use supra_framework::coin::{Self};
    use supra_framework::primary_fungible_store;
    use supra_framework::chain_id;
    use supra_framework::timestamp;

    use dfmm_framework::asset_router as router;
    use dfmm_framework::config;
    use dfmm_framework::asset_config;
    use dfmm_framework::asset_pool;
    use dfmm_framework::poel;
    use dfmm_framework::asset_util;
    use dfmm_framework::test_util;
    use dfmm_framework::iAsset;
    use supra_oracle::supra_oracle_storage;

    const CHAIN_ID:u8 = 6;

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123)]
    fun test_deposit_fa(deployer: &signer, supra: &signer, user1: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10, 
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 9, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_deposit2 = 1000;
        let user1_address = signer::address_of(user1);
        
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);

        asset_config::register_fa(deployer, asset_sol);
        assert!(asset_config::is_fa_supported(asset_sol), 1);

        asset_config::set_fa_deposit_limit(deployer, asset_sol, amount_deposit1 + amount_deposit2); // apply a limit
        let limit = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == amount_deposit1 + amount_deposit2, 1);        

        router::deposit_fa(user1, asset_sol, amount_deposit1);
        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        let limit  = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == amount_deposit1 + amount_deposit2, 1);

        router::deposit_fa(user1, asset_sol, amount_deposit2); // again

        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        let pool_details = router::get_fa_pool_details(asset_sol);
        let (r_balance, r_deposited, _, r_limit) = router::deconstruct_fa_pool_details(&pool_details);
        assert!(r_balance == fa_balance, 1);
        assert!(r_deposited == ((amount_deposit1 + amount_deposit2) as u128), 1);
        assert!(r_limit == limit, 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123,
        supra_oracles = @supra_oracle)]
    fun test_deposit_fa_with_fees(deployer: &signer, supra: &signer, user1: &signer, supra_oracles: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        supra_oracle_storage::init_module_for_test(supra_oracles);
        let supra_price: u128 = 5000000000000000; // 0.005
        let asset_price: u128 = 150_000000000000000000; // 150 usd
        supra_oracle_storage::set_price(10, (asset_price as u128), 18); // sol
        supra_oracle_storage::set_price(500, (supra_price as u128), 18); // supra        

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        let sol_decimals = 9;
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10, 
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, sol_decimals, test_util::bridge_address_vec());
        let iasset = iAsset::get_iasset_metadata(asset_util::get_fa_key(asset_sol), chain_id); // take iasset

        let amount = 20_000_000_000;
        let amount_deposit1 = 3_000_000_000; // 3 sol, 9 decimals
        let amount_deposit2 = 1_000_000_000;  // 1 sol, 9 decimals
        let user1_address = signer::address_of(user1);
        let in_supra_fees = 50_00000000; // 50 supra
        let expected_asset_service_fee = 166666;
        
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);

        asset_config::set_service_fees(deployer, in_supra_fees, 0, 0);
        let (in_fees, _, _) = asset_config::get_service_fees();
        assert!(in_fees == in_supra_fees, 1);

        asset_config::register_fa(deployer, asset_sol);
        assert!(asset_config::is_fa_supported(asset_sol), 1);

        // 1st deposit
        router::deposit_fa(user1, asset_sol, amount_deposit1);
        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);

        let items =  iAsset::get_liquidity_table_items(iasset);
        let (_,_,_,_,_,_,preminted,_,deposited) = iAsset::deconstruct_liquidity_table_items(&items);
        let (_, preminted_user, _, _) = iAsset::deconstruct_asset_premint(&iAsset::get_preminted_per_asset(user1_address, iasset));
        let (_, preminted_service, _, _) = iAsset::deconstruct_asset_premint(&iAsset::get_preminted_per_asset(config::get_service_fees_address(), iasset));

        let scaled_amount_deposit1 =  (asset_util::scale((amount_deposit1 as u128), sol_decimals, 8) as u64);
        assert!(preminted == scaled_amount_deposit1 && deposited == preminted, 1);
        assert!(preminted_user == (scaled_amount_deposit1 - expected_asset_service_fee), 1);
        assert!(preminted_service == expected_asset_service_fee, 1);

        router::deposit_fa(user1, asset_sol, amount_deposit2); // again

        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        let pool_details = router::get_fa_pool_details(asset_sol);
        let (r_balance, r_deposited, _, _) = router::deconstruct_fa_pool_details(&pool_details);
        assert!(r_balance == fa_balance, 1);
        assert!(r_deposited == ((amount_deposit1 + amount_deposit2) as u128), 1);

        let items =  iAsset::get_liquidity_table_items(iasset);
        let (_,_,_,_,_,_,preminted,_,deposited) = iAsset::deconstruct_liquidity_table_items(&items);
        let (_, preminted_user, _, _) = iAsset::deconstruct_asset_premint(&iAsset::get_preminted_per_asset(user1_address, iasset));
        let (_, preminted_service, _, _) = iAsset::deconstruct_asset_premint(&iAsset::get_preminted_per_asset(config::get_service_fees_address(), iasset));

        let scaled_amount_deposit2 =  (asset_util::scale((amount_deposit2 as u128), sol_decimals, 8) as u64);
        assert!(preminted == scaled_amount_deposit1 + scaled_amount_deposit2 && deposited == preminted, 1);
        assert!(preminted_user == (scaled_amount_deposit1 + scaled_amount_deposit2 - 2*expected_asset_service_fee), 1);
        assert!(preminted_service == 2* expected_asset_service_fee, 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123)]
    fun test_deposit_fa_without_limit(deployer: &signer, supra: &signer, user1: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 9, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_deposit2 = 5000;
        let user1_address = signer::address_of(user1);
        
        let limit = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == 0, 1);

        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);

        asset_config::register_fa(deployer, asset_sol);

        router::deposit_fa(user1, asset_sol, amount_deposit1);
        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        let limit  = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == 0, 1);

        router::deposit_fa(user1, asset_sol, amount_deposit2); // again

        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        let pool_details = router::get_fa_pool_details(asset_sol);
        let (r_balance, r_deposited, _, r_limit) = router::deconstruct_fa_pool_details(&pool_details);
        assert!(r_balance == fa_balance, 1);
        assert!(r_deposited == ((amount_deposit1 + amount_deposit2) as u128), 1);
        assert!(r_limit == 0, 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }    

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123)]
    #[expected_failure(abort_code = 196620, location = asset_config )] // error::invalid_state(EASSET_DEPOSIT_LIMIT_EXCEEDED));
    fun test_deposit_fa_limit_exceeded(deployer: &signer, supra: &signer, user1: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10, 
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 9, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_deposit2 = 1000;
        let user1_address = signer::address_of(user1);

        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);

        asset_config::register_fa(deployer, asset_sol);
        assert!(asset_config::is_fa_supported(asset_sol), 1);

        asset_config::set_fa_deposit_limit(deployer, asset_sol, amount_deposit1); // apply a limit
        let limit  = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == amount_deposit1, 1);        

        router::deposit_fa(user1, asset_sol, amount_deposit1);
        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        let limit  = asset_config::get_fa_deposit_limit(asset_sol);
        assert!(limit == amount_deposit1, 1);

        router::deposit_fa(user1, asset_sol, amount_deposit2); // again, but limit is exceeded

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }    

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123)]
    #[expected_failure(abort_code = 196611, location = asset_config )] // error::invalid_state(EASSET_NOT_SUPPORTED)
    fun test_deposit_fa_not_supported(deployer: &signer, supra: &signer, user1: &signer) {
        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset        

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");

        let amount = 10000;
        let amount_deposit1 = 3000;
        let user1_address = signer::address_of(user1);
        
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);

        assert!(!asset_config::is_fa_supported(asset_sol), 1); // not registered
        router::deposit_fa(user1, asset_sol, amount_deposit1); // error

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123, user2 = @0x2345)]
    fun test_admin_withdraw_request_fa(deployer: &signer, supra: &signer, user1: &signer, user2: &signer) {
        config::init_for_test(deployer);
        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 9, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_withdraw = 1000;
        let user1_address = signer::address_of(user1);
        let user2_address = signer::address_of(user2);
        
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);

        asset_config::register_fa(deployer, asset_sol);
        assert!(asset_config::is_fa_supported(asset_sol), 1);

        router::deposit_fa(user1, asset_sol, amount_deposit1);
        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);

        router::admin_withdraw_request_fa(deployer, asset_sol, amount_withdraw, user1_address); 
        let (fa_balance, deposited, withdrawn) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        assert!(withdrawn == 0, 1);

        let (requested, ts, destination) = router::deconstruct_withdraw_request(&router::get_admin_withdraw_request(asset_sol));
        assert!(requested == amount_withdraw, 1);
        assert!(ts == time0, 1);
        assert!(destination == user1_address, 1);

        // again, user2
        let delta = 100;
        timestamp::fast_forward_seconds(delta); // forward time
        router::admin_withdraw_request_fa(deployer, asset_sol, amount_withdraw, user2_address); 
        let (fa_balance, deposited, withdrawn) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        assert!(withdrawn == 0, 1);

        let (requested, ts, destination) =  router::deconstruct_withdraw_request(&router::get_admin_withdraw_request(asset_sol));
        assert!(requested == amount_withdraw * 2, 1);
        assert!(ts == time0  + delta, 1);
        assert!(destination == user2_address, 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_admin_withdraw_request_fa_unauthorized(deployer: &signer, supra: &signer, user1: &signer) {
        config::init_for_test(deployer);
        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 9, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_withdraw = 1000;
        let user1_address = signer::address_of(user1);
        
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        asset_config::register_fa(deployer, asset_sol);
        router::deposit_fa(user1, asset_sol, amount_deposit1);

        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);

        router::admin_withdraw_request_fa(user1, asset_sol, amount_withdraw, user1_address); // error is expected
        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123)]
    #[expected_failure(abort_code = 196609, location = router )] // EPOOL_INSUFFICIENT_FUNDS
    fun test_admin_withdraw_request_fa_not_enough(deployer: &signer, supra: &signer, user1: &signer) {
        config::init_for_test(deployer);
        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 9, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_withdraw = 6000;
        let user1_address = signer::address_of(user1);
        
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        asset_config::register_fa(deployer, asset_sol);
        router::deposit_fa(user1, asset_sol, amount_deposit1);
        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);

        router::admin_withdraw_request_fa(deployer, asset_sol, amount_withdraw, user1_address); // error is expected
        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123, user2 = @0x123456)]
    fun test_admin_withdraw_fa(deployer: &signer, supra: &signer, user1: &signer, user2: &signer) {
        config::init_for_test(deployer);
        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 9, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_withdraw = 1000;
        let user1_address = signer::address_of(user1);
        
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);

        asset_config::register_fa(deployer, asset_sol);
        assert!(asset_config::is_fa_supported(asset_sol), 1);

        router::deposit_fa(user1, asset_sol, amount_deposit1);
        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);

        let user2_address = signer::address_of(user2);
        router::admin_withdraw_request_fa(deployer, asset_sol, amount_withdraw, user2_address); 
        let (fa_balance, deposited, withdrawn) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        assert!(withdrawn == 0, 1);

        let (requested, ts, destination) =  router::deconstruct_withdraw_request(&router::get_admin_withdraw_request(asset_sol));
        assert!(requested == amount_withdraw, 1);
        assert!(ts == time0, 1);
        assert!(destination == user2_address, 1);

        timestamp::fast_forward_seconds(asset_config::get_withdraw_delay()); // forward time

        router::admin_withdraw_fa(deployer, asset_sol); 
        let (fa_balance, deposited, withdrawn) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1 - amount_withdraw, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        assert!(withdrawn == (amount_withdraw as u128), 1);        
        assert!(primary_fungible_store::balance(user2_address, asset_sol) == amount_withdraw, 1);

        let (requested, ts, destination) =  router::deconstruct_withdraw_request(&router::get_admin_withdraw_request(asset_sol));
        assert!(requested == 0, 1);
        assert!(ts == 0, 1);
        assert!(destination == @0x0, 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123, user2 = @0x123456)]
    #[expected_failure(abort_code = 196610, location = router )] // EWITHDRAW_REQ_MISSED
    fun test_admin_withdraw_fa_already_removed(deployer: &signer, supra: &signer, user1: &signer, user2: &signer) {
        config::init_for_test(deployer);
        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 9, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_withdraw = 1000;
        let user1_address = signer::address_of(user1);
        
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);

        asset_config::register_fa(deployer, asset_sol);
        assert!(asset_config::is_fa_supported(asset_sol), 1);

        router::deposit_fa(user1, asset_sol, amount_deposit1);
        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);

        let user2_address = signer::address_of(user2);
        router::admin_withdraw_request_fa(deployer, asset_sol, amount_withdraw, user2_address); 
        let (fa_balance, deposited, withdrawn) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        assert!(withdrawn == 0, 1);

        let (requested, ts, destination) =  router::deconstruct_withdraw_request(&router::get_admin_withdraw_request(asset_sol));
        assert!(requested == amount_withdraw, 1);
        assert!(ts == time0, 1);
        assert!(destination == user2_address, 1);

        timestamp::fast_forward_seconds(asset_config::get_withdraw_delay()); // forward time

        // remove before withdarw execution
        router::admin_remove_withdraw_fa(deployer, asset_sol); 
        router::admin_withdraw_fa(deployer, asset_sol); // error expected

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123, user2 = @0x123456)]
    fun test_admin_remove_withdraw_fa(deployer: &signer, supra: &signer, user1: &signer, user2: &signer) {
        config::init_for_test(deployer);
        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 9, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_withdraw = 1000;
        let user1_address = signer::address_of(user1);
        
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        asset_config::register_fa(deployer, asset_sol);
        router::deposit_fa(user1, asset_sol, amount_deposit1);

        let user2_address = signer::address_of(user2);
        router::admin_withdraw_request_fa(deployer, asset_sol, amount_withdraw, user2_address); 
        let (fa_balance, deposited, withdrawn) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        assert!(withdrawn == 0, 1);

        let (requested, ts, destination) =  router::deconstruct_withdraw_request(&router::get_admin_withdraw_request(asset_sol));
        assert!(requested == amount_withdraw, 1);
        assert!(ts == time0, 1);
        assert!(destination == user2_address, 1);

        timestamp::fast_forward_seconds(asset_config::get_withdraw_delay() - 100); // forward time

        router::admin_remove_withdraw_fa(deployer, asset_sol);
        let (requested, ts, destination) =  router::deconstruct_withdraw_request(&router::get_admin_withdraw_request(asset_sol));
        assert!(requested == 0, 1);
        assert!(ts == 0, 1);
        assert!(destination == @0x0, 1);        

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123, user2 = @0x123456)]
    #[expected_failure(abort_code = 196610, location = router )] // EWITHDRAW_REQ_MISSED
    fun test_admin_remove_withdraw_fa_empty(deployer: &signer, supra: &signer, user1: &signer, user2: &signer) {
        config::init_for_test(deployer);
        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 9, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_withdraw = 1000;
        let user1_address = signer::address_of(user1);
        
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        asset_config::register_fa(deployer, asset_sol);
        router::deposit_fa(user1, asset_sol, amount_deposit1);

        let (requested, ts, destination) =  router::deconstruct_withdraw_request(&router::get_admin_withdraw_request(asset_sol));
        assert!(requested == 0, 1);
        assert!(ts == 0, 1);
        assert!(destination == @0x0, 1);

        router::admin_remove_withdraw_fa(deployer, asset_sol); // error

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123, user2 = @0x123456)]
    #[expected_failure(abort_code = 196611, location = router )] // ENOT_ENOUGH_TIME_PASSED
    fun test_admin_withdraw_fa_not_enough_time(deployer: &signer, supra: &signer, user1: &signer, user2: &signer) {
        config::init_for_test(deployer);
        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 9, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_withdraw = 1000;
        let user1_address = signer::address_of(user1);
        
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        asset_config::register_fa(deployer, asset_sol);
        router::deposit_fa(user1, asset_sol, amount_deposit1);

        let user2_address = signer::address_of(user2);
        router::admin_withdraw_request_fa(deployer, asset_sol, amount_withdraw, user2_address); 
        let (fa_balance, deposited, withdrawn) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        assert!(withdrawn == 0, 1);

        let (requested, ts, destination) =  router::deconstruct_withdraw_request(&router::get_admin_withdraw_request(asset_sol));
        assert!(requested == amount_withdraw, 1);
        assert!(ts == time0, 1);
        assert!(destination == user2_address, 1);

        timestamp::fast_forward_seconds(asset_config::get_withdraw_delay() - 100); // forward time

        router::admin_withdraw_fa(deployer, asset_sol); 

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123, user2 = @0x123456)]
    #[expected_failure(abort_code = 196610, location = router )]//EWITHDRAW_REQ_MISSED
    fun test_admin_withdraw_fa_req_missed_1(deployer: &signer, supra: &signer, user1: &signer, user2: &signer) {
        config::init_for_test(deployer);
        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 9, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_withdraw = 1000;
        let user1_address = signer::address_of(user1);
        
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        asset_config::register_fa(deployer, asset_sol);
        router::deposit_fa(user1, asset_sol, amount_deposit1);

        let user2_address = signer::address_of(user2);
        router::admin_withdraw_request_fa(deployer, asset_sol, amount_withdraw, user2_address); 
        let (fa_balance, deposited, withdrawn) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        assert!(withdrawn == 0, 1);

        let (requested, ts, destination) =  router::deconstruct_withdraw_request(&router::get_admin_withdraw_request(asset_sol));
        assert!(requested == amount_withdraw, 1);
        assert!(ts == time0, 1);
        assert!(destination == user2_address, 1);

        timestamp::fast_forward_seconds(asset_config::get_withdraw_delay()); // forward time

        router::admin_withdraw_fa(deployer, asset_sol); 
        assert!(primary_fungible_store::balance(user2_address, asset_sol) == amount_withdraw, 1);

        router::admin_withdraw_fa(deployer, asset_sol); // again error        

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123)]
    #[expected_failure(abort_code = 196610, location = router )]//EWITHDRAW_REQ_MISSED
    fun test_admin_withdraw_fa_req_missed_2(deployer: &signer, supra: &signer, user1: &signer) {
        config::init_for_test(deployer);
        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 9, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_withdraw = 1000;
        let user1_address = signer::address_of(user1);
        
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        asset_config::register_fa(deployer, asset_sol);
        router::deposit_fa(user1, asset_sol, amount_deposit1);

        let (requested, ts, destination) =  router::deconstruct_withdraw_request(&router::get_admin_withdraw_request(asset_sol));
        assert!(requested == 0, 1);
        assert!(ts == 0, 1);
        assert!(destination == @0x0, 1);

        timestamp::fast_forward_seconds(asset_config::get_withdraw_delay()); // forward time

        router::admin_withdraw_fa(deployer, asset_sol);  // error

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }    

}