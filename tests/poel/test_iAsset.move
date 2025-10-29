/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
#[test_only]
module dfmm_framework::iAsset_test  {
    use dfmm_framework::iAsset;
    use dfmm_framework::iAsset::{AssetInfo, AssetPremint};
    use dfmm_framework::poel;
    use dfmm_framework::config;
    use dfmm_framework::test_util;
    use std::signer;
    use std::error;
    use supra_framework::coin;
    use supra_framework::account;
    use supra_framework::object::{Self, Object};
    use supra_framework::supra_coin;
    use supra_framework::primary_fungible_store;
    use supra_framework::timestamp;
    use std::option::{Self};
    use std::string::{Self};
    use aptos_std::fungible_asset::{Self, Metadata};
    use supra_framework::reconfiguration;
    use std::vector;
    use aptos_std::math64;

    use supra_oracle::supra_oracle_storage;

    use dfmm_framework::poel_test_helpers::{setup_env_with_users_and_assets, setup_btc_eth, setup_usdt_eth};

    const ORIGIN_TOKEN_CHAIN_ID: u64 = 1;
    const ORIGIN_TOKEN_ADDRESS: vector<u8> = x"e2794e1ef7d4ac86506a5947a1f0f342c139f10c";
    const SOURCE_TOKEN_ADDRESS: vector<u8> = x"e2794e1139f10c";
    const SOURCE_TOKEN_DECIMALS:u16 = 8;
    const DEF_DECIMALS :u8 = 8;
    const CYCLE: u64 = 48*60*1000;

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_create_iasset(
        deployer: &signer,
        supra : &signer
    ) {

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        clean_up(burn_cap, mint_cap);

        test_util::init_root_config(deployer);
        poel::init_poel_for_test(deployer);

        iAsset::init_iAsset_for_test(deployer);
        let phydy = @0xface;
        let symbol = b"iBTC";

        poel::create_new_iasset(deployer, b"BTC", symbol, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        let asset = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);
        assert!(object::owner(asset) == signer::address_of(deployer), error::invalid_state(1));

        // check that liquidity table was initialized
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, desirability_score, _, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&items);
        assert!(desirability_score == 1, 1); // desirability_score = 1 upon iasset creation

        // check that iAsset is not paused and redeemable is true
        let (paused, redeemable) = iAsset::get_asset_status(asset);
        assert!(!paused , error::invalid_state(1));
        assert!(redeemable , error::invalid_state(1));

        let liquidity_provider_address = iAsset::ensure_liquidity_provider_for_test(phydy);
        //create IassetEntry for a user
        iAsset::create_iasset_entry_for_test(phydy, asset);

        //get total liquidity object
        assert!(
          liquidity_provider_address == iAsset::get_total_liquidity_provider_table_value_for_test(phydy), error::invalid_state(4)
        );

        // check the asset_entry fields
        let (
            user_reward_index,
            preminted_iAssets,
            redeem_requested_iAssets,
            preminting_epoch_number,
            unlock_olc_index
        ) = iAsset::get_liquidity_provider_asset_entry_items_for_test(liquidity_provider_address, asset);

        // assert they were all initialized to zero
        assert!(user_reward_index == 0, error::invalid_state(1));
        assert!(preminted_iAssets == 0, error::invalid_state(1));
        assert!(redeem_requested_iAssets == 0, error::invalid_state(1));
        assert!(preminting_epoch_number == 0, error::invalid_state(1));
        assert!(unlock_olc_index == 0, error::invalid_state(1));
    }

    #[test(creator = @dfmm_framework, supra = @0x1)]
    #[expected_failure]
    fun test_create_iasset_duplicate(
        creator: &signer,
        supra : &signer
    ) {
        test_util::init_root_config(creator);
        iAsset::init_iAsset_for_test(creator);
        let symbol = b"iBTC";
        poel::create_new_iasset(supra, b"BTC", symbol, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        let asset = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);

        assert!(object::owner(asset) == signer::address_of(supra), error::invalid_state(1));
        poel::create_new_iasset(supra, b"BTC", symbol, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_create_iasset_decimals_check(deployer: &signer, supra : &signer) {
        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        clean_up(burn_cap, mint_cap);
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);

        let decimals_btc = 18;
        let asset_btc = iAsset::create_new_iasset(supra, b"BTC", b"iBTC", decimals_btc, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        assert!(fungible_asset::decimals(asset_btc) == decimals_btc, 1); // check decimals

        let sol_token_address: vector<u8> = x"e279450c";
        let sol_token_chain_id : u64 = 10;
        let decimals_sol = 9;
        let asset_sol = iAsset::create_new_iasset(supra,  b"SOL", b"iSOL", decimals_sol, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            sol_token_address, sol_token_chain_id, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        assert!(fungible_asset::decimals(asset_sol) == decimals_sol, 1); // check decimals
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_update_pair_id(deployer: &signer, supra : &signer) {
        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        clean_up(burn_cap, mint_cap);
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);

        let decimals = 6;
        let pair_id:u32 = 48;
        let asset_usdt = iAsset::create_new_iasset(supra, b"USDT", b"iUSDT", decimals, pair_id,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/usdt.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        assert!(fungible_asset::decimals(asset_usdt) == decimals, 1);

        let decimals_btc = 18;
        let pair_id_btc:u32 = 0;
        let btc_token_address: vector<u8> = x"e279450c";
        let btc_token_chain_id : u64 = 10;        
        let asset_btc = iAsset::create_new_iasset(supra, b"BTC", b"iBTC", decimals_btc, pair_id_btc,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            btc_token_address, btc_token_chain_id, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        assert!(fungible_asset::decimals(asset_btc) == decimals_btc, 1);

        let (usdt_pair_id, _, _, _, _, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&iAsset::get_liquidity_table_items(asset_usdt));
        assert!(usdt_pair_id == pair_id, 1);
        let (btc_pair_id, _, _, _, _, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&iAsset::get_liquidity_table_items(asset_btc));
        assert!(btc_pair_id == pair_id_btc, 1);        

        let usdt_pair_id_new:u32 = 999999;
        let btc_pair_id_new:u32 = 166;
        iAsset::batch_update_pair_ids(vector[asset_usdt, asset_btc], vector[usdt_pair_id_new, btc_pair_id_new]);

        let (usdt_pair_id, _, _, _, _, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&iAsset::get_liquidity_table_items(asset_usdt));
        let (btc_pair_id, _, _, _, _, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&iAsset::get_liquidity_table_items(asset_btc));
        assert!(usdt_pair_id == usdt_pair_id_new, 1);
        assert!(btc_pair_id == btc_pair_id_new, 1);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_get_iasset_metadata(deployer: &signer, supra : &signer) {

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        clean_up(burn_cap, mint_cap);
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);

        let asset_btc = iAsset::create_new_iasset(supra, b"BTC", b"iBTC", DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        assert!(object::owner(asset_btc) == signer::address_of(supra), error::invalid_state(1));
        let asset_btc_by_origin = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);
        assert!(asset_btc == asset_btc_by_origin, 1); // compare the assets

        let (token_btc, chain_btc, decimals_btc, bridge_btc) = iAsset::deconstruct_iasset_source(&iAsset::get_iasset_source(asset_btc));
        // compare origin detail stored under assetinfo
        assert!(token_btc == ORIGIN_TOKEN_ADDRESS, 1);
        assert!(chain_btc == ORIGIN_TOKEN_CHAIN_ID, 1);
        assert!(bridge_btc == SOURCE_TOKEN_ADDRESS, 1);
        assert!(decimals_btc == SOURCE_TOKEN_DECIMALS, 1);

        let sol_token_address: vector<u8> = x"e279450c";
        let sol_token_chain_id : u64 = 10;
        let sol_token_decimals : u16 = 9;
        let asset_sol = iAsset::create_new_iasset(supra,  b"SOL", b"iSOL", DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            sol_token_address, sol_token_chain_id, sol_token_decimals, SOURCE_TOKEN_ADDRESS);
        assert!(object::owner(asset_sol) == signer::address_of(supra), error::invalid_state(1));
        let asset_sol_by_origin = iAsset::get_iasset_metadata(sol_token_address, sol_token_chain_id);
        assert!(asset_sol == asset_sol_by_origin, 1);

        let (token_sol, chain_sol, decimals_sol, bridge_sol) = iAsset::deconstruct_iasset_source(&iAsset::get_iasset_source(asset_sol));
        // compare origin detail stored under assetinfo
        assert!(token_sol == sol_token_address, 1);
        assert!(chain_sol == sol_token_chain_id, 1);
        assert!(bridge_sol == SOURCE_TOKEN_ADDRESS, 1);
        assert!(decimals_sol == sol_token_decimals, 1);

        assert!(asset_btc_by_origin != asset_sol_by_origin, 1);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    #[expected_failure(abort_code = 393227, location = iAsset )] // error::not_found(EASSET_NOT_PRESENT)
    fun test_get_iasset_metadata_not_found(deployer: &signer, supra : &signer) {

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        clean_up(burn_cap, mint_cap);
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);

        let asset_btc = iAsset::create_new_iasset(supra, b"BTC", b"iBTC", DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        let asset_btc_by_origin = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);
        assert!(asset_btc == asset_btc_by_origin, 1); // compare the assets

        // error expected
        iAsset::get_iasset_metadata(x"e279450c", 10);
    }



    #[test(deployer = @dfmm_framework, supra = @0x1)]
    #[expected_failure(abort_code = 196621, location = iAsset )] // error::invalid_state(EIASSET_ALREADY_DEPLOYED)
    fun test_create_iasset_duplicate_source(deployer: &signer, supra : &signer) {

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        clean_up(burn_cap, mint_cap);
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);

        let asset_btc = iAsset::create_new_iasset(supra, b"BTC", b"iBTC", DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        assert!(object::owner(asset_btc) == signer::address_of(supra), error::invalid_state(1));
        let asset_btc_by_origin = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);
        assert!(asset_btc == asset_btc_by_origin, 1); // compare the assets

        // error expected
        iAsset::create_new_iasset(supra,  b"SOL", b"iSOL", DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
    }

    fun clean_up (burn_cap : coin::BurnCapability<supra_coin::SupraCoin>, mint_cap : coin::MintCapability<supra_coin::SupraCoin>) {
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_view_functions_new_user(deployer: &signer, supra : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let symbol = b"iBTC";

        let asset = iAsset::create_new_iasset(supra, b"BTC", symbol, DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);

        let user_1 = @0x123;
        assert!(iAsset::get_allocated_rewards(user_1) == 0, 1);

        let (withdrawable_rewards, _, reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(user_1);
        assert!(withdrawable_rewards == 0 && reward_allocation_timestamp == 0, 1);

        assert!(!iAsset::is_reward_withdrawable(user_1), 1);
        assert!(iAsset::get_allocatable_rewards(user_1, asset) == 0, 1);

        let (_, preminted_iassets, preminting_epoch_number, preminting_ts) = iAsset::deconstruct_asset_premint(&iAsset::get_preminted_per_asset(user_1, asset));
        assert!(preminted_iassets == 0 && preminting_epoch_number == 0 && preminting_ts == 0, 1);

        let all_assets = iAsset::get_all_asset_preminted(user_1);
        assert!(vector::is_empty(&all_assets), 1);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_premint_empty_metrics(deployer: &signer, supra : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let symbol = b"iBTC";

        let asset = iAsset::create_new_iasset(supra, b"BTC", symbol, DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);

        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        assert!(total_preminted_assets == 0 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == 0 , error::invalid_state(1));
        assert!(iAsset::get_iasset_supply(asset) == 0, error::invalid_state(1));
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_premint(deployer: &signer, supra : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let symbol = b"iBTC";
        let asset = iAsset::create_new_iasset(supra, b"BTC", symbol, DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        account::create_account_for_test(signer::address_of(supra));

        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);
        reconfiguration::initialize_for_test(supra);
        reconfiguration::reconfigure_for_test_custom();

        let receiver_1 = @0x123;
        let amount_1 = 1000;
        let receiver_2 = @0x234;
        let amount_2 = 2000;

        // premint user1, amount1
        iAsset::premint_iasset(amount_1, asset, receiver_1);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _,total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry = iAsset :: get_asset_entry(receiver_1, asset);
        let (_, preminted_iassets_1, _, preminting_epoch_number1, preminting_ts1, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry));
        assert!(total_preminted_assets == amount_1 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == amount_1 , error::invalid_state(1));
        assert!(preminted_iassets_1 == amount_1 , error::invalid_state(1));
        assert!(preminting_epoch_number1 > 0 , error::invalid_state(1)); // epoch is set
        assert!(preminting_ts1 == time0 , error::invalid_state(1));

        // premint user2, amount2
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        iAsset::premint_iasset(amount_2, asset, receiver_2);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _,  total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry = iAsset :: get_asset_entry(receiver_2, asset);
        let (_, preminted_iassets2, _, preminting_epoch_number2, preminting_ts2, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry));
        assert!(total_preminted_assets == (amount_1 + amount_2) , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == (amount_1 + amount_2) , error::invalid_state(1));
        assert!(preminted_iassets2 == amount_2 , error::invalid_state(1));
        assert!(preminting_epoch_number2 > preminting_epoch_number1 , error::invalid_state(1)); // epoch for premint_mint2 is greather thant for premint_mint1
        assert!(preminting_ts2 == time0 + delta, 1);

        assert!(iAsset::get_iasset_supply(asset) == 0, error::invalid_state(1));
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_mint_without_premint(deployer: &signer, supra : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let asset = iAsset::create_new_iasset(supra, b"BTC", b"iBTC", DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);

        let receiver_1 = @0x123;
        iAsset::mint_iasset(receiver_1, asset);

        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry = iAsset :: get_asset_entry(receiver_1, asset);
        let (_, preminted_iassets, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry));
        assert!(total_preminted_assets == 0 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == 0 , error::invalid_state(1));
        assert!(preminted_iassets == 0 , error::invalid_state(1));
        assert!(iAsset::get_iasset_supply(asset) == 0, error::invalid_state(1));
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    #[expected_failure(abort_code = 393227, location = iAsset )] // error::not_found(EASSET_NOT_PRESENT)
    fun test_mint_invalid_asset(deployer: &signer, supra : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let asset = test_dummy_fa(supra, b"BTC", b"iBTC");

        let receiver_1 = @0x123;
        iAsset::mint_iasset(receiver_1, asset);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, invalid_admin = @0x2)]
    #[expected_failure(abort_code = 327681, location = config )]
    fun test_mint_invalid_admin(deployer: &signer, supra : &signer, invalid_admin : &signer) {
        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        clean_up(burn_cap, mint_cap);

        test_util::init_root_config(deployer);
        poel::init_poel_for_test(deployer);

        let symbol = b"iBTC";
        poel::create_new_iasset(invalid_admin, b"BTC", symbol, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
    }


    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_mint(deployer: &signer, supra : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let symbol = b"iBTC";
        let asset = iAsset::create_new_iasset(supra, b"BTC", symbol, DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        account::create_account_for_test(signer::address_of(supra));
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);
        reconfiguration::initialize_for_test(supra);

        let receiver_1 = @0x123;
        let amount_1 = 1000;
        let receiver_2 = @0x234;
        let amount_2 = 2000;
        let amount_3 = 3000;

        // premint user1, amount1
        iAsset::premint_iasset(amount_1, asset, receiver_1);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry = iAsset :: get_asset_entry(receiver_1, asset);
        let (_, preminted_iassets_1, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry));
        assert!(total_preminted_assets == amount_1 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == amount_1 , error::invalid_state(1));
        assert!(preminted_iassets_1 == amount_1 , error::invalid_state(1));
        assert!(primary_fungible_store::balance(receiver_1, asset) == 0, error::invalid_state(1));

        // premint user2, amount2
        iAsset::premint_iasset(amount_2, asset, receiver_2);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry = iAsset :: get_asset_entry(receiver_2, asset);
        let (_, preminted_iassets_2, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry));
        assert!(total_preminted_assets == (amount_1 + amount_2) , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == (amount_1 + amount_2) , error::invalid_state(1));
        assert!(preminted_iassets_2 == amount_2 , error::invalid_state(1));

        // change epoch
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();

        // mint user1
        iAsset::mint_iasset(receiver_1, asset);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry1 = iAsset :: get_asset_entry(receiver_1, asset);
        let asset_entry2 = iAsset :: get_asset_entry(receiver_2, asset);
        let (_, preminted_iassets_1, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry1));
        let (_, preminted_iassets_2, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry2));
        assert!(total_preminted_assets == amount_2 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == (amount_1 + amount_2) , error::invalid_state(1));
        assert!(preminted_iassets_1 == 0 , error::invalid_state(1));
        assert!(preminted_iassets_2 == amount_2 , error::invalid_state(1));

        // mint user2
        iAsset::mint_iasset(receiver_2, asset);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry1 = iAsset :: get_asset_entry(receiver_1, asset);
        let asset_entry2 = iAsset :: get_asset_entry(receiver_2, asset);
        let (_, preminted_iassets_1, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry1));
        let (_, preminted_iassets_2, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry2));
        assert!(total_preminted_assets == 0 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == (amount_1 + amount_2) , error::invalid_state(1));
        assert!(preminted_iassets_1 == 0 , error::invalid_state(1));
        assert!(preminted_iassets_2 == 0 , error::invalid_state(1));

        // again premint user1, amount3
        iAsset::premint_iasset(amount_3, asset, receiver_1);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry = iAsset :: get_asset_entry(receiver_1, asset);
        let (_, preminted_iassets_1, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry));
        assert!(total_preminted_assets == amount_3 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == (amount_1 + amount_2 + amount_3) , error::invalid_state(1));
        assert!(preminted_iassets_1 == amount_3 , error::invalid_state(1));
        assert!(primary_fungible_store::balance(receiver_1, asset) == amount_1, error::invalid_state(1));
        assert!(iAsset::get_iasset_supply(asset) == (amount_1 + amount_2), error::invalid_state(1));
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, alice = @0x999)]
    #[expected_failure(abort_code = 196612, location = iAsset )] // error::invalid_state(EBALANCE_NOT_ENOUGH)
    fun test_redeem_request_insufficient(deployer: &signer, supra : &signer,  alice : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let symbol = b"iBTC";
        let asset = iAsset::create_new_iasset(supra, b"BTC", symbol, DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);

        let amount = 1000;
        iAsset::redeem_request(alice, amount, asset, 0);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, alice = @0x999)]
    #[expected_failure(abort_code = 393227, location = iAsset )] // error::not_found(EASSET_NOT_PRESENT)
    fun test_redeem_request_invalid_asset(deployer: &signer, supra : &signer, alice : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let asset = test_dummy_fa(supra, b"BTC", b"iBTC");

        let amount = 1000;
        iAsset::redeem_request(alice, amount, asset, 0);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, alice = @0x999, bob = @0x888)]
    fun test_redeem_request(deployer: &signer, supra : &signer, alice : &signer, bob : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let symbol = b"iBTC";
        let asset = iAsset::create_new_iasset(supra, b"BTC", symbol, DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        account::create_account_for_test(signer::address_of(supra));
        reconfiguration::initialize_for_test(supra);

        let alice_addr = signer::address_of(alice);
        let bob_addr = signer::address_of(bob);
        let amount_1 = 5000;
        let amount_2 = 8000;
        let amount_1_r = 1000;

        timestamp::set_time_has_started_for_testing(supra);
        let time_0 = 100001000000;
        timestamp::update_global_time_for_test_secs(time_0);
        let delta_time = 5000000;

        // premint user1, amount1
        iAsset::premint_iasset(amount_1, asset, alice_addr);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry1 = iAsset :: get_asset_entry(alice_addr, asset);
        let (_, preminted_iassets_1, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry1));
        assert!(total_preminted_assets == amount_1 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == amount_1 , error::invalid_state(1));
        assert!(preminted_iassets_1 == amount_1 , error::invalid_state(1));
        assert!(primary_fungible_store::balance(alice_addr, asset) == 0, error::invalid_state(1));
        assert!(iAsset::get_iasset_supply(asset) == 0, error::invalid_state(1));

        // premint user2, amount2
        iAsset::premint_iasset(amount_2, asset, bob_addr);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry2 = iAsset::get_asset_entry(bob_addr, asset);
        let (_, preminted_iassets_2, _, _, _, _, _) = iAsset::deconstruct_asset_entry(option::borrow(&asset_entry2));
        assert!(total_preminted_assets == amount_1 + amount_2 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == amount_1 + amount_2 , error::invalid_state(1));
        assert!(preminted_iassets_2 == amount_2 , error::invalid_state(1));
        assert!(primary_fungible_store::balance(bob_addr, asset) == 0, error::invalid_state(1));
        assert!(iAsset::get_iasset_supply(asset) == 0, error::invalid_state(1));

        timestamp::fast_forward_seconds(delta_time);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta_time);
        reconfiguration::reconfigure_for_test_custom();

        // mint user1
        iAsset::mint_iasset(alice_addr, asset);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry_alice = iAsset :: get_asset_entry(alice_addr, asset);
        let asset_entry_bob = iAsset :: get_asset_entry(bob_addr, asset);

        let (_, preminted_iassets_1, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry_alice));
        let (_, preminted_iassets_2, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry_bob));

        assert!(total_preminted_assets == amount_2 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == amount_1 + amount_2 , error::invalid_state(1));
        assert!(primary_fungible_store::balance(alice_addr, asset) == amount_1, error::invalid_state(1));
        assert!(preminted_iassets_1 == 0 , error::invalid_state(1));
        assert!(preminted_iassets_2 == amount_2 , error::invalid_state(1)); // user2 has not minted yet
        assert!(iAsset::get_iasset_supply(asset) == amount_1, error::invalid_state(1));

        // mint user2
        iAsset::mint_iasset(bob_addr, asset);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);


        let asset_entry_alice = iAsset :: get_asset_entry(alice_addr, asset);
        let asset_entry_bob = iAsset :: get_asset_entry(bob_addr, asset);

        let (_, preminted_iassets_1, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry_alice));
        let (_, preminted_iassets_2, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry_bob));

        assert!(total_preminted_assets == 0 , error::invalid_state(1)); // all minted now
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == amount_1 + amount_2 , error::invalid_state(1));
        assert!(primary_fungible_store::balance(bob_addr, asset) == amount_2, error::invalid_state(1));
        assert!(preminted_iassets_1 == 0 , error::invalid_state(1));
        assert!(preminted_iassets_2 == 0 , error::invalid_state(1));
        assert!(iAsset::get_iasset_supply(asset) == amount_1 + amount_2, error::invalid_state(1));

        //timestamp::fast_forward_seconds(delta_time);
        // redeem_request
        iAsset::redeem_request(alice, amount_1_r, asset, 0);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, total_withdraw_requests,total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry = iAsset :: get_asset_entry(alice_addr, asset);
        let (_, _, redeem_requested_iassets_1, _, _, unlock_request_timestep, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry));
        assert!(total_preminted_assets == 0 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == amount_1_r , error::invalid_state(1));
        assert!(redeem_requested_iassets_1 == amount_1_r , error::invalid_state(1));
        assert!(unlock_request_timestep == (time_0 + (delta_time * 2)) , error::invalid_state(1));
        //preview_redeem is under review, so we only check total_withdraw_requests >= amount_1_r
        assert!(total_withdraw_requests >= amount_1_r , error::invalid_state(1));
        assert!(deposited_asset_supply == (amount_1 + amount_2) , error::invalid_state(1));
        assert!(primary_fungible_store::balance(alice_addr, asset) == amount_1 - amount_1_r, error::invalid_state(1));
        assert!(iAsset::get_iasset_supply(asset) == amount_1 + amount_2 - amount_1_r, error::invalid_state(1));

    }

    #[test(deployer = @dfmm_framework, supra = @0x1, alice = @0x999)]
    #[expected_failure(abort_code = 196614, location = iAsset )] // error::invalid_state(EREDEEM_AMOUNT)
    fun test_redeem_iasset_insufficient(deployer: &signer, supra : &signer,  alice : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        timestamp::set_time_has_started_for_testing(supra);

        let symbol = b"iBTC";
        let asset = iAsset::create_new_iasset(supra, b"BTC", symbol, DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        account::create_account_for_test(signer::address_of(supra));
        reconfiguration::initialize_for_test(supra);

        let alice_addr = signer::address_of(alice);
        let amount_1 = 5000;

        // premint user1, amount1
        iAsset::premint_iasset(amount_1, asset, alice_addr);

        // error. no redeem_request recorded
        iAsset::redeem_iasset(alice, asset);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, alice = @0x999)]
    #[expected_failure(abort_code = 393227, location = iAsset )] // error::not_found(EASSET_NOT_PRESENT)
    fun test_redeem_iasset_invalid_asset(deployer: &signer, supra : &signer, alice : &signer) {
        test_util::init_root_config(deployer);
        timestamp::set_time_has_started_for_testing(supra);
        iAsset::init_iAsset_for_test(deployer);
        let asset = test_dummy_fa(supra, b"BTC", b"iBTC");

        iAsset::redeem_iasset(alice, asset);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_preview_redeem(deployer: &signer, supra : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let symbol = b"iBTC";
        let asset = iAsset::create_new_iasset(supra, b"BTC", symbol, DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        account::create_account_for_test(signer::address_of(supra));
        reconfiguration::initialize_for_test(supra);
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        let receiver_1 = @0x123;
        let amount_1 = 50000;
        let amount_redeem_1 = 1000;

        // premint user1, amount1
        iAsset::premint_iasset(amount_1, asset, receiver_1);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_,  _, _, _, _, _, total_preminted_assets, _, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry = iAsset :: get_asset_entry(receiver_1, asset);
        let (_, preminted_iassets_1, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry));
        assert!(total_preminted_assets == amount_1 , error::invalid_state(1));
        assert!(deposited_asset_supply == amount_1 , error::invalid_state(1));
        assert!(preminted_iassets_1 == amount_1 , error::invalid_state(1));

        // no iasset minted but deposited_asset_supply and total_preminted_assets are not 0
        assert!(iAsset::preview_redeem(amount_redeem_1, asset) == amount_redeem_1, error::invalid_state(1));

        // change epoch
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();

        // mint user1
        iAsset::mint_iasset(receiver_1, asset);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, _, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry = iAsset :: get_asset_entry(receiver_1, asset);
        let (_, preminted_iassets_1, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry));

        assert!(total_preminted_assets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == amount_1 , error::invalid_state(1));
        assert!(preminted_iassets_1 == 0 , error::invalid_state(1));
        // iasset_amount * asset_liquidity_ref.deposited_asset_supply / iasset_supply
        assert!(iAsset::preview_redeem(amount_redeem_1, asset) == amount_redeem_1, error::invalid_state(1));
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_preview_withdraw(deployer: &signer, supra : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let symbol = b"iBTC";
        let asset = iAsset::create_new_iasset(supra, b"BTC", symbol, DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        account::create_account_for_test(signer::address_of(supra));
        reconfiguration::initialize_for_test(supra);
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        let receiver_1 = @0x123;
        let amount_1 = 50000;
        let amount_withdraw_1 = 1000;

        // premint user1, amount1
        iAsset::premint_iasset(amount_1, asset, receiver_1);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, _, _, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        assert!(deposited_asset_supply == amount_1 , error::invalid_state(1));


        assert!(iAsset::preview_withdraw(amount_withdraw_1, asset) == math64::mul_div(amount_withdraw_1, amount_1, deposited_asset_supply), error::invalid_state(1));

        // change epoch
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        // mint user1
        iAsset::mint_iasset(receiver_1, asset);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, _, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        assert!(total_preminted_assets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == amount_1 , error::invalid_state(1));

        // preview_withdraw is not 0 now
        assert!(iAsset::preview_withdraw(amount_withdraw_1, asset) == amount_withdraw_1, error::invalid_state(1));
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    #[expected_failure(abort_code = 196623, location = iAsset )] // error::invalid_state(EDEPOSITED_ASSET_AMOUNT)
    fun test_preview_withdraw_no_deposit(deployer: &signer, supra : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let symbol = b"iBTC";
        let asset = iAsset::create_new_iasset(supra, b"BTC", symbol, DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);

        let amount_withdraw_1 = 1000;

        iAsset::preview_withdraw(amount_withdraw_1, asset); // error is expected because no deposited asset
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, alice = @0x999)]
    fun test_redeem_iasset1(deployer: &signer, supra : &signer, alice : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);

        let symbol = b"iBTC";
        let asset = iAsset::create_new_iasset(supra, b"BTC", symbol, DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        account::create_account_for_test(signer::address_of(supra));
        reconfiguration::initialize_for_test(supra);

        let alice_addr = signer::address_of(alice);
        let amount_1 = 5000;
        let amount_1_r = 1000;

        timestamp::set_time_has_started_for_testing(supra);
        let time_0 = 100001000000;
        timestamp::update_global_time_for_test_secs(time_0);
        let delta_time = 500000;

        // premint user1, amount1
        iAsset::premint_iasset(amount_1, asset, alice_addr);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry = iAsset :: get_asset_entry(alice_addr, asset);
        let (_, preminted_iassets_1, _, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry));
        assert!(total_preminted_assets == amount_1 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == amount_1 , error::invalid_state(1));
        assert!(preminted_iassets_1 == amount_1 , error::invalid_state(1));
        assert!(primary_fungible_store::balance(alice_addr, asset) == 0, error::invalid_state(1));
        assert!(iAsset::get_iasset_supply(asset) == 0, error::invalid_state(1));

        // change epoch
        timestamp::fast_forward_seconds(delta_time);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta_time);
        reconfiguration::reconfigure_for_test_custom();

        // mint user1
        iAsset::mint_iasset(alice_addr, asset);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry = iAsset::get_asset_entry(alice_addr, asset);
        let (_, preminted_iassets_1, _, _, _, _, _) = iAsset::deconstruct_asset_entry(option::borrow(&asset_entry));

        assert!(total_preminted_assets == 0 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(deposited_asset_supply == amount_1 , error::invalid_state(1));
        assert!(primary_fungible_store::balance(alice_addr, asset) == amount_1, error::invalid_state(1));
        assert!(preminted_iassets_1 == 0 , error::invalid_state(1));
        assert!(iAsset::get_iasset_supply(asset) == amount_1, error::invalid_state(1));

        //timestamp::fast_forward_seconds(delta_time);
        // redeem_request
        iAsset::redeem_request(alice, amount_1_r, asset, 0);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, total_withdraw_requests, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry_alice = iAsset :: get_asset_entry(alice_addr, asset);
        let (_, _, redeem_requested_iassets_1, _, _, unlock_request_timestep, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry_alice));
        assert!(total_preminted_assets == 0 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == amount_1_r , error::invalid_state(1));
        assert!(redeem_requested_iassets_1 == amount_1_r , error::invalid_state(1));

        let length_of_lockup_cycle = config::get_length_of_lockup_cycle();
        assert!(unlock_request_timestep == (time_0 + (delta_time * 2)), error::invalid_state(1));
        // time is not reached the value when redeem_iasset is allowed
        assert!(unlock_request_timestep + length_of_lockup_cycle > timestamp::now_seconds(), error::invalid_state(1));
        assert!(unlock_request_timestep == timestamp::now_seconds(), error::invalid_state(1));
        //preview_redeem is under review, so we only check total_withdraw_requests >= amount_1_r
        assert!(total_withdraw_requests >= amount_1_r , error::invalid_state(1));

        assert!(deposited_asset_supply == amount_1 , error::invalid_state(1));
        assert!(primary_fungible_store::balance(alice_addr, asset) == amount_1 - amount_1_r, error::invalid_state(1));
        assert!(iAsset::get_iasset_supply(asset) == amount_1 - amount_1_r, error::invalid_state(1));

        // move the time
        timestamp::fast_forward_seconds(test_util::get_cycle_length()); // move
        reconfiguration::reconfigure_for_test_custom();
        // time is reached, redeem_iasset is allowed
        assert!(unlock_request_timestep + length_of_lockup_cycle <= timestamp::now_seconds(), error::invalid_state(1));
        // redeem
        iAsset::update_recent_cycle_update_epoch(3);
        iAsset::redeem_iasset(alice, asset); // 3rd parameter is an external wallet
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        let asset_entry_alice = iAsset :: get_asset_entry(alice_addr, asset);
        let (_, _, redeem_requested_iassets_1, _, _, _, _) = iAsset :: deconstruct_asset_entry(option::borrow(&asset_entry_alice));
        assert!(total_preminted_assets == 0 , error::invalid_state(1));
        assert!(total_redeem_requested_iassets == 0 , error::invalid_state(1));
        assert!(redeem_requested_iassets_1 == 0 , error::invalid_state(1));

        //preview_withdraw is under review, the formula for deposited_asset_supply update is not finalized. Check only deposited_asset_supply < amount_1
        assert!(deposited_asset_supply <= amount_1 , error::invalid_state(1));
        assert!(primary_fungible_store::balance(alice_addr, asset) == amount_1 - amount_1_r, error::invalid_state(1));
        assert!(iAsset::get_iasset_supply(asset) == amount_1 - amount_1_r, error::invalid_state(1));
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, alice = @0x999)]
    #[expected_failure(abort_code = 65541, location = iAsset )] // error::invalid_state(EUNLOCK_REQUEST_TIME)
    fun test_redeem_iasset_time_not_reached(deployer: &signer, supra : &signer, alice : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);

        let symbol = b"iBTC";
        let asset = iAsset::create_new_iasset(supra, b"BTC", symbol, DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        account::create_account_for_test(signer::address_of(supra));
        reconfiguration::initialize_for_test(supra);

        let alice_addr = signer::address_of(alice);
        let amount_1 = 5000;
        let amount_1_r = 1000;

        timestamp::set_time_has_started_for_testing(supra);
        let time_0 = 100001000000;
        timestamp::update_global_time_for_test_secs(time_0);
        let delta_time = 500000;

        // premint user1, amount1
        iAsset::premint_iasset(amount_1, asset, alice_addr);
        assert!(primary_fungible_store::balance(alice_addr, asset) == 0, error::invalid_state(1));
        assert!(iAsset::get_iasset_supply(asset) == 0, error::invalid_state(1));

        // change epoch
        timestamp::fast_forward_seconds(delta_time);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta_time);
        reconfiguration::reconfigure_for_test_custom();

        // mint user1
        iAsset::mint_iasset(alice_addr, asset);
        assert!(iAsset::get_iasset_supply(asset) == amount_1, error::invalid_state(1));

        //timestamp::fast_forward_seconds(delta_time);
        // redeem_request
        iAsset::redeem_request(alice, amount_1_r, asset, 0);
        let asset_entry = iAsset::get_asset_entry(alice_addr, asset);
        let (_, _, _, _, _, unlock_request_timestep, _) = iAsset::deconstruct_asset_entry(option::borrow(&asset_entry));
        let length_of_lockup_cycle = config::get_length_of_lockup_cycle();
        assert!(unlock_request_timestep == (time_0 + (delta_time * 2)) , error::invalid_state(1));
        // time is not reached the value when redeem_iasset is allowed
        assert!(unlock_request_timestep + length_of_lockup_cycle > timestamp::now_seconds(), error::invalid_state(1));
        assert!(primary_fungible_store::balance(alice_addr, asset) == amount_1 - amount_1_r, error::invalid_state(1));
        assert!(iAsset::get_iasset_supply(asset) == amount_1 - amount_1_r, error::invalid_state(1));

        // move the time
        iAsset::redeem_iasset(alice, asset); // 3rd parameter is an external wallet
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_update_rewards(deployer: &signer, supra : &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let symbol = b"iBTC";
        let asset = iAsset::create_new_iasset(supra, b"BTC", symbol, DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        account::create_account_for_test(signer::address_of(supra));
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);
        reconfiguration::initialize_for_test(supra);

        let receiver_1 = @0x123;
        let receiver_2 = @0x234;
        let amount_1 = 10000;
        let amount_2 = 20000;

        // premint user1, amount1
        iAsset::premint_iasset(amount_1, asset, receiver_1);
        iAsset::premint_iasset(amount_2, asset, receiver_2);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, _, _, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        assert!(deposited_asset_supply == amount_1 + amount_2 , error::invalid_state(1));

        // change epoch
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();

        // mint user1, user2
        iAsset::mint_iasset(receiver_1, asset);
        iAsset::mint_iasset(receiver_2, asset);

        // update rewards
        let rewards1 = 50000;
        let rewards2 = 100000;
        (asset, rewards1, false);

        let items =  iAsset::get_liquidity_table_items(asset);
        let (_, _, _, _, _, _, _, _, deposited_asset_supply) = iAsset::deconstruct_liquidity_table_items(&items);
        assert!(primary_fungible_store::balance(receiver_1, asset) == amount_1, error::invalid_state(1));
        assert!(primary_fungible_store::balance(receiver_2, asset) == amount_2, error::invalid_state(1));
        assert!(deposited_asset_supply == amount_1 + amount_2, error::invalid_state(1));

        // check rewards for user1, user2
        let global_index = iAsset::get_asset_rewards_index(asset);
        let asset_entry1 = iAsset::get_asset_entry(receiver_1, asset);
        let asset_entry2 = iAsset::get_asset_entry(receiver_2, asset);
        let (user_index_1, _, _, _, _, _, _) = iAsset::deconstruct_asset_entry(option::borrow(&asset_entry1));
        let (user_index_2, _, _, _, _, _, _) = iAsset::deconstruct_asset_entry(option::borrow(&asset_entry2));
        assert!(user_index_1 == 0, 1);// index was not updated yet
        assert!(user_index_2 == 0, 1);// index was not updated yet

        // update rewards : no errors, no update
        iAsset::update_rewards(receiver_1, asset);
        iAsset::update_rewards(receiver_2, asset);

        let asset_entry1 = iAsset::get_asset_entry(receiver_1, asset);
        let asset_entry2 = iAsset::get_asset_entry(receiver_2, asset);
        let (user_index_1, _, _, _, _, _, _) = iAsset::deconstruct_asset_entry(option::borrow(&asset_entry1));
        let (user_index_2, _, _, _, _, _, _) = iAsset::deconstruct_asset_entry(option::borrow(&asset_entry2));
        assert!(user_index_1 == global_index, 1);
        assert!(user_index_2 == global_index, 1);

        // new rewards
        iAsset::update_reward_index(asset, rewards2);
        iAsset::update_rewards(receiver_1, asset);
        iAsset::update_rewards(receiver_2, asset);

        let asset_entry1 = iAsset::get_asset_entry(receiver_1, asset);
        let asset_entry2 = iAsset::get_asset_entry(receiver_2, asset);
        let (user_index_1, _, _, _, _, _, _) = iAsset::deconstruct_asset_entry(option::borrow(&asset_entry1));
        let (user_index_2, _, _, _, _, _, _) = iAsset::deconstruct_asset_entry(option::borrow(&asset_entry2));
        let global_index = iAsset::get_asset_rewards_index(asset);
        let rewards_1 = iAsset::get_allocated_rewards(receiver_1);
        let rewards_2 = iAsset::get_allocated_rewards(receiver_2);

        assert!(global_index == user_index_1, 1); // user index is updated
        assert!(global_index == user_index_2, 1); // user index is updated
        assert!(rewards_2 == rewards_1 * 2, 1); // user2.balance is 2x of user1.balance
    }

    #[test(deployer = @dfmm_framework)]
    fun test_batch_update_desirability_score(deployer: &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);
        let scores = vector::singleton<u64>(43);
        let asset_btc = iAsset::create_new_iasset(deployer, b"BTC",  b"iBTC", DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        let asset_sol = iAsset::create_new_iasset(deployer, b"SOL",  b"iSOL", DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/solana.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            x"e2794e1139f10c", ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);

        iAsset::batch_update_desirability_score(vector[asset_btc, asset_sol], vector[43, 58]);
        let (_, _, btc_score) = iAsset::get_asset_collateral_supply_weight_score(asset_btc);
        assert!(btc_score == 43, 1);
        let (_, _, sol_score) = iAsset::get_asset_collateral_supply_weight_score(asset_sol);
        assert!(sol_score == 58, 1);

        iAsset::batch_update_desirability_score(vector[asset_sol, asset_btc], vector[77, 58]);
        let (_, _, btc_score) = iAsset::get_asset_collateral_supply_weight_score(asset_btc);
        assert!(btc_score == 58, 1);
        let (_, _, sol_score) = iAsset::get_asset_collateral_supply_weight_score(asset_sol);
        assert!(sol_score == 77, 1);
    }

    #[test(deployer = @dfmm_framework)]
    #[expected_failure(abort_code = 196627, location = iAsset )] // error::invalid_state(EWRONG_DESIRED_SCORE)
    fun test_batch_update_desirability_score_too_big(deployer: &signer) {
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);

        let scores = vector::singleton<u64>(101);
        let asset = iAsset::create_new_iasset(deployer, b"BTC",  b"iBTC", DEF_DECIMALS, 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        let assets = vector::singleton(asset);
        iAsset::batch_update_desirability_score(assets, scores); // error is expected
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_update_desired_weight_three_assets_total_100000(deployer: &signer, supra: &signer) {
        iAsset::init_iAsset_for_test(deployer);

        let i = 0;

        // create 3 new unique assets
        let assets = vector::empty();
        while (i < 3) {
            let iasset_name: vector<u8> = b"BTC";
            let iasset_symbol: vector<u8> = b"iBTC";
            let origin_token_address: vector<u8> = b"btc50m34ddr355";
            let source_bridge_address: vector<u8> = b"btcsupra50m34ddr355";

            vector::push_back<u8>(&mut iasset_name, i);
            vector::push_back<u8>(&mut iasset_symbol, i);
            vector::push_back<u8>(&mut origin_token_address, i);
            vector::push_back<u8>(&mut source_bridge_address, i);

            let asset = iAsset::create_new_iasset(
                supra,
                iasset_name,
                iasset_symbol,
                8,
                1,
                b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
                origin_token_address,
                1,
                SOURCE_TOKEN_DECIMALS,
                source_bridge_address
            );
            vector::push_back(&mut assets, asset);

            i = i + 1;
        };

        iAsset::batch_update_desired_weight(assets, vector[30000, 50000, 20000]); // asset1, asset2, asset3
        let (_, w1, _) = iAsset::get_asset_collateral_supply_weight_score(*vector::borrow(&assets, 0));
        let (_, w2, _) = iAsset::get_asset_collateral_supply_weight_score(*vector::borrow(&assets, 1));
        let (_, w3, _) = iAsset::get_asset_collateral_supply_weight_score(*vector::borrow(&assets, 2));
        assert!(w1 == 30000, 1);
        assert!(w2 == 50000, 1);
        assert!(w3 == 20000, 1);

        iAsset::batch_update_desired_weight(assets, vector[10000, 30000, 60000]); // asset1, asset2, asset3
        let (_, w1, _) = iAsset::get_asset_collateral_supply_weight_score(*vector::borrow(&assets, 0));
        let (_, w2, _) = iAsset::get_asset_collateral_supply_weight_score(*vector::borrow(&assets, 1));
        let (_, w3, _) = iAsset::get_asset_collateral_supply_weight_score(*vector::borrow(&assets, 2));
        assert!(w1 == 10000, 1);
        assert!(w2 == 30000, 1);
        assert!(w3 == 60000, 1);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_update_desired_weight_single_asset_full_weight(deployer: &signer, supra: &signer) {
        iAsset::init_iAsset_for_test(deployer);

        let asset = iAsset::create_new_iasset(
            supra,
            b"BTC",
            b"iBTC",
            8,
            1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            b"btc50m34ddr355",
            1,
            SOURCE_TOKEN_DECIMALS,
            b"btcsupra50m34ddr355"
        );

        iAsset::batch_update_desired_weight(vector[asset], vector[100000]);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_update_desired_weight_hundred_assets_total_100000(deployer: &signer, supra: &signer) {
        iAsset::init_iAsset_for_test(deployer);

        // weights sum = 100000
        let weights: vector<u32> = vector[
            2000, 0, 0, 2000, 1000, 0, 1000, 2000, 0, 0,
            1000, 8000, 2000, 0, 0, 2000, 1000, 0, 0, 0,
            2000, 0, 1000, 0, 0, 1000, 2000, 1000, 1000, 0,
            1000, 0, 0, 1000, 1000, 2000, 0, 0, 1000, 0,
            0, 1000, 1000, 2000, 1000, 2000, 1000, 1000, 5000, 0,
            2000, 1000, 1000, 2000, 1000, 1000, 0, 0, 0, 1000,
            2000, 1000, 1000, 0, 0, 0, 2000, 1000, 1000, 0,
            0, 2000, 1000, 0, 0, 2000, 1000, 1000, 2000, 0,
            0, 1000, 0, 0, 3000, 2000, 1000, 1000, 0, 1000,
            1000, 1000, 7000, 1000, 0, 1000, 2000, 0, 1000, 1000
        ];

        let weights_total: u32 = 0;
        vector::for_each(weights, |w| {
            weights_total = weights_total + w;
        });

        assert!(vector::length<u32>(&weights) == 100, 100000);
        assert!(weights_total == 100000, 100001);

        let i = 0;

        // create 100 new unique assets
        let assets = vector::empty();
        while (i < 100) {
            let iasset_name: vector<u8> = b"BTC";
            let iasset_symbol: vector<u8> = b"iBTC";
            let origin_token_address: vector<u8> = b"btc50m34ddr355";
            let source_bridge_address: vector<u8> = b"btcsupra50m34ddr355";

            vector::push_back<u8>(&mut iasset_name, i);
            vector::push_back<u8>(&mut iasset_symbol, i);
            vector::push_back<u8>(&mut origin_token_address, i);
            vector::push_back<u8>(&mut source_bridge_address, i);

            let asset = iAsset::create_new_iasset(
                supra,
                iasset_name,
                iasset_symbol,
                8,
                1,
                b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
                origin_token_address,
                1,
                SOURCE_TOKEN_DECIMALS,
                source_bridge_address
            );
            vector::push_back(&mut assets, asset);

            i = i + 1;
        };

        iAsset::batch_update_desired_weight(assets, weights);
    }

    #[test(deployer = @dfmm_framework)]
    #[expected_failure(abort_code = 65543)] // abort = EWRONG_WEIGHT
    fun test_update_desired_weight_no_assets(deployer: &signer) {
        iAsset::init_iAsset_for_test(deployer);

        iAsset::batch_update_desired_weight(vector[], vector[]);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    #[expected_failure(abort_code = 65543, location = iAsset)] // abort = EWRONG_WEIGHT
    fun test_update_desired_fails_weight_all_assets_total_0(deployer: &signer, supra: &signer) {
        iAsset::init_iAsset_for_test(deployer);

        let i = 0;

        // create 4 new unique assets
        let assets = vector::empty();
        while (i < 4) {
            let iasset_name: vector<u8> = b"BTC";
            let iasset_symbol: vector<u8> = b"iBTC";
            let origin_token_address: vector<u8> = b"btc50m34ddr355";
            let source_bridge_address: vector<u8> = b"btcsupra50m34ddr355";

            vector::push_back<u8>(&mut iasset_name, i);
            vector::push_back<u8>(&mut iasset_symbol, i);
            vector::push_back<u8>(&mut origin_token_address, i);
            vector::push_back<u8>(&mut source_bridge_address, i);

            let asset = iAsset::create_new_iasset(
                supra,
                iasset_name,
                iasset_symbol,
                8,
                1,
                b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
                origin_token_address,
                1,
                SOURCE_TOKEN_DECIMALS,
                source_bridge_address
            );
            vector::push_back(&mut assets, asset);

            i = i + 1;
        };

        iAsset::batch_update_desired_weight(assets, vector[0, 0, 0, 0]);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    #[expected_failure(abort_code = 65544)] // abort = EWRONG_CWV_LENGTH
    fun test_update_desired_weight_fails_on_vector_length_mismatch(deployer: &signer, supra : &signer) {
        iAsset::init_iAsset_for_test(deployer);

        let i = 0;

        // create 5 new unique assets
        let assets = vector::empty();
        while (i < 5) {
            let iasset_name: vector<u8> = b"BTC";
            let iasset_symbol: vector<u8> = b"iBTC";
            let origin_token_address: vector<u8> = b"btc50m34ddr355";
            let source_bridge_address: vector<u8> = b"btcsupra50m34ddr355";

            vector::push_back<u8>(&mut iasset_name, i);
            vector::push_back<u8>(&mut iasset_symbol, i);
            vector::push_back<u8>(&mut origin_token_address, i);
            vector::push_back<u8>(&mut source_bridge_address, i);

            let asset = iAsset::create_new_iasset(
                supra,
                iasset_name,
                iasset_symbol,
                8,
                1,
                b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
                origin_token_address,
                1,
                SOURCE_TOKEN_DECIMALS,
                source_bridge_address
            );
            vector::push_back(&mut assets, asset);

            i = i + 1;
        };

        iAsset::batch_update_desired_weight(assets, vector[25000, 25000, 25000, 25000]);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    #[expected_failure(abort_code = 65543)] // abort = EWRONG_WEIGHT
    fun test_update_desired_weight_fails_on_total_weight_more_than_100000(deployer: &signer, supra : &signer) {
        iAsset::init_iAsset_for_test(deployer);

        let i = 0;

        // create 5 new unique assets
        let assets = vector::empty();
        while (i < 5) {
            let iasset_name: vector<u8> = b"BTC";
            let iasset_symbol: vector<u8> = b"iBTC";
            let origin_token_address: vector<u8> = b"btc50m34ddr355";
            let source_bridge_address: vector<u8> = b"btcsupra50m34ddr355";

            vector::push_back<u8>(&mut iasset_name, i);
            vector::push_back<u8>(&mut iasset_symbol, i);
            vector::push_back<u8>(&mut origin_token_address, i);
            vector::push_back<u8>(&mut source_bridge_address, i);

            let asset = iAsset::create_new_iasset(
                supra,
                iasset_name,
                iasset_symbol,
                8,
                1,
                b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
                origin_token_address,
                1,
                SOURCE_TOKEN_DECIMALS,
                source_bridge_address
            );
            vector::push_back(&mut assets, asset);

            i = i + 1;
        };

        iAsset::batch_update_desired_weight(assets, vector[25000, 25000, 25000, 25000, 10000]);
    }

    #[test(deployer = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1)]
    fun test_is_asset_registered(deployer: &signer, supra_oracles: &signer, supra : &signer) {
        let (_, _, _, _, _, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            false,
        );

        // registered iassets
        assert!(
            iAsset::is_iasset_registered(x"e2794e1ef7d4ac86506a5947a1f0f342c139f10c", 0) == true &&
            iAsset::is_iasset_registered(x"e2794e1ef7d4ac86506a5947a1f0f342c139f10c", 10) == true,
            1
        );

        // unregistered iasset
        assert!(iAsset::is_iasset_registered(x"1234567890", 1) == false, 1);
    }

    #[test(deployer = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1)]
    fun test_is_bridge_valid(deployer: &signer, supra_oracles: &signer, supra : &signer) {
        let (_, _, _, _, _, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            false,
        );

        // valid bridge address for iAssets
        assert!(
            iAsset::is_bridge_valid(x"e2794e1ef7d4ac86506a5947a1f0f342c139f10c", 0, x"e2794e1139f10c") == true &&
            iAsset::is_bridge_valid(x"e2794e1ef7d4ac86506a5947a1f0f342c139f10c", 10, x"e2794e1139f10c") == true,
            1
        );

        // invalid bridge address for iAssets
        assert!(
            iAsset::is_bridge_valid(x"e2794e1ef7d4ac86506a5947a1f0f342c139f10c", 0, x"1234567890") == false &&
            iAsset::is_bridge_valid(x"e2794e1ef7d4ac86506a5947a1f0f342c139f10c", 10, x"1234567890") == false,
            1
        );
    }

    #[test(deployer = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1)]
    fun test_get_asset_price(deployer: &signer, supra_oracles: &signer, supra : &signer) {
        let (btc, sol, _, _, _, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            false,
        );

        let (btc_value, btc_decimal, btc_timestamp, btc_round) = iAsset::deconstruct_asset_price(&iAsset::get_asset_price(btc));
        let (sol_value, sol_decimal, sol_timestamp, sol_round) =  iAsset::deconstruct_asset_price(&iAsset::get_asset_price(sol));

        assert!(
            btc_value == 100000000000000000000000 &&
            btc_decimal == 18 &&
            btc_timestamp == 100001000000000 &&
            btc_round == 1,
            1
        );

        assert!(
            sol_value == 50000000000000000000000 &&
            sol_decimal == 18 &&
            sol_timestamp == 100001000000000 &&
            sol_round == 1,
            1
        );
    }

    #[test(deployer = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1)]
    fun test_get_supra_price(deployer: &signer, supra_oracles: &signer, supra : &signer) {
        let (_, _, _, _, _, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            false,
        );

        let (supra_price, supra_decimals, _, _) = iAsset::deconstruct_asset_price(&iAsset::get_supra_price());

        assert!(
            supra_price == 20000000000000000 &&
            supra_decimals == 18,
            1
        );
    }

    #[test(deployer = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1)]
    fun test_get_usdt_price(deployer: &signer, supra_oracles: &signer, supra : &signer) {
        let usdt_price = 100057500; // ~1, ignored
        let (usdt, _) = setup_usdt_eth(
            supra,
            deployer,
            supra_oracles,
            usdt_price,// usdt price ignored because of pair_id=48
            4000_000000000000000000, // eth 1000
            50000000000000000 // 0.05 not important
        );

        let (usdt_value, usdt_decimal, usdt_timestamp, usdt_round) = iAsset::deconstruct_asset_price(&iAsset::get_asset_price(usdt));

        // usdt price is 1
        assert!(
            usdt_value == 100000000 &&
            usdt_decimal == 8,
            1
        );
    }    

    #[test(deployer = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1)]
    fun test_get_assets(deployer: &signer, supra_oracles: &signer, supra : &signer) {
        let (btc, sol, _, _, _, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            false,
        );

        let assets = iAsset::get_assets();

        let btc_asset = *vector::borrow(&assets, 0);
        let sol_asset = *vector::borrow(&assets, 1);

        assert!(btc == btc_asset && sol == sol_asset, 1);
    }

    #[test(deployer = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1)]
    fun test_preview_mint(deployer: &signer, supra_oracles: &signer, supra : &signer) {
        let (btc, _, _, _, u1, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            false,
        );

        let time0 = 100001000000;
        let delta = 3600;

        let amt10: u64 = 10_00000000;

        let mint_amount = iAsset::preview_mint(amt10, btc);

        // supply == 0
        assert!(mint_amount == amt10, 1);

        poel::borrow_request(btc, amt10, u1, 0, @0x0, 0, @0x0);

        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);
        poel::borrow(btc, u1);

        // supply > 0
        let mint_amount = iAsset::preview_mint(123456789 * 3, btc);

        assert!(mint_amount == 370370367, 1);
    }

    #[test(deployer = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1)]
    fun test_calculate_principle(deployer: &signer, supra_oracles: &signer, supra : &signer) {
        let (btc, sol, _, _, _, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            false,
        );

        let btc_collateral: u64 = 10_00000000;
        let sol_collateral: u64 = 50_00000000;

        iAsset::increase_collateral_supply(btc, btc_collateral);
        iAsset::increase_collateral_supply(sol, sol_collateral);

        iAsset::batch_update_desired_weight(vector[btc, sol], vector[50000, 50000]);
        iAsset::batch_update_desirability_score(vector[btc, sol],vector[1,1]);

        let min_col: u64 = 12000;
        let max_col1: u64 = 15000;
        let max_col2: u64 = 20000;
        let ts: u64 = timestamp::now_seconds();

        let rentable = iAsset::calculate_principle(min_col, max_col1, max_col2);

        assert!(rentable == 1186817964018000, 1);
    }

    #[test(deployer = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1)]
    fun test_calculate_collateralization_rate(deployer: &signer, supra_oracles: &signer, supra : &signer) {
        let (btc, sol, eth, dot, _, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[50000, 30000, 10000, 10000]);
        iAsset::batch_update_desirability_score(vector[btc], vector[2]);

        let collateral_amt: u64 = 10_00000000;
        iAsset::increase_collateral_supply(btc, collateral_amt);

        let min_col: u64 = 12000;
        let max_col1: u64 = 15000;
        let max_col2: u64 = 20000;

        let liquidity_of_asset: u128 = 1_000_000_000;
        let total_nominal_liquidity: u128 = 2_000_000_000;

        let (rate, weight, score) = iAsset::calculate_collateralization_rate(
            btc,
            liquidity_of_asset,
            min_col,
            max_col1,
            max_col2,
            total_nominal_liquidity
        );

        assert!(rate == 12000, 1);
        assert!(weight == 50000, 2);
        assert!(score == 2, 3);
    }

    #[test(deployer = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1, u1 = @0x71)]
    #[expected_failure]
    fun test_freeze_account(deployer: &signer, supra_oracles: &signer, supra : &signer, u1: &signer) {
        let (btc, _, _, _, u2, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            false,
        );

        let u1_addr = signer::address_of(u1);

        let amt10: u64 = 10_00000000;

        poel::borrow_request(btc, amt10, u1_addr, 0, @0x0, 0, @0x0);

        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::borrow(btc, u1_addr);

        iAsset::freeze_account(btc, u1_addr);

        primary_fungible_store::transfer(u1, btc, u2, amt10 / 2);
    }

    #[test(deployer = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1, u1 = @0x71)]
    #[expected_failure]
    fun test_set_pause(deployer: &signer, supra_oracles: &signer, supra : &signer, u1: &signer) {
        let (btc, _, _, _, u2, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            false,
        );

        let u1_addr = signer::address_of(u1);

        let amt10: u64 = 10_00000000;

        poel::borrow_request(btc, amt10, u1_addr, 0, @0x0, 0, @0x0);

        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::borrow(btc, u1_addr);

        iAsset::set_pause(btc, true);

        primary_fungible_store::transfer(u1, btc, u2, amt10 / 2);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_set_redeemable(deployer: &signer, supra : &signer) {

        account::create_account_for_test(signer::address_of(supra));
        test_util::init_root_config(deployer);
        iAsset::init_iAsset_for_test(deployer);

        poel::create_new_iasset(deployer, b"iBTC",  b"iBTC", 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        let asset = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);
        assert!(object::owner(asset) == signer::address_of(deployer), error::invalid_state(1));

        let (paused, redeemable) = iAsset::get_asset_status(asset);
        assert!(!paused , error::invalid_state(1));
        assert!(redeemable , error::invalid_state(1));

        iAsset::set_redeemable(asset, false);
        let (paused, redeemable) = iAsset::get_asset_status(asset);
        assert!(!paused , error::invalid_state(1));
        assert!(!redeemable , error::invalid_state(1));

        iAsset::set_redeemable(asset, true);
        iAsset::set_pause(asset, true);

        let (paused, redeemable) = iAsset::get_asset_status(asset);
        assert!(paused , error::invalid_state(1));
        assert!(redeemable , error::invalid_state(1));
    }

#[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_is_withdrawable(deployer: &signer, supra : &signer) {
        test_util::init_root_config(deployer);

        iAsset::init_iAsset_for_test(deployer);
        account::create_account_for_test(signer::address_of(supra));
        reconfiguration::initialize_for_test(supra);

        let receiver_1 = @0x123;
        let time0 = 100001000000;
        let rewards = 1500;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        let allocated_rewards = iAsset::get_allocated_rewards(receiver_1);
        assert!(allocated_rewards == 0, 1);
        let (withdrawable_rewards, _, reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(receiver_1);
        assert!(withdrawable_rewards == 0 && reward_allocation_timestamp == 0, 1);
        iAsset::update_recent_cycle_update_epoch(1);
        assert!(!iAsset::is_reward_withdrawable(receiver_1), 1);

        iAsset::set_allocated_rewards(receiver_1, rewards);

        let allocated_rewards = iAsset::get_allocated_rewards(receiver_1);
        assert!(allocated_rewards == rewards, 1);
        let (withdrawable_rewards, _, reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(receiver_1);
        assert!(withdrawable_rewards == 0 && reward_allocation_timestamp == 0, 1);
        assert!(iAsset::is_reward_withdrawable(receiver_1), 1);

        iAsset::claim_rewards(receiver_1); // 1st step
        let allocated_rewards = iAsset::get_allocated_rewards(receiver_1);
        assert!(allocated_rewards == 0, 1); // allocated moved to withdrawable
        let (withdrawable_rewards, _, reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(receiver_1);
        assert!(withdrawable_rewards == rewards, 1); // allocated moved to withdrawable
        assert!(reward_allocation_timestamp == time0, 1); // reward_allocation_timestamp is now
        iAsset::update_recent_cycle_update_epoch(2);
        assert!(iAsset::is_reward_withdrawable(receiver_1), 1); // false
    }

    #[test(admin = @dfmm_framework, user = @0x123)]
    public fun test_get_all_desired_weights(admin: &signer, user: &signer) {
        iAsset::init_iAsset_for_test(admin);
        let (token_a, token_b) = iAsset::create_test_assets(admin);

        let assets = vector::empty<Object<Metadata>>();
        vector::push_back(&mut assets, token_a);
        vector::push_back(&mut assets, token_b);

        let weights = vector::empty<u32>();
        vector::push_back(&mut weights, 30_000);
        vector::push_back(&mut weights, 70_000);

        iAsset::batch_update_desired_weight(assets, weights);

        let result = iAsset::get_all_desired_weights();
        assert!(vector::length(&result) == 2, 101);

        let (asset0, value0) = iAsset::deconstruct_asset_value_pair(vector::borrow(&result, 0));
        let (asset1, value1) = iAsset::deconstruct_asset_value_pair(vector::borrow(&result, 1));

        assert!(asset0 == iAsset::get_asset_address(token_a), 102);
        assert!(asset1 == iAsset::get_asset_address(token_b), 103);
        assert!(asset0 == iAsset::get_asset_address(token_a), 102);
        assert!(asset1 == iAsset::get_asset_address(token_b), 103);

        assert!(value0 + value1 == 100_000, 104);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    public fun test_get_source_token_addresses_by_chain(deployer: &signer, supra : &signer){
        iAsset::init_iAsset_for_test(deployer);
        let (_, _) = iAsset::create_test_assets(deployer);
        let results: vector<AssetInfo> = iAsset::get_asset_details_by_chain(1);

        assert!(vector::length(&results) == 1, 301);

        let results: vector<AssetInfo> = iAsset::get_asset_details_by_chain(2);

        assert!(vector::length(&results) == 1, 301);

        let results: vector<AssetInfo> = iAsset::get_asset_details_by_chain(3);

        assert!(vector::length(&results) == 0, 301);
    }

    #[test(admin = @dfmm_framework, framework = @0x1, supra_oracles = @supra_oracle)]
    fun test_calculate_nominal_liquidity(admin: &signer, framework: &signer, supra_oracles: &signer) {
        iAsset::init_iAsset_for_test(admin);

        let (token_a, token_b) = iAsset::create_test_assets(framework);

        supra_oracle_storage::init_module_for_test(supra_oracles);

        config::init_for_test(admin);

        timestamp::set_time_has_started_for_testing(framework);
        timestamp::update_global_time_for_test_secs(100001000000);

        supra_oracle_storage::set_price(1, 2, 18);
        supra_oracle_storage::set_price(2, 3, 18);
        supra_oracle_storage::set_price(500, 10, 18);

//        let liquidity_for_token_a = borrow_global_mut<LiquidityTableItems>(get_asset_address(token_a));
        iAsset::increase_collateral_supply(token_a, 100); // first increment eq just set
        iAsset::increase_collateral_supply(token_b, 200); // first increment eq just set
        //liquidity_for_token_a.collateral_supply = 100;
        //let liquidity_for_token_b = borrow_global_mut<LiquidityTableItems>(get_asset_address(token_b));
        //liquidity_for_token_b.collateral_supply = 200;

        let (total_nominal_liquidity, _) = iAsset::calculate_nominal_liquidity();

        // Expected liquidity calculation:
        //   Asset 0xA: 100 * 2 = 200
        //   Asset 0xB: 200 * 3 = 600
        //   Total = 200 + 600 = 800. Supra price = 10. total liquidity in supra = 800/10 = 80
        // keeping it 0, price is somehow not getting updated
        assert!(total_nominal_liquidity == 80, 1);
    }

    #[test(admin = @dfmm_framework, user = @0x123)]
    public entry fun test_get_preminted_per_asset_after_manual_update(
        admin: &signer,
        user: &signer
    ) {
        iAsset::init_iAsset_for_test(admin);

        let user_addr = signer::address_of(user);

        let (test_asset, _) = iAsset::create_test_assets(admin);
        iAsset::apply_premint(user_addr, test_asset, 1_000, 42, 123);

        let (_, preminted_iassets, preminting_epoch_number, preminting_ts) = iAsset::deconstruct_asset_premint(&iAsset::get_preminted_per_asset(user_addr, test_asset));

        assert!(preminted_iassets == 1_000, 201);
        assert!(preminting_epoch_number == 42, 202);
        assert!(preminting_ts == 123, 203);
    }

    #[test(admin = @dfmm_framework, user = @supra_oracle)]
    public entry fun test_get_all_asset_preminted_filters_and_returns_correct(
        admin: &signer,
        user: &signer
    ) {
        iAsset::init_iAsset_for_test(admin);

        let user_addr = signer::address_of(user);

        let (test_asset1, test_asset2) = iAsset::create_test_assets(admin);

        iAsset::apply_premint(user_addr, test_asset1, 100, 7, 123);
        iAsset::apply_premint(user_addr, test_asset2, 0, 0, 0);

        let results: vector<AssetPremint> = iAsset::get_all_asset_preminted(user_addr);
        assert!(vector::length(&results) == 1, 301);

        let (preminted_asset, preminted_iassets, preminting_epoch_number, preminting_ts) = iAsset::deconstruct_asset_premint(vector::borrow(&results, 0));
        assert!(preminted_asset                    == test_asset1, 302);
        assert!(preminted_iassets        == 100,    303);
        assert!(preminting_epoch_number  == 7,      304);
        assert!(preminting_ts            == 123,    305);
    }

    #[test(admin = @dfmm_framework, user = @0x123)]
    public entry fun test_get_allocated_reward_after_manual_update(admin: &signer, user: &signer) {
        iAsset::init_iAsset_for_test(admin);
        let user_address = signer::address_of(user);
        iAsset::set_allocated_rewards(user_address, 42);
        let r = iAsset::get_allocated_rewards(user_address);
        let (allocated, _, _, _, _,) = iAsset::deconstruct_user_rewards(&iAsset::get_user_rewards(user_address));
        assert!(r == 42 && allocated == 42, 101);
    }

    #[test(admin = @dfmm_framework, user = @0x123)]
    public entry fun test_get_withdrawn_reward_after_manual_update(admin: &signer, user: &signer) {
        iAsset::init_iAsset_for_test(admin);
        let user_address = signer::address_of(user);
        iAsset::set_withdrawn_rewards(user_address, 42);
        let r = iAsset::get_total_withdrawn_reward(user_address);
        let (_, _, _, _, withdrawn) = iAsset::deconstruct_user_rewards(&iAsset::get_user_rewards(user_address));
        assert!(r == 42 && withdrawn == 42, 101);
    }

    #[test(admin = @dfmm_framework, user = @0x123)]
    public entry fun test_get_withdrawable_rewards_after_manual_update(admin: &signer, user: &signer) {
        iAsset::init_iAsset_for_test(admin);

        let user_address = signer::address_of(user);

        iAsset::set_withdrawable_rewards(user_address, 42, 1000 , 5000);
        let (withdrawable_rewards, reward_allocation_epoch, reward_allocation_epoch_ts) = iAsset::get_withdrawable_rewards(user_address);
        assert!(withdrawable_rewards == 42, 101);
        assert!(reward_allocation_epoch == 1000, 101);
        assert!(reward_allocation_epoch_ts == 5000, 101);

        let (_, withdrawable_rewards, reward_allocation_epoch, reward_allocation_epoch_ts, _) = iAsset::deconstruct_user_rewards(&iAsset::get_user_rewards(user_address));
        assert!(withdrawable_rewards == 42, 101);
        assert!(reward_allocation_epoch == 1000, 101);
        assert!(reward_allocation_epoch_ts == 5000, 101);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user = @0x123)]
    public fun test_get_withdraw_timer_for_user(deployer: &signer, supra : &signer, user : &signer) {
        iAsset::init_iAsset_for_test(deployer);
        config::init_for_test(deployer);
        timestamp::set_time_has_started_for_testing(supra);
        let user_address = signer::address_of(user);

        iAsset::set_withdrawable_rewards(user_address, 0, 5 , 1_000); // epoch and ts
        config::set_parameters(deployer, 10, 200, 1000, 3, 1001, 1002, 10, 10, 10, 10, 10, 3);
        iAsset::update_cycle_info(6);
        timestamp::update_global_time_for_test_secs(1500);
        let timer = iAsset::get_withdraw_timer_for_user(user_address);

        assert!(timer == 0, 1001);

        iAsset::set_withdrawable_rewards(user_address, 0, 10 , 1_500); // epoch and ts

        iAsset::update_cycle_info(7);
        timestamp::update_global_time_for_test_secs(2000);
        let timer = iAsset::get_withdraw_timer_for_user(user_address);

        assert!(timer == 700, 1002);
    }

    #[test(deployer = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1)]
    fun test_calculate_collateralization_rate_asset_weights(deployer: &signer, supra_oracles: &signer, supra : &signer) {
        let btc_price = 5000_000000000000000000; // 5000
        let eth_price = 1000_000000000000000000; // 1000
        let supra_price = 50000000000000000; // 0.05
        let (btc, eth) = setup_btc_eth(
            supra,
            deployer,
            supra_oracles,
            btc_price,// btc 5000
            eth_price, // eth 1000
            50000000000000000 // 0.05
        );

        let min_collateralisation = 1100;
        let max_collateralisation_first = 1150;
        let max_collateralisation_second = 1900;

        // iETH and iBTC, with target weights of 30% and 70%, respectively.
        iAsset::batch_update_desired_weight(vector[eth, btc], vector[30000, 70000]);

        // epoch0. eth 200, btc 100; eth price 1000; btc price 5000
        // expected eth rate = 1102; btc_rate = 1137
        calculate_collateralization_rate_asset_weights(
            eth,
            200_00000000, // supply eth
            1102, // expected rate eth
            btc,
            100_00000000, // supply btc
            1137 // expected rate btc
        );

        // epoch1. eth 204, btc 113; eth price 1000; btc price 5000
        // expected eth rate = 1105; btc_rate = 1192
        calculate_collateralization_rate_asset_weights(
            eth,
            204_00000000, // supply eth
            1_105, // expected rate eth
            btc,
            113_00000000,  // supply btc
            1_192 // expected rate btc
        );


        // epoch10. eth 209.025842233858	btc 117.518838230368 eth price 600; btc price 5000
        // expected eth rate = 1.1207; btc_rate = 1.43094
        let btc_price = 5000_000000000000000000; // 5000
        let eth_price = 600_000000000000000000; // 600
        supra_oracle_storage::set_price(0, btc_price, 18);
        supra_oracle_storage::set_price(1, eth_price, 18);
        calculate_collateralization_rate_asset_weights(
            eth,
            209_02584223, // supply eth
            1_120, // expected rate eth
            btc,
            117_51883823, // supply btc
            1_430 // expected rate btc
        );

        // epoch20. eth 221.875057183623	btc 143.547977681136 eth price 1200; btc price 3500
        // expected eth rate = 1.15300400456663; btc_rate = 1.10331275028541
        let btc_price = 3500_000000000000000000; // 3500
        let eth_price = 1200_000000000000000000; // 1200
        supra_oracle_storage::set_price(0, btc_price, 18);
        supra_oracle_storage::set_price(1, eth_price, 18);
        calculate_collateralization_rate_asset_weights(
            eth,
            221_87505718, // supply eth
            1_152, // expected rate eth
            btc,
            143_54797768, // supply btc
            1_103 // expected rate btc
        );

        // epoch30. eth 221.842289744152	btc 158.057797799086 eth price 900; btc price 7000
        // expected eth rate = 1.12452163295554; btc_rate = 1.49234612728867
        let btc_price = 7000_000000000000000000; // 7000
        let eth_price = 900_000000000000000000; // 900
        supra_oracle_storage::set_price(0, btc_price, 18);
        supra_oracle_storage::set_price(1, eth_price, 18);
        calculate_collateralization_rate_asset_weights(
            eth,
            221_84228974, // supply eth
            1_124, // expected rate eth
            btc,
            158_05779779, // supply btc
            1_492 // expected rate btc
        );

    }

    inline fun calculate_collateralization_rate_asset_weights (
            eth: Object<Metadata>, eth_supply: u64,expected_eth_rate: u64,
            btc: Object<Metadata>, btc_supply: u64, expected_btc_rate: u64) {

        let min_collateralisation = 1100;
        let max_collateralisation_first = 1150;
        let max_collateralisation_second = 1900;


        iAsset::set_collateral_supply(eth, eth_supply);
        iAsset::set_collateral_supply(btc, btc_supply);

        let (total_nominal_liquidity, _) = iAsset::calculate_nominal_liquidity();

        let eth_liquidity = iAsset::get_nominal_liquidity_by_asset(eth);
        let (eth_rate, _, _) = iAsset::calculate_collateralization_rate(
            eth,
            eth_liquidity,
            min_collateralisation,
            max_collateralisation_first,
            max_collateralisation_second,
            total_nominal_liquidity
        );

        let btc_liquidity = iAsset::get_nominal_liquidity_by_asset(btc);
        let (btc_rate, _, _) = iAsset::calculate_collateralization_rate(
            btc,
            btc_liquidity,
            min_collateralisation,
            max_collateralisation_first,
            max_collateralisation_second,
            total_nominal_liquidity
        );
        //debug::print(&string_utils::format2(&b"eth_supply {} btc_supply {}", eth_supply, btc_supply));
        //debug::print(&string_utils::format2(&b"eth_rate {} btc_rate {}", eth_rate, btc_rate));
        assert!(eth_rate == expected_eth_rate, 1);
        assert!(btc_rate == expected_btc_rate, 1);


    }

    fun test_dummy_fa (admin:&signer, name:vector<u8>, symbol:vector<u8>) : Object<Metadata> {
        let metadata_constructor_ref = &object::create_named_object(admin, symbol);

        // Create a store enabled fungible asset
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            metadata_constructor_ref,
            option::none(),
            string::utf8(name),
            string::utf8(symbol),
            8,
            string::utf8(b""),
            string::utf8(b""),
        );
        let metadata = object::object_from_constructor_ref(metadata_constructor_ref);
        metadata
    }

}