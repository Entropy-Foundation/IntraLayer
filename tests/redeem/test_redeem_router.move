/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
#[test_only]
module dfmm_framework::redeem_router_test  {

    use std::signer;

    use supra_framework::supra_coin::SupraCoin;

    use supra_framework::account;
    use supra_framework::coin::{Self};
    use supra_framework::primary_fungible_store;
    use supra_framework::chain_id;
    use supra_framework::reconfiguration;
    use supra_framework::supra_account;
    use supra_framework::timestamp;
    use supra_oracle::supra_oracle_storage;

    use dfmm_framework::asset_router as router;
    use dfmm_framework::redeem_router;
    use dfmm_framework::asset_config as asset_config;
    use dfmm_framework::asset_pool;
    use dfmm_framework::poel;
    use dfmm_framework::iAsset;
    use dfmm_framework::asset_util;
    use dfmm_framework::test_util;
    use dfmm_framework::config;

    const CHAIN_ID:u8 = 6;


    // This test checks the redeem_request process is not possible because it is disable on the asset level
    #[test(deployer = @dfmm_framework, supra = @0x1, supra_oracles = @supra_oracle, user1 = @0x2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a)]
    #[expected_failure(abort_code = 196617, location = iAsset )] // error::permission_denied(ENOT_REDEEMABLE));
    fun test_poel_redeem_request_disabled(deployer: &signer, supra: &signer, supra_oracles: &signer, user1: &signer) {
        test_util::init_root_config(deployer); // set cycle length
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        supra_oracle_storage::init_module_for_test(supra_oracles);
        supra_oracle_storage::set_price(1, 500_000_000, 18);
        supra_oracle_storage::set_price(500, 100_000_000, 18);

        // create fa
        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        // register iasset
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 8, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_to_redeem1 = 1000;
        let user1_address = signer::address_of(user1);

        // mint fa
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        // register fa as supported asset
        asset_config::register_fa(deployer, asset_sol);
        // deposit
        router::deposit_fa(user1, asset_sol, amount_deposit1); // reposit funds, borrow_request is triggered
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount - amount_deposit1, 1);

        timestamp::fast_forward_seconds(delta); // change epoch to mint
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);
        // take iasset reference
        let iasset = iAsset::get_iasset_metadata(asset_util::get_fa_key(asset_sol), chain_id);

        poel::borrow(iasset, user1_address); // mint iasset
        assert!(primary_fungible_store::balance(user1_address, iasset) == amount_deposit1, 1); // iasset

        poel::set_redeemable(deployer, iasset, false); // disable redeem on the asset level
        poel::redeem_request(user1, iasset, amount_to_redeem1); // not allowed!!

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }


    // This test checks the redeem_request process is not possible because it is disable on the asset level
    #[test(deployer = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1, user1 = @0x2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a)]
    #[expected_failure(abort_code = 196617, location = iAsset )] // error::permission_denied(ENOT_REDEEMABLE));
    fun test_poel_redeem_iasset_disabled(deployer: &signer, supra: &signer, supra_oracles: &signer, user1: &signer) {
        test_util::init_root_config(deployer); // set cycle length
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);
        // reconfiguration::initialize_for_test(supra);

        supra_oracle_storage::init_module_for_test(supra_oracles);
        supra_oracle_storage::set_price(1, 500_000_000, 18);
        supra_oracle_storage::set_price(500, 100_000_000, 18);


        // create fa
        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        // register iasset
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 8, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_to_redeem1 = 1000;
        let user1_address = signer::address_of(user1);

         // poel::borrow_request(asset, asset_amount1, recipient_1, 0, @0x0, 0, @0x0);

        // mint fa
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);// balance in original asset

        // register fa as supported asset
        asset_config::register_fa(deployer, asset_sol);

        // deposit
        router::deposit_fa(user1, asset_sol, amount_deposit1); // reposit funds, borrow_request is triggered
        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);

        timestamp::fast_forward_seconds(delta); // change epoch to mint
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);
        // take iasset reference
        let iasset = iAsset::get_iasset_metadata(asset_util::get_fa_key(asset_sol), chain_id);

        poel::borrow(iasset, user1_address); // mint iasset

        poel::redeem_request(user1, iasset, amount_to_redeem1); // redeem request
        timestamp::fast_forward_seconds(test_util::get_cycle_length()); // move the time

        poel::set_redeemable(deployer, iasset, false); // disable redeem on the asset level
        poel::redeem_iasset(user1, iasset, x"2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a");

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    // This test checks the redeem process and ineracts only with poel module to mint, call redeem_request and redeem_iasset
    // This test uses FA as a asset for access pool
    #[test(deployer = @dfmm_framework, supra = @0x1, supra_oracles = @supra_oracle, user1 = @0x2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a)]
    fun test_poel_redeem_iasset(deployer: &signer, supra: &signer, supra_oracles: &signer, user1: &signer) {
        test_util::init_root_config(deployer); // set cycle length
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        supra_oracle_storage::init_module_for_test(supra_oracles);
        supra_oracle_storage::set_price(1, 500_000_000, 18);
        supra_oracle_storage::set_price(500, 100_000_000, 18);

        // create fa
        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        // register iasset
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 8, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_to_redeem1 = 1000;
        let user1_address = signer::address_of(user1);

        // mint fa
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);// balance in original asset

        // register fa as supported asset
        asset_config::register_fa(deployer, asset_sol);

        // deposit
        router::deposit_fa(user1, asset_sol, amount_deposit1); // reposit funds, borrow_request is triggered
        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount - amount_deposit1, 1);

        timestamp::fast_forward_seconds(delta); // change epoch to mint
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);

        // take iasset reference
        let iasset = iAsset::get_iasset_metadata(asset_util::get_fa_key(asset_sol), chain_id);

        poel::borrow(iasset, user1_address); // mint iasset
        assert!(primary_fungible_store::balance(user1_address, iasset) == amount_deposit1, 1); // iasset

        poel::redeem_request(user1, iasset, amount_to_redeem1); // redeem request
        timestamp::fast_forward_seconds(test_util::get_cycle_length()); // move the time
        iAsset::update_recent_cycle_update_epoch(3);
        poel::redeem_iasset(user1, iasset, x"2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a");

        // after redeem
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount - amount_deposit1 + amount_to_redeem1, 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    // This test checks the redeem process and ineracts with iasset module directly to mint, call redeem_request and redeem_iasset
    // This test uses FA as a asset for access pool
    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a)]
    fun test_redeem_iasset(deployer: &signer, supra: &signer, user1: &signer) {
        test_util::init_root_config(deployer); // set cycle length
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        // create fa
        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        // register iasset
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 8, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_to_redeem1 = 1000;
        let user1_address = signer::address_of(user1);

        // mint fa
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);// balance in original asset

        // register fa as supported asset
        asset_config::register_fa(deployer, asset_sol);

        // deposit
        router::deposit_fa(user1, asset_sol, amount_deposit1); // reposit funds, borrow_request is triggered
        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount - amount_deposit1, 1);

        timestamp::fast_forward_seconds(delta); // change epoch to mint
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();

        // take iasset reference
        let iasset = iAsset::get_iasset_metadata(asset_util::get_fa_key(asset_sol), chain_id);
        iAsset::mint_iasset(user1_address, iasset); // mint iasset
        assert!(primary_fungible_store::balance(user1_address, iasset) == amount_deposit1, 1); // iasset

        iAsset::redeem_request(user1, amount_to_redeem1, iasset, 0); // redeem request
        // move the time
        timestamp::fast_forward_seconds(test_util::get_cycle_length());
        iAsset::update_recent_cycle_update_epoch(3);
        let amount_redeem = iAsset::redeem_iasset(user1, iasset);
        let (origin_token_address, origin_token_chain_id, _, source_bridge_address) = iAsset::deconstruct_iasset_source(&iAsset::get_iasset_source(iasset));
        // target fa is not specified
        redeem_router::redeem_iasset(origin_token_address, origin_token_chain_id, source_bridge_address, (amount_redeem as u128), x"2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a");

        // after redeem
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount - amount_deposit1 + amount_redeem, 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a)]
    fun test_redeem_iasset_less_than_8_decimals(deployer: &signer, supra: &signer, user1: &signer) {
        test_util::init_root_config(deployer); // set cycle length
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        // create fa
        let original_decimals = 6;
        let original_decimals_multiplier = 1_000000;
        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa_custom_decimals(deployer, b"SOL", b"SOL", 
            original_decimals);
        let chain_id = (chain_id::get() as u64);
        // register iasset
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, (original_decimals as u16), test_util::bridge_address_vec());

        // take iasset reference
        let iasset = iAsset::get_iasset_metadata(asset_util::get_fa_key(asset_sol), chain_id);

        let original_asset_total_amount  = 100 *original_decimals_multiplier; // 6 decimals
        let original_amount_deposit      = 40 * original_decimals_multiplier; // 6 decimals
        let original_asset_before_redeem = 60 * original_decimals_multiplier; // 6 decimals
        let original_asset_after_redeem  = 70 * original_decimals_multiplier; // 6 decimals        

        // redeem 10 iasset
        let iasset_amount_to_redeem      = 10_00000000; // iasset 8 decimals
        // minted 40 iasset
        let iasset_amount_deposit        = 40_00000000; // iasset 8 decimals

        let user1_address = signer::address_of(user1);

        // mint fa
        primary_fungible_store::mint(&mint_sol_cap, user1_address, original_asset_total_amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == original_asset_total_amount, 1);// balance in original asset

        // register fa as supported asset
        asset_config::register_fa(deployer, asset_sol);

        // deposit
        router::deposit_fa(user1, asset_sol, original_amount_deposit); // reposit funds, borrow_request is triggered
        let (fa_balance, pool_deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == original_amount_deposit, 1);
        assert!(pool_deposited == (original_amount_deposit as u128), 1);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == original_asset_total_amount - original_amount_deposit, 1);

        let (_, preminted_user, _, _) = iAsset::deconstruct_asset_premint(&iAsset::get_preminted_per_asset(user1_address, iasset));
        assert!(preminted_user == iasset_amount_deposit, 1);

        timestamp::fast_forward_seconds(delta); // change epoch to mint
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();

        iAsset::mint_iasset(user1_address, iasset); // mint iasset

        let iasset_supply  = iAsset::get_iasset_supply(iasset);
        assert!(iasset_supply == iasset_amount_deposit, 1);
        assert!(primary_fungible_store::balance(user1_address, iasset) == iasset_amount_deposit, 1); // iasset

        iAsset::redeem_request(user1, iasset_amount_to_redeem, iasset, 0); // redeem request 10 iasset
        // move the time
        timestamp::fast_forward_seconds(test_util::get_cycle_length());
        iAsset::update_recent_cycle_update_epoch(3);
        
        assert!(original_asset_before_redeem == primary_fungible_store::balance(user1_address, asset_sol), 1);
        
        poel::redeem_iasset(user1, iasset, x"2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a");

        // after redeem
        assert!(original_asset_after_redeem == primary_fungible_store::balance(user1_address, asset_sol), 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a)]
    fun test_redeem_iasset_greather_than_8_decimals(deployer: &signer, supra: &signer, user1: &signer) {
        test_util::init_root_config(deployer); // set cycle length
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        // create fa
        let original_decimals = 18;
        let original_decimals_multiplier = 1_000_000_000_000_000_000;
        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa_custom_decimals(deployer, b"SOL", b"SOL", 
            original_decimals);
        let chain_id = (chain_id::get() as u64);
        // register iasset
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, (original_decimals as u16), test_util::bridge_address_vec());

        // take iasset reference
        let iasset = iAsset::get_iasset_metadata(asset_util::get_fa_key(asset_sol), chain_id);

        let original_asset_total_amount  = 10 * original_decimals_multiplier; // 18 decimals
        let original_amount_deposit      = 4 * original_decimals_multiplier; // 18 decimals
        let original_asset_before_redeem = 6 * original_decimals_multiplier; // 18 decimals
        let original_asset_after_redeem  = 7 * original_decimals_multiplier; // 18 decimals        

        // redeem 1 iasset
        let iasset_amount_to_redeem      = 1_00000000; // iasset 8 decimals
        // minted 4 iasset
        let iasset_amount_deposit        = 4_00000000; // iasset 8 decimals

        let user1_address = signer::address_of(user1);

        // mint fa
        primary_fungible_store::mint(&mint_sol_cap, user1_address, original_asset_total_amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == original_asset_total_amount, 1);// balance in original asset

        // register fa as supported asset
        asset_config::register_fa(deployer, asset_sol);

        // deposit
        router::deposit_fa(user1, asset_sol, original_amount_deposit); // reposit funds, borrow_request is triggered
        let (fa_balance, pool_deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == original_amount_deposit, 1);
        assert!(pool_deposited == (original_amount_deposit as u128), 1);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == original_asset_total_amount - original_amount_deposit, 1);

        let (_, preminted_user, _, _) = iAsset::deconstruct_asset_premint(&iAsset::get_preminted_per_asset(user1_address, iasset));
        assert!(preminted_user == iasset_amount_deposit, 1);

        timestamp::fast_forward_seconds(delta); // change epoch to mint
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();

        iAsset::mint_iasset(user1_address, iasset); // mint iasset

        let iasset_supply  = iAsset::get_iasset_supply(iasset);
        assert!(iasset_supply == iasset_amount_deposit, 1);
        assert!(primary_fungible_store::balance(user1_address, iasset) == iasset_amount_deposit, 1); // iasset

        iAsset::redeem_request(user1, iasset_amount_to_redeem, iasset, 0); // redeem request 10 iasset
        // move the time
        timestamp::fast_forward_seconds(test_util::get_cycle_length());
        iAsset::update_recent_cycle_update_epoch(3);
        
        assert!(original_asset_before_redeem == primary_fungible_store::balance(user1_address, asset_sol), 1);
        
        poel::redeem_iasset(user1, iasset, x"2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a");

        // after redeem
        assert!(original_asset_after_redeem == primary_fungible_store::balance(user1_address, asset_sol), 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }    

    // This test checks the redeem process and ineracts with iasset module directly to mint, call redeem_request and redeem_iasset
    // This test uses FA as a asset for access pool
    // Negative test, it checks the absense of funds to redeem
    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a)]
    #[expected_failure(abort_code = 196614, location = iAsset )] // error::invalid_state(EREDEEM_AMOUNT)
    fun test_none_redeem_iasset(deployer: &signer, supra: &signer, user1: &signer) {
        test_util::init_root_config(deployer); // set cycle length
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        // create fa
        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        // register iasset
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 8, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let user1_address = signer::address_of(user1);

        // mint fa
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);// balance in original asset

        // register fa as supported asset
        asset_config::register_fa(deployer, asset_sol);

        // deposit
        router::deposit_fa(user1, asset_sol, amount_deposit1); // reposit funds, borrow_request is triggered
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount - amount_deposit1, 1);

        timestamp::fast_forward_seconds(delta); // change epoch to mint
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();

        // take iasset reference
        let iasset = iAsset::get_iasset_metadata(asset_util::get_fa_key(asset_sol), chain_id);
        iAsset::mint_iasset(user1_address, iasset); // mint iasset
        assert!(primary_fungible_store::balance(user1_address, iasset) == amount_deposit1, 1); // iasset

        let amount_redeem = iAsset::redeem_iasset(user1, iasset); // no redeem_rquest before
        let (origin_token_address, origin_token_chain_id, _, source_bridge_address) = iAsset::deconstruct_iasset_source(&iAsset::get_iasset_source(iasset));
        redeem_router::redeem_iasset(origin_token_address, origin_token_chain_id, source_bridge_address, (amount_redeem as u128), x"2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a");

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

     // Negative test to check attempt to trigger external redeem process
    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a)]
    #[expected_failure(abort_code = 196621, location = redeem_router )]
    fun test_redeem_iasset_not_supported(deployer: &signer, supra: &signer, user1: &signer) {
        test_util::init_root_config(deployer); // set cycle length
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);
        let chain_id = (chain_id::get() as u64);

        // create fa
        let (asset_eth, mint_eth_cap) = test_util::create_dummy_fa(deployer, b"ETH", b"ETH");
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_eth), chain_id, 8, test_util::bridge_address_vec());

        // coin
        poel::create_new_iasset(deployer, b"isupra", b"isupra", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/supra.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_supra_coin_key(), chain_id, 8, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_to_redeem1 = 1000;
        let user1_address = signer::address_of(user1);

        // register fa and deposit fa
        primary_fungible_store::mint(&mint_eth_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_eth) == amount, 1);// balance in original asset
        asset_config::register_fa(deployer, asset_eth);
        router::deposit_fa(user1, asset_eth, amount_deposit1); // reposit funds, borrow_request is triggered
        assert!(primary_fungible_store::balance(user1_address, asset_eth) == amount - amount_deposit1, 1);

        timestamp::fast_forward_seconds(delta); // change epoch to mint
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();

        // take iasset reference
        let iasset = iAsset::get_iasset_metadata(asset_util::get_fa_key(asset_eth), chain_id);
        iAsset::mint_iasset(user1_address, iasset); // mint iasset
        assert!(primary_fungible_store::balance(user1_address, iasset) == amount_deposit1, 1); // iasset

        iAsset::redeem_request(user1, amount_to_redeem1, iasset, 0); // redeem request
        // move the time
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        iAsset::update_recent_cycle_update_epoch(3);

        let amount_redeem = iAsset::redeem_iasset(user1, iasset);
        let (_, _, _, source_bridge_address) = iAsset::deconstruct_iasset_source(&iAsset::get_iasset_source(iasset));
        // specify wrong target address, so it is an attempt to call hypernova in the future which is not supported yet
        redeem_router::redeem_iasset(x"e2794e1139f10c", 11155111, source_bridge_address, (amount_redeem as u128), x"2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a");

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

     // Negative test to direct access to redeem_router and condition if not enough funds in the pool
    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a)]
    #[expected_failure(abort_code = 196620, location = redeem_router )]
    fun test_redeem_iasset_not_enough(deployer: &signer, supra: &signer, user1: &signer) {
        test_util::init_root_config(deployer); // set cycle length
        asset_config::init_for_test(deployer);
        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);
        let chain_id = (chain_id::get() as u64);

        // create fa
        let (asset_eth, mint_eth_cap) = test_util::create_dummy_fa(deployer, b"ETH", b"ETH");
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_eth), chain_id, 8, test_util::bridge_address_vec());

        let amount = 10000;
        let amount_deposit1 = 3000;
        let amount_to_redeem1 = 4000;
        let user1_address = signer::address_of(user1);

        // register fa and deposit fa
        primary_fungible_store::mint(&mint_eth_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_eth) == amount, 1);// balance in original asset
        asset_config::register_fa(deployer, asset_eth);
        router::deposit_fa(user1, asset_eth, amount_deposit1); // reposit funds, borrow_request is triggered
        assert!(primary_fungible_store::balance(user1_address, asset_eth) == amount - amount_deposit1, 1);

        // redeem amount is too big
        redeem_router::redeem_iasset(asset_util::get_fa_key(asset_eth), chain_id, test_util::bridge_address_vec(), (amount_to_redeem1 as u128), x"2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a");

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    // This test checks the redeem process and ineracts with iasset module directly to mint, call redeem_request and redeem_iasset
    // This test uses FA as a asset for access pool
    #[test(deployer = @dfmm_framework, supra = @0x1,
        fees_receiver = @0x46541ee138920e00595c0af4aa04f1e248d22af6c6e90e834b13b04ce9b55cec,
        user1 = @0x2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a,
        supra_oracles = @supra_oracle)]
    fun test_redeem_iasset_with_fees(deployer: &signer, supra: &signer,
        fees_receiver: &signer, user1: &signer, supra_oracles: &signer) {

        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        supra_oracle_storage::init_module_for_test(supra_oracles);
        let supra_price: u128 = 5000000000000000;
        let asset_price: u128 = 150000000000000000000;
        supra_oracle_storage::set_price(10, (asset_price as u128), 18);
        supra_oracle_storage::set_price(500, (supra_price as u128), 18); // supra

        let fees_recipient = signer::address_of(fees_receiver);
        test_util::init_root_config(deployer); // set cycle length
        asset_config::init_for_test(deployer);
        config::set_service_fees_address(deployer, fees_recipient);

        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);

        // create fa
        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        // register iasset
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 8, test_util::bridge_address_vec());

        let amount = 10_00000000; // 10 SOl
        let amount_deposit1 = 8_00000000; // 8 SOL
        let amount_to_redeem1 = 5_00000000; // 5 SOL
        let user1_address = signer::address_of(user1);
        let fees_supra = 50_00000000; // 50 supra
        let expected_burned_iassets = 4_99833334;
        let expected_fee_in_iasset = 166666;

        // mint fa
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);// balance in original asset

        // register fa as supported asset
        asset_config::register_fa(deployer, asset_sol);

        // deposit
        router::deposit_fa(user1, asset_sol, amount_deposit1); // reposit funds, borrow_request is triggered
        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount - amount_deposit1, 1);

        timestamp::fast_forward_seconds(delta); // change epoch to mint
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();

        // take iasset reference
        let iasset = iAsset::get_iasset_metadata(asset_util::get_fa_key(asset_sol), chain_id);
        iAsset::mint_iasset(user1_address, iasset); // mint iasset
        assert!(primary_fungible_store::balance(user1_address, iasset) == amount_deposit1, 1); // iasset

        asset_config::set_service_fees(deployer, 0, fees_supra, 0); // only supra out fees
        let (in_fees, out_fees, out_fees_external) = asset_config::get_service_fees();
        assert!(in_fees == 0, 1);
        assert!(out_fees == fees_supra, 1);
        assert!(out_fees_external == 0, 1);

        poel::redeem_request(user1, iasset, amount_to_redeem1); // redeem request
        //iAsset::redeem_request(user1, amount_to_redeem1, iasset, fees_in_supra); // redeem request
        assert!(primary_fungible_store::balance(fees_recipient, iasset) == expected_fee_in_iasset, 1); // admin receives the portion of iasset

        // move the time
        timestamp::fast_forward_seconds(test_util::get_cycle_length());
        iAsset::update_recent_cycle_update_epoch(4);
        let amount_redeem = iAsset::redeem_iasset(user1, iasset);
        assert!(amount_redeem == expected_burned_iassets, 1); // redeem is less than requested

        let (origin_token_address, origin_token_chain_id, _, source_bridge_address) = iAsset::deconstruct_iasset_source(&iAsset::get_iasset_source(iasset));
        redeem_router::redeem_iasset(origin_token_address, origin_token_chain_id, source_bridge_address, (amount_redeem as u128), x"2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a");

        // after redeem
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount - amount_deposit1 + amount_redeem, 1);
        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    // This megative test to check the error if requested amount is less than fees
    #[test(deployer = @dfmm_framework, supra = @0x1,
        fees_receiver = @0x46541ee138920e00595c0af4aa04f1e248d22af6c6e90e834b13b04ce9b55cec,
        user1 = @0x2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a,
        supra_oracles = @supra_oracle)]
    #[expected_failure(abort_code = 196629, location = iAsset )]//ECANT_COVER_FEES
    fun test_redeem_iasset_with_fees_not_enough(deployer: &signer, supra: &signer,
        fees_receiver: &signer, user1: &signer, supra_oracles: &signer) {

        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        supra_oracle_storage::init_module_for_test(supra_oracles);
        let supra_price: u128 = 5000000000000000;
        let asset_price: u128 = 150000000000000000000;
        supra_oracle_storage::set_price(10, (asset_price as u128), 18);
        supra_oracle_storage::set_price(500, (supra_price as u128), 18); // supra

        let fees_recipient = signer::address_of(fees_receiver);
        test_util::init_root_config(deployer); // set cycle length
        asset_config::init_for_test(deployer);
        config::set_service_fees_address(deployer, fees_recipient);

        let (s_burn_cap, s_mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset, router
        chain_id::initialize_for_test(supra, CHAIN_ID);

        // create fa
        let (asset_sol, mint_sol_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let chain_id = (chain_id::get() as u64);
        // register iasset
        poel::create_new_iasset(deployer, b"iSOL", b"iSOL", 10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            asset_util::get_fa_key(asset_sol), chain_id, 8, test_util::bridge_address_vec());

        let amount = 10_00000000; // 10 SOl
        let amount_deposit1 = 8_00000000; // 8 SOL
        let amount_to_redeem1 = 1000000; // 0.01 SOL
        let user1_address = signer::address_of(user1);
        let fees_supra = 500_00000000; // 500 supra

        // mint fa
        primary_fungible_store::mint(&mint_sol_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount, 1);// balance in original asset

        // register fa as supported asset
        asset_config::register_fa(deployer, asset_sol);

        // deposit
        router::deposit_fa(user1, asset_sol, amount_deposit1); // reposit funds, borrow_request is triggered
        let (fa_balance, deposited, _) = asset_pool::get_fa_pool_details(asset_sol);
        assert!(fa_balance == amount_deposit1, 1);
        assert!(deposited == (amount_deposit1 as u128), 1);
        assert!(primary_fungible_store::balance(user1_address, asset_sol) == amount - amount_deposit1, 1);

        timestamp::fast_forward_seconds(delta); // change epoch to mint
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();

        // take iasset reference
        let iasset = iAsset::get_iasset_metadata(asset_util::get_fa_key(asset_sol), chain_id);
        iAsset::mint_iasset(user1_address, iasset); // mint iasset
        assert!(primary_fungible_store::balance(user1_address, iasset) == amount_deposit1, 1); // iasset

        // iasset 1000000, fees in iasset  = 1666666
        iAsset::redeem_request(user1, amount_to_redeem1, iasset, fees_supra); // redeem request, error expected

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

}