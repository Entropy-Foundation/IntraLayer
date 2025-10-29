/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
#[test_only]
module dfmm_framework::asset_pool_test  {
    use dfmm_framework::asset_pool;

    use std::signer;
    use std::string::{Self};

    use supra_framework::object::{Self, Object};
    use supra_framework::primary_fungible_store;
    use supra_framework::fungible_asset::{Self, Metadata, MintRef};

    use dfmm_framework::test_util;
    use dfmm_framework::asset_util;

    #[test(deployer = @dfmm_framework, supra = @0x1)]
    fun test_init_module(deployer: &signer, supra: &signer) {
        let (s_burn_cap, s_mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        asset_pool::init_for_test(deployer);
        assert!(asset_pool::get_vault_address()!=@0x0, 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123)]
    fun test_deposit_fa(deployer: &signer, supra: &signer, user1: &signer) {
        let (s_burn_cap, s_mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        asset_pool::init_for_test(deployer);
        let (asset, mint_cap) = test_util::create_dummy_fa(user1, b"SOL", b"SOL");

        let (balance, deposited, withdrawn) = asset_pool::get_fa_pool_details(asset);
        assert!(balance == 0, 1);
        assert!(deposited == 0, 1);
        assert!(withdrawn == 0, 1);

        let amount = 10000;
        let amount_deposit = 4000;
        let amount_directly = 1000;
        let user1_address = signer::address_of(user1);
        primary_fungible_store::mint(&mint_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset) == amount, 1);
        
        asset_pool::deposit_fa(user1, asset, amount_deposit);

        let (fa_balance, deposited, withdrawn) = asset_pool::get_fa_pool_details(asset);
        assert!(fa_balance == amount_deposit, 1);
        assert!(deposited == (amount_deposit as u128), 1);
        assert!(withdrawn == 0, 1);

        // send directly 
        fungible_asset::transfer(
            user1,
            primary_fungible_store::ensure_primary_store_exists(user1_address, asset), 
            primary_fungible_store::ensure_primary_store_exists(asset_pool::get_vault_address(), asset),
            amount_directly);
        let (fa_balance, deposited, withdrawn) = asset_pool::get_fa_pool_details(asset);
        assert!(fa_balance == amount_deposit + amount_directly, 1); // increased
        assert!(deposited == (amount_deposit as u128), 1); // remains as is
        assert!(withdrawn == 0, 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
   }

    #[test(deployer = @dfmm_framework, supra = @0x1, user1 = @0x123, user2 = @0x234)]
    fun test_withdraw_fa(deployer: &signer, supra: &signer, user1: &signer, user2: &signer) {
        let (s_burn_cap, s_mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        asset_pool::init_for_test(deployer);
        let (asset, mint_cap) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        
        let amount = 10000;
        let amount_deposit = 4000;
        let amount_withdraw = 1000;
        let user1_address = signer::address_of(user1);
        let user2_address = signer::address_of(user2);

        primary_fungible_store::mint(&mint_cap, user1_address, amount);
        assert!(primary_fungible_store::balance(user1_address, asset) == amount, 1);
        
        asset_pool::deposit_fa(user1, asset, amount_deposit);
        assert!(primary_fungible_store::balance(user1_address, asset) == amount - amount_deposit, 1);

        let (fa_balance, deposited, withdrawn) = asset_pool::get_fa_pool_details(asset);
        assert!(fa_balance == amount_deposit, 1);
        assert!(deposited == (amount_deposit as u128), 1);
        assert!(withdrawn == 0, 1);

        asset_pool::withdraw_fa(asset, amount_withdraw, user2_address);

        let (fa_balance, deposited, withdrawn) = asset_pool::get_fa_pool_details(asset);
        assert!(fa_balance == (amount_deposit - amount_withdraw), 1);
        assert!(deposited == (amount_deposit as u128), 1);
        assert!(withdrawn == (amount_withdraw as u128), 1);

        assert!(primary_fungible_store::balance(user1_address, asset) == amount - amount_deposit, 1);
        assert!(primary_fungible_store::balance(user2_address, asset) == amount_withdraw, 1);

        test_util::clean_up(s_burn_cap, s_mint_cap);
    }

}