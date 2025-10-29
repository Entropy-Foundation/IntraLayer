/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
#[test_only]
module dfmm_framework::poel_rewards_test {
    use aptos_std::signer;
    use aptos_std::vector;
    use dfmm_framework::config;
    use dfmm_framework::iAsset;
    use dfmm_framework::poel;
    use dfmm_framework::poel_test_helpers::setup_env_with_users_and_assets;
    use supra_framework::primary_fungible_store;
    use supra_framework::reconfiguration;
    use supra_framework::reconfiguration::{current_epoch};
    use supra_framework::timestamp;
    use std::option::{Self};

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_distribute_rewards(supra: &signer, deployer: &signer, supra_oracles: &signer) {
        let (
            asset_btc,
            asset_sol,
            _,
            _,
            recipient_1,
            recipient_2,
            _,
            _,
        ) = setup_env_with_users_and_assets(supra, deployer, supra_oracles, false);
        let asset_amount1: u64 = 10_00000000; // 10 btc
        let asset_amount2: u64 = 20_00000000; // 20 sol
        let btc_desired_weight = 50000; // identical
        let sol_desired_weight = 50000;
        let btc_score = 1; // identical
        let sol_score = 1;

        let delta = 3600;

        // user1,2 : borrow_request
        poel::borrow_request(asset_btc, asset_amount1, recipient_1, 0, @0x0, 0, @0x0);
        poel::borrow_request(asset_sol, asset_amount2, recipient_2, 0, @0x0, 0, @0x0);

        let user1_liq_address = iAsset::get_total_liquidity_provider_table_value_for_test(recipient_1);
        let user2_liq_address = iAsset::get_total_liquidity_provider_table_value_for_test(recipient_2);
        let (
            _,
            preminted_iassets1,
            _,
            _,
            _,
        ) = iAsset::get_liquidity_provider_asset_entry_items_for_test(user1_liq_address, asset_btc);
        let (
            _,
            preminted_iassets2,
            _,
            _,
            _,
        ) = iAsset::get_liquidity_provider_asset_entry_items_for_test(user2_liq_address, asset_sol);
        let items_btc =  iAsset::get_liquidity_table_items(asset_btc);
        let (_, _, _, _, total_borrow_requests1, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&items_btc);
        let items_sol =  iAsset::get_liquidity_table_items(asset_sol);
        let (_, _, _, _, total_borrow_requests2, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&items_sol);

        assert!(preminted_iassets1 == asset_amount1, 1);
        assert!(total_borrow_requests1 == asset_amount1, 1);
        assert!(preminted_iassets2 == asset_amount2, 1);
        assert!(total_borrow_requests2 == asset_amount2, 1);
        assert!(primary_fungible_store::balance(recipient_1, asset_btc) == 0, 1); // balance is 0, no real minting
        assert!(primary_fungible_store::balance(recipient_2, asset_sol) == 0, 1); // balance is 0, no real minting

        // change epoch because mint/borrow is allowed in the next epoch only
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);

        // user1: borrow
        poel::borrow(asset_btc, recipient_1);
        poel::borrow(asset_sol, recipient_2);
        assert!(primary_fungible_store::balance(recipient_1, asset_btc) == asset_amount1, 1);
        assert!(primary_fungible_store::balance(recipient_2, asset_sol) == asset_amount2, 1);

        let supply_btc = iAsset::get_iasset_supply(asset_btc);
        let supply_sol = iAsset::get_iasset_supply(asset_sol);
        assert!(supply_btc == asset_amount1, 1);
        assert!(supply_sol == asset_amount2, 1);

        // TEST
        iAsset::batch_update_desired_weight(vector[asset_btc, asset_sol], vector[btc_desired_weight, sol_desired_weight]);
        iAsset::batch_update_desirability_score(vector[asset_btc, asset_sol], vector[btc_score, sol_score]);

        let (_, btc_w, btc_score_w) = iAsset::get_asset_collateral_supply_weight_score(asset_btc);
        let (_, sol_w, sol_score_w) = iAsset::get_asset_collateral_supply_weight_score(asset_sol);
        assert!(btc_w == btc_desired_weight, 1);
        assert!(sol_w == sol_desired_weight, 1);
        assert!(btc_score_w == btc_score, 1);
        assert!(sol_score_w == sol_score, 1);

        let rewards_trivial = 1; // 0.0000001 sup
        let rewards_1 = 2000_00000000; // 2000 sup
        let rewards_2 = 10000_00000000; // 10k sup
        let rewards_3 = 10000000000_00000000; // 10B sup

        timestamp::fast_forward_seconds(120); // update the ts
        reconfiguration::reconfigure_for_test_custom();
        poel::increase_total_distributable_rewards(rewards_1);
        let (last_dist_asset1, _) = poel::get_total_distributable_rewards_of(asset_btc);
        let (last_dist_asset2, total_dist) = poel::get_total_distributable_rewards_of(asset_sol);
        assert!(last_dist_asset1 == 0, 1); // no updates because no distribution happened
        assert!(last_dist_asset2 == 0, 1); // no updates because no distribution happened
        assert!(total_dist == rewards_1, 1); // global rewards to distribute

        iAsset::increase_collateral_supply(asset_btc, asset_amount1); // increase collateral_supply in the test
        iAsset::increase_collateral_supply(asset_sol, asset_amount2); // increase collateral_supply in the test

        let (btc_apy0, _) = poel::get_asset_apy(asset_btc);
        let (sol_apy0, _) = poel::get_asset_apy(asset_sol);
        assert!(btc_apy0 == 0, 1); // no rewards
        assert!(sol_apy0 == 0, 1); // no rewards

        // 1st round of rewards
        let now_1 = current_epoch();//timestamp::now_seconds();
        poel::distribute_rewards(deployer);
        let (btc_apy1, _) = poel::get_asset_apy(asset_btc);
        let (sol_apy1, _) = poel::get_asset_apy(asset_sol);

        assert!(btc_apy1 == 0, 1); // rewards available, but no time delta
        assert!(sol_apy1 == 0, 1); // rewards available, but no time delta

        let (last_dist_asset, total_dist) = poel::get_total_distributable_rewards_of(asset_btc);
        assert!(last_dist_asset == rewards_1, 1); // round is completed
        assert!(total_dist == rewards_1, 1);
        let btc_index = iAsset::get_asset_rewards_index(asset_btc); // get global index
        let sol_index = iAsset::get_asset_rewards_index(asset_sol); // get global index

        assert!(btc_index == 10000000000, 1);
        assert!(sol_index == 5000000000, 1);
        let rewards_user_1 = iAsset::calculate_rewards(recipient_1, 0, asset_btc); // rewards for BTC holder
        let rewards_user_2 = iAsset::calculate_rewards(recipient_2, 0, asset_sol); // rewards for SOL holder
        assert!(rewards_user_1 == rewards_user_2, 1);
        // equal rewards for both users, because user 1 delegated 10 btc @ 100k each, and user 2 delegated 20 sol @ 50k each
        assert!(rewards_user_1 == rewards_1/2, 1);
        assert!(rewards_user_2 == rewards_1/2, 1);

        // invoke again, but no extra rewards, no exception
        timestamp::fast_forward_seconds(121); // update the ts
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(121); // update the ts
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(121); // update the ts
        reconfiguration::reconfigure_for_test_custom();
        poel::increase_total_distributable_rewards(rewards_trivial); // very small amount, but > 0
        let now_2 = current_epoch();//timestamp::now_seconds();
        poel::distribute_rewards(deployer);

        let (btc_apy2, btc_mult) = poel::get_asset_apy(asset_btc);
        let (sol_apy2, sol_mult) = poel::get_asset_apy(asset_sol);

        assert!(btc_apy2 == sol_apy2, 1); // rewards available, apy are the same for both
        assert!(btc_mult == sol_mult, 1); // the same multiplier
        assert!(btc_apy2 == 70080000, 1);
        assert!(btc_mult == 100000000, 1); // constant

        let (last_dist_asset_btc, total_dist) = poel::get_total_distributable_rewards_of(asset_btc);
        assert!(last_dist_asset_btc == rewards_1 + rewards_trivial, 1);
        assert!(total_dist == rewards_1 + rewards_trivial, 1);

        // SECOND round of rewards
        timestamp::fast_forward_seconds(121); // update the ts
        reconfiguration::reconfigure_for_test_custom();
        poel::increase_total_distributable_rewards(rewards_2); // only global value is updated
        let (last_dist_asset_btc, total_dist) = poel::get_total_distributable_rewards_of(asset_btc);
        assert!(last_dist_asset_btc == rewards_1 + rewards_trivial, 1);
        assert!(total_dist == rewards_1 + rewards_2 + rewards_trivial, 1); // global rewards in increased

        let now_3 = current_epoch();//timestamp::now_seconds();
        poel::distribute_rewards(deployer); // asset based value is increased now
        let (last_dist_asset_btc, total_dist) = poel::get_total_distributable_rewards_of(asset_btc);
        assert!(last_dist_asset_btc == rewards_1 + rewards_2 + rewards_trivial, 1);
        assert!(total_dist == rewards_1 + rewards_2 + rewards_trivial, 1);
        let btc_index = iAsset::get_asset_rewards_index(asset_btc);
        let sol_index = iAsset::get_asset_rewards_index(asset_sol);

        assert!(btc_index == 60000000000, 1);
        assert!(sol_index == 30000000000, 1);
        let rewards_user_1 = iAsset::calculate_rewards(recipient_1, 0, asset_btc); // rewards for BTC holder
        let rewards_user_2 = iAsset::calculate_rewards(recipient_2, 0, asset_sol); // rewards for SOL holder
        assert!(rewards_user_1 == rewards_user_2, 1);
        assert!(rewards_user_1 == total_dist/2, 1);
        assert!(rewards_user_2 == total_dist/2, 1);

        // 3rd round of rewards
        timestamp::fast_forward_seconds(121); // update the ts
        poel::increase_total_distributable_rewards(rewards_3); // only global value is updated
        let (last_dist_asset, total_dist) = poel::get_total_distributable_rewards_of(asset_btc);
        assert!(last_dist_asset == rewards_1 + rewards_2 + rewards_trivial, 1);
        assert!(total_dist == rewards_1 + rewards_2 + rewards_3 + rewards_trivial, 1); // global rewards in increased

        poel::distribute_rewards(deployer);
        let (last_dist_asset, total_dist) = poel::get_total_distributable_rewards_of(asset_btc);
        assert!(last_dist_asset == rewards_1 + rewards_2 + rewards_3 + rewards_trivial, 1);
        assert!(total_dist == rewards_1 + rewards_2 + rewards_3 + rewards_trivial, 1);
        let btc_index = iAsset::get_asset_rewards_index(asset_btc);
        let sol_index = iAsset::get_asset_rewards_index(asset_sol);

        assert!(btc_index == 50000060000000000, 1);
        assert!(sol_index == 25000030000000000, 1);
        let rewards_user_1 = iAsset::calculate_rewards(recipient_1, 0, asset_btc); // rewards for BTC holder
        let rewards_user_2 = iAsset::calculate_rewards(recipient_2, 0, asset_sol); // rewards for SOL holder
        assert!(rewards_user_1 == rewards_user_2, 1);
        assert!(rewards_user_1 == total_dist/2, 1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle, u1 = @0x71)]
    #[expected_failure(abort_code = 196633, location = poel)]
    fun test_rewards_iasset_transfer_without_new_distributable_rewards(
        supra: &signer,
        deployer: &signer,
        supra_oracles: &signer,
        u1: &signer,
    ) {
        let (btc, sol, eth, dot, _, u2, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        let btc_desired_weight = 65000;
        let sol_desired_weight = 25000;
        let score = 1;
        let u1_addr = signer::address_of(u1);

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_desired_weight, sol_desired_weight, 5000, 5000]);
        iAsset::batch_update_desirability_score(vector[btc], vector[score]);

        let amt10: u64 = 10_00000000;
        poel::borrow_request(btc, amt10, u1_addr, 0, @0x0, 0, @0x0);
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);

        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);

        poel::borrow(btc, u1_addr);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(0); //error
        poel::distribute_rewards(deployer);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle, u1 = @0x71)]
    fun test_rewards_iasset_transfer_with_new_distributable_rewards(
        supra: &signer,
        deployer: &signer,
        supra_oracles: &signer,
        u1: &signer,
    ) {
        let (btc, sol, eth, dot, _, u2, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        let btc_desired_weight = 65000;
        let sol_desired_weight = 25000;
        let score = 1;
        let u1_addr = signer::address_of(u1);

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_desired_weight, sol_desired_weight, 5000, 5000]);
        iAsset::batch_update_desirability_score(vector[btc], vector[score]);

        let amt10: u64 = 10_00000000;
        poel::borrow_request(btc, amt10, u1_addr, 0, @0x0, 0, @0x0);
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);

        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);

        poel::borrow(btc, u1_addr);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);

        let u1_allocatable_rewards = iAsset::get_allocatable_rewards(u1_addr, btc);

        let u1_allocated_rewards = iAsset::get_allocated_rewards(u1_addr);

        assert!(u1_allocatable_rewards == u1_allocated_rewards && u1_allocatable_rewards == 0, 1);
        let asset_entry_btc = iAsset::get_asset_entry(u1_addr, btc);
        let (user_btc_index, _, _, _, _, _, _) = iAsset::deconstruct_asset_entry(option::borrow(&asset_entry_btc));

        let btc_asset_rewards_index = iAsset::get_asset_rewards_index(btc);
        assert!(btc_asset_rewards_index == 100000000, 1);

        iAsset::update_rewards(u1_addr, btc);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);

        let asset_entry_btc = iAsset::get_asset_entry(u1_addr, btc);
        let (user_btc_index, _, _, _, _, _, _) = iAsset::deconstruct_asset_entry(option::borrow(&asset_entry_btc));
        assert!(user_btc_index == 100000000, 1);

        let u1_allocatable_rewards = iAsset::get_allocatable_rewards(u1_addr, btc);
        let u1_allocated_rewards = iAsset::get_allocated_rewards(u1_addr);
        assert!(u1_allocatable_rewards == 1000000000, 1);
        assert!(u1_allocated_rewards == 0, 1);

        iAsset::update_rewards(u1_addr, btc);

        let u1_allocatable_rewards = iAsset::get_allocatable_rewards(u1_addr, btc);
        let u1_allocated_rewards = iAsset::get_allocated_rewards(u1_addr);
        let btc_asset_rewards_index = iAsset::get_asset_rewards_index(btc);
        let asset_entry_btc = iAsset::get_asset_entry(u1_addr, btc);
        let (user_btc_index, _, _, _, _, _, _) = iAsset::deconstruct_asset_entry(option::borrow(&asset_entry_btc));

        assert!(btc_asset_rewards_index == user_btc_index, 1);
        assert!(u1_allocatable_rewards == 0, 1);
        assert!(u1_allocated_rewards == 1000000000, 1);

        let half: u64 = 5_00000000;
        primary_fungible_store::transfer(u1, btc, u2, half);

        // user2 now elegible for rewards, because on this distribution cycle new distributable rewards were added
        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);

        let u1_allocated_rewards = iAsset::get_allocated_rewards(u1_addr);
        let u2_allocated_rewards = iAsset::get_allocated_rewards(u2);

        let u1_allocatable_rewards = iAsset::get_allocatable_rewards(u1_addr, btc);
        let u2_allocatable_rewards = iAsset::get_allocatable_rewards(u2, btc);

        assert!(u1_allocated_rewards + u1_allocatable_rewards == 1500000000, 1);
        assert!(u2_allocated_rewards + u2_allocatable_rewards == 500000000, 1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle, u1 = @0x71)]
    fun test_rewards_iasset_transfer_also_for_user2_iasset(
        supra: &signer,
        deployer: &signer,
        supra_oracles: &signer,
        u1: &signer,
    ) {
        let (btc, sol, eth, dot, _, u2, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );
        let btc_desired_weight = 65000;
        let sol_desired_weight = 25000;
        let score = 1;
        let u1_addr = signer::address_of(u1);

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_desired_weight, sol_desired_weight, 5000, 5000]);
        iAsset::batch_update_desirability_score(vector[btc, sol], vector[score, score]);

        let amt10: u64 = 10_00000000;
        poel::borrow_request(btc, amt10, u1_addr, 0, @0x0, 0, @0x0);
        poel::borrow_request(sol, amt10, u2, 0, @0x0, 0, @0x0);
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);

        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);

        poel::borrow(btc, u1_addr);
        poel::borrow(sol, u2);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1_addr, btc);
        iAsset::update_rewards(u2, sol);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1_addr, btc);
        iAsset::update_rewards(u2, sol);

        let u1_allocated_rewards = iAsset::get_allocated_rewards(u1_addr);
        let u2_allocated_rewards = iAsset::get_allocated_rewards(u2);

        assert!(u1_allocated_rewards == 668069750, 1);
        assert!(u2_allocated_rewards == 331930240, 1);

        let half: u64 = 5_00000000;
        primary_fungible_store::transfer(u1, btc, u2, half);

        // user2 now elegible for rewards of two iAssets
        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);

        let u1_allocated_rewards = iAsset::get_allocated_rewards(u1_addr);
        let u2_allocated_rewards = iAsset::get_allocated_rewards(u2);

        let u1_allocatable_rewards = iAsset::get_allocatable_rewards(u1_addr, btc);
        let u2_allocatable_rewards = iAsset::get_allocatable_rewards(u2, sol);

        assert!(u1_allocated_rewards + u1_allocatable_rewards == 1002104625, 1);
        assert!(u2_allocated_rewards + u2_allocatable_rewards == 663860480, 1);

        let u2_allocated_rewards = iAsset::get_allocated_rewards(u2);

        let u2_allocatable_rewards_btc = iAsset::get_allocatable_rewards(u2, btc);

        assert!(
            u2_allocated_rewards + u2_allocatable_rewards + u2_allocatable_rewards_btc == 997895355,
            1,
        );
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle, u1 = @0x71)]
    fun test_rewards_iasset_burn(
        supra: &signer,
        deployer: &signer,
        supra_oracles: &signer,
        u1: &signer,
    ) {
        let (btc, sol, eth, dot, _, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );
        let btc_desired_weight = 65000;
        let sol_desired_weight = 25000;
        let score = 1;

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_desired_weight, sol_desired_weight, 5000, 5000]);
        iAsset::batch_update_desirability_score(vector[btc], vector[score]);

        let u1_addr = signer::address_of(u1);

        let amt10: u64 = 10_00000000;
        poel::borrow_request(btc, amt10, u1_addr, 0, @0x0, 0, @0x0);
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);

        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);

        poel::borrow(btc, u1_addr);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1_addr, btc);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1_addr, btc);

        let u1_allocated_rewards = iAsset::get_allocated_rewards(u1_addr);

        assert!(u1_allocated_rewards == 1000000000, 1);

        let balance = iAsset::get_iasset_supply(btc);

        assert!(balance == 1000000000, 1);

        // for burning iAssets
        iAsset::redeem_request(u1, 500000000, btc, 0);

        let balance = iAsset::get_iasset_supply(btc);

        assert!(balance == 500000000, 1);

        let u1_allocated_rewards = iAsset::get_allocated_rewards(u1_addr);

        assert!(u1_allocated_rewards == 1000000000, 1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_rewards_distribution_multi_asset_multi_user(
        supra: &signer,
        deployer: &signer,
        supra_oracles: &signer,
    ) {
        let (btc, sol, eth, dot, u1, u2, u3, u4) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        let btc_w = 40000;
        let sol_w = 30000;
        let eth_w = 20000;
        let dot_w = 10000;

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_w, sol_w, eth_w, dot_w]);
        iAsset::batch_update_desirability_score(vector[btc, sol, eth, dot], vector[2,1,3,4]);

        let amt10: u64 = 10_00000000;
        poel::borrow_request(btc, amt10, u1, 0, @0x0, 0, @0x0);
        poel::borrow_request(sol, amt10, u2, 0, @0x0, 0, @0x0);
        poel::borrow_request(eth, amt10, u3, 0, @0x0, 0, @0x0);
        poel::borrow_request(dot, amt10, u4, 0, @0x0, 0, @0x0);

        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);

        poel::borrow(btc, u1);
        poel::borrow(sol, u2);
        poel::borrow(eth, u3);
        poel::borrow(dot, u4);

        iAsset::increase_collateral_supply(btc, amt10);
        iAsset::increase_collateral_supply(sol, amt10);
        iAsset::increase_collateral_supply(eth, amt10);
        iAsset::increase_collateral_supply(dot, amt10);

        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1, btc);
        iAsset::update_rewards(u2, sol);
        iAsset::update_rewards(u3, eth);
        iAsset::update_rewards(u4, dot);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1, btc);
        iAsset::update_rewards(u2, sol);
        iAsset::update_rewards(u3, eth);
        iAsset::update_rewards(u4, dot);

        let r1 = iAsset::get_allocated_rewards(u1);
        let r2 = iAsset::get_allocated_rewards(u2);
        let r3 = iAsset::get_allocated_rewards(u3);
        let r4 = iAsset::get_allocated_rewards(u4);

        assert!(r1 == 670507000, 1);
        assert!(r2 == 162744410, 1);
        assert!(r3 == 502880250, 1);
        assert!(r4 == 663868320, 1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_rewards_get_allocatable_rewards(
        supra: &signer,
        deployer: &signer,
        supra_oracles: &signer,
    ) {
        let (btc, sol, eth, dot, u1, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        // zero, no errors
        let u1_store = primary_fungible_store::ensure_primary_store_exists(u1, btc);
        let u1_allocatable_rewards_on_store = iAsset::get_allocatable_rewards_for_store(u1_store, btc);
        let u1_allocatable_rewards = iAsset::get_allocatable_rewards(u1, btc);        
        assert!(u1_allocatable_rewards == 0, 1);
        assert!(u1_allocatable_rewards == u1_allocatable_rewards_on_store, 1);


        let btc_w = 40000;
        let sol_w = 30000;
        let eth_w = 20000;
        let dot_w = 10000;

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_w, sol_w, eth_w, dot_w]);
        iAsset::batch_update_desirability_score(vector[btc], vector[2]);

        let amt10: u64 = 10_00000000;
        poel::borrow_request(btc, amt10, u1, 0, @0x0, 0, @0x0);

        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);

        poel::borrow(btc, u1);

        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1, btc);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        let u1_allocatable_rewards = iAsset::get_allocatable_rewards(u1, btc);

        let u1_store = primary_fungible_store::ensure_primary_store_exists(u1, btc);
        let u1_allocatable_rewards_on_store = iAsset::get_allocatable_rewards_for_store(u1_store, btc);

        assert!(u1_allocatable_rewards == 2000000000, 1);
        assert!(u1_allocatable_rewards == u1_allocatable_rewards_on_store, 1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_rewards_get_withdrawable_rewardss(
        supra: &signer,
        deployer: &signer,
        supra_oracles: &signer,
    ) {
        let (btc, sol, eth, dot, u1, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        let btc_w = 40000;
        let sol_w = 30000;
        let eth_w = 20000;
        let dot_w = 10000;

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_w, sol_w, eth_w, dot_w]);
        iAsset::batch_update_desirability_score(vector[btc], vector[2]);

        let amt10: u64 = 10_00000000;
        poel::borrow_request(btc, amt10, u1, 0, @0x0, 0, @0x0);

        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);
        poel::borrow(btc, u1);

        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1, btc);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        let allocate_rewards_ts = timestamp::now_seconds();
        iAsset::update_rewards(u1, btc);

        iAsset::claim_rewards(u1);

        let (u1_withdrawable_rewards, _, u1_reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(
            u1,
        );

        assert!(u1_withdrawable_rewards == 2000000000, 1);
        assert!(u1_reward_allocation_timestamp == allocate_rewards_ts, 1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_rewards_claim_rewards(supra: &signer, deployer: &signer, supra_oracles: &signer) {
        let (btc, sol, eth, dot, u1, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        let btc_w = 40000;
        let sol_w = 30000;
        let eth_w = 20000;
        let dot_w = 10000;

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_w, sol_w, eth_w, dot_w]);
        iAsset::batch_update_desirability_score(vector[btc], vector[2]);

        let amt10: u64 = 10_00000000;
        poel::borrow_request(btc, amt10, u1, 0, @0x0, 0, @0x0);

        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);
        poel::borrow(btc, u1);

        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1, btc);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        let allocate_rewards_ts = timestamp::now_seconds();
        iAsset::update_rewards(u1, btc);

        let claim_ts = timestamp::now_seconds();
        // claimed_rewards has value, ready_to_withdraw == 0
        let claimed_rewards = iAsset::claim_rewards(u1);
        assert!(claimed_rewards == 2000000000, 1);

        let (u1_withdrawable_rewards, _, u1_reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(
            u1,
        );

        assert!(u1_withdrawable_rewards == 2000000000, 1);
        assert!(u1_reward_allocation_timestamp == allocate_rewards_ts, 1);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);
        iAsset::update_rewards(u1, btc);
        iAsset::update_rewards(u1, btc);
        timestamp::fast_forward_seconds(48*60*1000);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);

        iAsset::update_recent_cycle_update_epoch(3);
        // claimed_rewards == 0 , ready_to_withdraw > 0

        let ready_to_withdraw = iAsset::withdraw_rewards(u1);
        let (u1_withdrawable_rewards, _, u1_reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(
            u1,
        );

        assert!(ready_to_withdraw == 2000000000, 1);
        assert!(u1_withdrawable_rewards == 0, 1);
        assert!(u1_reward_allocation_timestamp == claim_ts, 1);

        let r1 = iAsset::get_allocated_rewards(u1);
        assert!(r1 == 2000000000, 1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_rewards_post_claim_new_rewards(supra: &signer, deployer: &signer, supra_oracles: &signer) {
        let (btc, sol, eth, dot, u1, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        let btc_w = 40000;
        let sol_w = 30000;
        let eth_w = 20000;
        let dot_w = 10000;

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_w, sol_w, eth_w, dot_w]);
        iAsset::batch_update_desirability_score(vector[btc], vector[2]);

        let amt10: u64 = 10_00000000;
        poel::borrow_request(btc, amt10, u1, 0, @0x0, 0, @0x0);

        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);

        poel::borrow(btc, u1);

        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1, btc);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        let allocate_rewards_ts = timestamp::now_seconds();
        iAsset::update_rewards(u1, btc);

        iAsset::claim_rewards(u1);

        let (u1_withdrawable_rewards, u1_reward_allocation_OLC_index, u1_reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(
            u1,
        );

        assert!(u1_withdrawable_rewards == 2000000000, 1);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);
        iAsset::update_rewards(u1, btc);
        iAsset::update_rewards(u1, btc);
        timestamp::fast_forward_seconds(48*60*1000);
        iAsset::update_recent_cycle_update_epoch(3);

        let ready_to_withdraw = iAsset::withdraw_rewards(u1);

        let (u1_withdrawable_rewards, _, u1_reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(
            u1,
        );

        assert!(ready_to_withdraw == 2000000000, 1);
        assert!(u1_withdrawable_rewards == 0, 1);
        assert!(u1_reward_allocation_timestamp == allocate_rewards_ts, 1);

        let r1 = iAsset::get_allocated_rewards(u1);
        assert!(r1 == 2000000000, 1);

        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1, btc);
        let r1 = iAsset::get_allocated_rewards(u1);
        assert!(r1 == 4000000000, 1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_rewards_borrow_after_claimed_previous_rewards(
        supra: &signer,
        deployer: &signer,
        supra_oracles: &signer,
    ) {
        let (btc, sol, eth, dot, u1, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        let btc_w = 40000;
        let sol_w = 30000;
        let eth_w = 20000;
        let dot_w = 10000;

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_w, sol_w, eth_w, dot_w]);
        iAsset::batch_update_desirability_score(vector[btc], vector[2]);

        let amt10: u64 = 10_00000000;
        poel::borrow_request(btc, amt10, u1, 0, @0x0, 0, @0x0);

        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);
        poel::borrow(btc, u1);

        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1, btc);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        let allocate_rewards_ts = timestamp::now_seconds();
        iAsset::update_rewards(u1, btc);

        iAsset::claim_rewards(u1);

        let (u1_withdrawable_rewards, u1_reward_allocation_OLC_index, u1_reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(
            u1,
        );

        assert!(u1_withdrawable_rewards == 2000000000, 1);

        // borrow_request of 5 btc after claim rewards
        poel::borrow_request(btc, 10_00000000, u1, 0, @0x0, 0, @0x0);
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);
        poel::borrow(btc, u1);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1, btc);

        let r1 = iAsset::get_allocated_rewards(u1);

        assert!(r1 == 1000000000, 1);

        let (u1_withdrawable_rewards, u1_reward_allocation_OLC_index, u1_reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(
            u1,
        );

        assert!(u1_withdrawable_rewards == 2000000000, 1);

        timestamp::fast_forward_seconds(48*60*1000);
        iAsset::update_recent_cycle_update_epoch(3);
        let  ready_to_withdraw = iAsset::withdraw_rewards(u1);

        assert!(ready_to_withdraw == 2000000000, 1);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);
        iAsset::update_rewards(u1, btc);
        iAsset::update_rewards(u1, btc);

        iAsset::claim_rewards(u1);

        let (u1_withdrawable_rewards, _, _) = iAsset::get_withdrawable_rewards(u1);

        assert!(u1_withdrawable_rewards == 2000000000, 1);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(1_000_000_000);
        poel::distribute_rewards(deployer);
        iAsset::update_rewards(u1, btc);
        iAsset::update_rewards(u1, btc);

        timestamp::fast_forward_seconds(48*60*1000);

        iAsset::update_recent_cycle_update_epoch(5);
        let  ready_to_withdraw = iAsset::withdraw_rewards(u1);
        let (u1_withdrawable_rewards, u1_reward_allocation_OLC_index, _) = iAsset::get_withdrawable_rewards(
            u1,
        );

        assert!(ready_to_withdraw == 2000000000, 1);
        assert!(u1_withdrawable_rewards == 0, 1);
        assert!(u1_reward_allocation_OLC_index == 0, 1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    #[expected_failure(abort_code = 65554, location = iAsset)]
    fun test_rewards_claim_rewards_no_allocation(
        supra: &signer,
        deployer: &signer,
        supra_oracles: &signer,
    ) {
        let (btc, sol, eth, dot, u1, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        let btc_w = 40000;
        let sol_w = 30000;
        let eth_w = 20000;
        let dot_w = 10000;

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_w, sol_w, eth_w, dot_w]);
        iAsset::batch_update_desirability_score(vector[btc], vector[2]);

        let amt10: u64 = 10_00000000;
        poel::borrow_request(btc, amt10, u1, 0, @0x0, 0, @0x0);

        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);
        poel::borrow(btc, u1);

        iAsset::claim_rewards(u1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    #[expected_failure]
    fun test_rewards_claim_rewards_before_lockup(
        supra: &signer,
        deployer: &signer,
        supra_oracles: &signer,
    ) {
        let (btc, sol, eth, dot, u1, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        let btc_w = 40000;
        let sol_w = 30000;
        let eth_w = 20000;
        let dot_w = 10000;

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_w, sol_w, eth_w, dot_w]);
        iAsset::batch_update_desirability_score(vector[btc], vector[2]);

        let amt10: u64 = 10_00000000;
        poel::borrow_request(btc, amt10, u1, 0, @0x0, 0, @0x0);

        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();

        poel::borrow(btc, u1);

        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1, btc);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        let allocate_rewards_ts = timestamp::now_seconds();
        iAsset::update_rewards(u1, btc);

        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        iAsset::withdraw_rewards(u1);

        let (u1_withdrawable_rewards, _, u1_reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(
            u1,
        );

        assert!(u1_withdrawable_rewards == 2000000000, 1);
        assert!(u1_reward_allocation_timestamp == allocate_rewards_ts, 1);

        iAsset::claim_rewards(u1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_get_total_withdrawn_reward(supra: &signer, deployer: &signer, supra_oracles: &signer) {
        let (btc, sol, eth, dot, u1, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        let btc_w = 40000;
        let sol_w = 30000;
        let eth_w = 20000;
        let dot_w = 10000;

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_w, sol_w, eth_w, dot_w]);
        iAsset::batch_update_desirability_score(vector[btc], vector[2]);

        let amt10: u64 = 10_00000000;
        poel::borrow_request(btc, amt10, u1, 0, @0x0, 0, @0x0);

        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);
        poel::borrow(btc, u1);

        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        iAsset::update_rewards(u1, btc);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        let allocate_rewards_ts = timestamp::now_seconds();
        iAsset::update_rewards(u1, btc);



        iAsset::claim_rewards(u1);

        let (u1_withdrawable_rewards, _, u1_reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(
            u1,
        );

        assert!(u1_withdrawable_rewards == 2000000000, 1);
        assert!(u1_reward_allocation_timestamp == allocate_rewards_ts, 1);

        iAsset::update_recent_cycle_update_epoch(4);

        timestamp::fast_forward_seconds(121);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);
        iAsset::update_rewards(u1, btc);
        timestamp::fast_forward_seconds(48*60*1000);

        iAsset::update_recent_cycle_update_epoch(4);

        let ready_to_withdraw = iAsset::withdraw_rewards(u1);

        let (u1_withdrawable_rewards, _, u1_reward_allocation_timestamp) = iAsset::get_withdrawable_rewards(
            u1,
        );
        assert!(ready_to_withdraw == 2000000000, 1);
        assert!(u1_withdrawable_rewards == 0, 1);

        let total_withdrawn_rewards = iAsset::get_total_withdrawn_reward(u1);

        assert!(total_withdrawn_rewards == 2000000000, 1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_get_allocated_rewards_for_asset(supra: &signer, deployer: &signer, supra_oracles: &signer) {
        let (btc, sol, eth, dot, u1, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        let btc_w = 40000;
        let sol_w = 30000;
        let eth_w = 20000;
        let dot_w = 10000;

        let amt10: u64 = 10_00000000;

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_w, sol_w, eth_w, dot_w]);

        iAsset::batch_update_desirability_score(vector[btc, sol, eth, dot], vector[2, 1, 3, 4]);

        // check for btc
        let (_, w, s) = iAsset::get_asset_collateral_supply_weight_score(btc);
        assert!(w == btc_w && s == 2, 1);

        // check for sol
        let (_, w, s) = iAsset::get_asset_collateral_supply_weight_score(sol);
        assert!(w == sol_w && s == 1, 1);

        // check for eth
        let (_, w, s) = iAsset::get_asset_collateral_supply_weight_score(eth);
        assert!(w == eth_w && s == 3, 1);

        // check for dot
        let (_, w, s) = iAsset::get_asset_collateral_supply_weight_score(dot);
        assert!(w == dot_w && s == 4, 1);

        poel::borrow_request(btc, amt10, u1, 0, @0x0, 0, @0x0);
        poel::borrow_request(sol, amt10, u1, 0, @0x0, 0, @0x0);
        poel::borrow_request(eth, amt10, u1, 0, @0x0, 0, @0x0);
        poel::borrow_request(dot, amt10, u1, 0, @0x0, 0, @0x0);
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);
        poel::borrow(btc, u1);
        poel::borrow(sol, u1);
        poel::borrow(eth, u1);
        poel::borrow(dot, u1);

        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(2_000_000_000);
        poel::distribute_rewards(deployer);

        let allocated_btc = iAsset::get_allocated_rewards_for_asset(btc);
        let allocated_sol = iAsset::get_allocated_rewards_for_asset(sol);
        let allocated_eth = iAsset::get_allocated_rewards_for_asset(eth);
        let allocated_dot = iAsset::get_allocated_rewards_for_asset(dot);

        assert!(allocated_btc == 670507005, 1);
        assert!(allocated_sol == 162744418, 1);
        assert!(allocated_eth == 502880253, 1);
        assert!(allocated_dot == 663868322, 1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_get_asset_apy(supra: &signer, deployer: &signer, supra_oracles: &signer) {
        let (btc, sol, eth, dot, u1, _, _, _) = setup_env_with_users_and_assets(
            supra,
            deployer,
            supra_oracles,
            true,
        );

        let btc_w = 40000;
        let sol_w = 30000;
        let eth_w = 20000;
        let dot_w = 10000;

        let amt1: u64 = 1_00000000;

        iAsset::batch_update_desired_weight(vector[btc, sol, eth, dot], vector[btc_w, sol_w, eth_w, dot_w]);
        iAsset::batch_update_desirability_score(vector[btc, sol, eth, dot], vector[2, 1, 3, 4]);

        poel::borrow_request(btc, amt1, u1, 0, @0x0, 0, @0x0);
        poel::borrow_request(sol, amt1, u1, 0, @0x0, 0, @0x0);
        poel::borrow_request(eth, amt1, u1, 0, @0x0, 0, @0x0);
        poel::borrow_request(dot, amt1, u1, 0, @0x0, 0, @0x0);
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(3600);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);
        poel::borrow(btc, u1);
        poel::borrow(sol, u1);
        poel::borrow(eth, u1);
        poel::borrow(dot, u1);

        // 1st round of rewards dist
        timestamp::fast_forward_seconds(120);
        poel::increase_total_distributable_rewards(100_00000000); // 100 supra
        poel::distribute_rewards(deployer);

        // apy in 1 hour
        let (btc_apy, _) = iAsset::get_asset_apy(btc);
        let (sol_apy, _) = iAsset::get_asset_apy(sol);
        let (eth_apy, _) = iAsset::get_asset_apy(eth);
        let (dot_apy, _) = iAsset::get_asset_apy(dot);

        let (btc_apy0, btc_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(btc);
        let (sol_apy0, sol_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(sol);
        let (eth_apy0, eth_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(eth);
        let (dot_apy0, dot_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(dot);

        // no epoch differences
        assert!(btc_apy == 0 && btc_apy0 == 0 && btc_apy0_epoch == 0, 1);
        assert!(sol_apy == 0 && sol_apy0 == 0 && sol_apy0_epoch == 0, 1);
        assert!(eth_apy == 0 && eth_apy0 == 0 && eth_apy0_epoch == 0, 1);
        assert!(dot_apy == 0 && dot_apy0 == 0 && dot_apy0_epoch == 0, 1);

        // 2nd round of rewards dist
        timestamp::fast_forward_seconds(120);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(120);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(120);
        reconfiguration::reconfigure_for_test_custom();
        let epoch1 = current_epoch();
        poel::increase_total_distributable_rewards(400_00000000); // 400 supra
        poel::distribute_rewards(deployer);

        let (btc_apy, _) = iAsset::get_asset_apy(btc);
        let (sol_apy, _) = iAsset::get_asset_apy(sol);
        let (eth_apy, _) = iAsset::get_asset_apy(eth);
        let (dot_apy, _) = iAsset::get_asset_apy(dot);

        let (btc_apy0, btc_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(btc);
        let (sol_apy0, sol_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(sol);
        let (eth_apy0, eth_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(eth);
        let (dot_apy0, dot_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(dot);

        assert!(btc_apy0_epoch == epoch1, 1);
        assert!(sol_apy0_epoch == epoch1, 1);
        assert!(eth_apy0_epoch == epoch1, 1);
        assert!(dot_apy0_epoch == epoch1, 1);

        assert!(btc_apy == 23494565 && btc_apy0 == 23494565 , 1);
        assert!(sol_apy == 11405128 && sol_apy0 == 11405128, 1);
        assert!(eth_apy == 35241848 && eth_apy0 == 35241848, 1);
        assert!(dot_apy == 46523892 && dot_apy0 == 46523892, 1);

        // 3nd round of rewards dist
        timestamp::fast_forward_seconds(120);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(120);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(120);
        reconfiguration::reconfigure_for_test_custom();

        let epoch2 = current_epoch();
        poel::increase_total_distributable_rewards(200_00000000); // 200 supra
        poel::distribute_rewards(deployer);

        let (btc_apy0, btc_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(btc);
        let (sol_apy0, sol_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(sol);
        let (eth_apy0, eth_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(eth);
        let (dot_apy0, dot_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(dot);

        assert!(epoch2 > epoch1 , 1);
        assert!(btc_apy0 == 93978261 && btc_apy0_epoch == epoch2 , 1);
        assert!(sol_apy0 == 45620515 && sol_apy0_epoch == epoch2, 1);
        assert!(eth_apy0 == 140967392 && eth_apy0_epoch == epoch2, 1);
        assert!(dot_apy0 == 186095568 && dot_apy0_epoch == epoch2, 1);

        // 4nd round, not completed for APY period
        timestamp::fast_forward_seconds(120);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(120);
        reconfiguration::reconfigure_for_test_custom();

        let epoch3 = current_epoch();
        poel::increase_total_distributable_rewards(200_00000000); // 200 supra
        poel::distribute_rewards(deployer);

        let (btc_apy0, btc_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(btc);
        let (sol_apy0, sol_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(sol);
        let (eth_apy0, eth_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(eth);
        let (dot_apy0, dot_apy0_epoch) = iAsset::get_asset_apy_and_epoch_update(dot);

        // apy the same.
        assert!(epoch3 > epoch2 , 1);
        assert!(btc_apy0 == 93978261 && btc_apy0_epoch == epoch2 , 1);
        assert!(sol_apy0 == 45620515 && sol_apy0_epoch == epoch2, 1);
        assert!(eth_apy0 == 140967392 && eth_apy0_epoch == epoch2, 1);
        assert!(dot_apy0 == 186095568 && dot_apy0_epoch == epoch2, 1);

    }
}