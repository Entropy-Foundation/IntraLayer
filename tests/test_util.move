/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
#[test_only]
module dfmm_framework::test_util  {
    use std::signer;
    use std::option::{Self};
    use std::string::{Self};

    use supra_framework::account;
    use supra_framework::supra_coin;
    use supra_framework::coin::{Self};
    use supra_framework::object::{Self, Object};
    use supra_framework::primary_fungible_store;
    use supra_framework::fungible_asset::{Self, Metadata, MintRef};
    use supra_framework::reconfiguration;

    use dfmm_framework::asset_router as router;
    use dfmm_framework::iAsset;
    use dfmm_framework::poel;
    use dfmm_framework::asset_util;
    use dfmm_framework::config;

    const CYCLE: u64 = 48*60*1000;
    const EPOCH: u64 = 8*60*1000;

    public fun init_router_poel_iasset (deployer: &signer, supra: &signer) : (coin::BurnCapability<supra_coin::SupraCoin>, coin::MintCapability<supra_coin::SupraCoin>) {
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        router::init_for_test(deployer);
        account::create_account_for_test(signer::address_of(supra));
        reconfiguration::initialize_for_test(supra);
        poel::init_poel_for_test(deployer);
        iAsset::init_iAsset_for_test(deployer);
        (burn_cap, mint_cap)
    }

    public fun bridge_address_vec ():vector<u8> {
        asset_util::get_address_key(&@dfmm_framework)
    }

    public fun clean_up (burn_cap : coin::BurnCapability<supra_coin::SupraCoin>, mint_cap : coin::MintCapability<supra_coin::SupraCoin>) {
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    public fun create_dummy_fa (admin:&signer, name:vector<u8>, symbol:vector<u8>) : (Object<Metadata>, MintRef) {
        create_dummy_fa_custom_decimals(admin, name, symbol, 8)
    }

    public fun create_dummy_fa_custom_decimals (admin:&signer, name:vector<u8>, symbol:vector<u8>, decimals:u8) : (Object<Metadata>, MintRef) {
        let metadata_constructor_ref = &object::create_named_object(admin, symbol);

        // Create a store enabled fungible asset
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            metadata_constructor_ref,
            option::none(),
            string::utf8(name),
            string::utf8(symbol),
            decimals,
            string::utf8(b""),
            string::utf8(b""),
        );
        let metadata = object::object_from_constructor_ref(metadata_constructor_ref);
        let mint_ref = fungible_asset::generate_mint_ref(metadata_constructor_ref);
        (metadata, mint_ref)
    }

    public fun init_root_config (deployer: &signer) {
        config::init_for_test(deployer);
        config::set_parameters(deployer, 1, EPOCH, CYCLE, 3, 10, 10,0,0,0, 1000000000, 0, 3); // 10 supra
    }

    public fun get_cycle_length () :u64 {
        CYCLE
    }
}