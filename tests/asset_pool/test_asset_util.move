/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
#[test_only]
module dfmm_framework::asset_util_test  {

    use std::signer;

    use aptos_std::object;
    use supra_framework::fungible_asset::{Metadata};
    use supra_framework::supra_coin::SupraCoin;

    use std::string::{Self};
    use aptos_std::type_info::{Self};

    use dfmm_framework::asset_util;
    use dfmm_framework::test_util;

    #[test()]
    fun test_price_denomination() {

        // prices from oralce, 18 decimals
        let price_btc:u128 = 102942670000000000000000;
        let price_eth:u128 = 2326260000000000000000;
        let price_sol:u128 = 169157500000000000000;
        let price_pepe:u128 = 12449410000000;
        let price_sup:u128 = 7480000000000000;
                     
        let btc = 1;
        let eth = 5;
        let sol = 500;
        let pepe = 20;
        let unit_multiplier = 100000000;
        
        let btc_supra = asset_util::get_asset_value_in(btc * unit_multiplier, price_btc, 18, price_sup, 18);
        let eth_supra = asset_util::get_asset_value_in(eth * unit_multiplier, price_eth, 18, price_sup, 18);
        let sol_supra = asset_util::get_asset_value_in(sol * unit_multiplier, price_sol, 18, price_sup, 18);
        let pepe_supra = asset_util::get_asset_value_in(pepe * unit_multiplier, price_pepe, 18, price_sup, 18);

        assert!(btc_supra == 1376238903743315, 1); // 1btc in supra
        assert!(eth_supra == 155498663101604, 1); // 5eth in supra
        assert!(sol_supra == 1130731951871657, 1); // 500sol in supra
        assert!(pepe_supra == 3328719, 1); // 20 pepe in supra
    }

    #[test()]
    fun test_scale() {
        // prices from oralce, 18 decimals
        let price_18:u128 = 2_000_000_000_000_000_000;
        let price_9:u128 = 2_000_000_000;
        let price_3:u128 = 2_000;

        let calc_price_9 = asset_util::scale(price_18, 18, 9);
        assert!(price_9 == calc_price_9, 1);

        let calc_price_18 = asset_util::scale(price_9, 9, 18);
        assert!(price_18 == calc_price_18, 1);

        let calc_price_18 = asset_util::scale(price_18, 18, 18);
        assert!(price_18 == calc_price_18, 1);

        let calc_price_3 = asset_util::scale(price_18, 18, 3);
        assert!(price_3 == calc_price_3, 1);        
    }    

    #[test(deployer = @dfmm_framework)]
    fun test_fa_key(deployer: &signer) {
        let (asset_sol, _) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let (asset_eth, _) = test_util::create_dummy_fa(deployer, b"ETH", b"ETH");

        let sol_fa_sol_key = asset_util::get_fa_key(asset_sol);
        let sol_fa_eth_key = asset_util::get_fa_key(asset_eth);
        
        let sol_address = object::object_address(&asset_sol);
        let eth_address = object::object_address(&asset_eth);

        let sol_fa_sol_key2 = asset_util::get_address_key(&sol_address);
        let sol_fa_eth_key2 = asset_util::get_address_key(&eth_address);
        
        assert!(sol_fa_sol_key != sol_fa_eth_key, 1); // key are different

        assert!(sol_fa_sol_key == sol_fa_sol_key2, 1); // the same key constructed
        assert!(sol_fa_eth_key == sol_fa_eth_key2, 1); // the same key constructed
    }

    #[test(deployer = @dfmm_framework)]
    fun test_supra_coin_key() {
        let supra_key = asset_util::get_supra_coin_key();
        let supra_key2 = *string::bytes(&type_info::type_name<SupraCoin>());
        
        assert!(supra_key == supra_key2, 1); 
    }

    #[test(deployer = @dfmm_framework)]
    fun test_metadata_from_key(deployer: &signer) {
        let (asset_sol, _) = test_util::create_dummy_fa(deployer, b"SOL", b"SOL");
        let (asset_eth, _) = test_util::create_dummy_fa(deployer, b"ETH", b"ETH");

        let sol_fa_sol_key = asset_util::get_fa_key(asset_sol); // build a key
        let sol_fa_eth_key = asset_util::get_fa_key(asset_eth); // build a key
        
        let reconstruct_sol_address = asset_util::get_address_from_key(sol_fa_sol_key);
        let reconstruct_eth_address = asset_util::get_address_from_key(sol_fa_eth_key);
        
        assert!(sol_fa_sol_key != sol_fa_eth_key, 1); // key are different
        assert!(reconstruct_sol_address != reconstruct_eth_address, 1); // addresses are different

        let reconstruct_asset_sol = object::address_to_object<Metadata>(reconstruct_sol_address); // Metadata
        let reconstruct_asset_eth = object::address_to_object<Metadata>(reconstruct_eth_address); // Metadata

        assert!(asset_sol == reconstruct_asset_sol, 1); // the same key constructed
        assert!(asset_eth == reconstruct_asset_eth, 1); // the same key constructed

        assert!(asset_sol == asset_util::get_fa_metadata(sol_fa_sol_key), 1); // the same key constructed
        assert!(asset_eth == asset_util::get_fa_metadata(sol_fa_eth_key), 1); // the same key constructed
    }

    #[test(user1 = @0x2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a, user2 = @0x8b03e77a855951828b22b9541977ca860a9c527c1e5d145b3cbb4fabe3e4660b)]
    fun test_recovery_address(user1: &signer, user2: &signer) {
        let user1_address = signer::address_of(user1);
        let user2_address = signer::address_of(user2);

        let user1_address_vec = x"2a1d929f9939b0755adfa3053b7b57ea6e205adc1a71b594835dd7c06f0f609a";
        let user2_address_vec = x"8b03e77a855951828b22b9541977ca860a9c527c1e5d145b3cbb4fabe3e4660b";

        let user1_address_reconstruct = asset_util::get_address_from_key(user1_address_vec);
        let user2_address_reconstruct = asset_util::get_address_from_key(user2_address_vec);

        assert!(user1_address_reconstruct == user1_address, 1);
        assert!(user2_address_reconstruct == user2_address, 1);
        
        
    }       

}