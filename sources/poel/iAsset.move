/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
/// 
/// This module represents iAsset concept
///
module dfmm_framework::iAsset {
    use aptos_std::vector;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::table_with_length::{Self, TableWithLength};
    use aptos_std::error;
    use aptos_std::math64;
    use aptos_std::math128;
    use aptos_std::object::{Self, Object, ExtendRef};
    use aptos_std::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use std::signer;
    use std::string;
    use std::option::{Self, Option};
    use supra_oracle::supra_oracle_storage;
    use supra_framework::function_info::{Self, FunctionInfo};
    use supra_framework::primary_fungible_store;
    use supra_framework::reconfiguration::current_epoch;
    use supra_framework::dispatchable_fungible_asset;

    use dfmm_framework::config;
    use dfmm_framework::asset_util;
    use supra_framework::timestamp;
    use supra_framework::event::{Self};

    friend dfmm_framework::poel;

    /// Thrown when the FA coin is paused
    const EPAUSED: u64 = 2;

    /// Thrown when not enough epochs have passed to allow minting of the preminted iAssets
    const EMINT_NOT_VALID_EPOCH: u64 = 3;

    /// Thrown when the asset balance is insufficient to perform an operation
    const EBALANCE_NOT_ENOUGH: u64 = 4;

    /// Thrown when the required waiting period has not yet passed to redeem assets from the system
    const EUNLOCK_REQUEST_TIME: u64 = 5;

    /// Thrown when the redeem amount is equal to zero
    const EREDEEM_AMOUNT: u64 = 6;

    ///Thrown when the sum of all asset weights does not equal MAX_WEIGHT
    const EWRONG_WEIGHT: u64 = 7;

    ///Thrown when the length of the desired asset weight vector does not match the number of assets supported by the system.
    const EWRONG_CWV_LENGTH: u64 = 8;

    /// Thrown when the iasset is not redeemable
    const ENOT_REDEEMABLE: u64 = 9;

    ///Thrown when the length of the desirability score vector does not match the number of assets supported by the system
    const EWRONG_DESIRABILITY_SCORE_LEN: u64 = 10;

    ///Thrown when the asset is not supported by the PoEL system.
    const EASSET_NOT_PRESENT: u64 = 11;

    /// Thrown when the asset being deployed has already been deployed
    const EIASSET_ALREADY_DEPLOYED: u64 = 13;

    /// Thrown when the IntraLayer vault contains no assets
    const EDEPOSITED_ASSET_AMOUNT: u64 = 15;

    /// Thrown when the required waiting period has not passed to withdraw the claimed rewards
    const ENOT_ENOUGH_TIME_PASSED: u64 = 16;

    /// Thrown when there are no rewards available for withdrawal
    const ENOT_ENOUGH_WITHDRAWABLE_REWARDS: u64 = 17;

    /// Thrown when no rewards have been allocated.
    const ENO_ALLOCATED_REWARDS: u64 = 18;

    ///Thrown when desirability score is out of supported range
    const EWRONG_DESIRED_SCORE: u64 = 19;

    /// Thrown when the amount cannot cover service fees
    const ECANT_COVER_FEES: u64 = 21;

    /// Thrown when the requested amount exceeds deposited asset supply
    const EWITHDRAW_ASSET_AMOUNT_EXCEEDED: u64 = 22;

    /// Thrown when the requested amount of iasset exceeds the allowed amount
    const EREDEEM_REQ_IASSET_EXCEEDED: u64 = 23;

    /// Thrown when nominal liquidity is zero
    const EZERO_LIQUIDITY: u64 = 24;

    /// Thrown when there are no withdrawable rewards
    const ENO_WITHDRAWABLE_REWARDS: u64 = 25;

    /// Thrown when the epoch is invalid
    const EINVALID_EPOCH: u64 = 26;

    /// The storage object name used in `object::create_named_object(address, OBJECT_NAME)`
    const IASSET_GLOBAL: vector<u8> = b"IASSET_GLOBAL";

    /// Maximum weight used in portfolio composition calculations
    const MAX_WEIGHT: u64 = 100_000;

    const MULTIPLIER: u128 = 1_000;

    /// Multiplier used when calculating collateralization rates
    const COLLATERALISATION_RATE_MULTIPLIER: u128 = 1_000;

    /// Oracle price ID for the Supra coin
    const SUPRA_PAIR_ID :u32 = 500;

    /// Internal identifier for USDT (NOT an oracle pair ID). Used only by get_asset_price() for identifying USDT.
    const USDT_ID :u32 = 999999;// must not collide with real pair IDs

    /// Number of seconds in one year (365 days)
    const ONE_YEAR_SEC :u64 = 31536000;

    /// Multiplier used in reward calculations
    const REWARDS_MULTIPLIER: u64 = 100000000;

    /// Default desired score value for asset
    const DEF_DESIRED_SCORE: u64 = 1;

    // Maximum desired score value for asset
    const MAX_DESIRED_SCORE: u64 = 100;

    struct AssetValuePair has copy, drop, store {
      asset: address,
      value: u64,
    }

    #[event]
    struct DesirabilityScoresUpdatedEvent has copy, drop, store {
      scores: vector<AssetValuePair>
    }

    #[event]
    struct DesiredWeightsUpdatedEvent has copy, drop, store {
      weights: vector<AssetValuePair>
    }

    #[event]
    struct AccountUnfrozenEvent has copy, drop, store {
      asset: address,
      account: address,
    }

    #[event]
    struct AccountFrozenEvent has copy, drop, store {
      asset: address,
      account: address,
    }

    #[event]
    struct PauseToggledEvent has copy, drop, store {
      asset: address,
      paused: bool,
    }

    #[event]
    struct RedeemToggledEvent has copy, drop, store {
      asset: address,
      redeemable: bool,
    }

    #[event]
    struct RedeemRequestedEvent has copy, drop, store {
      requester:    address,
      asset:        address,
      iasset_amount: u64,
      preview_amount: u64,
    }

    #[event]
    struct IAssetRedeemedToCoinEvent has copy, drop, store {
      origin_token_address: vector<u8>,
      origin_token_chain_id: u64,
      amount: u64,
      destination: address,
    }

    #[event]
    struct UpdateRewardsEvent has copy, drop, store {
      account: address,
      asset: Object<Metadata>,
      amount : u64
    }

    /// Contains the essential identifiers needed to uniquely identify a token from its source blockchain.
    struct OriginTokenInfo has store, copy, drop {
        // contract address of the token on source chain
        token_address: vector<u8>,
        // identifier of the source blockchain
        chain_id: u64
    }

    struct IAssetFunctionStore has key {
        withdraw_function: FunctionInfo,
        deposit_function: FunctionInfo,
    }

    struct AssetCalculationInfo has copy, drop {
        /// configured fees in supra
        fees_in_supra : u64,
        /// portion of iasset as fees
        fees_iasset : u64,
        /// portion of orginal asset as fees
        fees_asset : u64,
        /// input amount or scaled input amount if normalization required for the operation
        scaled_input : u64,
        /// calculated target amount according to the operation
        target_amount : u64,
    }

    ///The AssetEntry struct maintains user-specific metrics for each iAsset, with one entry per asset per user.
    struct AssetEntry has store, copy, drop {
        /// track RewardIndex specific to the user for each asset
        user_reward_index: u64,
        /// tracks  number  of iAssets that are preminted
        preminted_iassets: u64,
        /// number of iAssets for which redemption has been requested
        redeem_requested_iassets: u64,
        /// records the epoch number in which the last preminting request was submitted for a given asset.
        preminting_epoch_number: u64,
        /// records the timestamp where last preminting request was submited for a given asset.
        preminting_ts: u64,
        /// records the timestamp of the user's most recent unlock request.
        unlock_request_timestamp: u64,
        /// records the epoch of the user's most recent unlock request.
        unlock_request_epoch: u64
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Represents a user's liquidity provider profile, storing information about their iAsset holdings
    /// One instance per user, managing their assets and reward allocations.
    struct LiquidityProvider has key {
        /// A table mapping iasset metadata to the user's asset-specific details
        asset_entry: SmartTable<Object<Metadata>, AssetEntry>,
        /// Epoch when rewards were last allocated to the user
        reward_allocation_epoch: u64,
        /// Total rewards allocated to the user
        allocated_rewards: u64,
        /// Rewards available for withdrawal after the lockup period.
        withdrawable_rewards: u64,
        /// Total withdrawn rewards by the user
        total_withdrawn_rewards: u64,
        /// Timestamp when rewards were last allocated to the user
        reward_allocation_timestamp: u64,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    ///Stores global liquidity metrics and operational data for all assets managed in the system.
    struct TotalLiquidity has key {
        ///Maps user addresses to their corresponding liquidity provider object addresses
        liquidity_provider_objects: TableWithLength<address, address>,
        /// A table mapping iasset metadata to detailed asset information, such as reward indices and origin details.
        assets: SmartTable<Object<Metadata>, AssetInfo>,
        /// Maps origin token information (address and chain ID) to corresponding iAsset metadata.
        asset_origins: SmartTable<OriginTokenInfo, Object<Metadata>>, //origin details (address, chain) to iasset metadata
        /// Reference for extending the global liquidity object's functionality.
        extend_ref: ExtendRef,
        /// Last epoch at which a lockup-cycle change was detected
        recent_cycle_update_epoch: u64,
        /// Most recent timestamp when a lockup-cycle change was detected
        lockup_cycle_start_ts: u64
    }

    #[resource_group_member(group = aptos_std::object::ObjectGroup)]
    /// Manages references for controlling iAsset fungible assets, including minting, transferring, and burning capabilities.
    /// One instance per asset.
    struct ManagingRefs has key {
        /// Reference enabling minting of new iAsset tokens.
        mint_ref: MintRef,
        /// Reference enabling transfer operations for the iAsset
        transfer_ref: TransferRef,
        /// Reference enabling burning of iAsset tokens
        burn_ref: BurnRef,
        /// Reference for extending the asset's object functionality
        extend_ref: ExtendRef,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Tracks liquidity metrics for each asset
    struct LiquidityTableItems has key, copy, drop {
        /// Unique identifier for the asset's oracle price pair
        pair_id: u32,
        /// Total amount of the underlying asset applied to borrow and delegate Supra.
        collateral_supply: u64,
        /// Target weight of the asset in the collateral portfolio
        desired_weight: u32,
        /// Desirability score of the asset.
        desirability_score: u64,
        /// Total amount of borrow requests for the asset.
        total_borrow_requests: u64,
        /// Total amount of withdrawal requests for the asset
        total_withdraw_requests: u64,
        /// Total amount of preminted iAssets for the asset
        total_preminted_assets: u64,
        /// Total amount of iAssets requested for redemption
        total_redeem_requested_iassets: u64,
        /// Total amount of the underlying asset deposited into the intralayer vault
        deposited_asset_supply: u64
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Tracks operations for each asset
    struct AssetOperations has key {
        /// Indicates whether the asset's transfer is paused
        paused: bool,
        /// Boolean indicating iAsset redeemability
        redeemable: bool,
    }

    /// Stores relevant iasset details
    struct AssetInfo has store, copy, drop {
        /// Asset APY over the previous calculation window
        apy : u64,
        /// Last epoch when APY was updated
        apy_update_epoch: u64,
        /// Previous gloabl reward index for the iasset
        previous_reward_index_asset : u64,
        /// Global reward index for the iasset
        reward_index_asset: u64,
        /// Total rewards available for distribution to holders of the iasset.
        allocated_rewards_for_asset: u64,
        /// Address of origin token and its native chain id.
        origin_token: OriginTokenInfo,
        /// Address of the bridge service responsible for preminting the iAsset.
        source_bridge_address: vector<u8>,
        /// Number of decimals for the token on its native chain.
        origin_token_decimals: u16
    }

    struct AssetPremint has copy, drop, store {
        /// Metadata of the preminted iAssets.
        asset: Object<Metadata>,
        /// Amount of iAssets preminted for the user.
        preminted_iassets: u64,
        /// The last epoch number when the preminting occurred.
        preminting_epoch_number: u64,
        /// The last timestampt when the preminting occurred.
        preminting_ts: u64
    }

    struct IAssetSource has copy, drop {
        /// address of the origin token
        token_address : vector<u8>,
        /// chain id of the origin token
        chain_id : u64,
        /// number of decimals of the origin token
        token_decimals : u16,
        /// bridge address
        bridge_address : vector<u8>,
    }

    struct UserRewardsInfo has copy, drop {
        /// Allocated rewards for a user
        allocated_rewards: u64,
        /// Withdrawable (claimed) rewards for a user
        withdrawable_rewards: u64,
        /// Epoch when rewards were claimed
        withdrawable_rewards_epoch: u64,
        /// Timestamp when rewards were claimed
        withdrawable_rewards_ts: u64,
        /// Withdrawn rewards for a user
        withdrawn_rewards: u64
    }

    struct AssetPrice has store, drop {
        value: u128,
        decimals: u16,
        timestamp: u64,
        round: u64
    }

    /// Initializes the module by creating the global storage object and setting up essential structures.
    fun init_module(account: &signer) {
        let constructor_ref = object::create_named_object(account, IASSET_GLOBAL);

        let global_signer = &object::generate_signer(&constructor_ref);


        /// Initialize the TotalLiquidity structure to track assets and liquidity providers.
        move_to(global_signer, TotalLiquidity {
            liquidity_provider_objects: table_with_length::new(),
            assets: smart_table::new(),
            asset_origins : smart_table::new(),
            extend_ref: object::generate_extend_ref(&constructor_ref),
            recent_cycle_update_epoch: 0,
            lockup_cycle_start_ts: 0,
        });

        /// Store global function references for deposit and withdraw operations
        move_to (global_signer, IAssetFunctionStore {
            withdraw_function: function_info::new_function_info(
                account,
                string::utf8(b"iAsset"),
                string::utf8(b"withdraw"),
            ),
            deposit_function: function_info::new_function_info(
                account,
                string::utf8(b"iAsset"),
                string::utf8(b"deposit"),
            )
        });
    }

    ///Updates the global reward index for an asset based on newly distributed rewards.
    public(friend) fun update_reward_index(
        asset: Object<Metadata>,
        rewards: u64
    ) acquires TotalLiquidity, LiquidityTableItems {
        // Get the supply of the iasset
        let iasset_supply = get_iasset_supply(asset);
        if (iasset_supply == 0) return; // to not break the allocate_rewards TX in case of multiple asset types
        // Calculate the increase in reward-index based on the distributed rewards and iasset supply
        let reward_index_increase = math64::mul_div(rewards, REWARDS_MULTIPLIER, iasset_supply);

        let total_liquidity_ref = borrow_global_mut<TotalLiquidity>(get_storage_address());
        let asset_info = smart_table::borrow_mut(
            &mut total_liquidity_ref.assets,
            asset
        );

        let epoch = current_epoch();
        // criteria to calculate APY based on the target APY calculation window
        if (epoch > asset_info.apy_update_epoch + config::get_number_of_epoch_in_apy()) {
            // calculate apy
            let (apy, _) = calculate_asset_apy(asset,
                (asset_info.reward_index_asset - asset_info.previous_reward_index_asset),
                config::get_number_of_epoch_in_apy() + 1);

            // Update the APY details of the iasset and previous global reward index
            asset_info.apy = apy;
            asset_info.apy_update_epoch = epoch;
            asset_info.previous_reward_index_asset = asset_info.reward_index_asset;
        };

        // update global reward index for the iasste and total allocated rewards for the asset
        asset_info.reward_index_asset = asset_info.reward_index_asset + reward_index_increase;
        asset_info.allocated_rewards_for_asset = asset_info.allocated_rewards_for_asset +  rewards;
    }

    #[view]
    /// Calculates rewards accrued for the user based on their reward index and iAsset balance.
    public fun calculate_rewards(
        user_address: address,
        user_reward_index: u64,
        asset: Object<Metadata>
    ): u64 acquires TotalLiquidity {
        let iasset_balance = primary_fungible_store::balance(user_address, asset);
        calculate_rewards_internal(user_reward_index, iasset_balance, asset)
    }

    /// Updates the user's reward index and allocated rewards
    /// Ensures the user's reward index is updated to the latest global reward index for iasset after calculating distributable rewards.
    public(friend) fun update_rewards(user_address: address, asset: Object<Metadata>) acquires TotalLiquidity, LiquidityProvider {
        let iasset_balance = primary_fungible_store::balance(user_address, asset);
        update_rewards_internal(user_address, iasset_balance, asset);
    }

    /// Allows a user to claim their withdrawable rewards
    public(friend) fun claim_rewards(user_address: address): u64 acquires LiquidityProvider, TotalLiquidity {
        let liquidity_provider_object_address = ensure_liquidity_provider(user_address);
        let liquidity_provider_ref = borrow_global_mut<LiquidityProvider>(liquidity_provider_object_address);

        let current_ts = timestamp::now_seconds();

        // ensures that user has some allocated rewards that could be claimed
        assert!(liquidity_provider_ref.allocated_rewards != 0, error::invalid_argument(ENO_ALLOCATED_REWARDS));

        // add the allocated rewards to the withdrawable claimed-rewards balance, can be withdrawn once the lockup cycle ends.
        liquidity_provider_ref.withdrawable_rewards = liquidity_provider_ref.withdrawable_rewards + liquidity_provider_ref.allocated_rewards;
        liquidity_provider_ref.allocated_rewards = 0;
        // update the timestamp and epoch at which rewards were claimed
        liquidity_provider_ref.reward_allocation_epoch = current_epoch();
        liquidity_provider_ref.reward_allocation_timestamp = current_ts;

        liquidity_provider_ref.withdrawable_rewards
    }

    /// Withdraw wihdrawable claimed rewards
    public(friend) fun withdraw_rewards(user_address: address):  u64 acquires LiquidityProvider, TotalLiquidity {
        let liquidity_provider_object_address = ensure_liquidity_provider(user_address);
        let liquidity_provider_ref = borrow_global_mut<LiquidityProvider>(liquidity_provider_object_address);

        let recent_cycle_update_epoch = get_cycle_data();

        assert!(liquidity_provider_ref.withdrawable_rewards > 0, error::invalid_argument(ENO_WITHDRAWABLE_REWARDS));
        // ensure the lockup period has ended after claiming, so the claimed tokens are already in the PoEL vault and available for withdrawal
        assert!(liquidity_provider_ref.reward_allocation_epoch < recent_cycle_update_epoch, error::invalid_argument(ENOT_ENOUGH_TIME_PASSED));

        let withdrawable_rewards = liquidity_provider_ref.withdrawable_rewards;
        liquidity_provider_ref.withdrawable_rewards = 0;
        liquidity_provider_ref.reward_allocation_epoch = 0;

        if (withdrawable_rewards > 0) {
            // update global counter for the user
            liquidity_provider_ref.total_withdrawn_rewards = liquidity_provider_ref.total_withdrawn_rewards + withdrawable_rewards;
        };

        // withdrawable_rewards - variable holds amount ready to withdraw
        withdrawable_rewards
    }



    /// Creates a new iAsset as a fungible asset and registers it in the TotalLiquidty struct.
    /// Ensures the iAsset is linked to its origin token and bridge service
    public(friend) fun create_new_iasset(
        admin: &signer,
        iAsset_name: vector<u8>,
        iAsset_symbol: vector<u8>,
        decimals: u8,
        pair_id: u32,
        icon_uri: vector<u8>,
        project_uri: vector<u8>,
        origin_token_address: vector<u8>,
        origin_token_chain_id: u64,
        origin_token_decimals: u16,
        source_bridge_address: vector<u8> // connection to the bridge service
    ): Object<Metadata> acquires TotalLiquidity, IAssetFunctionStore {
        //get the global storage address
        let tracker_address = get_storage_address();

        let token_identifier = build_token_info(origin_token_address, origin_token_chain_id);

        /// Ensure the iAsset for this origin token has not been deployed already.
        assert!(!smart_table::contains(&borrow_global<TotalLiquidity>(tracker_address).asset_origins, token_identifier), error::invalid_state(EIASSET_ALREADY_DEPLOYED));

        /// Create metadata for the new iAsset.
        let metadata_constructor_ref = &object::create_named_object(
            admin, iAsset_symbol
        );

        // Create a store enabled fungible asset
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            metadata_constructor_ref,
            option::none(),
            string::utf8(iAsset_name),
            string::utf8(iAsset_symbol),
            decimals,
            string::utf8(icon_uri),
            string::utf8(project_uri),
        );

        /// Override deposit and withdraw functions to enforce custom logic
        let iasset_functions = borrow_global<IAssetFunctionStore>(tracker_address);
        dispatchable_fungible_asset::register_dispatch_functions(
            metadata_constructor_ref,
            option::some(iasset_functions.withdraw_function),
            option::some(iasset_functions.deposit_function),
            option::none(),
        );

        // Generate the mint, burn transfer and extend refs then store
        let mint_ref = fungible_asset::generate_mint_ref(metadata_constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(metadata_constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(metadata_constructor_ref);
        let extend_ref = object::generate_extend_ref(metadata_constructor_ref);
        let metadata_object_signer = &object::generate_signer(metadata_constructor_ref);
        move_to(
            metadata_object_signer,
            ManagingRefs { mint_ref, transfer_ref, burn_ref, extend_ref}
        );

        move_to(metadata_object_signer, LiquidityTableItems {
            pair_id,
            collateral_supply: 0,
            desired_weight: 0,
            desirability_score: DEF_DESIRED_SCORE, // default desirability score  is 1
            total_borrow_requests: 0,
            total_withdraw_requests: 0,
            total_preminted_assets: 0,
            total_redeem_requested_iassets: 0,
            deposited_asset_supply: 0
        });

        move_to(metadata_object_signer, AssetOperations {
            paused: false, // not paused, transfer is allowed
            redeemable: true // redeem is allowed
        });

        let metadata = object::object_from_constructor_ref(metadata_constructor_ref);
        smart_table::add(
            &mut borrow_global_mut<TotalLiquidity>(tracker_address).assets,
            metadata,
            AssetInfo {
                apy: 0,
                apy_update_epoch: 0,
                previous_reward_index_asset: 0,
                reward_index_asset: 0,
                allocated_rewards_for_asset: 0,
                origin_token: build_token_info(origin_token_address, origin_token_chain_id),
                source_bridge_address: source_bridge_address,
                origin_token_decimals: origin_token_decimals
            }
        );
        /// Registers the relationship between the origin and iAsset metadata.
        smart_table::add(
            &mut borrow_global_mut<TotalLiquidity>(tracker_address).asset_origins,
            token_identifier,
            metadata
        );

        metadata

    }


    #[view]
    /// Retrieves the metadata object for an iAsset based on its origin token's address and chain ID.
    public fun get_iasset_metadata(origin_token_address: vector<u8>, origin_token_chain_id: u64): Object<Metadata> acquires TotalLiquidity {
        let tracker_address = get_storage_address();
        let token_identifier = build_token_info(origin_token_address, origin_token_chain_id);
        assert!(smart_table::contains(&borrow_global<TotalLiquidity>(tracker_address).asset_origins, token_identifier), error::not_found(EASSET_NOT_PRESENT));
        *smart_table::borrow(&borrow_global<TotalLiquidity>(tracker_address).asset_origins, token_identifier)
    }


    #[view]
    /// Checks if an iAsset is registered for a given origin token address and chain ID.
    public fun is_iasset_registered(origin_token_address: vector<u8>, origin_token_chain_id: u64): bool acquires TotalLiquidity {
        let tracker_address = get_storage_address();
        let token_identifier = build_token_info(origin_token_address, origin_token_chain_id);
        smart_table::contains(&borrow_global<TotalLiquidity>(tracker_address).asset_origins, token_identifier)
    }

    #[view]
    /// Verifies if the provided bridge address is valid for an iAsset's origin token.
    public fun is_bridge_valid(origin_token_address: vector<u8>, origin_token_chain_id: u64, source_bridge_address: vector<u8>): bool acquires TotalLiquidity {
        let tracker_address = get_storage_address();
        let token_identifier = build_token_info(origin_token_address, origin_token_chain_id);
        let total_liq = borrow_global<TotalLiquidity>(tracker_address);

        if (!smart_table::contains(&total_liq.asset_origins, token_identifier)) {
            false
        } else {
            let asset = *smart_table::borrow(&total_liq.asset_origins, token_identifier);
            // get_iasset_source returns (origin_token_address, origin_token_chain_id,origin_token_decimals, source_bridge_address)
            let iasset_source = get_iasset_source(asset);

            source_bridge_address == iasset_source.bridge_address
        }


    }

    #[view]
    /// Retrieves the source details of an iAsset, including its origin token address, chain ID, decimals, and bridge address
    public fun get_iasset_source(asset : Object<Metadata>):IAssetSource acquires TotalLiquidity {
        let tracker_address = get_storage_address();
        let tracked_assets = borrow_global<TotalLiquidity>(tracker_address);
        assert!(smart_table::contains(&tracked_assets.assets, asset),error::not_found(EASSET_NOT_PRESENT));
        let asset_info = smart_table::borrow(&tracked_assets.assets, asset);
        IAssetSource {
            token_address : asset_info.origin_token.token_address,
            chain_id : asset_info.origin_token.chain_id,
            token_decimals : asset_info.origin_token_decimals,
            bridge_address : asset_info.source_bridge_address
        }
    }

    public fun deconstruct_iasset_source(item: &IAssetSource): (vector<u8>, u64, u16, vector<u8>) {
        (item.token_address, item.chain_id, item.token_decimals, item.bridge_address)
    }

    public fun deconstruct_asset_value_pair (item: &AssetValuePair): (address, u64) {
        (item.asset, item.value)
    }

    public fun deconstruct_user_rewards (item: &UserRewardsInfo): (u64, u64, u64, u64, u64) {
        (item.allocated_rewards, item.withdrawable_rewards, item.withdrawable_rewards_epoch, item.withdrawable_rewards_ts, item.withdrawn_rewards)
    }

    #[view]
    /// Returns the address of an asset's metadata object
    public fun get_asset_address(asset: Object<Metadata>): address {
        object::object_address(&asset)
    }

    /// Get the address of the global storage object
    fun get_storage_address(): address {
        object::create_object_address(&@dfmm_framework, IASSET_GLOBAL)
    }

    #[view]
    /// Retrieves LiquidityTableItems struct
    public fun get_liquidity_table_items(asset: Object<Metadata>): LiquidityTableItems acquires LiquidityTableItems {
        *borrow_global<LiquidityTableItems>(get_asset_address(asset))
    }

    /// Retrieves values from LiquidityTableItems struct (pair_id, collateral_supply, desired_weight, desirability_score, total_borrow_requests, total_withdraw_requests, total_preminted_assets, total_redeem_requested_iassets, deposited_asset_supply)
    public fun deconstruct_liquidity_table_items(items : &LiquidityTableItems): (u32, u64, u32, u64, u64, u64, u64, u64, u64) {
        (
            items.pair_id,
            items.collateral_supply,
            items.desired_weight,
            items.desirability_score,
            items.total_borrow_requests,
            items.total_withdraw_requests,
            items.total_preminted_assets,
            items.total_redeem_requested_iassets,
            items.deposited_asset_supply
        )
    }

    #[view]
    /// Retrieves paused flag and redeemable flag
    public fun get_asset_status(asset: Object<Metadata>): (bool, bool) acquires AssetOperations {
        let items = borrow_global<AssetOperations>(get_asset_address(asset));
        (items.paused, items.redeemable)
    }

    #[view]
    /// Retrieves the current price and related data for an asset from the price oracle
    public fun get_asset_price(asset: Object<Metadata>): AssetPrice acquires LiquidityTableItems {
        let items = get_liquidity_table_items(asset);
        let (value, decimals, timestamp, round) = get_oracle_price_impl(items.pair_id);
        AssetPrice {value, decimals, timestamp, round}
    }

    #[view]
    /// Retrieves the current price and decimals for the SUPRA token in USDT.
    public fun get_supra_price(): AssetPrice {
        // get_price returns (value,decimal,timestamp,round)
        let (value, decimals, timestamp, round) = supra_oracle_storage::get_price(SUPRA_PAIR_ID);
        AssetPrice {value, decimals, timestamp, round}
    }

    public fun deconstruct_asset_price(item: &AssetPrice): (u128, u16, u64, u64) {
        (item.value, item.decimals, item.timestamp, item.round)
    }

    #[view]
    /// Returns the total supply of an iAsset
    public fun get_iasset_supply(asset: Object<Metadata>): u64 {
        let supply_opt = fungible_asset::supply(asset);
        if (option::is_none(&supply_opt)) {
            0
        } else {
            (option::extract(&mut supply_opt) as u64)
        }
    }

    #[view]
    public fun get_assets(): vector<Object<Metadata>> acquires TotalLiquidity {
        let tracked_assets = borrow_global<TotalLiquidity>(get_storage_address());

        smart_table::keys(&tracked_assets.assets)
    }

    /// Creates an AssetEntry record for a user and iasset. If liqudity provider entry is not available then it is registered (ensure_liquidity_provider)
    fun create_iasset_entry(account: address, asset: Object<Metadata>) acquires TotalLiquidity, LiquidityProvider {
        //check if the liquidity provider object is initialized for the address
        let liquidity_provider_object_address = ensure_liquidity_provider(account);

        let provider_ref = borrow_global_mut<LiquidityProvider>(liquidity_provider_object_address);

        // sanity check for verification of added asset entry
        if (!smart_table::contains(&provider_ref.asset_entry, asset)) {
            smart_table::add(&mut provider_ref.asset_entry, asset, AssetEntry {
                    user_reward_index: 0,
                    preminted_iassets: 0,
                    redeem_requested_iassets: 0,
                    preminting_epoch_number: 0,
                    preminting_ts: 0,
                    unlock_request_epoch: 0,
                    unlock_request_timestamp: 0
                }
            );
        };
    }

    /// Returns asset price based on pair_id. If pair_id = USDT_ID then oracle data feed is not used, price is a constant.
    fun get_oracle_price_impl (pair_id: u32) :  (u128, u16, u64, u64) {
        // if pair_id = USDT_ID then oracle data feed is not used, price is a constant.
        if (pair_id == USDT_ID) {
            // 8 decimals and time & round = 0. Zero means constant
            (100000000, 8, 0, 0)
        } else {
            supra_oracle_storage::get_price(pair_id)
        }
    }

    ///Returns address of a LiquidityProvider object for a user and initializes if it doesn't exist.
    fun ensure_liquidity_provider(user_address: address): address acquires TotalLiquidity {
        // get a mutable reference of the Total liquidity Global state
        let obj_address = get_storage_address();
        let total_liquidity_ref = borrow_global<TotalLiquidity>(obj_address);

        // check if table contains user address
        if (table_with_length::contains(&total_liquidity_ref.liquidity_provider_objects, user_address)) {
            // return Liquidity provider Object
            *table_with_length::borrow(&total_liquidity_ref.liquidity_provider_objects, user_address)
        } else {
            let liquidity_provider_object = borrow_global_mut<TotalLiquidity>(obj_address);
            // initialize the liquidity provider if it is not tracked
            let constructor_ref = object::create_object(obj_address);
            let account = &object::generate_signer(&constructor_ref);
            let liquidity_provider = LiquidityProvider {
                //unlock_request_timestamp: 0u64,
                asset_entry: smart_table::new(),
                reward_allocation_epoch: 0,
                withdrawable_rewards:0,
                allocated_rewards: 0,
                total_withdrawn_rewards: 0,
                reward_allocation_timestamp: 0,
            };
            move_to(account, liquidity_provider);

            let lp_obj_address = signer::address_of(account);

            table_with_length::add(
                &mut liquidity_provider_object.liquidity_provider_objects,
                user_address,
                lp_obj_address
            );
            lp_obj_address
        }
    }

    /// Checks if a LiquidityProvider object exists for a user and returns its address.
    fun get_liquidity_provider(user_address: address): Option<address> acquires TotalLiquidity {
        let liquidity_provider_object = borrow_global<TotalLiquidity>(get_storage_address());
        if (table_with_length::contains(&liquidity_provider_object.liquidity_provider_objects, user_address)) {
            option::some(*table_with_length::borrow(&liquidity_provider_object.liquidity_provider_objects, user_address))
        }else {
            option::none()
        }
    }


    #[view]
    /// Retrieves the asset entry details for a user and asset, including reward index and preminted iasset data.
    public fun get_asset_entry(
        user_address: address,
        asset: Object<Metadata>
    ): Option<AssetEntry> acquires TotalLiquidity, LiquidityProvider {

        let user_liquidity_address_opt = get_liquidity_provider(user_address);
        if (option::is_none(&user_liquidity_address_opt)) return option::none();

        let liq_provider = borrow_global<LiquidityProvider>(option::extract(&mut user_liquidity_address_opt));

        // asset entry is not registered yet for the user, then return none
        if (!smart_table::contains(&liq_provider.asset_entry, asset)) return option::none();

        option::some(*smart_table::borrow(&liq_provider.asset_entry, asset))
    }

    /// Retrieves values from AssetEntry struct (user_reward_index, preminted_iassets, redeem_requested_iassets, preminting_epoch_number, preminting_ts, unlock_request_timestamp, unlock_request_epoch)
    public fun deconstruct_asset_entry(item: &AssetEntry): (u64, u64, u64, u64, u64, u64,  u64) {
        (item.user_reward_index, item.preminted_iassets, item.redeem_requested_iassets, item.preminting_epoch_number, item.preminting_ts, item.unlock_request_timestamp, item.unlock_request_epoch)
    }

    /// Premints iAssets for a user based on deposited assets, updating user and global liquidity metrics.
    public(friend) fun premint_iasset(
        asset_amount: u64,
        asset: Object<Metadata>,
        receiver: address,
    ) acquires LiquidityProvider, TotalLiquidity, LiquidityTableItems {

        let tracked_assets = borrow_global<TotalLiquidity>(get_storage_address());
        // assert that the iAsset being preminted has been created
        assert!(smart_table::contains(&tracked_assets.assets, asset),error::not_found(EASSET_NOT_PRESENT));

        // check whether the AssetEntry struct is in the store address
        create_iasset_entry(receiver, asset);

        let user_liquidity_obj_address = option::extract(&mut get_liquidity_provider(receiver));

        let asset_entry = smart_table::borrow_mut(
            &mut borrow_global_mut<LiquidityProvider>(user_liquidity_obj_address).asset_entry,
            asset
        );

        let iasset_amount = preview_mint(asset_amount, asset);

        // update preminted_iassets for the user and iasset
        asset_entry.preminted_iassets = (asset_entry.preminted_iassets + iasset_amount);

        let asset_liquidity_ref = borrow_global_mut<LiquidityTableItems>(get_asset_address(asset));
        // update the global preminted_iasset value for this asset.
        asset_liquidity_ref.total_preminted_assets = asset_liquidity_ref.total_preminted_assets + iasset_amount;
        // update total deposited asset supply
        asset_liquidity_ref.deposited_asset_supply = asset_liquidity_ref.deposited_asset_supply + asset_amount;

        // store current epoch
        asset_entry.preminting_epoch_number = current_epoch();
        // store timestamp
        asset_entry.preminting_ts = timestamp::now_seconds();
    }


    /// Mints preminted iAssets for a user into their primary store, ensuring epoch validity.
    /// Updates rewards before modifying the user's balance.
    public(friend) fun mint_iasset(
        user_address: address,
        asset: Object<Metadata>
    ):u64 acquires ManagingRefs, TotalLiquidity, LiquidityProvider, LiquidityTableItems {

        let tracked_assets = borrow_global<TotalLiquidity>(get_storage_address());
        // assert that the iAsset being preminted has been created
        assert!(smart_table::contains(&tracked_assets.assets, asset),error::not_found(EASSET_NOT_PRESENT));

        let managing_refs = borrow_global<ManagingRefs>(
            object::object_address(&asset)
        );

        create_iasset_entry(user_address, asset);

        let user_liquidity_obj_address = option::extract(&mut get_liquidity_provider(user_address));

        let asset_entry = smart_table::borrow_mut(
            &mut borrow_global_mut<LiquidityProvider>(user_liquidity_obj_address).asset_entry,
            asset
        );

        if (asset_entry.preminted_iassets > 0) {
            // ensure sufficient time has elapsed for the user to mint the iAsset
            assert!((asset_entry.preminting_epoch_number + 1) < current_epoch(), error::invalid_state(EMINT_NOT_VALID_EPOCH));

            let preminted = asset_entry.preminted_iassets;

            let asset_liquidity_ref = borrow_global_mut<LiquidityTableItems>(get_asset_address(asset));
            // decrease the global total_preminted_assets for this asset.
            asset_liquidity_ref.total_preminted_assets = asset_liquidity_ref.total_preminted_assets - asset_entry.preminted_iassets;
            // reset user-specific preminted_iassets for the asset
            asset_entry.preminted_iassets = 0;

            // update rewards before user balance modification
            update_rewards(user_address, asset);
            //mint into primary store
            fungible_asset::mint_to(&managing_refs.mint_ref, primary_fungible_store::ensure_primary_store_exists(user_address, asset), preminted);
            preminted
        }else {
            0
        }
    }

    #[view]
    /// Returns the last epoch at which a lockup-cycle change was detected
    public fun get_cycle_data(): u64 acquires TotalLiquidity {
        let lockup_ref = borrow_global<TotalLiquidity>(get_storage_address());
        lockup_ref.recent_cycle_update_epoch
    }

    #[view]
    /// Returns the last timestamp at which a lockup-cycle change was detected
    public fun get_lockup_cycle_ts(): u64 acquires TotalLiquidity {
        let lockup_ref = borrow_global<TotalLiquidity>(get_storage_address());
        lockup_ref.lockup_cycle_start_ts
    }

    #[view]
    /// Returns total number of liquidity providers
    public fun get_total_lps(): u64 acquires TotalLiquidity {
        let total_liquidity_ref = borrow_global<TotalLiquidity>(get_storage_address());
        table_with_length::length(&total_liquidity_ref.liquidity_provider_objects)
    }

    #[view]
    /// Calculates the amount of iAssets to mint based on deposited assets.
    /// Returns the input amount if the iAsset supply is zero, otherwise uses proportional calculation.
    public fun preview_mint(asset_amount: u64, asset: Object<Metadata>): u64 acquires LiquidityTableItems{
        let asset_liquidity_ref = borrow_global<LiquidityTableItems>(get_asset_address(asset));
        let iasset_supply = get_iasset_extended_supply(asset, asset_liquidity_ref);
        //If iAsset_supply equals 0, set iasset_amount to asset_amount.
        let iasset_amount = if (iasset_supply == 0) {
            asset_amount
        } else {
            math64::mul_div(asset_amount, iasset_supply, asset_liquidity_ref.deposited_asset_supply)
        };
        iasset_amount

    }

    #[view]
    /// Calculates the amount of underlying assets to receive by redeeming a specified amount of iAssets.
    public fun preview_redeem(iasset_amount: u64, asset: Object<Metadata>): u64 acquires LiquidityTableItems {
        let asset_liquidity_ref = borrow_global<LiquidityTableItems>(get_asset_address(asset)); // global store
        let iasset_supply = get_iasset_extended_supply(asset, asset_liquidity_ref);

        if (iasset_supply == 0) {
            0 // nothing to redeem
        } else {
            math64::mul_div(iasset_amount, asset_liquidity_ref.deposited_asset_supply, iasset_supply)
        }
    }


    #[view]
    /// Calculates the amount of iAssets to burn to withdraw a specified amount of underlying assets
    public fun preview_withdraw(asset_amount: u64, asset: Object<Metadata>): u64 acquires LiquidityTableItems {
        let asset_liquidity_ref = borrow_global<LiquidityTableItems>(get_asset_address(asset)); // global store
        let iasset_supply = get_iasset_extended_supply(asset, asset_liquidity_ref);

        assert!(asset_liquidity_ref.deposited_asset_supply > 0
                && asset_liquidity_ref.deposited_asset_supply >= asset_amount,
            error::invalid_state(EDEPOSITED_ASSET_AMOUNT));
        math64::mul_div(iasset_supply, asset_amount, asset_liquidity_ref.deposited_asset_supply)
    }

    #[view]
    /// Returns a breakdown of a redeem operation for a given iAsset amount
    public fun get_redeem_calculations(asset: Object<Metadata>, iasset_amount: u64, fees: u64): AssetCalculationInfo acquires LiquidityTableItems {
        let (fee_in_iasset, fee_in_asset) = get_asset_fees(asset, fees);
        AssetCalculationInfo {
            fees_in_supra : fees,
            fees_iasset : fee_in_iasset,
            fees_asset : fee_in_asset,
            scaled_input: iasset_amount, // iasset amount is already scaled
            target_amount : preview_redeem(iasset_amount, asset),
        }
    }

    /// Retrieves values from AssetCalculationInfo struct (fees_in_supra, fees_iasset, fees_asset, scaled_input, target_amount)
    public fun deconstruct_calculations(calculations: &AssetCalculationInfo) : (u64, u64, u64, u64, u64) {
        (calculations.fees_in_supra, calculations.fees_iasset, calculations.fees_asset, calculations.scaled_input, calculations.target_amount)
    }

    #[view]
    /// Returns a breakdown of a deposit operation for a given iAsset amount
    public fun get_deposit_calculations(asset: Object<Metadata>, asset_amount: u64, fees: u64): AssetCalculationInfo acquires LiquidityTableItems, TotalLiquidity {
        let (fee_in_iasset, fee_in_asset) = get_asset_fees(asset, fees);
        let iasset_source = get_iasset_source(asset);
        // perform normalization: (origin decimals --> 8 decimals)
        let n_amount = (asset_util::scale((asset_amount as u128), iasset_source.token_decimals, 8) as u64);
        //the caller calls assert!(n_amount > fee_asset, error::invalid_state(ECANT_COVER_FEES));
        AssetCalculationInfo {
            fees_in_supra : fees,
            fees_iasset : fee_in_iasset,
            fees_asset : fee_in_asset,
            scaled_input: n_amount,
            target_amount : preview_mint(n_amount, asset),
        }
    }

    /// Submits a request to redeem iAssets, burning them and updating user and global redemption metrics.
    public (friend) fun redeem_request(
        account: &signer,
        iasset_amount: u64,
        asset: Object<Metadata>,
        fees: u64
    ) acquires TotalLiquidity, ManagingRefs, LiquidityTableItems, LiquidityProvider, AssetOperations {

        let tracked_assets = borrow_global<TotalLiquidity>(get_storage_address());
        // ensure that this iAsset exists and it is redeemable
        assert!(smart_table::contains(&tracked_assets.assets, asset),error::not_found(EASSET_NOT_PRESENT));
        assert_redeemable(asset);

        let account_address = signer::address_of(account);
        let iasset_balance = primary_fungible_store::balance(account_address, asset);

        // ensure that user has enough iassets
        assert!(iasset_balance >= iasset_amount, error::invalid_state(EBALANCE_NOT_ENOUGH));

        let liquidity_provider_object = borrow_global<TotalLiquidity>(get_storage_address());

        let user_liquidity_obj_address = *table_with_length::borrow(
            &liquidity_provider_object.liquidity_provider_objects, account_address
        );

        // before burning iassets updates rewards for the user
        update_rewards(account_address, asset);

        let managing_ref = borrow_global<ManagingRefs>(object::object_address(&asset));

        // calculate the redeemption results
        let redeem_info = get_redeem_calculations(asset, iasset_amount, fees);

        // ensure that user can cover the redeemption fees
        assert!(iasset_amount > redeem_info.fees_iasset, error::invalid_state(ECANT_COVER_FEES));

        // calculate how much iassets needs be burned
        let iassets_to_burn = iasset_amount - redeem_info.fees_iasset;

        // transfer fees to `service fees address`
        if (redeem_info.fees_iasset > 0){
            create_iasset_entry(config::get_service_fees_address(), asset);
            update_rewards(config::get_service_fees_address(), asset);
            fungible_asset::transfer_with_ref(&managing_ref.transfer_ref,
                primary_fungible_store::primary_store(account_address, asset),
                primary_fungible_store::ensure_primary_store_exists(config::get_service_fees_address(), asset),
                redeem_info.fees_iasset);
        };

        //burn the assets
        fungible_asset::burn_from(&managing_ref.burn_ref,
            primary_fungible_store::primary_store(account_address, asset),
            iassets_to_burn);

        let asset_entry = smart_table::borrow_mut(
            &mut borrow_global_mut<LiquidityProvider>(user_liquidity_obj_address).asset_entry, asset);
        // increase the redeem requested iAsset balance of the user and log the timestamp and epoch of request
        asset_entry.redeem_requested_iassets = asset_entry.redeem_requested_iassets + iassets_to_burn;
        asset_entry.unlock_request_timestamp = timestamp::now_seconds();
        asset_entry.unlock_request_epoch = current_epoch();

        let asset_liquidity_ref = borrow_global_mut<LiquidityTableItems>(get_asset_address(asset));
        // increase total_redeem_requested_iassets (global state for this iasset)
        asset_liquidity_ref.total_redeem_requested_iassets = asset_liquidity_ref.total_redeem_requested_iassets + iassets_to_burn;
        // increase total_withdraw_request
        asset_liquidity_ref.total_withdraw_requests = asset_liquidity_ref.total_withdraw_requests + (redeem_info.target_amount - redeem_info.fees_asset);

        event::emit<RedeemRequestedEvent>(
            RedeemRequestedEvent {
                requester:     account_address,
                asset:         object::object_address(&asset),
                iasset_amount: iasset_amount,
                preview_amount: redeem_info.target_amount - redeem_info.fees_asset,
            }
        );
    }
    /// Updates the system's record of the last operator lockup cycle change (a concept inherent to delegation pools).
    /// This function is triggered when the system detects a withdrawable amount from the pools, indicating the end of the previous lockup cycle.
    public (friend) fun update_cycle_info(
        current_epoch: u64
    ) acquires TotalLiquidity {
        let ref = borrow_global_mut<TotalLiquidity>(get_storage_address());
        // update epoch and timestamp when a lockup-cycle change is detected
        ref.recent_cycle_update_epoch = current_epoch;
        ref.lockup_cycle_start_ts = timestamp::now_seconds();
    }

    /// Redeems iAssets for underlying assets after the lockup period, updating user and global metrics.
    public (friend) fun redeem_iasset(
        account: &signer,
        asset: Object<Metadata>,
    ) :u64 acquires LiquidityProvider, TotalLiquidity, LiquidityTableItems, AssetOperations {


        let tracked_assets = borrow_global<TotalLiquidity>(get_storage_address());
        // ensure that the iasset exists and it is redeemable
        assert!(smart_table::contains(&tracked_assets.assets, asset),error::not_found(EASSET_NOT_PRESENT));
        assert_redeemable(asset);

        let account_address = signer::address_of(account);

        let user_liquidity_obj_address = ensure_liquidity_provider(account_address);

        let provider_ref = borrow_global_mut<LiquidityProvider>(user_liquidity_obj_address);

        let recent_cycle_update_epoch = get_cycle_data();

        let asset_entry = smart_table::borrow_mut(
            &mut provider_ref.asset_entry, asset);

        // Ensure that redeem_requested_iAssets is greater 0 and that the required waiting period has elapsed to redeem the iAsset
        assert!(asset_entry.redeem_requested_iassets > 0, error::invalid_state(EREDEEM_AMOUNT));
        assert!(asset_entry.unlock_request_epoch < recent_cycle_update_epoch, error::invalid_argument(EUNLOCK_REQUEST_TIME));

        // calculate the amount of collateral asset the user should receive
        let asset_to_withdraw = preview_redeem(asset_entry.redeem_requested_iassets, asset);

        let asset_liquidity_ref = borrow_global_mut<LiquidityTableItems>(get_asset_address(asset));
        // decrease deposited_asset_supply on the global level per asset
        assert!(asset_liquidity_ref.deposited_asset_supply >= asset_to_withdraw, error::invalid_state(EWITHDRAW_ASSET_AMOUNT_EXCEEDED));
        asset_liquidity_ref.deposited_asset_supply = asset_liquidity_ref.deposited_asset_supply - asset_to_withdraw;

        // decrease total_redeem_requested_iassets (global state for this iasset)
        assert!(asset_liquidity_ref.total_redeem_requested_iassets >= asset_entry.redeem_requested_iassets, error::invalid_state(EREDEEM_REQ_IASSET_EXCEEDED));
        asset_liquidity_ref.total_redeem_requested_iassets = asset_liquidity_ref.total_redeem_requested_iassets - asset_entry.redeem_requested_iassets;
        // reset redeem_requested_iasset for the user and asset
        asset_entry.redeem_requested_iassets = 0;
        asset_to_withdraw

    }

    /// Updates the desired weights for all assets in TotalLiquidity to align with strategic objectives.
    /// Ensures the sum of weights equals MAX_WEIGHT.
    public(friend) fun batch_update_desired_weight(
        assets: vector<Object<Metadata>>,
        weights: vector<u32>
    ) acquires TotalLiquidity, LiquidityTableItems {
        let obj_address = get_storage_address();
        let tracked_assets = borrow_global<TotalLiquidity>(obj_address);

        assert!(vector::length(&assets) == vector::length(&weights), error::invalid_argument(EWRONG_CWV_LENGTH));

        let pairs = vector::empty<AssetValuePair>();

        let total_weight = vector::fold(weights, 0, | t, weight| { t + weight });
        assert!((total_weight as u64) == MAX_WEIGHT, error::invalid_argument(EWRONG_WEIGHT));

        vector::zip<Object<Metadata>, u32>(
            assets,
            weights,
            |asset, new_weight|
        {
            assert!(smart_table::contains(&tracked_assets.assets, asset),error::not_found(EASSET_NOT_PRESENT));
            let asset_address = object::object_address(&asset);
            let table_obj = borrow_global_mut<LiquidityTableItems>(asset_address);
            vector::push_back(&mut pairs, AssetValuePair { asset: asset_address, value: (new_weight as u64)});
            table_obj.desired_weight = new_weight;
        });

        event::emit<DesiredWeightsUpdatedEvent>(
            DesiredWeightsUpdatedEvent {
                weights: pairs,
            }
        );
    }

    /// Updates the desirability score for a specific asset(s) in TotalLiquidity.
    public(friend) fun batch_update_desirability_score(
        assets: vector<Object<Metadata>>,
        scores: vector<u64>
    ) acquires TotalLiquidity, LiquidityTableItems {
        let obj_address = get_storage_address();

        let tracked_assets = borrow_global<TotalLiquidity>(obj_address);

        // assert that the input vectors have equal length
        assert!(vector::length(&assets) == vector::length(&scores), error::invalid_argument(EWRONG_DESIRABILITY_SCORE_LEN));

        let pairs = vector::empty<AssetValuePair>();

        vector::zip<Object<Metadata>, u64>(
            assets,
            scores,
            |asset, new_desirability_score|
        {
            // wnsure the iasset exists
            assert!(smart_table::contains(&tracked_assets.assets, asset),error::not_found(EASSET_NOT_PRESENT));
            let asset_address = object::object_address(&asset);
            let table_obj = borrow_global_mut<LiquidityTableItems>(asset_address);
            // control the range
            assert!(new_desirability_score <= MAX_DESIRED_SCORE, error::invalid_state(EWRONG_DESIRED_SCORE));
            vector::push_back(&mut pairs, AssetValuePair { asset: asset_address, value: new_desirability_score });
            table_obj.desirability_score = new_desirability_score;
        });

        event::emit<DesirabilityScoresUpdatedEvent>(
            DesirabilityScoresUpdatedEvent {
                scores: pairs,
            }
        );
    }

    /// Update existing oracle pair IDs for the assets with new values
    public(friend) fun batch_update_pair_ids(
        assets: vector<Object<Metadata>>,
        pair_ids: vector<u32>
    ) acquires TotalLiquidity, LiquidityTableItems {
        let obj_address = get_storage_address();
        let tracked_assets = borrow_global<TotalLiquidity>(obj_address);

        assert!(vector::length(&assets) == vector::length(&pair_ids), error::invalid_argument(EWRONG_CWV_LENGTH));

        vector::zip<Object<Metadata>, u32>(
            assets,
            pair_ids,
            |asset, new_pair_id|
        {
            assert!(smart_table::contains(&tracked_assets.assets, asset),error::not_found(EASSET_NOT_PRESENT));
            let asset_address = object::object_address(&asset);
            let table_obj = borrow_global_mut<LiquidityTableItems>(asset_address);
            table_obj.pair_id = new_pair_id;
        });

    }

    /// Calculates the total nominal liquidity across all assets, update collateral supplies based on borrow and withdraw requests.
    public fun calculate_nominal_liquidity(): (u128, AssetPrice) acquires TotalLiquidity, LiquidityTableItems {
        let total_nominal_liquidity: u128 = 0;
        let total_liquidity_ref = borrow_global<TotalLiquidity>(get_storage_address());

        let supra_price = get_supra_price(); // supra price in usdt

        smart_table::for_each_ref<Object<Metadata>, AssetInfo>(
            &total_liquidity_ref.assets,
            |key, _value| {
                let asset = *key;
                let table_obj = borrow_global_mut<LiquidityTableItems>(object::object_address(&asset));
                // update collateral supply
                // The subtraction is safe because a withdrawal request can only be made against the submitted collateral.
                // As a result, the sum of collateral supply and borrow requests can never be smaller than the withdrawal request
                table_obj.collateral_supply = table_obj.collateral_supply + table_obj.total_borrow_requests - table_obj.total_withdraw_requests;
                table_obj.total_borrow_requests = 0;
                table_obj.total_withdraw_requests = 0;

                let collateral_supply = table_obj.collateral_supply;

                let (price, decimal, _, _) = get_oracle_price_impl(table_obj.pair_id); // price in usdt of the asset
                // Compute the nominal liquidity value(acting as collateral) denominated in SUPRA
                let liquidity_of_asset = asset_util::get_asset_value_in(collateral_supply, price, decimal, supra_price.value, supra_price.decimals);

                total_nominal_liquidity = total_nominal_liquidity + liquidity_of_asset;
        });

        (total_nominal_liquidity, supra_price)
    }

    /// Calculates the total principle amount across all assets based on collateralization rates and submitted collateral balance.
    public fun calculate_principle(
        min_collateralisation: u64,
        max_collateralisation_first: u64,
        max_collateralisation_second: u64,
    ): u64 acquires LiquidityTableItems, TotalLiquidity {

        let (total_nominal_liquidity, supra_price) = calculate_nominal_liquidity();
        // ensure that some liquidity has been submitted to the system that acts as collateral
        assert!(total_nominal_liquidity > 0, error::invalid_state(EZERO_LIQUIDITY)); // break the further calculations

        let total_principle_amount: u128 = 0;

        let tracked_assets = borrow_global<TotalLiquidity>(get_storage_address());

        // looping over all the assets
        smart_table::for_each_ref<Object<Metadata>, AssetInfo>(
            &tracked_assets.assets,
            |key, _value|
        {
                let asset = *key;
                let items =  get_liquidity_table_items(asset);
                let asset_price = get_asset_price(asset);

                // calculate nominal value of the liquidity and collateralization rate for the iassst
                let liquidity_of_asset = asset_util::get_asset_value_in(items.collateral_supply, asset_price.value, asset_price.decimals, supra_price.value, supra_price.decimals);
                let (collateralisation_rate, _, _) = calculate_collateralization_rate(
                    asset,
                    liquidity_of_asset, // cost in supra
                    min_collateralisation,
                    max_collateralisation_first,
                    max_collateralisation_second,
                    total_nominal_liquidity
                );

                // calculate the collateralization rate adjusted liquidity
                let collaterisation_adjusted_in_supra = (liquidity_of_asset / (collateralisation_rate as u128)) * COLLATERALISATION_RATE_MULTIPLIER;

                // calculating total principle
                total_principle_amount = (total_principle_amount as u128) + collaterisation_adjusted_in_supra;
        });

        // returning total rentable
        option::destroy_some(asset_util::safe_u128_to_u64(total_principle_amount))
    }


    /// Calculates the collateralization rate for an asset based on its weight relative to the desired weight.
    public fun calculate_collateralization_rate(
        asset: Object<Metadata>,
        liquidity_of_asset: u128, // in supra
        min_collateralisation: u64,
        max_collateralisation_first: u64,
        max_collateralisation_second: u64,
        total_nominal_liquidity: u128 // in supra
    ): (u64, u32, u64) acquires LiquidityTableItems {
        let liq_items = borrow_global<LiquidityTableItems>(get_asset_address(asset));
        let desired_weight = liq_items.desired_weight;
        let desirability_score = liq_items.desirability_score;

        assert!(total_nominal_liquidity > 0, error::invalid_state(EZERO_LIQUIDITY)); // break the further calculations

        // compute the weight of the asset within the system-wide collateral portfolio
        let asset_weight = ((MAX_WEIGHT as u128) * liquidity_of_asset) / total_nominal_liquidity;

        // calculate collateralisation rate
        let collateralisation_rate = calculate_collateralization_rate_impl(asset_weight, desired_weight, min_collateralisation, max_collateralisation_first, max_collateralisation_second);
        (collateralisation_rate, desired_weight, desirability_score)
    }

    /// Increases total amount of asset that has been submitted to be applied as collateral but not yet accounted
    public(friend) fun update_borrow_request(asset: Object<Metadata>, value_to_add: u64) acquires LiquidityTableItems {
        let liquidity_ref = borrow_global_mut<LiquidityTableItems>(object::object_address(&asset));
        liquidity_ref.total_borrow_requests = liquidity_ref.total_borrow_requests + value_to_add;
    }

    /// Deposit hook function (Dispatchable Fungible Asset concept) to execute the update of the reward index and ensure the FA coin is not paused.
    /// Hook function doesn't check if the primary fungible store is frozen, it is not needed inside the hook method.
    /// The assertation (user is frozen or not) is happening inside fungible_asset::deposit_sanity_check.
    /// The invocation of fungible_asset::deposit_sanity_check is happening before the hook method. Here is a stack of methods:
    /// primary_fungible_store::transfer --> dispatchable_fungible_asset::transfer / deposit --> fungible_asset::deposit_sanity_check -->  assert!(!fa_store.frozen, error::permission_denied(ESTORE_IS_FROZEN));
    public fun deposit<T: key>(
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &TransferRef,
    ) acquires LiquidityProvider, AssetOperations, TotalLiquidity {
        let metadata = fungible_asset::store_metadata(store);
        let balance = fungible_asset::balance(store);

        assert_not_paused(metadata);
        let owner_address = object::owner(store);

        create_iasset_entry(owner_address, metadata);

        update_rewards_internal(owner_address, balance, metadata);

        fungible_asset::deposit_with_ref(transfer_ref, store, fa);
    }

    /// Withdraw function (Dispatchable Fungible Asset concept) to execute the update of the reward index and ensure the FA coin is not paused.
    /// Hook function doesn't check if the primary fungible store is frozen, it is not needed inside the hook method.
    /// The assertation (user is frozen or not) is happening inside fungible_asset::withdraw_sanity_check.
    /// The invocation of fungible_asset::withdraw_sanity_check is happening before the hook method. Here is a stack of methods:
    /// primary_fungible_store::transfer --> dispatchable_fungible_asset::transfer / withdraw --> fungible_asset::withdraw_sanity_check -->  assert!(!fa_store.frozen, error::permission_denied(ESTORE_IS_FROZEN));
    public fun withdraw<T: key>(
        store: Object<T>,
        amount: u64,
        transfer_ref: &TransferRef,
    ): FungibleAsset acquires TotalLiquidity, LiquidityProvider, AssetOperations {
        let metadata = fungible_asset::store_metadata(store);

        let balance = fungible_asset::balance(store);

        assert_not_paused(metadata);

        let owner_address = object::owner(store);

        update_rewards_internal(owner_address, balance, metadata);

        fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
    }

    /// Freeze an account so it cannot transfer or receive an iasset.
    public (friend) fun freeze_account(
        asset: Object<Metadata>,
        account: address
    ) acquires ManagingRefs {

        let transfer_ref = &get_managing_refs(asset).transfer_ref;
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, true);

        event::emit<AccountFrozenEvent>(
            AccountFrozenEvent {
                asset: object::object_address(&asset),
                account: account,
            }
        );
    }

    /// Unfreeze an account so it can transfer or receive an iasset.
    public (friend) fun unfreeze_account(
        asset: Object<Metadata>,
        account: address
    ) acquires ManagingRefs {

        let transfer_ref = &get_managing_refs(asset).transfer_ref;
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, false);
        event::emit<AccountUnfrozenEvent>(
            AccountUnfrozenEvent {
                asset: object::object_address(&asset),
                account: account,
            }
        );
    }

    /// Pause or unpause the transfer of an iasset.
    public (friend) fun set_pause(asset: Object<Metadata>, paused: bool) acquires AssetOperations {
        let state = borrow_global_mut<AssetOperations>(get_asset_address(asset));
        if (state.paused == paused) { return };
        state.paused = paused;

        event::emit<PauseToggledEvent>(
            PauseToggledEvent {
                asset: object::object_address(&asset),
                paused,
            }
        );
    }

    /// Change the redeemable flag to control the redeem process of an iasset.
    public (friend) fun set_redeemable(asset: Object<Metadata>, redeemable: bool) acquires AssetOperations {
        let state = borrow_global_mut<AssetOperations>(get_asset_address(asset));
        if (state.redeemable == redeemable) { return };
        state.redeemable = redeemable;

        event::emit<RedeemToggledEvent>(
            RedeemToggledEvent {
                asset: object::object_address(&asset),
                redeemable,
            }
        );
    }

    #[view]
    ///Calculate the fees in asset
    public fun calculate_asset_fee (asset: Object<Metadata>, supra_service_fees: u64):u64 acquires LiquidityTableItems{
        if (supra_service_fees > 0) {
            let asset_price = get_asset_price(asset); // asset price in usdt
            let supra_price = get_supra_price(); // supra price in usdt
            let amount_as_fee = asset_util::get_asset_value_in_safe_u64(supra_service_fees, supra_price.value, supra_price.decimals, asset_price.value, asset_price.decimals);
            amount_as_fee
        } else {
            0
        }
    }

    #[view]
    /// Returns details about user rewards (allocated, withdrawable, withdrawn)
    public fun get_user_rewards(user_address: address): UserRewardsInfo acquires LiquidityProvider, TotalLiquidity {
        let user_liquidity_address_opt = get_liquidity_provider(user_address);
        if (option::is_none(&user_liquidity_address_opt))
            return UserRewardsInfo {
                allocated_rewards : 0,
                withdrawable_rewards: 0,
                withdrawable_rewards_epoch: 0,
                withdrawable_rewards_ts: 0,
                withdrawn_rewards : 0
            };

        let liq_provider = borrow_global<LiquidityProvider>(option::extract(&mut user_liquidity_address_opt));

        UserRewardsInfo {
            allocated_rewards : liq_provider.allocated_rewards,
            withdrawable_rewards: liq_provider.withdrawable_rewards,
            withdrawable_rewards_epoch: liq_provider.reward_allocation_epoch,
            withdrawable_rewards_ts: liq_provider.reward_allocation_timestamp,
            withdrawn_rewards : liq_provider.total_withdrawn_rewards
        }
    }

    #[view]
    /// Checks if a user's rewards are withdrawable based on the lockup period.
    public fun is_reward_withdrawable(user_address: address): bool acquires LiquidityProvider, TotalLiquidity {
        let user_liquidity_address_opt = get_liquidity_provider(user_address);

        if (option::is_none(&user_liquidity_address_opt)) return false;

        let liq_provider = borrow_global<LiquidityProvider>(option::extract(&mut user_liquidity_address_opt));

        let recent_cycle_update_epoch = get_cycle_data();
        // check whether the lockup cycle changed after rewards were claimed
        if (liq_provider.reward_allocation_epoch < recent_cycle_update_epoch) {
            true
        } else {
            false
        }
    }

    #[view]
    /// Calculates the allocatable rewards for a user and asset based on the current reward index.
    public fun get_allocatable_rewards(user_address: address, asset: Object<Metadata>): u64 acquires LiquidityProvider, TotalLiquidity {
        get_allocatable_rewards_impl(user_address, asset, primary_fungible_store::balance(user_address, asset))
    }

    #[view]
    /// Calculates the allocatable rewards for a store and asset based on the current reward index.
    public fun get_allocatable_rewards_for_store<T: key>(store: Object<T>, asset: Object<Metadata>): u64 acquires LiquidityProvider, TotalLiquidity {
        let owner_address = object::owner(store);
        let balance = fungible_asset::balance(store);
        get_allocatable_rewards_impl(owner_address, asset, balance)
    }

    #[view]
    /// Returns the preminted iAssets, epoch number and timestamp for a user and asset.
    public fun get_preminted_per_asset(user_address: address, asset: Object<Metadata>): AssetPremint acquires LiquidityProvider, TotalLiquidity {
        let user_liquidity_address_opt = get_liquidity_provider(user_address);
        if (option::is_none(&user_liquidity_address_opt))
            return AssetPremint {
                asset: asset,
                preminted_iassets: 0,
                preminting_epoch_number: 0,
                preminting_ts: 0
            };

        let liq_provider = borrow_global<LiquidityProvider>(option::extract(&mut user_liquidity_address_opt));

        // asset entry is not registered yet for the user, then return 0
        if (!smart_table::contains(&liq_provider.asset_entry, asset))
            return AssetPremint {
                asset: asset,
                preminted_iassets: 0,
                preminting_epoch_number: 0,
                preminting_ts: 0
            };

        let asset_entry = smart_table::borrow(&liq_provider.asset_entry, asset);
        AssetPremint {
            asset : asset,
            preminted_iassets : asset_entry.preminted_iassets,
            preminting_epoch_number : asset_entry.preminting_epoch_number,
            preminting_ts : asset_entry.preminting_ts,
        }
    }

    #[view]
    /// Returns a vector of all preminted iAssets for a user across all assets.
    public fun get_all_asset_preminted(user_address: address): vector<AssetPremint> acquires LiquidityProvider, TotalLiquidity {
        let user_liquidity_address_opt = get_liquidity_provider(user_address);
        if (option::is_none(&user_liquidity_address_opt)) return vector::empty();

        let liq_provider = borrow_global<LiquidityProvider>(option::extract(&mut user_liquidity_address_opt));

        let vec: vector<AssetPremint> = vector::empty();

        // iterate over all of the iAssets of the user to check for any pre-minted assets.
        smart_table::for_each_ref<Object<Metadata>, AssetEntry>(
            &liq_provider.asset_entry,
            |key, value|
        {
            let asset_entry: &AssetEntry = value;
            let asset: Object<Metadata> = *key;
            if (asset_entry.preminted_iassets > 0 ||  asset_entry.preminting_epoch_number > 0) {
                vector::push_back(&mut vec, AssetPremint { asset, preminted_iassets: asset_entry.preminted_iassets, preminting_epoch_number: asset_entry.preminting_epoch_number, preminting_ts: asset_entry.preminting_ts});
            }
        });

        vec
    }

    public fun deconstruct_asset_premint(item : &AssetPremint): (Object<Metadata>, u64, u64, u64) {
        (
            item.asset,
            item.preminted_iassets,
            item.preminting_epoch_number,
            item.preminting_ts,
        )
    }

    fun get_epoch_timer_impl(event_epoch: u64, event_ts: u64): u64 acquires TotalLiquidity {
         assert!(
            event_epoch != 0,
            error::invalid_state(ENO_WITHDRAWABLE_REWARDS)
        );

        let remaining_time: u64 = 0;
        let number_of_epoch_in_cycle = config::get_number_of_epoch_in_cycle();

        let recent_cycle_update_epoch = get_cycle_data();
        let length_of_lockup_cycle = config::get_length_of_lockup_cycle();
        let current_ts = timestamp::now_seconds();

        assert!(event_epoch > number_of_epoch_in_cycle, error::invalid_state(EINVALID_EPOCH));

        if (recent_cycle_update_epoch == (event_epoch - number_of_epoch_in_cycle)) {
            let deadline = event_ts + length_of_lockup_cycle + config::get_length_of_epoch();
            if (deadline > current_ts) {
                remaining_time = deadline - current_ts;
            };

        } else if (recent_cycle_update_epoch <= event_epoch) {
            let lockup_start = get_lockup_cycle_ts();
            let deadline = lockup_start + length_of_lockup_cycle;
            if (deadline > current_ts) {
                remaining_time = deadline - current_ts;
            };

        };

        remaining_time
    }


    #[view]
    /// Returns the collateralization rate multiplier constant.
    public fun get_coll_rate_multiplier(): u128 {
        COLLATERALISATION_RATE_MULTIPLIER
    }

    #[view]
    /// Returns the maximum remaining time (in seconds) the user may need to wait before before he can withdraw his rewards
    public fun get_withdraw_timer_for_user(user_address: address): u64 acquires LiquidityProvider, TotalLiquidity {

        let lp_opt = get_liquidity_provider(user_address);
        if (option::is_none(&lp_opt)) return 0;
        let lp_ref = borrow_global<LiquidityProvider>(option::extract(&mut lp_opt));

        get_epoch_timer_impl(lp_ref.reward_allocation_epoch, lp_ref.reward_allocation_timestamp)
    }

    #[view]
    public fun get_redeem_iasset_timer_for_user(user_address: address, asset: Object<Metadata>): u64 acquires LiquidityProvider, TotalLiquidity {
        let lp_opt = get_liquidity_provider(user_address);
        if (option::is_none(&lp_opt)) return 0;
        let lp_ref = borrow_global<LiquidityProvider>(option::extract(&mut lp_opt));
        let asset_entry = smart_table::borrow(&lp_ref.asset_entry, asset);

        get_epoch_timer_impl(asset_entry.unlock_request_epoch, asset_entry.unlock_request_timestamp)
    }


    #[view]
    /// Returns the total allocated rewards for the specified iAsset
    public fun get_allocated_rewards_for_asset(asset: Object<Metadata>): u64 acquires TotalLiquidity {
        let tracker_address = get_storage_address();

        let total_liq_ref = borrow_global<TotalLiquidity>(tracker_address);

        let asset_info = smart_table::borrow(
            &total_liq_ref.assets,
            asset
        );

        asset_info.allocated_rewards_for_asset
    }

    #[view]
    // Returns the total nominal liquidity used as collateral in the system, denominated in SUPRA
    public fun get_total_nominal_liquidity(): u128 acquires TotalLiquidity, LiquidityTableItems {
        let total_nominal_liquidity: u128 = 0;
        let total_liquidity_ref = borrow_global<TotalLiquidity>(get_storage_address());

        let supra_price = get_supra_price();

        // iterate through all assets to calculate nominal liquidity, denominated in SUPRA
        smart_table::for_each_ref<Object<Metadata>, AssetInfo>(
            &total_liquidity_ref.assets,
            |key, _value| {
                let asset = *key;
                let table_obj = borrow_global<LiquidityTableItems>(get_asset_address(asset));

                let (price, decimal, _, _) = get_oracle_price_impl(table_obj.pair_id);
                let liquidity_of_asset = asset_util::get_asset_value_in(table_obj.collateral_supply, price, decimal, supra_price.value, supra_price.decimals);

                total_nominal_liquidity = total_nominal_liquidity + liquidity_of_asset;
        });

        total_nominal_liquidity
    }

    #[view]
    /// Calculate total nominal collateral supply for an asset
    public fun get_nominal_liquidity_by_asset(asset: Object<Metadata>): u128 acquires TotalLiquidity, LiquidityTableItems {
        let total_liquidity_ref = borrow_global<TotalLiquidity>(get_storage_address());

        assert!(smart_table::contains(&total_liquidity_ref.assets, asset),error::not_found(EASSET_NOT_PRESENT));

        let supra_price = get_supra_price();

        let table_obj = borrow_global<LiquidityTableItems>(get_asset_address(asset));

        let (price, decimal, _, _) = get_oracle_price_impl(table_obj.pair_id);
        let liquidity_of_asset = asset_util::get_asset_value_in(table_obj.collateral_supply, price, decimal, supra_price.value, supra_price.decimals);

        liquidity_of_asset
    }

    #[view]
    /// Get current collaterisation rate for all assets supported by the system
    public fun get_coll_rates(): vector<AssetValuePair> acquires TotalLiquidity, LiquidityTableItems{
        let tracked_assets = get_assets();
        let results = vector::empty<AssetValuePair>();

        let (min_collateralisation,
            _, _, _, max_collateralisation_first, max_collateralisation_second,
            _, _, _, _, _, _) = config::get_mut_params();
        let total_nominal_liquidity = get_total_nominal_liquidity();

        vector::for_each_ref<Object<Metadata>>(
            &tracked_assets,
            |key|
        {
            let asset = *key;
            let liquidity_of_asset = get_nominal_liquidity_by_asset(asset);

            let (asset_specific_collateralisation_rate, _, _) = calculate_collateralization_rate(
                asset,
                liquidity_of_asset,
                min_collateralisation,
                max_collateralisation_first,
                max_collateralisation_second,
                total_nominal_liquidity
            );
            let pair = AssetValuePair {
                    asset: get_asset_address(asset),
                    value: asset_specific_collateralisation_rate,
            };

            vector::push_back(&mut results, pair);
        });

        results
    }

    #[view]
    /// First returned value is an asset APY, the second one is Multiplier used to scale
    public fun get_asset_apy(asset: Object<Metadata>): (u64, u64) acquires TotalLiquidity {
        let tracked_assets = borrow_global<TotalLiquidity>(get_storage_address());
        if (!smart_table::contains(&tracked_assets.assets, asset)) return (0, 0);
        let asset_info = smart_table::borrow(&tracked_assets.assets, asset);
        return (asset_info.apy, REWARDS_MULTIPLIER)
    }

    #[view]
    /// Return details for all system-supported assets originating from the specified chain
    public fun get_asset_details_by_chain(chain_id: u64): vector<AssetInfo> acquires TotalLiquidity {
        let total_liquidity_ref = borrow_global<TotalLiquidity>(get_storage_address());

        let info: vector<AssetInfo> = vector::empty();

        smart_table::for_each_ref<Object<Metadata>, AssetInfo>(&total_liquidity_ref.assets, |_key, value| {
            let asset_info: AssetInfo = *value;
            if (asset_info.origin_token.chain_id == chain_id) {
                vector::push_back(&mut info, asset_info);
            }
        });

        info
    }

    #[view]
    /// Returns the desired weights of all assets in the collateral portfolio
    public fun get_all_desired_weights(): vector<AssetValuePair> acquires TotalLiquidity, LiquidityTableItems {
        let tracker = borrow_global<TotalLiquidity>(get_storage_address());
        let results = vector::empty<AssetValuePair>();

        smart_table::for_each_ref<Object<Metadata>, AssetInfo>(
            &tracker.assets,
            |key, _info| {
                let asset = *key;
                let asset_address = get_asset_address(asset);
                let table = borrow_global<LiquidityTableItems>(asset_address);
                let pair = AssetValuePair {
                    asset: asset_address,
                    value: (table.desired_weight as u64),
                };
                vector::push_back(&mut results, pair);
            }
        );

        results
    }

    #[view]
    public fun get_asset_info(asset: Object<Metadata>): AssetInfo acquires TotalLiquidity {
        let tracked_assets = borrow_global<TotalLiquidity>(get_storage_address());
        assert!(smart_table::contains(&tracked_assets.assets, asset),error::not_found(EASSET_NOT_PRESENT));
        *smart_table::borrow(&tracked_assets.assets, asset)
    }

    /// Assert that the iasset is not paused
    fun assert_not_paused(asset: Object<Metadata>) acquires AssetOperations {
        let state = borrow_global<AssetOperations>(get_asset_address(asset));
        assert!(!state.paused, error::invalid_state(EPAUSED));
    }

    /// Assert that the iasset is not redeemable
    fun assert_redeemable(asset: Object<Metadata>) acquires AssetOperations {
        let state = borrow_global<AssetOperations>(get_asset_address(asset));
        assert!(state.redeemable, error::invalid_state(ENOT_REDEEMABLE));
    }

    /// Updates the allocated rewards and reward index of the user
    fun update_rewards_internal(user_address: address, iasset_balance: u64, asset: Object<Metadata>) acquires TotalLiquidity, LiquidityProvider {
        let obj_address = get_storage_address();
        let user_liquidity_address = ensure_liquidity_provider(user_address);

        let total_liquidity_ref = borrow_global<TotalLiquidity>(obj_address);
        let liquidity_provider_ref = borrow_global_mut<LiquidityProvider>(user_liquidity_address);

        let asset_entry = smart_table::borrow_mut(
            &mut liquidity_provider_ref.asset_entry,
            asset
        );

        let distributable_rewards_table_item = smart_table::borrow(&total_liquidity_ref.assets, asset);
        let reward_index_asset = distributable_rewards_table_item.reward_index_asset;

        if (asset_entry.user_reward_index > 0) {
            if (asset_entry.user_reward_index == reward_index_asset) return;
            // calculates accrued rewards of the user
            let distributable_rewards = calculate_rewards_internal(asset_entry.user_reward_index, iasset_balance, asset);

            // increases allocated rewards of the user
            liquidity_provider_ref.allocated_rewards = liquidity_provider_ref.allocated_rewards + distributable_rewards;
            event::emit<UpdateRewardsEvent>(
                UpdateRewardsEvent {
                    account: user_address,
                    asset,
                    amount: distributable_rewards
                }
            );
        };

        /// update the user's reward index to match the global reward index of iasset.
        asset_entry.user_reward_index = reward_index_asset;
    }

    /// Calculates rewards accrued for the user based on their reward index and iAsset balance
    fun calculate_rewards_internal(
        user_reward_index: u64,
        iasset_balance : u64,
        asset: Object<Metadata>
    ): u64 acquires TotalLiquidity {
        if (iasset_balance == 0) return 0;

        let total_liquidity_ref = borrow_global<TotalLiquidity>(get_storage_address());
        let reward_index_asset = smart_table::borrow(
            &total_liquidity_ref.assets,
            asset
        ).reward_index_asset;

        if (user_reward_index > reward_index_asset) return 0;

        /// Compute Rewards using the formula:  Rewards= iAssetBalance * (reward_index_asset - rewardIndexOf[_account])
        option::destroy_some(asset_util::safe_u128_to_u64(
            ( (iasset_balance as u128) * ( (reward_index_asset - user_reward_index) as u128) ) / (REWARDS_MULTIPLIER as u128)
        ))
    }

    fun get_allocatable_rewards_impl(user_address: address, asset: Object<Metadata>, user_balance : u64): u64 acquires LiquidityProvider, TotalLiquidity {
        let user_liquidity_address_opt = get_liquidity_provider(user_address);
        if (option::is_none(&user_liquidity_address_opt)) return 0;

        let liquidity_provider_ref = borrow_global<LiquidityProvider>(option::extract(&mut user_liquidity_address_opt));

        // asset entry is not registered yet for the user, then return 0
        if (!smart_table::contains(&liquidity_provider_ref.asset_entry, asset)) return 0;

        let asset_entry = smart_table::borrow(
            &liquidity_provider_ref.asset_entry,
            asset
        );
        //  user_reward_index should be  greater than 0 . see update_rewards method
        if (asset_entry.user_reward_index > 0) {
            calculate_rewards_internal(asset_entry.user_reward_index, user_balance, asset)
        } else {
            0
        }
    }

    /// Convert SUPRA-denominated redemption and deposit fees into underlying-asset and iAsset amounts
    fun get_asset_fees(asset: Object<Metadata>, supra_fees: u64): (u64, u64) acquires LiquidityTableItems {
        if (supra_fees > 0){
            let fee_asset = calculate_asset_fee(asset, supra_fees);
            let fee_iasset = preview_mint(fee_asset, asset);
            (fee_iasset, fee_asset)
        }else {
            (0, 0)
        }
    }

    /// Calculate APY recieved by the holders of an iasset
    fun calculate_asset_apy(asset: Object<Metadata>, delta_reward_index: u64, number_epoch_in_apy : u64): (u64, u64) acquires LiquidityTableItems {
        let iasset_supply = get_iasset_supply(asset);

        // if the iAsset supply is 0, there are no holders that accrue rewards
        if (iasset_supply == 0) return (0, 0);

        let liq_table_obj = borrow_global<LiquidityTableItems>(get_asset_address(asset));

        let supra_price = get_supra_price(); // supra price in usdt
        let (price, decimal, _, _) = get_oracle_price_impl(liq_table_obj.pair_id); // price in usdt of the asset
        // compute the SUPRA value of one iAsset unit, multiplied by the rewards multiplier.
        let iasset_price_supra = asset_util::get_asset_value_in(
            preview_redeem(REWARDS_MULTIPLIER, asset), price, decimal, supra_price.value, supra_price.decimals);

        if (iasset_price_supra == 0) return (0, 0);

        // calculate number of epochs in a year
        let number_of_epoch_year = ONE_YEAR_SEC / config::get_length_of_epoch();

        // Calculate the APY based on how much SUPRA a single iAsset unit earns over the APY window (number_epoch_in_apy)
        // APY = (per-unit SUPRA earned over window) * (epochs_per_year) / (iAsset price in SUPRA(for a unit) * window length)
        let apy = math128::mul_div( (REWARDS_MULTIPLIER as u128) * (delta_reward_index as u128),
            (number_of_epoch_year as u128),
            (iasset_price_supra * (number_epoch_in_apy as u128))
        );
        ((apy as u64), REWARDS_MULTIPLIER)
    }

    /// Calculate the collateralization rate based on current weight and desired weight of asset in the collateral portfolio
    fun calculate_collateralization_rate_impl(
        asset_weight: u128,
        desired_weight : u32,
        min_collateralisation: u64,
        max_collateralisation_first: u64,
        max_collateralisation_second: u64
    ):u64 {
        // calculation uses a piecewise function with three intervals
        let collateralisation_rate: u128 = if (asset_weight == 0 || (asset_weight == (MAX_WEIGHT as u128) && desired_weight == (MAX_WEIGHT as u32))) {
            (min_collateralisation as u128)
        } else if(asset_weight <= (desired_weight as u128 )) {
            let numerator = (desired_weight as u128) - asset_weight;
            let denominator = (desired_weight as u128);
            let ratio = (numerator * MULTIPLIER) / denominator;

            (min_collateralisation as u128) + (((max_collateralisation_first - min_collateralisation) as u128) * ratio) / MULTIPLIER
        } else {
            let numerator = asset_weight - (desired_weight as u128);
            let denominator = (MAX_WEIGHT as u128) - (desired_weight as u128);
            let ratio = (numerator * MULTIPLIER) / denominator;

            (min_collateralisation as u128) + (((max_collateralisation_second - min_collateralisation) as u128) * ratio) / MULTIPLIER
        };
        option::destroy_some(asset_util::safe_u128_to_u64(collateralisation_rate))
    }

    inline fun get_iasset_extended_supply(asset: Object<Metadata>, asset_liquidity_ref : &LiquidityTableItems) : u64 {
        get_iasset_supply(asset) + asset_liquidity_ref.total_preminted_assets + asset_liquidity_ref.total_redeem_requested_iassets
    }

    inline fun build_token_info (origin_token_address: vector<u8>, origin_token_chain_id: u64) : OriginTokenInfo {
        OriginTokenInfo {
            chain_id: origin_token_chain_id,
            token_address: origin_token_address
        }
    }

    /// Borrow the immutable reference of the refs of `metadata`.
    inline fun get_managing_refs(
        asset: Object<Metadata>,
    ): &ManagingRefs acquires ManagingRefs {
        borrow_global<ManagingRefs>(object::object_address(&asset))
    }

    #[test_only]
    const TOKEN_A_SYMBOL: vector<u8> = b"TSTA";
    #[test_only]
    const TOKEN_B_SYMBOL: vector<u8> = b"TSTB";

    #[test_only]
    friend dfmm_framework::iAsset_test;
    #[test_only]
    friend dfmm_framework::redeem_router_test;
    #[test_only]
    friend dfmm_framework::poel_test;
    #[test_only]
    friend dfmm_framework::poel_rewards_test;

    #[test_only]
    public fun init_iAsset_for_test(deployer: &signer) {
        init_module(deployer);
    }

    #[test_only]
    public fun create_iasset_entry_for_test(account: address, asset: Object<Metadata>) acquires TotalLiquidity, LiquidityProvider {
        create_iasset_entry(account, asset)
    }

    #[test_only]
    public fun ensure_liquidity_provider_for_test(account: address): address acquires TotalLiquidity {
        ensure_liquidity_provider(account)
    }

    #[test_only]
    public fun get_total_liquidity_provider_table_value_for_test(user_address: address): address acquires TotalLiquidity {
        let total_liquidity = borrow_global<TotalLiquidity>(get_storage_address());
        *table_with_length::borrow(&total_liquidity.liquidity_provider_objects, user_address)
    }

    #[test_only]
    public fun increase_collateral_supply(
         asset: Object<Metadata>,
         amount_to_increase: u64
     ): u64 acquires LiquidityTableItems {
         let table_obj = borrow_global_mut<LiquidityTableItems>(object::object_address(&asset));
         table_obj.collateral_supply = table_obj.collateral_supply + amount_to_increase;
         table_obj.collateral_supply
    }

    #[test_only]
    public fun set_collateral_supply(
         asset: Object<Metadata>,
         amount_to_increase: u64
     ) acquires LiquidityTableItems {
         let table_obj = borrow_global_mut<LiquidityTableItems>(object::object_address(&asset));
         table_obj.collateral_supply = amount_to_increase;
    }

    #[test_only]
    public fun apply_premint(account: address, asset: Object<Metadata>,
        preminted_iassets: u64, preminting_epoch_number : u64, preminting_ts : u64) acquires TotalLiquidity, LiquidityProvider {

        create_iasset_entry(account, asset);
        let user_liquidity_obj_address = option::extract(&mut get_liquidity_provider(account));
        let asset_entry = smart_table::borrow_mut(
            &mut borrow_global_mut<LiquidityProvider>(user_liquidity_obj_address).asset_entry,
            asset
        );
        asset_entry.preminted_iassets = preminted_iassets;
        asset_entry.preminting_epoch_number = preminting_epoch_number;
        asset_entry.preminting_ts = preminting_ts;
    }

    #[test_only]
    public fun get_liquidity_provider_asset_entry_items_for_test(
        liquidity_provider: address,
        asset: Object<Metadata>
    ): (u64, u64, u64, u64, u64) acquires LiquidityProvider {
        let total_liquidity = borrow_global<LiquidityProvider>(liquidity_provider);
        let asset_entry = smart_table::borrow(&total_liquidity.asset_entry, asset);
        (
            asset_entry.user_reward_index,
            asset_entry.preminted_iassets,
            asset_entry.redeem_requested_iassets,
            asset_entry.preminting_epoch_number,
            asset_entry.unlock_request_timestamp,
        )
    }

    #[test_only]
    /// Retrieves the collateral supply, desired weight, and desirability score for an asset.
    public fun get_asset_collateral_supply_weight_score(asset: Object<Metadata>): (u64, u32, u64) acquires LiquidityTableItems {
        let items = borrow_global<LiquidityTableItems>(get_asset_address(asset));

        (
            items.collateral_supply,
            items.desired_weight,
            items.desirability_score,
        )
    }

    #[test_only]
    public fun update_recent_cycle_update_epoch(recent_cycle_update_epoch:u64) acquires TotalLiquidity {
        let ref = borrow_global_mut<TotalLiquidity>(get_storage_address());

        ref.recent_cycle_update_epoch = recent_cycle_update_epoch;
    }

    #[test_only]
    public fun get_total_withdrawn_reward(user_address: address): u64 acquires LiquidityProvider, TotalLiquidity {
        let user_liquidity_address_opt = get_liquidity_provider(user_address);
        if (option::is_none(&user_liquidity_address_opt)) return 0;
        let liq_provider = borrow_global<LiquidityProvider>(option::extract(&mut user_liquidity_address_opt));
        liq_provider.total_withdrawn_rewards
    }

    #[test_only]
    public fun get_allocated_rewards(user_address: address): u64 acquires LiquidityProvider, TotalLiquidity {
        let user_liquidity_address_opt = get_liquidity_provider(user_address);
        if (option::is_none(&user_liquidity_address_opt)) return 0;
        let liq_provider = borrow_global<LiquidityProvider>(option::extract(&mut user_liquidity_address_opt));
        liq_provider.allocated_rewards
    }

    #[test_only]
    public fun get_withdrawable_rewards(user_address: address): (u64, u64, u64) acquires LiquidityProvider, TotalLiquidity {
        let user_liquidity_address_opt = get_liquidity_provider(user_address);
        if (option::is_none(&user_liquidity_address_opt)) return (0, 0, 0);
        let liq_provider = borrow_global<LiquidityProvider>(option::extract(&mut user_liquidity_address_opt));
        (liq_provider.withdrawable_rewards, liq_provider.reward_allocation_epoch, liq_provider.reward_allocation_timestamp)
    }

    #[test_only]
    public fun set_allocated_rewards(user_address: address, amount:u64) acquires TotalLiquidity, LiquidityProvider {
        let liquidity_provider_object_address = ensure_liquidity_provider(user_address);
        let liquidity_provider_ref = borrow_global_mut<LiquidityProvider>(liquidity_provider_object_address);
        liquidity_provider_ref.allocated_rewards = amount;
    }

    #[test_only]
    public fun set_withdrawn_rewards(user_address: address, amount:u64) acquires TotalLiquidity, LiquidityProvider {
        let liquidity_provider_object_address = ensure_liquidity_provider(user_address);
        let liquidity_provider_ref = borrow_global_mut<LiquidityProvider>(liquidity_provider_object_address);
        liquidity_provider_ref.total_withdrawn_rewards = amount;
    }

    #[test_only]
    public fun set_withdrawable_rewards(user_address: address, amount:u64, epoch: u64, ts:u64) acquires TotalLiquidity, LiquidityProvider {
        let liquidity_provider_object_address = ensure_liquidity_provider(user_address);
        let liquidity_provider_ref = borrow_global_mut<LiquidityProvider>(liquidity_provider_object_address);
        liquidity_provider_ref.withdrawable_rewards = amount;
        liquidity_provider_ref.reward_allocation_epoch = epoch;
        liquidity_provider_ref.reward_allocation_timestamp = ts;
    }

    #[test_only]
    public fun get_asset_rewards_index(asset: Object<Metadata>): (u64) acquires TotalLiquidity {
        let total_liquidity_ref = borrow_global_mut<TotalLiquidity>(get_storage_address());
        let asset_info = smart_table::borrow(& total_liquidity_ref.assets, asset);
        asset_info.reward_index_asset
    }

    #[test_only]
    public fun get_asset_apy_and_epoch_update(asset: Object<Metadata>): (u64,u64) acquires TotalLiquidity {
        let tracked_assets = borrow_global<TotalLiquidity>(get_storage_address());
        assert!(smart_table::contains(&tracked_assets.assets, asset),error::not_found(EASSET_NOT_PRESENT));
        let asset_info = smart_table::borrow(&tracked_assets.assets, asset);
        (asset_info.apy, asset_info.apy_update_epoch)
    }

    #[test_only]
    public fun create_test_assets(account: &signer): (Object<Metadata>, Object<Metadata>) acquires TotalLiquidity, IAssetFunctionStore  {
        let token_a =
            create_new_iasset(
                account,
                b"Test Token A",
                TOKEN_A_SYMBOL,
                8, // decimals
                1,
                b"https://qa-supra-nova-ui.supra.com/images/currency-icons/token_a.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory/token_a",
                x"e2794e1ef7d4ac86506a5947a1f0f342c139f10c",
                1,
                8,
                x"e2794e1139f10c"
            );

        let token_b =
            create_new_iasset(
                account,
                b"Test Token B",
                TOKEN_B_SYMBOL,
                8, // decimals
                2,
                b"https://qa-supra-nova-ui.supra.com/images/currency-icons/token_b.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory/token_b",
                x"e2794e1ef7d4ac86506a5947a1f0f342c139f20c",
                2,
                8,
                x"e2794e1139f20c"
            );
        assert!(fungible_asset::icon_uri(token_a) == string::utf8(b"https://qa-supra-nova-ui.supra.com/images/currency-icons/token_a.svg"), 1);
        assert!(fungible_asset::icon_uri(token_b) == string::utf8(b"https://qa-supra-nova-ui.supra.com/images/currency-icons/token_b.svg"), 1);

        assert!(fungible_asset::project_uri(token_a) == string::utf8(b"https://qa-supra-nova-ui.supra.com/iasset-factory/token_a"), 1);
        assert!(fungible_asset::project_uri(token_b) == string::utf8(b"https://qa-supra-nova-ui.supra.com/iasset-factory/token_b"), 1);

        (
            token_a,
            token_b
        )
    }

}


