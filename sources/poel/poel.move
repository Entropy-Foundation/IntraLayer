/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
module dfmm_framework::poel {
    use aptos_std::object::{Self, ExtendRef, Object};
    use aptos_std::vector;
    use aptos_std::signer;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::table::{Self, Table};
    use aptos_std::error;
    use aptos_std::fungible_asset::{Metadata};
    use supra_framework::math64::{
        Self, min, max, mul_div
    };
    use supra_framework::stake::{get_validator_state};
    use supra_framework::pbo_delegation_pool::{unlock, get_delegation_pool_stake, add_stake, withdraw, get_stake, get_pending_withdrawal, delegation_pool_exists};
    use supra_framework::account;
    use supra_framework::chain_id;
    use supra_framework::supra_account;
    use supra_framework::coin;
    use supra_framework::supra_coin::SupraCoin;
    use supra_framework::timestamp;
    use supra_framework::reconfiguration::{current_epoch};
    use supra_framework::event::{Self};
    use dfmm_framework::iAsset::{
        AssetCalculationInfo,
        Self,
        mint_iasset, premint_iasset, calculate_nominal_liquidity,
        calculate_collateralization_rate, calculate_principle, get_assets,
        get_asset_price, deconstruct_asset_price,
        update_borrow_request, update_reward_index,
        get_liquidity_table_items, deconstruct_liquidity_table_items,
        get_coll_rate_multiplier,
    };
    use dfmm_framework::redeem_router;
    use dfmm_framework::config;
    use dfmm_framework::asset_util;
    use dfmm_framework::asset_config;

    friend dfmm_framework::evm_hypernova_adapter;
    friend dfmm_framework::asset_router;


    /// Thrown when the caller's balance is insufficient.
    const EINSUFICIENT_CALLER_BALANCE: u64 = 6;

    /// Thrown when the requested amount exceeds the allowed amount
    const EAMOUNT_EXCEEDED: u64 = 11;

    /// automation invocation is not in sync mode
    const ENOT_SYNC_STATE: u64 = 12;

    /// Thrown when the request amount is zero
    const EAMOUNT_ZERO: u64 = 13;

    /// Thrown when a pool is already registered
    const EPOOL_REGISTERED: u64 = 16;

    /// Thrown when a request is not registered.
    const EREQUEST_NOT_FOUND: u64 = 17;

    /// Thrown when a request is already registered
    const EREQUEST_REGISTERED: u64 = 18;

    /// Thrown when insufficient time has passed
    const ENOT_ENOUGH_TIME_PASSED: u64 = 19;

    /// Thrown when request is still being processed
    const EREQUEST_IN_PROGRESS: u64 = 21;

    const EPOOL_NOT_REGISTERED: u64 = 22;

    /// Delegated amount of the replaced pool exceeds the total delegated amount
    const EREPLACED_POOL_DELEGATED_TOO_HIGH: u64 = 24;

    /// No rewards to distribute
    const ENO_DISTRIBUTABLE_REWARDS: u64 = 25;

    /// Pool is not active
    const EPOOL_NOT_ACTIVE: u64 = 26;

    /// Pool has not zero leftover
    const EPOOL_LEFTOVER_COINS: u64 = 28;

    /// Delegation cap reached
    const DELEGATION_CAP_REACHED: u64 = 29;

    /// No stimulation rewards to distribute
    const ENO_STIMULATION_REWARDS: u64 = 30;

    /// Replaced pool has inactive and pending inactive tokens
    const EREPLACED_POOL_HAS_INACTIVE_PENDING_INACTIVE: u64 = 31;

    /// Seed  for the total liquidity object for easy access
    const POEL_STORAGE_ADDRESS: vector<u8> = b"PoELStorageGlobal";
    
    /// Seed for treasure resource account that keeps all funds
    const POEL_VAULT_SEED: vector<u8> = b"POEL_VAULT";

    /// Multiplier for reward reduction calculations
    const REWARD_CALCULATION_MULTIPLIER :u64 = 10000;

    /// Minimum amount used to satisfy minimum staking and unlocking requirements of delegation pools
    const MIN_COINS_ON_SHARES_POOL: u64 = 100000000;

    /// Decimal precision for assets
    const ASSET_DECIMALS: u8 = 8;

    const VALIDATOR_STATUS_ACTIVE: u64 = 2; // constant from stake.move

    #[event]
    struct DelegationPoolsInitializedEvent has copy, drop, store {
      pools: vector<address>,
    }

    #[event]
    struct CapitalEfficiencyCoefficientUpdatedEvent has copy, drop, store {
      new_coefficient: u64,
    }

    #[event]
    struct RewardsAllocatedEvent has copy, drop, store {
      total_reward_earned: u64,
      total_distributable: u64,
      reward_budget_remaining: u64,
    }

    #[event]
    struct RewardsDistributedEvent has copy, drop, store {
      asset: Object<Metadata>,
      amount: u64,
    }

    #[event]
    struct BorrowedAmountUpdatedEvent has copy, drop, store {
      epoch: u64,
      total_delegated_amount: u64,
      total_borrowed_amount: u64,
    }

    #[event]
    struct BorrowableAmountIncreasedEvent has copy, drop, store {
      old_borrowable_amount: u64,
      new_borrowable_amount: u64,
    }

    #[event]
    struct BorrowableAmountDecreaseRequestEvent has copy, drop, store {
      requested_amount: u64,
      withdraw_requested_assets: u64,
      withdraw_request_epoch: u64,
    }

    #[event]
    struct BorrowRequestEvent has copy, drop, store {
      asset: address,
      user_amount: u64,
      user_address: address,
      service_fee: u64,
      service_fee_address: address,
      relayer_fee: u64,
      relayer_fee_address: address,
    }

    #[event]
    struct BorrowEvent has copy, drop, store {
      asset: address,
      amount: u64,
      account: address,
    }

    #[event]
    struct MultiAssetExtraRewardsAddedEvent has copy, drop, store {
      amount: u64,
    }

    #[event]
    struct SingleAssetExtraRewardsAddedEvent has copy, drop, store {
      asset: address,
      amount: u64,
    }

    #[event]
    struct DelegationPoolReplacedEvent has copy, drop, store {
      old_pool_address: address,
      new_pool_address: address,
    }

    #[event]
    struct RewardsClaimedEvent has copy, drop, store {
      account: address,
      amount: u64,
    }

    #[event]
    struct RewardsWithdrawnEvent has copy, drop, store {
      account: address,
      amount: u64,
    }

    #[event]
    struct StimulationRewardsWithdrawnEvent has copy, drop, store {
      account: address,
      amount: u64,
    }

    #[event]
    struct SurplusRewardsWithdrawnEvent has copy, drop, store {
      account: address,
      amount: u64,
    }

    #[event]
    struct IAssetCreatedEvent has copy, drop, store {
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        pair_id: u32,
        origin_token_address: vector<u8>,
        origin_token_chain_id: u64,
        origin_token_decimals: u16,
        source_bridge_address: vector<u8>,
        iasset: Object<Metadata>,
    }

    #[event]
    struct RedeemEvent has copy, drop, store {
        account: address, // user
        asset: address, // iasset
        amount: u64, // assets to withdraw 
        origin_token_amount : u128, // scaled amount
        origin_token_address : vector<u8>, 
        origin_token_chain_id : u64, // chain id
        source_bridge_address : vector<u8>, // bridge
        destination_address : vector<u8> // receiver
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Stores reward budget and distribution data
    struct RewardBudget has key {
        /// Total reward budget
        reward_budget: u64,
        /// Capital efficiency coefficient for reward calculations
        capital_efficiency_coefficient: u64,
        /// Total rewards available for distribution
        total_distributable_rewards: u64,
        /// Last rewards per asset
        last_distributable_rewards: SmartTable<Object<Metadata>, u64>,
        /// Timestamp of last reward allocation
        allocation_ts: u64,
        /// Total allocated reward balance
        allocated_reward_balance: u64,
        /// Tracks extra rewards for assets for a single asset
        single_asset_reward_balance: Table<Object<Metadata>, u64>,
        /// Tracks extra rewards for assets for multiple asset
        multiple_asset_reward_balance: u64,
        /// Track stimulation rewards according to the reduction rate
        stimulation_rewards_accumulated: u64,
        /// Track already claimed stimulation rewards
        stimulation_rewards_claimed: u64,
        /// Track the epoch when stimulation rewards were claimed
        stimulation_rewards_claim_epoch: u64
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Stores the list of delegation pools
    struct DelegationPools has key {
        pools: vector<address>,
        /// Reserved variable to have another way of identification of cycle change
        total_olc_index : u128,
        replace_delegation_pool: ReplacedDelegationPool
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Tracks delegated and borrowable $SUPRA amounts
    struct DelegatedAmount has key {
        /// Total $SUPRA delegated to pools
        total_delegated_amount: u64,
        /// Total $SUPRA available for borrowing
        total_borrowable_amount: u64,
        /// Total $SUPRA currently borrowed
        total_borrowed_amount: u64,
        /// Amount unlocked in the previous cycle
        previous_unlocked_amount: u64,
        /// Epoch of last borrowed amount update
        borrowed_amount_update_epoch: u64,
        /// Timestamp of last borrowed amount update
        borrowed_amount_update_ts: u64,
        /// Timestamp of penultimate borrowed amount update
        previous_borrowed_amount_update_ts: u64,
        /// Total amount of $Supra tokens requested for withdrawal
        withdraw_requested_assets: u64,
        /// Timestep of the last withdrawal request submitted by the admin
        withdraw_request_epoch: u64,
    }

    /// Tracks details of a replaced delegation pool
    struct ReplacedDelegationPool has store, copy, drop {
        /// Address of the replaced pool
        pool: address,
        /// Lockup Cycle Index of replacement request
        lockup_cycle_update_epoch: u64,
        /// Amount delegated to the replaced pool
        delegated: u64,
    }
    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct PoelControler has key {
        extend_ref: ExtendRef,
        // Signer capability of the resource account owning the funds pool
        vault_signer_cap: account::SignerCapability,
    }

    struct AssetSpecific has drop {
        asset: Object<Metadata>,
        collateral_supply: u64,
        asset_specific_borrowed_amount_with_desirability_scores: u128,
        desirability_score: u64,
    }

    struct RewardsBudgetInfo has copy, drop {
        rewards_budget : u64,
        capital_efficiency_coefficient: u64,
        total_distributable_rewards : u64,
        allocation_ts : u64,
        stimulation_rewards_accumulated: u64,
        stimulation_rewards_claimed: u64,
        stimulation_rewards_claim_epoch: u64
    }

    struct DelegatedAmountsInfo has copy, drop {
        total_delegated_amount : u64,
        total_borrowable_amount : u64,
        total_borrowed_amount : u64,
    }

    struct DelegatedAmountFullInfo has copy, drop {
        total_delegated_amount: u64,
        total_borrowable_amount: u64,
        total_borrowed_amount: u64,
        previous_unlocked_amount: u64,
        borrowed_amount_update_epoch: u64,
        borrowed_amount_update_ts: u64,
        previous_borrowed_amount_update_ts: u64,
        withdraw_requested_assets: u64,
        withdraw_request_epoch: u64,
    }

    fun init_module(account: &signer) {
        let constructor_ref = &object::create_named_object(account, POEL_STORAGE_ADDRESS);

        let obj_signer = &object::generate_signer(constructor_ref);

        let extend_ref = object::generate_extend_ref(constructor_ref);

        // create a resource account to keep all supra coins
        let (vault_signer, vault_signer_cap) = account::create_resource_account(account, POEL_VAULT_SEED);
        coin::register<SupraCoin>(&vault_signer);

        move_to(obj_signer, PoelControler {
            extend_ref: extend_ref,
            vault_signer_cap : vault_signer_cap, // store signer capability of the resource account that keeps all supra coins
        });

        move_to(obj_signer, DelegationPools {
            pools: vector::empty<address>(),
            total_olc_index : 0,
            replace_delegation_pool: ReplacedDelegationPool {
              pool: @0x0,
              lockup_cycle_update_epoch:0,
              delegated: 0
            }
        });

        move_to(obj_signer, DelegatedAmount {
            total_delegated_amount: 0,
            total_borrowable_amount: 0,
            total_borrowed_amount: 0,
            previous_unlocked_amount: 0,
            borrowed_amount_update_epoch: 0,
            borrowed_amount_update_ts: 0,
            withdraw_requested_assets: 0,
            withdraw_request_epoch: 0,
            previous_borrowed_amount_update_ts: 0,
        });

        move_to(obj_signer, RewardBudget {
            reward_budget: 0,
            capital_efficiency_coefficient: 0,
            total_distributable_rewards: 0,
            last_distributable_rewards: smart_table::new(),
            allocation_ts : 0,
            allocated_reward_balance: 0,
            single_asset_reward_balance: table::new(),
            multiple_asset_reward_balance: 0,
            stimulation_rewards_accumulated: 0,
            stimulation_rewards_claimed: 0,
            stimulation_rewards_claim_epoch: 0
        });
    }

    public entry fun initialize_delegation_pools(account: &signer, delegation_pools: vector<address>) acquires DelegationPools {
        config::assert_admin(account);
        let ref = borrow_global_mut<DelegationPools>(get_storage_address());
        vector::for_each_ref<address>(&delegation_pools, |pool| {
            assert!(!vector::contains(&ref.pools, pool), error::invalid_state(EPOOL_REGISTERED));
            assert!(delegation_pool_exists(*pool), error::invalid_state(EPOOL_NOT_REGISTERED));
            vector::push_back(&mut ref.pools, *pool);
        });

        event::emit<DelegationPoolsInitializedEvent>(
            DelegationPoolsInitializedEvent {
                pools: delegation_pools,
            }
        );
    }

    fun get_storage_address(): address {
        object::create_object_address(&@dfmm_framework, POEL_STORAGE_ADDRESS)
    }

    #[view]
    /// Returns information about delegation (total_delegated_amount, total_borrowable_amount, total_borrowed_amount)
    public fun get_delegated_amounts(): DelegatedAmountsInfo acquires DelegatedAmount {
        let delegated_amount_ref = borrow_global<DelegatedAmount>(get_storage_address());
        DelegatedAmountsInfo {
            total_delegated_amount : delegated_amount_ref.total_delegated_amount,
            total_borrowable_amount :delegated_amount_ref.total_borrowable_amount,
            total_borrowed_amount : delegated_amount_ref.total_borrowed_amount,
        }
    }

    #[view]
    /// Returns full information about the delegation state.
    /// (total_delegated_amount, total_borrowable_amount, total_borrowed_amount, previous_unlocked_amount, borrowed_amount_update_epoch, borrowed_amount_update_ts, previous_borrowed_amount_update_ts, withdraw_requested_assets, withdraw_request_epoch)
    public fun get_delegated_amount_full(): DelegatedAmountFullInfo acquires DelegatedAmount {
        let delegated_amount_ref = borrow_global<DelegatedAmount>(get_storage_address());
        DelegatedAmountFullInfo {
            total_delegated_amount : delegated_amount_ref.total_delegated_amount,
            total_borrowable_amount :delegated_amount_ref.total_borrowable_amount,
            total_borrowed_amount : delegated_amount_ref.total_borrowed_amount,
            previous_unlocked_amount : delegated_amount_ref.previous_unlocked_amount,
            borrowed_amount_update_epoch : delegated_amount_ref.borrowed_amount_update_epoch,
            borrowed_amount_update_ts : delegated_amount_ref.borrowed_amount_update_ts,
            previous_borrowed_amount_update_ts : delegated_amount_ref.previous_borrowed_amount_update_ts,
            withdraw_requested_assets : delegated_amount_ref.withdraw_requested_assets,
            withdraw_request_epoch : delegated_amount_ref.withdraw_request_epoch,
        }
    }

    public fun deconstruct_delegated_amounts (item: &DelegatedAmountsInfo): (u64, u64, u64) {
        (item.total_delegated_amount, item.total_borrowable_amount, item.total_borrowed_amount)
    }

    #[view]
    public fun get_allocated_rewards_balance(): u64 acquires RewardBudget {
        let reward_budget_ref = borrow_global<RewardBudget>(get_storage_address());
        reward_budget_ref.allocated_reward_balance
    }

    #[view]
    /// Returns the address of the PoEL vault holding $SUPRA coins
    public fun get_vault_address(): address {
        account::create_resource_address(&@dfmm_framework, POEL_VAULT_SEED)
    }

    #[view]
    /// Returns the addresses of delegation pools
    public fun get_delegation_pools(): vector<address> acquires DelegationPools {
        borrow_global<DelegationPools>(get_storage_address()).pools
    }

    #[view]
    /// Returns information about rewards budget (rewards_budget, capital_efficiency_coefficient, total_distributable_rewards, allocation_ts)
    public fun get_reward_budget(): RewardsBudgetInfo acquires RewardBudget {
        let ref = borrow_global<RewardBudget>(get_storage_address());
        RewardsBudgetInfo{
            rewards_budget: ref.reward_budget,
            capital_efficiency_coefficient : ref.capital_efficiency_coefficient,
            total_distributable_rewards : ref.total_distributable_rewards,
            allocation_ts : ref.allocation_ts,
            stimulation_rewards_accumulated: ref.stimulation_rewards_accumulated,
            stimulation_rewards_claimed: ref.stimulation_rewards_claimed,
            stimulation_rewards_claim_epoch: ref.stimulation_rewards_claim_epoch
        }
    }

    #[view]
    public fun get_replaced_delegation_pool(): ReplacedDelegationPool acquires DelegationPools {
        let delegation_pool_ref = borrow_global<DelegationPools>(get_storage_address());
        delegation_pool_ref.replace_delegation_pool
    }

    public fun deconstruct_replaced_delegation_pool (item: &ReplacedDelegationPool): (address, u64, u64) {
        (item.pool, item.lockup_cycle_update_epoch, item.delegated)
    }

    #[view]
    public fun get_total_staked () : u64 acquires DelegationPools{
        let pools_ref = borrow_global<DelegationPools>(get_storage_address());
        let vault_address = get_vault_address();
        vector::fold(pools_ref.pools, 0, |t, pool_address|
        {
            let (active_stake, _, _) = get_stake(pool_address, vault_address);
            t + active_stake
        })
    }

    #[view]
    /// Returns the APY for a given asset
    public fun get_asset_apy(asset: Object<Metadata>): (u64, u64) {
        iAsset::get_asset_apy(asset)
    }

    fun get_obj_signer(): signer acquires PoelControler {
        let extend_ref = borrow_global<PoelControler>(get_storage_address());
        object::generate_signer_for_extending(&extend_ref.extend_ref)
    }

    /// Returns signer of the PoEL Vault. All supra coins are accumulated here
    fun get_vault_signer(): signer acquires PoelControler {
        let poel_controler = borrow_global<PoelControler>(get_storage_address());
        account::create_signer_with_capability(&poel_controler.vault_signer_cap)
    }

    /// Updates the capital efficiency coefficient for reward calculations
    public entry fun update_capital_efficiency_coefficient(account: &signer, value: u64) acquires RewardBudget {
        config::assert_admin(account);
        let obj_address = get_storage_address();

        let reward_budget_ref = borrow_global_mut<RewardBudget>(obj_address);

        reward_budget_ref.capital_efficiency_coefficient = value;

        event::emit<CapitalEfficiencyCoefficientUpdatedEvent>(
            CapitalEfficiencyCoefficientUpdatedEvent {
                new_coefficient: value,
            }
        );
    }

    /// Update existing oracle pair IDs for the assets with new values
    public entry fun batch_update_pair_ids(account: &signer, assets: vector<Object<Metadata>>, pair_ids: vector<u32>) {
        config::assert_owner(account);
        iAsset::batch_update_pair_ids(assets, pair_ids);
    }

    /// Unlocks SUPRA tokens from delegation pools
    fun unlock_tokens(supra_amount: u64, total_delegated_amount: u64) :u64 acquires DelegationPools, PoelControler {
        let storage_address = get_storage_address();
        let pools_ref = borrow_global_mut<DelegationPools>(storage_address);
        let replaced_pool_ref = pools_ref.replace_delegation_pool;
        let vault_address = get_vault_address();

        // take into account the replaced_pool_ref.delegated
        assert!(total_delegated_amount > replaced_pool_ref.delegated, error::invalid_state(EREPLACED_POOL_DELEGATED_TOO_HIGH));
        assert!(supra_amount <= (total_delegated_amount - replaced_pool_ref.delegated), error::invalid_state(EAMOUNT_EXCEEDED));

        let unlockable = supra_amount;

        let pool_vec = pools_ref.pools;

        while (unlockable > MIN_COINS_ON_SHARES_POOL && vector::length(&pool_vec) > 0) {
            // the mechanism unlocks from the pools with the largest PoEL delegation, identify the pools with the highest delegation
            let (max_bal, idx, max1_bal, idx1) = find_top_pools(&pool_vec, vault_address);
            let max_address = *vector::borrow(&pool_vec, idx);
            let max_address_1 = *vector::borrow(&pool_vec, idx1);

            if (!is_pool_active(max_address)) {
                vector::remove(&mut pool_vec, idx);
                continue
            };
            if (!is_pool_active(max_address_1)) {
                vector::remove(&mut pool_vec, idx1);
                continue
            };

            // unlocks from the corresponding pools
            unlockable = unlock_from_pools(
                max_address,
                max_bal,
                unlockable
            );

            if (unlockable > MIN_COINS_ON_SHARES_POOL && max_address != max_address_1) {
                 unlockable = unlock_from_pools(
                    max_address_1,
                    max1_bal,
                    unlockable
                 );
            };

            // remove the higher-indexed pool from the vector before the lower-indexed one to avoid index shifts after the first removal
            let (hi, lo) = if (idx > idx1) { (idx, idx1) } else { (idx1, idx) };
            vector::remove(&mut pool_vec, hi);
            if (hi != lo) {
                vector::remove(&mut pool_vec, lo);
            };
        };


        // return total unlocked amount
        supra_amount - unlockable
    }

    // Unlocks from the pools
    fun unlock_from_pools(
        pool_address: address,
        bal: u64,
        unlockable: u64,
    ): u64 acquires PoelControler {
        let vault_signer = get_vault_signer();

        // when computing available tokens for unlock, consider the global active token balance of the pool to ensure 
        // we do not attempt to unlock more than the delegation pool can support
        let (active_tokens, _, _, _) = get_delegation_pool_stake(pool_address);
        // bal represents the balance of the pool's active stake
        let available = if (bal > MIN_COINS_ON_SHARES_POOL) {
            // prevent unlocking that would drop the remaining delegation below MIN_COINS_ON_SHARES_POOL
            min(bal - MIN_COINS_ON_SHARES_POOL, active_tokens)
        } else { 0 };

        if (available >= unlockable) {
        // unlockable is the amount of Supra being unlocked from the pools
            unlock(&vault_signer, pool_address, unlockable);
            unlockable = 0;
        } else {
            unlock(&vault_signer, pool_address, available);
            unlockable = unlockable - available;
        };

        unlockable
    }

    /// Find the top two pools by active stake balance for a given vault (delegator)
    fun find_top_pools(
        pools: &vector<address>,
        vault: address
    ): (u64, u64, u64, u64) {
        let max1_bal: u64 = 0;
        let max1_idx: u64 = 0;
        let max2_bal: u64 = 0;
        let max2_idx: u64 = 0;

        vector::enumerate_ref(pools, |idx, addr| {
            let addr = *addr;
            let (bal, _, _) = get_stake(addr, vault);
            if (bal > max1_bal) {
                max2_bal = max1_bal;
                max2_idx = max1_idx;
                max1_bal = bal;
                max1_idx = idx;
            } else if (bal > max2_bal) {
                max2_bal = bal;
                max2_idx = idx;
            };
        });

        (max1_bal, max1_idx, max2_bal, max2_idx)
    }



    /// Registers new iasset fa. Allowed only for admin
    public entry fun create_new_iasset(
        account: &signer,
        iAsset_name: vector<u8>,
        iAsset_symbol: vector<u8>,
        pair_id: u32,
        icon_uri: vector<u8>,
        project_uri: vector<u8>,
        origin_token_address: vector<u8>,
        origin_token_chain_id: u64,
        origin_token_decimals: u16,
        source_bridge_address: vector<u8>
    ) {
        config::assert_admin(account);
        let iasset = iAsset::create_new_iasset(account, iAsset_name, iAsset_symbol, ASSET_DECIMALS, pair_id,
            icon_uri, project_uri,
            origin_token_address, origin_token_chain_id, origin_token_decimals, source_bridge_address);
        event::emit<IAssetCreatedEvent>(
            IAssetCreatedEvent {
                name: iAsset_name,
                symbol: iAsset_symbol,
                decimals : ASSET_DECIMALS,
                pair_id: pair_id,
                origin_token_address: origin_token_address,
                origin_token_chain_id: origin_token_chain_id,
                origin_token_decimals : origin_token_decimals,
                source_bridge_address: source_bridge_address,
                iasset: iasset
            }
        );
    }

    /// Updates the desired weights for assets
    public entry fun batch_update_desired_weight(
        account: &signer,
        assets: vector<Object<Metadata>>,
        weights: vector<u32>
    ) {
        config::assert_admin(account);
        iAsset::batch_update_desired_weight(assets, weights);
    }

    /// Updates the desired weight for asset
    public entry fun update_desirability_score(
        account: &signer,
        asset: Object<Metadata>,
        desirability_score: u64,
    ) {
        config::assert_admin(account);
        iAsset::batch_update_desirability_score(vector[asset], vector[desirability_score]);
    }

    /// Updates desirability scores for multiple assets
    public entry fun batch_update_desirability_score(
        account: &signer,
        assets: vector<Object<Metadata>>,
        scores: vector<u64>
    ) {
        config::assert_admin(account);
        iAsset::batch_update_desirability_score(assets, scores);
    }

    public entry fun unfreeze_account(
        account: &signer,
        asset: Object<Metadata>,
        user_address: address
    ) {
        config::assert_admin(account);
        iAsset::unfreeze_account(asset, user_address);
    }

    public entry fun freeze_account(
        account: &signer,
        asset: Object<Metadata>,
        user_address: address
    ) {
        config::assert_admin(account);
        iAsset::freeze_account(asset, user_address);
    }

    public entry fun set_pause(
        account: &signer,
        asset: Object<Metadata>,
        paused: bool
    ) {
        config::assert_admin(account);
        iAsset::set_pause(asset, paused);
    }

    public entry fun set_redeemable(
        account: &signer,
        asset: Object<Metadata>,
        redeemable: bool
    ) {
        config::assert_admin(account);
        iAsset::set_redeemable(asset, redeemable);
    }

    /// Delegates $SUPRA tokens to delegation pools
    fun delegate_tokens(
        delegable_amount: u64,
        cap_value: u64
    ): u64 acquires DelegationPools, PoelControler {
        let pools_ref = borrow_global<DelegationPools>(get_storage_address());

        let pool_vec = pools_ref.pools;

        let vault_addr = get_vault_address();

        let total: u64 = 0;
        let to_delegate: u64 = 0;

        while (delegable_amount > MIN_COINS_ON_SHARES_POOL && vector::length(&pool_vec) > 0) {
            // the mechanism delegates to the pools with the smallest PoEL delegation, identify the pools with the smallest delegation
            let (min_bal, min_idx, min_bal_1, min_idx_1) = find_bottom_pools(&pool_vec, vault_addr, cap_value);
            let min_addr = *vector::borrow(&pool_vec, min_idx);
            let min_addr_1 = *vector::borrow(&pool_vec, min_idx_1);
            // ensure the selected delegation pools are active, if not, remove from the vector
            if (!is_pool_active(min_addr)) {
                vector::remove(&mut pool_vec, min_idx);
                continue
            };
            if (!is_pool_active(min_addr_1)) {
                vector::remove(&mut pool_vec, min_idx_1);
                continue
            };

            // delegate SUPRA to the pool 
            (total, to_delegate) = add_stake_to_pool(min_addr, min_bal, delegable_amount, cap_value, total);
            delegable_amount = delegable_amount - to_delegate;

            if (delegable_amount > MIN_COINS_ON_SHARES_POOL && min_addr != min_addr_1) {
                (total, to_delegate) = add_stake_to_pool(min_addr_1, min_bal_1, delegable_amount, cap_value, total);
                // determine what remains to be delegated after delegating to this pool
                delegable_amount = delegable_amount - to_delegate;
            };

            // remove the higher-indexed pool from the vector before the lower-indexed one to avoid index shifts after the first removal
            let (hi, lo) = if (min_idx > min_idx_1) { (min_idx, min_idx_1) } else { (min_idx_1, min_idx) };
            vector::remove(&mut pool_vec, hi);
            if (hi != lo) {
                vector::remove(&mut pool_vec, lo);
            };
        };

        // return total delegated amount
        total
    }

    /// Delegate tokens to the specified delegation pool 
    fun add_stake_to_pool(
        pool_address: address,
        bal: u64,
        delegable_amount: u64,
        cap_value: u64,
        total: u64,
    ): (u64, u64) acquires PoelControler {
        let vault_signer = get_vault_signer();

        // ensure the pool has not hit its delegation cap
        assert!(cap_value > bal + MIN_COINS_ON_SHARES_POOL, error::invalid_state(DELEGATION_CAP_REACHED));
        let allowable = cap_value - bal;
        let to_delegate = min(delegable_amount, allowable);
        // delegate SUPRA
        add_stake(&vault_signer, pool_address, to_delegate);

        total = total + to_delegate; // track total amount of delegated

        (total, to_delegate)
    }

    /// Find delegation pools with the smallest total amount delegated by PoEL. 
    fun find_bottom_pools(
        pools: &vector<address>,
        vault: address,
        cap: u64
    ): (u64, u64, u64, u64) {
        let min1_bal: u64 = cap;
        let min2_bal: u64 = cap;
        let min1_idx: u64 = 0;
        let min2_idx: u64 = 0;

        vector::enumerate_ref(pools, |idx, addr| {
            let addr = *addr;
            let (bal, _, _) = get_stake(addr, vault);
            if (bal < min1_bal) {
                min2_bal = min1_bal;
                min2_idx = min1_idx;
                min1_bal = bal;
                min1_idx = idx;
            } else if (bal < min2_bal) {
                min2_bal = bal;
                min2_idx = idx;
            };
        });

        (min1_bal, min1_idx, min2_bal, min2_idx)
    }


    /// Facilitates the withdrawal of inactive tokens from the delegation pools.
    fun withdraw_tokens(): u64 acquires DelegationPools, PoelControler {
        let pools_ref = borrow_global<DelegationPools>(get_storage_address());
        let total = 0;

        let vault_signer = get_vault_signer(); // signer to spend coins from PoEL Vault

        vector::for_each_ref<address>(&pools_ref.pools, |pool| {
            let pool_address = *pool;
            // avoid withdrawing from inactive vaults, it may prevent correct detection of lockup-cycle completion
            let withdrawable = if (is_pool_active(pool_address)) {
                safe_withdraw(&vault_signer, pool_address)
            }else {
                0
            };
            total = total + withdrawable;
        });

        total
    }

    /// The allocate_rewards() function is responsible for the following:
    ///a) Calculates the total rewards earned during the epoch by subtracting the PoEL vault's recorded total delegated amount (accounting state) from the
    ///actual amount held in delegation pools
    ///b. After this reward amount is determined, it submits an unlock request to the delegation pools to unlock.
    public entry fun allocate_rewards(_account: &signer) acquires DelegatedAmount, DelegationPools, PoelControler, RewardBudget {
        config::assert_allocate_rewards(); // if rewards allocation is disabled

        let obj_address = get_storage_address();

        let reward_ref = borrow_global<RewardBudget>(obj_address);
        let (_, _, _, _, _, _,
            reward_reduction_rate,
            _,
            smallest_portion_of_distributable_rewards,
            threshold_rewards_to_distribute,
            min_frequency_rewards_allocation,
            _
        ) = config::get_mut_params();

        let current_ts = timestamp::now_seconds();
        let total_staked_assets = get_total_staked();
        assert!(reward_ref.allocation_ts + min_frequency_rewards_allocation <= current_ts, error::invalid_state(ENOT_ENOUGH_TIME_PASSED));

        let delegated_amount_ref = borrow_global<DelegatedAmount>(obj_address);
        let pools_ref = borrow_global<DelegationPools>(obj_address);



        let replaced_pool_ref = pools_ref.replace_delegation_pool;

        // Checks if staking rewards have been earned by comparing the protocol's staked asset(pending active & active stake) balance
        //with total delegated assets(accounting state. If a pool is being replaced, assets delegated to it are also included in the calculation.
        if ((total_staked_assets + replaced_pool_ref.delegated) < delegated_amount_ref.total_delegated_amount) return;
        let total_reward_earned = total_staked_assets + replaced_pool_ref.delegated - delegated_amount_ref.total_delegated_amount;

        // stop the execution if rewards less than threshold, no need to unlock the tokens, rewards are too small
        if (total_reward_earned == 0 || total_reward_earned < threshold_rewards_to_distribute) return;

        // Since unlocking can trigger withdrawals and it's crucial to detect non-zero inactive stake to track OLC index changes.
        // Before unlock we first attempt to withdraw tokens from pools to identify any inactive stake.
        let withdrawn_tokens = withdraw_tokens();

        // Unlocks the earned rewards
        let unlocked_rewards = unlock_tokens(total_reward_earned, delegated_amount_ref.total_delegated_amount);

        let delegated_amount_ref = borrow_global_mut<DelegatedAmount>(obj_address);
        let reward_budget_ref = borrow_global_mut<RewardBudget>(obj_address);

        // Non-zero withdrawn tokens indicate inactive stake and a change in the OLC index.
        // The system updates the last cycle change epoch and adjusts the total borrowed amount to reflect the withdrawal.
        if (withdrawn_tokens > 0) {
            if (delegated_amount_ref.previous_unlocked_amount > 0) {
                delegated_amount_ref.total_borrowed_amount = delegated_amount_ref.total_borrowed_amount - delegated_amount_ref.previous_unlocked_amount;
                delegated_amount_ref.previous_unlocked_amount = 0;
            };

            iAsset::update_cycle_info(current_epoch());
        };

        // Increase the allocated reward balance by the amount of newly unlocked rewards.
        reward_budget_ref.allocated_reward_balance = reward_budget_ref.allocated_reward_balance + unlocked_rewards;

        // Adjusts the amount of earned rewards based on the reward reduction rate (set by the admin) and the capital_efficiency_coefficient,
        // a DFMM-specific variable that will apply once the AMM is live.
        let adjusted_rewards_by_rate = mul_div(unlocked_rewards,
            (REWARD_CALCULATION_MULTIPLIER - reward_reduction_rate), REWARD_CALCULATION_MULTIPLIER);
        let total_distributable_rewards = min(
            mul_div(
                adjusted_rewards_by_rate,
                max(smallest_portion_of_distributable_rewards, reward_budget_ref.capital_efficiency_coefficient),
                REWARD_CALCULATION_MULTIPLIER),
            reward_budget_ref.reward_budget + adjusted_rewards_by_rate);

        // Updates the stimulation_rewards_accumulated
        reward_budget_ref.stimulation_rewards_accumulated = reward_budget_ref.stimulation_rewards_accumulated
            + mul_div(unlocked_rewards, reward_reduction_rate, REWARD_CALCULATION_MULTIPLIER);

        // Updates the available reward budget based on the calculated amount of rewards to be distributed to users.
        reward_budget_ref.reward_budget = reward_budget_ref.reward_budget + adjusted_rewards_by_rate - total_distributable_rewards;

        // If any additional rewards (distributable to all iAssets) are available, they are added to the total distributable rewards.
        total_distributable_rewards = total_distributable_rewards + reward_budget_ref.multiple_asset_reward_balance;

        reward_budget_ref.multiple_asset_reward_balance = 0;

        // Increments the total_distributable_rewards state variable, which tracks the cumulative amount of distributed rewards.
        // This state variable is used in the distribute_rewards function.
        reward_budget_ref.total_distributable_rewards = reward_budget_ref.total_distributable_rewards + total_distributable_rewards;
        // save the time
        reward_budget_ref.allocation_ts = current_ts;

        event::emit<RewardsAllocatedEvent>(
            RewardsAllocatedEvent {
                total_reward_earned: unlocked_rewards,
                total_distributable: total_distributable_rewards,
                reward_budget_remaining: reward_budget_ref.reward_budget
            }
        );
    }

    /// Distributes rewards to assets based on their total value and desirability scores.
    /// 1. Retrieves the total distributable rewards.
    /// 2. Calculates the reward amount for each asset and updates their respective reward indices.
    public entry fun distribute_rewards(_account: &signer) acquires RewardBudget {
        let (min_collateralisation,
            _, _, _, max_collateralisation_first, max_collateralisation_second,
            _, _, _, _, _, _) = config::get_mut_params();

        let obj_address = get_storage_address();
        let tracked_assets = get_assets();
        let reward_budget_ref = borrow_global_mut<RewardBudget>(obj_address);

        let total = reward_budget_ref.total_distributable_rewards;

        // check if any new rewards were allocated (allocate_rewards)
        let new_rewards = vector::fold(tracked_assets, 0, |t, asset_address|
        {
            let last_distributable_rewards = *smart_table::borrow_with_default(
                &reward_budget_ref.last_distributable_rewards, asset_address, &0);
            let single_asset_reward_balance = *table::borrow_with_default(
                &reward_budget_ref.single_asset_reward_balance, asset_address, &0);

            t + (single_asset_reward_balance + (total - last_distributable_rewards))  
        });
        // assertation if nothing to distribute
        assert!(new_rewards > 0, error::invalid_state(ENO_DISTRIBUTABLE_REWARDS));

        // Computes the total nominal collateral value available in the system 
        let (total_nominal_liquidity, supra_price_entry) = calculate_nominal_liquidity();

        let total_borrowed_amount_with_desirability_scores: u128 = 0;
        let asset_specific_borrowed_amount: vector<AssetSpecific> = vector::empty();
        let (supra_price, supra_decimals, _, _) = deconstruct_asset_price(&supra_price_entry);

        // Rewards are distributed from the newly available rewards portion proportionally to weight of each asset
        // where the weight is desirability_score * nominal_liquidity / collateralization_rate.
        vector::for_each_ref<Object<Metadata>>(
            &tracked_assets,
            |key|
        {
            let asset = *key;
            let asset_price_entry = get_asset_price(asset);
            let items =  get_liquidity_table_items(asset);
            let (_, collateral_supply, _, desirability_score, _, _, _, _, _) =  deconstruct_liquidity_table_items(&items);
            let (asset_price, asset_decimals, _, _) = deconstruct_asset_price(&asset_price_entry);
            // Calculate the asset's collateral supply denominated in SUPRA.
            let liquidity_of_asset = asset_util::get_asset_value_in(collateral_supply, asset_price, asset_decimals, supra_price, supra_decimals);
            // Calculate the collateralisation rate for an asset. 
            let (asset_specific_collateralisation_rate, _, _) = calculate_collateralization_rate(
                asset,
                liquidity_of_asset,
                min_collateralisation,
                max_collateralisation_first,
                max_collateralisation_second,
                total_nominal_liquidity
            );
            // Compute the unnormalized weight (numerator) for the asset:
            // desirability_score * liquidity_in_SUPRA / collateralisation_rate(then scaled by get_coll_rate_multiplier()),
            let asset_specific_borrowed_amount_with_desirability_scores =
                (((desirability_score as u128) * liquidity_of_asset) / (asset_specific_collateralisation_rate as u128))
                * get_coll_rate_multiplier();

            vector::push_back(&mut asset_specific_borrowed_amount, AssetSpecific {asset, collateral_supply, asset_specific_borrowed_amount_with_desirability_scores, desirability_score});

            total_borrowed_amount_with_desirability_scores = total_borrowed_amount_with_desirability_scores + asset_specific_borrowed_amount_with_desirability_scores;
        });


        vector::for_each<AssetSpecific>(
            asset_specific_borrowed_amount,
            |value|
        {
            let asset_specific: AssetSpecific = value;
            // if no entry take 0
            let single_asset_reward_balance = table::borrow_mut_with_default(&mut reward_budget_ref.single_asset_reward_balance, asset_specific.asset, 0);

            let last_distributable_rewards = *smart_table::borrow_with_default(&reward_budget_ref.last_distributable_rewards, asset_specific.asset, &0);
            let new_rewards_portion = total - last_distributable_rewards; // difference

            if (new_rewards_portion > 0) {
                // Compute rewards for an iAsset proportional to the SUPRA borrowed by its holders
                // relative to all iasset borrowers, weighted by desirability scores.
                let available_reward_for_asset =  (*single_asset_reward_balance as u128) + (((new_rewards_portion as u128) * (asset_specific.asset_specific_borrowed_amount_with_desirability_scores)) / (total_borrowed_amount_with_desirability_scores as u128));
                // update global index for iasset
                update_reward_index(asset_specific.asset, (available_reward_for_asset as u64));
                // update the last_distributable_rewards for the iasset
                smart_table::upsert(&mut reward_budget_ref.last_distributable_rewards, asset_specific.asset, total);
                *single_asset_reward_balance = 0; // reset to 0

                event::emit<RewardsDistributedEvent>(
                    RewardsDistributedEvent {
                        asset: asset_specific.asset,
                        amount: (available_reward_for_asset as u64),
                    }
                );
            }
        });
    }


    /// Calculates and updates (delegates or unlocks) the total amount of Supra
    /// borrowed and delegated, based on supplied collateral, current asset prices, and collateralization rates.
    public entry fun update_borrowed_amount(_account: &signer) acquires DelegatedAmount, DelegationPools, PoelControler {
        let obj_address = get_storage_address();

        let delegated_amount_ref = borrow_global_mut<DelegatedAmount>(obj_address);
        let current_epoch = current_epoch();
        assert!(delegated_amount_ref.borrowed_amount_update_epoch < current_epoch, error::invalid_state(ENOT_ENOUGH_TIME_PASSED));
        let replaced_pool_ref = get_replaced_delegation_pool();
        let current_ts = timestamp::now_seconds();

        let (
            min_collateralisation, _, _, _,
            max_collateralisation_first, max_collateralisation_second,
            _, pool_max_delegation_cap, _,
            threshold_rewards_to_distribute, _, _) = config::get_mut_params();


        // Checks whether there are withdrawable tokens in the delegation pools; if so, withdraws them.
        // A withdrawable balance indicates the previous lockup cycle has ended.
        // If there is unlocked principal (i.e., principal_amount < current_delegated_amount in the previous epochs),
        // it is returned to the PoEL vault at the end of the lockup cycle, and
        // `total_borrowed_amount` (the principal borrowed by the users from PoEL vault) is updated accordingly.
        // Because the previous lockup cycle has ended, update the epoch and the timestamp at which this transition was detected.
        let withdrawn_tokens = withdraw_tokens();
        if (withdrawn_tokens > 0) {
            if (delegated_amount_ref.previous_unlocked_amount > 0) {
                delegated_amount_ref.total_borrowed_amount = delegated_amount_ref.total_borrowed_amount - delegated_amount_ref.previous_unlocked_amount;
                delegated_amount_ref.previous_unlocked_amount = 0;
            };

            iAsset::update_cycle_info(current_epoch);
        };

        // To ensure the delegation pools always maintain a non-zero balance in the pending-inactive state,
        // which is required to detect the end of a lockup cycle and cycle-index change,
        // we unlock a small amount of principal from the delegation pool every epoch.
        if (delegated_amount_ref.total_delegated_amount > 0) {
            let unlocked_threshold = unlock_tokens(threshold_rewards_to_distribute, delegated_amount_ref.total_delegated_amount);
            delegated_amount_ref.total_delegated_amount = delegated_amount_ref.total_delegated_amount - unlocked_threshold;
            delegated_amount_ref.previous_unlocked_amount =  delegated_amount_ref.previous_unlocked_amount + unlocked_threshold;
        };

        let recent_cycle_update_epoch = iAsset::get_cycle_data();

        // Checks whether tokens were unlocked due to a reduction in the system's borrowable amount
        // and whether the lockup cycle in which they were unlocked has ended.
        // If so, updates `total_borrowed_amount` and `total_borrowable_amount`,
        // then transfers the unlocked tokens to the withdrawal address.
        if (delegated_amount_ref.withdraw_request_epoch < recent_cycle_update_epoch && delegated_amount_ref.withdraw_requested_assets > 0) {
            let requested = delegated_amount_ref.withdraw_requested_assets;
            assert!(delegated_amount_ref.total_borrowed_amount >= requested, error::invalid_state(ENOT_SYNC_STATE));
            delegated_amount_ref.total_borrowed_amount = delegated_amount_ref.total_borrowed_amount - requested;
            delegated_amount_ref.total_borrowable_amount = delegated_amount_ref.total_borrowable_amount - requested;

            supra_account::transfer(&get_vault_signer(), config::get_withdrawal_address(), requested);

            delegated_amount_ref.withdraw_requested_assets = 0;
            delegated_amount_ref.withdraw_request_epoch = 0;
        };

        let current_delegated_amount = delegated_amount_ref.total_delegated_amount;
   
        // Based on the assets supplied as collateral and their prices, compute the principal to be borrowed for the user. 
        // This amount can change each epoch as collateral balances and prices update.
        let principle_amount: u64 = calculate_principle(
            min_collateralisation,
            max_collateralisation_first,
            max_collateralisation_second,
        );

        let total_borrowable_amount = delegated_amount_ref.total_borrowable_amount;
        let total_borrowed_amount = delegated_amount_ref.total_borrowed_amount;

        // Compare current_delegated_amount (borrowed assets in the active state of the pools) to the computed principal:
        // - If current_delegated_amount < principal: borrow and delegate additional assets to align with principal and preserve fair reward distribution.
        // - If current_delegated_amount > principal: too many assets are delegated, unlock tokens from the delegation pools to realign.
        if (principle_amount > current_delegated_amount) {
            // If the PoEL vault holds enough tokens to satisfy the full delegation requirement,delegate the exact amount needed 
            // to realign current_delegated_amount with the principal, otherwise, delegate whatever is available.
            let change_of_delegated_amount = min((principle_amount - current_delegated_amount), (total_borrowable_amount - total_borrowed_amount));

            //  Ensure the calculated delegable amount meets the pool's minimum requirement
            if (change_of_delegated_amount > MIN_COINS_ON_SHARES_POOL){
                let cap_value = math64::mul_div(total_borrowable_amount, pool_max_delegation_cap, 100);
                // delegate tokens
                let delegated = delegate_tokens(change_of_delegated_amount, cap_value);

                //updating total_delegated_amount and total_borrowed_amount
                delegated_amount_ref.total_delegated_amount = delegated_amount_ref.total_delegated_amount + delegated;
                delegated_amount_ref.total_borrowed_amount = delegated_amount_ref.total_borrowed_amount + delegated;
            }

        } else if (principle_amount < current_delegated_amount){
            // Since we do not unlock tokens from pools that are being replaced, check whether other delegation pools (active state) have enough to meet
            // the unlock requirement. If yes, unlock the full amount, otherwise, unlock whatever is available.
            let to_unlock = min((current_delegated_amount - principle_amount), (current_delegated_amount - replaced_pool_ref.delegated));
            // Verify the unlock amount meets the minimum requirements of the pools
            if (to_unlock > MIN_COINS_ON_SHARES_POOL){
                let unlocked = unlock_tokens(to_unlock, delegated_amount_ref.total_delegated_amount);
                // updating the previous_unlocked_amount and total_delegated_amount
                delegated_amount_ref.previous_unlocked_amount = delegated_amount_ref.previous_unlocked_amount + unlocked;
                delegated_amount_ref.total_delegated_amount = delegated_amount_ref.total_delegated_amount - unlocked;
            }
        };

        delegated_amount_ref.borrowed_amount_update_epoch = current_epoch;
        delegated_amount_ref.borrowed_amount_update_ts = current_ts;

        event::emit<BorrowedAmountUpdatedEvent>(
            BorrowedAmountUpdatedEvent {
                epoch:      current_epoch,
                total_delegated_amount: borrow_global<DelegatedAmount>(obj_address).total_delegated_amount,
                total_borrowed_amount:   borrow_global<DelegatedAmount>(obj_address).total_borrowed_amount,
            }
        );
    }

    /// Increases the total borrowable amount by transferring funds into the PoEL vault
    public entry fun increase_borrowable_amount(account: &signer, amount: u64) acquires DelegatedAmount {
        config::assert_owner(account);
        let user_balance = coin::balance<SupraCoin>(signer::address_of(account));
        assert!(user_balance >= amount, error::invalid_argument(EINSUFICIENT_CALLER_BALANCE));

        let delegated_amount_ref = borrow_global_mut<DelegatedAmount>(get_storage_address());

        // transfers SUPRA tokens from the owner's account to the PoEL vault
        supra_account::transfer(account, get_vault_address(), amount);
        //increase the total borrowable amount
        let old_amount = delegated_amount_ref.total_borrowable_amount;
        delegated_amount_ref.total_borrowable_amount = delegated_amount_ref.total_borrowable_amount + amount;

        event::emit<BorrowableAmountIncreasedEvent>(
            BorrowableAmountIncreasedEvent {
                old_borrowable_amount : old_amount,
                new_borrowable_amount : delegated_amount_ref.total_borrowable_amount,
            }
        );
    }

    /// Reduces the total borrowable amount in the PoEL vault
    public entry fun decrease_borrowable_amount(account: &signer, amount: u64) acquires  DelegatedAmount, DelegationPools, PoelControler {
        config::assert_owner(account);
        assert!(amount > 0, error::invalid_state(EAMOUNT_ZERO));

        let obj_address = get_storage_address();
        let delegated_amount_ref = borrow_global_mut<DelegatedAmount>(obj_address);
        let pools_ref = borrow_global<DelegationPools>(obj_address);
        // Ensure there are no prior borrowable-amount decrease requests still in progress
        assert!(delegated_amount_ref.withdraw_request_epoch == 0, error::invalid_state(EREQUEST_IN_PROGRESS));

        // ensure a valid amount is provided and the system is in a synced state 
        assert!(delegated_amount_ref.total_borrowable_amount - pools_ref.replace_delegation_pool.delegated >= amount, error::invalid_state(EAMOUNT_EXCEEDED));
        assert!(delegated_amount_ref.total_borrowable_amount >= delegated_amount_ref.total_borrowed_amount, error::invalid_state(ENOT_SYNC_STATE));

        // computes the principal amount available in the PoEL vault 
        let diff = delegated_amount_ref.total_borrowable_amount - delegated_amount_ref.total_borrowed_amount;
        // sendable amount takes the requested amount value or only a part of it
        let sendable_amount = min(diff, amount);

        if (sendable_amount > 0){
            // Transfer the available `sendable_amount` of Supra from the PoEL vault to the withdrawal address.
            supra_account::transfer(&get_vault_signer(), config::get_withdrawal_address(), sendable_amount);
            // Decrease the total_borrowable_amount by the sent amount
            delegated_amount_ref.total_borrowable_amount = delegated_amount_ref.total_borrowable_amount - sendable_amount;
        };

        // If there is not enough principal in the PoEL vault to withdraw, unlock the remaining amount from the delegation pools.
        if (amount > sendable_amount) {
            // Unlocking also withdraws inactive tokens, to track the end of previous lockup cycle and run accounting, we first attempt withdrawal
            let withdrawn_tokens = withdraw_tokens();
            let epoch = current_epoch();
            if (withdrawn_tokens > 0) {
                if (delegated_amount_ref.previous_unlocked_amount > 0) {
                    delegated_amount_ref.total_borrowed_amount = delegated_amount_ref.total_borrowed_amount - delegated_amount_ref.previous_unlocked_amount;
                    delegated_amount_ref.previous_unlocked_amount = 0;
                };

                iAsset::update_cycle_info(epoch);
            };

            let shortfall = amount - sendable_amount;
            // unlock the remaining amount
            // unlock the remaining amount
            let unlocked = unlock_tokens(shortfall, delegated_amount_ref.total_delegated_amount);
           // update the total delegated amount and record the withdraw request amount (for this operation) along with the corresponding epoch.
           // update the total delegated amount and record the withdraw request amount (for this operation) along with the corresponding epoch.
            delegated_amount_ref.total_delegated_amount = delegated_amount_ref.total_delegated_amount - unlocked;
            delegated_amount_ref.withdraw_requested_assets = unlocked;
            delegated_amount_ref.withdraw_request_epoch = epoch;
        };

        event::emit<BorrowableAmountDecreaseRequestEvent>(
            BorrowableAmountDecreaseRequestEvent {
                requested_amount: amount,
                withdraw_requested_assets: delegated_amount_ref.withdraw_requested_assets,
                withdraw_request_epoch: delegated_amount_ref.withdraw_request_epoch,
            }
        );

    }

    /// Allows the admin to withdraw rewards accumulated from pending inactive tokens that have already been withdrawn from pools.
    public entry fun withdraw_surplus_rewards(account: &signer, requested: u64) acquires DelegatedAmount, PoelControler, RewardBudget {
        config::assert_owner(account);
        assert!(requested > 0, error::invalid_state(EAMOUNT_ZERO));
        let vault_signer = get_vault_signer();
        let vault_address = signer::address_of(&vault_signer);
        // balance of the poel vaule
        let balance = coin::balance<SupraCoin>(vault_address);

        let obj_address = get_storage_address();
        let delegated_amount_ref = borrow_global<DelegatedAmount>(obj_address);
        let reward_budget_ref = borrow_global<RewardBudget>(obj_address);

        // Ensures that admin can not withdraw more that the potential accumulated suprlus rewards
        assert!(balance + delegated_amount_ref.total_borrowed_amount >= requested + delegated_amount_ref.total_borrowable_amount + reward_budget_ref.allocated_reward_balance, error::invalid_state(EAMOUNT_EXCEEDED));
        // Send requested amount of Supra from the PoEL contract to the withdrawal_address
        supra_account::transfer(&vault_signer, config::get_withdrawal_address(), requested);

        event::emit<SurplusRewardsWithdrawnEvent>(
            SurplusRewardsWithdrawnEvent {
                account: config::get_withdrawal_address(),
                amount: requested,
            }
        );        
    }

    /// Allows anybody to claim and withdraw stimulation rewards
    public entry fun withdraw_stimulation_rewards(account: &signer) acquires PoelControler, RewardBudget {
        let vault_signer = get_vault_signer();

        let reward_budget_ref = borrow_global_mut<RewardBudget>(get_storage_address());

        //ensure that stimulation rewards have been accrued 
        assert!(reward_budget_ref.stimulation_rewards_accumulated > 0, error::invalid_state(ENO_STIMULATION_REWARDS));

        // Withdrawal of stimulation rewards is a two-step process:
        // 1) the user submits a claim request; 2) after the lockup cycle ends, the user can withdraw.
        if (reward_budget_ref.stimulation_rewards_claimed == 0) {
            reward_budget_ref.stimulation_rewards_claimed = reward_budget_ref.stimulation_rewards_accumulated;
            reward_budget_ref.stimulation_rewards_claim_epoch = current_epoch();
        }else {
            let recent_cycle_update_epoch = iAsset::get_cycle_data();
            let requested = reward_budget_ref.stimulation_rewards_claimed;
            assert!(reward_budget_ref.stimulation_rewards_claim_epoch < recent_cycle_update_epoch,  error::invalid_state(ENOT_ENOUGH_TIME_PASSED));
            supra_account::transfer(&vault_signer, config::get_rewards_distribution_address(), requested);
            // after withdrawal, since these rewards are removed from the vault, update allocated_reward_balance.
            reward_budget_ref.allocated_reward_balance = reward_budget_ref.allocated_reward_balance - requested;
            // update accumulated stimulation rewards and claim-process state
            reward_budget_ref.stimulation_rewards_accumulated = reward_budget_ref.stimulation_rewards_accumulated - reward_budget_ref.stimulation_rewards_claimed;
            reward_budget_ref.stimulation_rewards_claimed = 0;
            reward_budget_ref.stimulation_rewards_claim_epoch = 0;

            event::emit<StimulationRewardsWithdrawnEvent>(
                StimulationRewardsWithdrawnEvent {
                    account: config::get_rewards_distribution_address(),
                    amount: requested,
                }
             );            
        }
    }

    /// Facilitates the creation of borrow requests following the deposition of the original asset into
    /// the intralayer vault.
    public(friend) fun borrow_request(
        asset: Object<Metadata>,
        user_amount: u64, // it will be transformed to u128 soon
        user_address: address,
        service_fee_amount: u64,
        service_fee_address: address,
        relayer_fee_amount: u64,
        relayer_fee_address : address
    ) {
        // update the amount requested to be used as borrowing collateral and pre-mints the iAsset for the user
        update_borrow_request(asset, user_amount + service_fee_amount + relayer_fee_amount);
        premint_iasset(user_amount, asset, user_address);

        // relayer and protocol fees are charged in iAssets; the corresponding iAsset amounts
        // are pre-minted to the relayer and service-fee addresses.
        if (service_fee_amount > 0) {
            premint_iasset(service_fee_amount, asset, service_fee_address);
        };
        
        if (relayer_fee_amount > 0) {
            premint_iasset(relayer_fee_amount, asset, relayer_fee_address);
        };

        event::emit<BorrowRequestEvent>(
            BorrowRequestEvent {
                asset: object::object_address(&asset),
                user_amount: user_amount,
                user_address,
                service_fee: service_fee_amount,
                service_fee_address,
                relayer_fee: relayer_fee_amount,
                relayer_fee_address
            }
        );
    }

    /// Borrow function facilitates the minting of iAssets to a user's address.
    /// Anyone can mint iAsset for a user, using the reciever address as long as the reciver already has preminted iAssets.
    public entry fun borrow(asset: Object<Metadata>, receiver_address: address) {
        let minted = mint_iasset(receiver_address, asset);

        if (minted > 0) {
            event::emit<BorrowEvent>(
                BorrowEvent {
                    asset: object::object_address(&asset),
                    amount: minted,
                    account: receiver_address,
                }
            );
        }
    }

    /// Allows anyone to deposit SUPRA into the contract and specify the target iAsset,
    /// the funds are distributed as rewards to holders of that iAsset at the next allocation.
    public entry fun add_single_asset_extra_rewards(account: &signer, asset: Object<Metadata>, amount: u64) acquires RewardBudget {
        let user_balance = coin::balance<SupraCoin>(signer::address_of(account));
        // ensure the user has sufficient SUPRA
        assert!(user_balance >= amount, error::invalid_argument(EINSUFICIENT_CALLER_BALANCE));
        
        // move coins from user account to PoEL vault address
        supra_account::transfer(account, get_vault_address(), amount);

        let obj_address = get_storage_address();

        let reward_budget_ref = borrow_global_mut<RewardBudget>(obj_address);

        // update single-asset reward balance and increase balance of allocated rewards
        let balance = table::borrow_mut_with_default(&mut reward_budget_ref.single_asset_reward_balance, asset, 0);
        *balance =  *balance + amount;

        reward_budget_ref.allocated_reward_balance = reward_budget_ref.allocated_reward_balance + amount;

        event::emit<SingleAssetExtraRewardsAddedEvent>(
            SingleAssetExtraRewardsAddedEvent {
                asset: object::object_address(&asset),
                amount: amount
            }
        );
    }

    /// Allows anyone to deposit SUPRA into the contract, the funds are distributed to all
    /// iAsset holders at the next allocation according to the system's distribution mechanism
    public entry fun add_multi_asset_extra_rewards(account: &signer, amount: u64) acquires RewardBudget {
        let user_balance = coin::balance<SupraCoin>(signer::address_of(account));
        // ensure the user has sufficient SUPRA
        assert!(user_balance >= amount, error::invalid_argument(EINSUFICIENT_CALLER_BALANCE));

        // move coins from user account to PoEL vault address
        supra_account::transfer(account, get_vault_address(), amount);

        let obj_address = get_storage_address();
        let reward_budget_ref = borrow_global_mut<RewardBudget>(obj_address);

        // update the extra reward balance and increase balance of allocated rewards
        reward_budget_ref.multiple_asset_reward_balance =  reward_budget_ref.multiple_asset_reward_balance + amount;
        reward_budget_ref.allocated_reward_balance = reward_budget_ref.allocated_reward_balance + amount;

        event::emit<MultiAssetExtraRewardsAddedEvent>(
            MultiAssetExtraRewardsAddedEvent {
                amount: amount
            }
        );
    }


    /// Facilitates submitting a request to replace a delegation pool applied in the system 
    public entry fun replace_delegation_pool_request(
        account: &signer,
        replaced_delegation_pool_address: address,
    ) acquires  DelegationPools, PoelControler {
        // Restrict pool replacement to the manager responsible for selecting Delegation Pools
        config::assert_delegation_pools(account);
        let obj_address = get_storage_address();

        let pools_ref = borrow_global_mut<DelegationPools>(obj_address);

        // Ensure there is no delegation-pool replacement request currently in progress.
        assert!(pools_ref.replace_delegation_pool.lockup_cycle_update_epoch == 0, error::invalid_state(EREQUEST_REGISTERED));
        let (exist, index) = vector::index_of(&pools_ref.pools, &replaced_delegation_pool_address);
        // Ensure the pool requested for replacement is already utilized by the PoEL system
        assert!(exist, error::invalid_state(EPOOL_NOT_REGISTERED));

        let vault_signer = get_vault_signer();
        let vault_address = signer::address_of(&vault_signer);

        let (active_stake, inactive, pending_inactive) = get_stake(replaced_delegation_pool_address, vault_address);
        // it is not ok to replace the pool with inactive/pending_inactive
        assert!(inactive == 0 && pending_inactive == 0, error::invalid_state(EREPLACED_POOL_HAS_INACTIVE_PENDING_INACTIVE));

        // unlock amount, don't update the delegated amount here
        if (active_stake > 0) {
            unlock(&vault_signer, replaced_delegation_pool_address, active_stake);
        };
        // Update the details of the replacement request process 
        pools_ref.replace_delegation_pool.lockup_cycle_update_epoch = current_epoch();
        pools_ref.replace_delegation_pool.pool = replaced_delegation_pool_address; // pool address itself
        pools_ref.replace_delegation_pool.delegated = active_stake; // pool address itself
        // remove from staking_pool_mapping immediately
        vector::remove(&mut pools_ref.pools, index);

    }

    /// Carries out the requested replacement of an existing delegation pool with a new one
    public entry fun replace_delegation_pool(
        account: &signer,
        replacing_pool_address: address,
    ) acquires DelegationPools, PoelControler {
        // Restrict pool replacement to the manager responsible for selecting Delegation Pools
        config::assert_delegation_pools(account);
        // Ensure the replacing pool is a valid delegation pool on the network and is currently active
        assert!(delegation_pool_exists(replacing_pool_address), error::invalid_state(EPOOL_NOT_REGISTERED));
        assert!(is_pool_active(replacing_pool_address), error::invalid_state(EPOOL_NOT_ACTIVE));
        let obj_address = get_storage_address();
        let vault_signer = get_vault_signer();
        let vault_address = signer::address_of(&vault_signer);

        let recent_cycle_update_epoch = iAsset::get_cycle_data();

        let pools_ref = borrow_global_mut<DelegationPools>(obj_address);
        let replaced_pool_ref = pools_ref.replace_delegation_pool;

        // ensure that replacement request exists.
        assert!(pools_ref.replace_delegation_pool.pool != @0x0, error::invalid_state(EREQUEST_NOT_FOUND));

        // ensure the lockup cycle in which the replacement request was submitted has ended, so the unlocked tokens are withdrawable.
        assert!(pools_ref.replace_delegation_pool.lockup_cycle_update_epoch < recent_cycle_update_epoch,  error::invalid_state(ENOT_ENOUGH_TIME_PASSED));

        // withdraw tokens from the pool being replaced.
        let withdrawn = safe_withdraw(&vault_signer, pools_ref.replace_delegation_pool.pool);

        // if nothing was withdrawn, don't call add_stake. If the withdrawn amount is positive, stake it in the replacing pool
        if (withdrawn > 0) {
            add_stake(&vault_signer, replacing_pool_address, withdrawn); 
        };
        // ensure no SUPRA coins belonging to PoEL remain in the replaced delegation poolL
        let (active_stake, _, pending_inacive) = get_stake(pools_ref.replace_delegation_pool.pool, vault_address);
        assert!(active_stake == 0 && pending_inacive == 0, error::invalid_state(EPOOL_LEFTOVER_COINS));

        // add the replacement delegation pool to the registered pools vector.
        if (!vector::contains(&pools_ref.pools, &replacing_pool_address)){
            vector::push_back(&mut pools_ref.pools, replacing_pool_address);
        };

        event::emit<DelegationPoolReplacedEvent>(
            DelegationPoolReplacedEvent {
                old_pool_address: replaced_pool_ref.pool,
                new_pool_address: replacing_pool_address,
            }
        );

        // reset values of pool replacement request
        pools_ref.replace_delegation_pool.delegated = 0;
        pools_ref.replace_delegation_pool.lockup_cycle_update_epoch = 0;
        pools_ref.replace_delegation_pool.pool = @0x0;
    }


    #[view]
    /// Return details users may need during deposit operation (expected iAsset to receive and fees)
    public fun get_deposit_calculations(iasset: Object<Metadata>, asset_amount: u64): AssetCalculationInfo {
        let (_, origin_token_chain_id, _, _) = iAsset::deconstruct_iasset_source(&iAsset::get_iasset_source(iasset));
        let (in_fees, _, _) = asset_config::get_service_fees();
        // fees depend on the chain ID
        let fees = if (origin_token_chain_id == (chain_id::get() as u64)){
            in_fees
        }else {
            0
        };
        iAsset::get_deposit_calculations(iasset, asset_amount, fees)
    }

    #[view]
    /// Return details users may need during redeem operation (expected collateral asset to receive and fees)
    public fun get_redeem_calculations(iasset: Object<Metadata>, iasset_amount: u64): AssetCalculationInfo {
        let fees = take_redeem_service_fees(iasset);
        iAsset::get_redeem_calculations(iasset, iasset_amount, fees)
    }
    
    /// Submits a redemption request to convert iAsset into the collateral asset
    public entry fun redeem_request(account: &signer, iasset: Object<Metadata>, amount: u64) {
        let fees = take_redeem_service_fees(iasset);
        iAsset::redeem_request(account, amount, iasset, fees);
    }

    /// Redeems iAsset for the collateral asset
    public entry fun redeem_iasset(account: &signer, iasset: Object<Metadata>, destination: vector<u8>) {
        let (origin_token_address, origin_token_chain_id, origin_token_decimals, source_bridge_address) = iAsset::deconstruct_iasset_source(&iAsset::get_iasset_source(iasset));
        let amount = iAsset::redeem_iasset(account, iasset);
        // de-normalize (from 8 to origin decimals) redeem amount before sending to the redeem process
        let n_amount = asset_util::scale_to_origin(amount, origin_token_decimals);
        redeem_router::redeem_iasset(origin_token_address, origin_token_chain_id, source_bridge_address, n_amount, destination);

        event::emit<RedeemEvent>(
            RedeemEvent {
                account : signer::address_of(account),
                asset : object::object_address(&iasset),
                amount : amount,
                origin_token_amount : n_amount,
                origin_token_address : origin_token_address,
                origin_token_chain_id: origin_token_chain_id,
                source_bridge_address : source_bridge_address,
                destination_address : destination
            }
        );
    }

    /// Updates the user-specific reward index
    public entry fun update_rewards(account: &signer, asset: Object<Metadata>) {
        let user_address = signer::address_of(account);
        iAsset::update_rewards(user_address, asset);
    }

    /// Enable users to claim their accrued rewards
    public entry fun claim_rewards(account: &signer) {
        let user_address = signer::address_of(account);
        let claimed_rewards = iAsset::claim_rewards(user_address);
        if (claimed_rewards > 0) {
            // there is no specific logic, only event for now
            event::emit<RewardsClaimedEvent>(
                RewardsClaimedEvent {
                    account: user_address,
                    amount: claimed_rewards,
                }
             );
        };
    }

    /// Enable users to withdraw their withdrawable rewards
    public entry fun withdraw_rewards(account: &signer) acquires PoelControler, RewardBudget {
        let user_address = signer::address_of(account);
        // method returns withdrawable 
        let  withdrawable_rewards = iAsset::withdraw_rewards(user_address);

        if (withdrawable_rewards > 0) {
            // send coins from PoEL vault to user address
            coin::transfer<SupraCoin>(&get_vault_signer(), user_address, withdrawable_rewards);

            let reward_budget_ref = borrow_global_mut<RewardBudget>(get_storage_address());
            // as rewards are withdrawn from the PoEL vault, update the allocated reward balance state
            reward_budget_ref.allocated_reward_balance = reward_budget_ref.allocated_reward_balance - withdrawable_rewards;

            event::emit<RewardsWithdrawnEvent>(
                RewardsWithdrawnEvent {
                    account: user_address,
                    amount: withdrawable_rewards,
                }
             );
        }
    }

    /// Withdraws SUPRA from delegation pools 
    fun safe_withdraw(delegator: &signer, pool_address: address): u64 {
        let delegator_address = signer::address_of(delegator);
        let (lockup_cycle_ended, inactive) = get_pending_withdrawal(pool_address, delegator_address);
        // Execute the withdrawal using the withdraw function from pbo_delegation_pool.move
        if (lockup_cycle_ended && inactive > 0) {
            withdraw(delegator, pool_address, inactive);
            inactive
        } else {
            0
        }
    }

    /// Return the redemption fees for the iasset
    fun take_redeem_service_fees (iasset: Object<Metadata>): u64 {
        let (_, origin_token_chain_id, _, _) = iAsset::deconstruct_iasset_source(&iAsset::get_iasset_source(iasset));
        let (_, out_fees, out_fees_external) = asset_config::get_service_fees();
        // fees depend on the chain id
        if (origin_token_chain_id == (chain_id::get() as u64)){
            out_fees
        }else {
            out_fees_external
        }
    }

    /// returns whether the delegation pool is active
    inline fun is_pool_active (pool: address) : bool {
        get_validator_state(pool) == VALIDATOR_STATUS_ACTIVE
    }

    #[test_only]
    friend dfmm_framework::poel_test;

    #[test_only]
    use supra_framework::stake;

    #[test_only]
    friend dfmm_framework::poel_rewards_test;

    #[test_only]
    friend dfmm_framework::iAsset_test;
    #[test_only]
    const LOCKUP_CYCLE_SECONDS: u64 = 2592000;

    #[test_only]
    const ONE_SUPRA: u64 = 100000000;

    #[test_only]
    const VALIDATOR_SUPRA: u64 = 1000 * 100000000;

    #[test_only]
    const VALIDATOR_A: address = @0x1;

    #[test_only]
    const VALIDATOR_A_AMOUNT: u64 = 10 * 100000000;

    #[test_only]
    const VALIDATOR_B_AMOUNT: u64 = 20 * 100000000;

    #[test_only]
    const VALIDATOR_B: address = @0x2;

    #[test_only]
    public fun init_poel_for_test(deployer: &signer) {
        init_module(deployer);
    }

    #[test_only]
    public fun get_total_borrowable_amount(): u64 acquires DelegatedAmount {
        borrow_global<DelegatedAmount>(get_storage_address()).total_borrowable_amount
    }

    #[test_only]
    public fun get_single_asset_reward_balance_for_test (asset: Object<Metadata>): u64 acquires RewardBudget {
        let reward_budget_ref = borrow_global<RewardBudget>(get_storage_address());
        *table::borrow_with_default(&reward_budget_ref.single_asset_reward_balance, asset, &0)
    }

    #[test_only]
    public fun get_multiple_asset_reward_balance_for_test (): u64 acquires RewardBudget {
        let reward_budget_ref = borrow_global<RewardBudget>(get_storage_address());
        reward_budget_ref.multiple_asset_reward_balance
    }

    #[test_only]
    public fun increase_total_distributable_rewards(amount:u64) acquires RewardBudget {
        let ref = borrow_global_mut<RewardBudget>(get_storage_address());
        ref.total_distributable_rewards = ref.total_distributable_rewards + amount;
        ref.allocation_ts = timestamp::now_seconds();
    }

    #[test_only]
    public fun increase_stimulation_rewards_accumulated(amount:u64) acquires RewardBudget {
        let ref = borrow_global_mut<RewardBudget>(get_storage_address());
        ref.stimulation_rewards_accumulated = amount;
    }

    #[test_only]
    public fun increase_allocated_reward_balance(amount:u64) acquires RewardBudget {
        let ref = borrow_global_mut<RewardBudget>(get_storage_address());
        ref.allocated_reward_balance = amount;
    }

    #[test_only]
    public fun get_stimulation_rewards():(u64, u64, u64) acquires RewardBudget {
        let ref = borrow_global<RewardBudget>(get_storage_address());
        (ref.stimulation_rewards_accumulated, ref.stimulation_rewards_claimed, ref.stimulation_rewards_claim_epoch)
    }

    #[test_only]
    public fun get_total_distributable_rewards_of(asset: Object<Metadata>):(u64, u64) acquires RewardBudget {
        let ref = borrow_global<RewardBudget>(get_storage_address());
        let last_distributable_rewards = *smart_table::borrow_with_default(&ref.last_distributable_rewards, asset, &0);
        (last_distributable_rewards, ref.total_distributable_rewards)
    }

    #[test_only]
    public fun update_borrowed_amount_for_test(deployer: &signer) acquires DelegatedAmount, DelegationPools, PoelControler {
        update_borrowed_amount(deployer);
    }

    #[test_only]
    public fun delegate_tokens_for_test(delegable_amount: u64,cap_value: u64): u64 acquires DelegationPools, PoelControler {
        delegate_tokens(delegable_amount, cap_value)
    }

    #[test_only]
    public fun find_top_pools_for_test(pools: &vector<address>, vault: address): (u64, u64, u64, u64) {
        find_top_pools(pools, vault)
    }

    #[test_only]
    public fun find_bottom_pools_for_test(pools: &vector<address>, vault: address, cap: u64): (u64, u64, u64, u64) {
        find_bottom_pools(pools, vault, cap)
    }

    #[test_only]
    public fun unlock_tokens_for_test(supra_amount: u64, total_delegated_amount: u64) :u64 acquires DelegationPools, PoelControler {
        unlock_tokens(supra_amount, total_delegated_amount)
    }

    #[test_only]
    public fun mint_stake(pools: vector<address>, values: vector<u64>) acquires PoelControler {
        let v_signer = get_vault_signer();
        stake::mint(&v_signer, VALIDATOR_SUPRA);

        vector::zip<address, u64>(
            pools,
            values,
            |pool, value|
        {
            add_stake(&v_signer, pool, value);
        });
    }

}
