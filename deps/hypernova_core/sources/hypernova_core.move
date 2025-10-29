/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
module hypernova_core::hypernova_core {
    use std::signer;
    use std::vector;
    use std::option::{Self, some, none, Option};
    use supra_framework::timestamp;
    use supra_framework::event::emit;
    use aptos_std::bls12381::{
        Self,
        public_key_from_bytes,
        public_key_from_bytes_with_pop_externally_verified,
        PublicKeyWithPoP,
        signature_to_bytes,
        public_key_to_bytes,
        public_key_with_pop_to_bytes
    };
    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::coin;
    use supra_framework::supra_coin::SupraCoin;
    use hypernova_core::eth_types::{
        BeaconBlockHeader,
        construct_beacon_block_header,
        get_slot,
        get_state_root,
        hash_tree_root_beacon_block_header,
        SyncCommittee,
        construct_sync_committee,
        get_sync_committee_public_keys,
        hash_tree_root_public_key,
        get_aggregate_public_key,
        SyncAggregate,
        get_sync_committee_bits,
        get_sync_committee_signature,
        construct_signing_data,
        hash_tree_root_signing_data,
        compute_fork_data_root,
        Fork,
        construct_fork,
        get_epoch,
        get_version,
        get_fork_version,
        is_valid_merkle_branch,
        calculate_root,
        LightClientUpdate,
        get_attested_header_update,
        get_sync_aggregate_update,
        get_signature_slot_update,
        construct_sync_aggregate,
        construct_lightclient_update,
        get_finality_branch_update,
        get_finalized_header_update
    };
    use hypernova_core::helpers::{
        hash_pair,
        is_valid_margin,
        compute_committee_updater_reward,
        compute_verification_fee
    };

    // Friend List
    friend hypernova_core::proof_verifier;

    /// ================================ Errors ================================

    /// Invalid source HN address. The source HN address is invalid or unrecognized.
    const EINVALID_SOURCE_HN_ADDRESS: u64 = 5000;

    /// Invalid slot order. The attested slot must be greater than the finalized slot.
    const EINVALID_SLOT_ORDER: u64 = 5001;

    /// Initializer not found. The initializer was not found or is missing.
    const EINITIALIZER_RESOURCE_NOT_FOUND: u64 = 5002;

    /// Not a relevant update slot. The attested slot must be newer than the last update slot,
    /// unless the next committee is needed.
    const ENOT_RELEVANT_UPDATE_SLOT: u64 = 5003;

    /// Invalid update period. The update period must match the current period,
    /// or the next period if a next committee is present.
    const EINVALID_UPDATE_PERIOD: u64 = 5004;

    /// Insufficient participation. The number of sync committee participants did not meet the required threshold.
    const EINSUFFICIENT_PARTICIPATION: u64 = 5005;

    /// Invalid aggregate public key. The provided aggregate public key is invalid or malformed.
    const EINVALID_AGGREGATE_PUBLIC_KEY: u64 = 5006;

    /// Invalid finality proof. The provided proof does not correctly link the attested header to the finalized header.
    const EINVALID_FINALITY_PROOF: u64 = 5007;

    /// Invalid sync committee signature. The aggregated signature from the sync committee failed verification.
    const EINVALID_SIGNATURE: u64 = 5008;

    /// Already initialized. The operation cannot be performed as the system is already initialized.
    const EALREADY_INITIALIZED: u64 = 5009;

    /// Missing initializer scratch space. The required InitializerScratchSpace resource was not found at the given address.
    const EMISSING_INITIALIZER_SCRATCH_SPACE: u64 = 5010;

    /// Missing next aggregate public key. The next sync committee's aggregate public key is missing or invalid.
    const ENEXT_AGGREGATE_PUBLIC_KEY_MISSING: u64 = 5011;

    /// Invalid step count. The step count provided is invalid or out of range.
    const EINVALID_STEP_COUNT: u64 = 5012;

    /// Missing light client update scratch space. The required LightClientUpdateScratchSpace resource was not found at the given account address.
    const ELIGHT_CLIENT_UPDATE_SCRATCH_SPACE_NOT_FOUND: u64 = 5013;

    /// Invalid safety level. The provided safety level must be greater than or equal to the minimum required safety level.
    const EINVALID_SAFETY_LEVEL: u64 = 5014;

    /// Epochs and versions length mismatch. The number of epochs does not match the length of the provided versions vector.
    const EPOCHS_VERSIONS_LENGTH_MISMATCH: u64 = 5015;

    /// Empty fork list. The fork list provided is empty or not properly populated.
    const EEMPTY_FORK_LIST: u64 = 5016;

    /// Unauthorized core admin. The core admin is unauthorized to perform the operation.
    const EUNAUTHORIZED_CORE_ADMIN: u64 = 5017;

    /// Invalid finalized header option. The finalized header option was None, indicating a missing or invalid value.
    const EINVALID_FINALIZED_HEADER_OPTION: u64 = 5018;

    /// Invalid finality branch option. The finality branch option was None, indicating a missing or invalid value.
    const EINVALID_FINALITY_BRANCH_OPTION: u64 = 5019;

    /// Invalid POP public key. The POP public key provided is invalid or malformed.
    const EINVALID_POP_PUBLIC_KEY: u64 = 5020;

    /// Invalid genesis timestamp. The genesis timestamp must be earlier than the current time.
    const EINVALID_GENESIS_TIMESTAMP: u64 = 5021;

    /// Hypernova protocol paused. The operation cannot proceed because the Hypernova protocol is currently paused.
    /// This may be due to maintenance, upgrades, or other administrative reasons.
    const EHYPERNOVA_PAUSED: u64 = 5022;

    /// Invalid sync committee threshold. The sync committee threshold value is invalid or out of range.
    const EINVALID_SYNC_COMMITTEE_THRESHOLD: u64 = 5023;

    /// Invalid epoch number. The new epoch must be greater than the latest epoch in the current fork list.
    /// This ensures that forks are added in sequential order without any gaps or duplicates.
    const EOUT_OF_ORDER_EPOCH: u64 = 5024;

    /// Invalid source event signature hash length. The length of the source event signature hash is invalid.
    const EINVALID_SOURCE_EVENT_SIGNATURE_HASH_LEN: u64 = 5025;

    /// Invalid signature slot order. This error occurs when the signature slot is not in the expected order
    /// relative to the current slot and the attested slot.
    const EINVALID_SIGNATURE_SLOT_ORDER: u64 = 5026;

    /// Insufficient wallet balance for verification. This error is triggered when the user does not have
    /// enough funds in their wallet to cover the verification fee required to complete the operation.
    const EINSUFFICIENT_WALLET_BALANCE_FOR_VERIFICATION: u64 = 5027;

    /// Insufficient balance in the Hypernova core contract for verification operations.
    const EHYPERNOVA_CORE_BALANCE_INSUFFICIENT: u64 = 5028;

    /// No fee collected. No verification fee was collected during the operation.
    const ENO_FEE_COLLECTED: u64 = 5029;

    /// Insufficient funds for withdrawal. The withdrawal amount exceeds the available balance.
    const EINSUFFICIENT_FUNDS_FOR_WITHDRAWAL: u64 = 5030;

    /// Invalid input value. A provided input value is out of the acceptable range or malformed.
    const EINVALID_INPUT_VALUE: u64 = 5031;

    /// Daily traffic cap exceeded. The per-day traffic count has exceeded the allowed maximum.
    const ETRAFFIC_PER_DAY_CANNOT_BE_MORE: u64 = 5032;

    /// Invalid margin value. The provided margin is outside acceptable bounds.
    const EINVALID_MARGIN: u64 = 5033;

    /// Error code indicating that the `hn_fee_config` is not set in `LightClientState`.
    const ECOMMITTEE_UPDATER_REWARD_NOT_SET: u64 = 5034;

    /// Error thrown when the light client update fails verification.
    const EUPDATE_VERIFICATION_FAILED: u64 = 5035;

    /// Error code indicating that the Hypernova configuration is not set.
    const EHYPERNOVA_CONFIG_NOT_SET: u64 = 5036;

    /// ================================ Constants ================================

    /// The number of participants in a sync committee.
    const SYNC_COMMITTEE_SIZE: u64 = 512;

    /// The number of slots in a single epoch.
    const SLOTS_PER_EPOCH: u64 = 32;

    /// The length (should be 32 in length).
    const BYTES_32_LEN: u64 = 32;

    /// The number of epochs in a sync committee period.
    const SYNC_PERIOD: u64 = 256;

    /// 1 slot duration in the Ethereum Beacon Chain, equal to 12 seconds.
    const SLOT_DURATION_SECONDS: u64 = 12;

    /// Domain type used for computing the sync committee signing root.
    /// This value (0x07000000) identifies the domain for sync committee signatures
    /// as defined in the Ethereum consensus specifications.
    const DOMAIN_TYPE: vector<u8> = x"07000000";

    /// Merkle tree depth of the current sync committee in Beacon state proof.
    const CURRENT_COMMITTEE_DEPTH: u64 = 6;

    /// Merkle tree index of the current sync committee in Beacon state proof.
    const CURRENT_COMMITTEE_INDEX: u64 = 22;

    /// Merkle tree index of the finality branch in Beacon state proof.
    const FINALITY_INDEX: u64 = 41;

    /// Merkle tree depth for finality proofs in Beacon state proof.
    const FINALITY_DEPTH: u64 = 7;

    /// Merkle tree index of the next sync committee in Beacon state proof.
    const NEXT_COMMITTEE_INDEX: u64 = 23; // Same index as current committee by spec

    /// Merkle tree depth of the next sync committee in Beacon state proof.
    const NEXT_COMMITTEE_DEPTH: u64 = 6;

    /// A unique seed identifier used across the Hypernova protocol for deterministic key generation.
    const HYPERNOVA_SEED: vector<u8> = b"ETH_SUPRA_HYPERNOVA_SEED";

    /// A constant representing the zero value for u8 type. 
    const ZERO_VALUE: u8 = 0;

    /// Root hash of the genesis block of the source chain
    const GENESIS_BLOCK_ROOT: vector<u8> = x"4b363db94e286120d76eb905340fdd4e54bfe9f06bf33ff6cf5ad27f511bfe95";

    /// Timestamp in seconds when the source chain genesis block was created
    const GENESIS_TIMESTAMP_SECONDS: u64 = 1606824023;

    /// The number of bytes from the fork data root to include in the domain identifier.
    /// According to Ethereum consensus specs, the domain is computed by:
    /// DOMAIN_TYPE (4 bytes) || first 28 bytes of fork_data_root = 32 bytes total.
    const DOMAIN_FORK_DATA_SIZE: u64 = 28;

    /// ================================ Structs and Resources ================================

    /// Configuration struct for the Hypernova verifier that contains all necessary parameters
    /// for verifying cross-chain messages and maintaining the light client state.
    struct VerifierConfig has store {
        /// Minimum number of signatures required from the sync committee for validation
        sync_committee_threshold: u64,
        /// Chain ID of the source blockchain
        source_chain_id: u64,
        /// Address of the administrator authorized to invoke administrative functions.
        admin_address: address,
        /// Address of the Hypernova contract on the source chain
        source_hypernova_contract_address: vector<u8>,
        /// List of supported protocol fork versions for compatibility
        protocol_fork_versions: vector<Fork>,
        /// Event signature hash of the source chain emited
        source_event_signature_hash: vector<u8>
    }

    /// Configuration for fee management and economic parameters in the Hypernova protocol.
    /// This struct includes parameters for committee update rewards, gas usage tracking, and verification fee calculations.
    struct HNFeeConfig has store {
        /// The percentage margin (in basis points or scaled value) awarded to the committee updater.
        /// This value is used in calculating reward distribution logic.
        committee_updater_margin: u64,

        /// The percentage margin (in basis points or scaled value) allocated to the verifier.
        /// Helps define the economic incentive for running verification routines.
        verifier_margin: u64,

        /// Daily transaction or data traffic handled by Hypernova.
        /// Represented as a count per day; u64 is sufficient for typical loads.
        traffic_per_day: u64,

        /// The total reward allocated to the committee updater, denominated in Quants.
        committee_updater_reward: u64,

        /// The verification fee charged for processing a cross-chain message.
        verification_fee: u64,
        /// Total gas cost for committee updates, represented in Quants.
        /// Calculated as: gas_used * gas_unit_price. Although u128 is sufficient in most cases,
        /// percentage-based operations could overflow, so u256 is used.
        committee_updater_gas_cost: u256,
    }


    /// Stores the state of a light client, tracking sync committees and updates.
    /// This struct maintains the current state of the light client including
    /// the latest update slot and both current and next sync committees.
    struct LightClientStore has store {
        /// The slot number of the most recent update to the light client state
        last_update_slot: u64,
        /// The current active sync committee responsible for signing blocks
        current_sync_committee: SyncCommittee,
        /// Optional next sync committee that will become active after the next sync period
        next_sync_committee: Option<SyncCommittee>
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Represents the complete state of the light client, including both the current state
    /// of the light client store and the configuration parameters for verification.
    struct LightClientState has key {
        /// is_paused: operation status (true = paused, false = active)
        is_paused: bool,
        /// The current state of the light client, containing information about
        /// the latest finalized header and sync committee
        light_client_store: LightClientStore,
        /// Configuration parameters for the verifier, including safety levels,
        /// thresholds, and chain-specific information
        verifier_config: VerifierConfig,
        /// Fee configuration for Hypernova, including margins, traffic,
        hn_fee_config: Option<HNFeeConfig>
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// A resource that holds the SignerCapability used to derive the Hypernova core signer.
    ///
    /// This capability is required for executing privileged operations such as:
    /// - Transferring collected fees
    /// - Disbursing rewards to committee updaters
    struct SignerCap has key {
        /// Capability used to create a signer that acts as the Hypernova core.
        signer_cap: SignerCapability
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Temporary storage used during the initial initialization of the module state.
    /// This struct holds intermediate values and proofs required for computing
    /// and verifying the initial state of the light client.
    struct InitializerScratchSpace has key {
        /// Number of steps taken during the initialization process
        current_step: u64,
        /// List of hashes of individual public keys from the sync committee
        committee_member_key_hashes: vector<vector<u8>>,
        /// Hash of the aggregated public key from the sync committee
        committee_aggregate_key_hash: vector<u8>,
        /// Merkle proof branch for verifying the current sync committee
        current_sync_committee_branch: vector<vector<u8>>,
        /// The beacon block header being verified during initialization , Initial header
        genesis_header: BeaconBlockHeader
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Temporary storage used for regular updates of the sync committee.
    /// This struct holds intermediate values and proofs required for processing
    /// and verifying light client updates, including committee transitions
    struct LightClientUpdateScratchSpace has key, drop {
        /// Slot number at which the signature was created
        signature_slot: u64,
        /// Number of steps taken during the update process
        current_step: u64,
        /// Merkle proof branch for verifying the next sync committee
        next_committee_merkle_proof: vector<vector<u8>>,
        /// Merkle proof branch for verifying the finalized header
        finality_merkle_proof: vector<vector<u8>>,
        /// List of hashe tree root of individual public keys from the sync committee
        committee_member_key_hashes: vector<vector<u8>>,
        /// Hash tree root of the aggregated public key from the sync committee
        committee_aggregate_key_hash: vector<u8>,
        /// Root hash of the next sync committee's merkle tree
        leaf_hash_tree_root_next_committee: vector<u8>,
        /// The beacon block header that was attested to
        attested_block_header: BeaconBlockHeader,
        /// The beacon block header that was finalized
        finalized_block_header: BeaconBlockHeader,
        /// The next sync committee that will become active
        next_sync_committee: SyncCommittee,
        /// The aggregate signature and participation data from the sync committee
        sync_aggregate: SyncAggregate
    }

    /// Struct representing the current state of the Light Client.
    ///
    /// Contains sync committee data and associated metadata such as the update slot
    /// and optional details about the next sync committee (if known).
    struct LightClientView has copy, drop, store {
        /// The latest slot at which the light client was updated.
        update_slot: u64,

        /// The current sync committee public keys.
        current_sync_committee_pubkeys: vector<vector<u8>>,

        /// The current sync committee's aggregate public key.
        current_sync_committee_aggregate_pubkey: vector<u8>,

        /// The next sync committee's public keys, if known.
        next_sync_committee_pubkeys: Option<vector<vector<u8>>>,

        /// The next sync committee's aggregate public key, if known.
        next_sync_committee_aggregate_pubkey: Option<vector<u8>>,
    }

    /// View struct representing the list of protocol fork versions and their corresponding epochs.
    struct ForksView has copy, drop, store {
        epochs: vector<u64>,
        versions: vector<vector<u8>>,
    }


    //===============Events=====================

    #[event]
    /// Event emitted when collected fees are withdrawn.
    struct FeeWithdrawalEvent has drop, store {
        deposit_account: address,
        withdrawal_amount: u64
    }

    #[event]
    /// Emitted when the Hypernova fee configuration is added or updated.
    struct HNFeeConfigUpdatedEvent has drop, store {
        committee_updater_margin: u64,
        verifier_margin: u64,
        traffic_per_day: u64,
        committee_updater_reward: u64,
        verification_fee: u64,
        committee_updater_gas_cost: u256
    }

    #[event]
    /// Event emitted when the sync committee threshold is updated.
    struct SyncCommitteeThresholdUpdatedEvent has drop, store {
        sync_committee_threshold: u64
    }

    #[event]
    /// Event emitted when the source hypernova contract address and chainid is updated.
    struct HypernovaSourceUpdatedEvent has drop, store {
        source_hypernova_contract_address: vector<u8>,
        chain_id: u64
    }

    #[event]
    /// Event emitted when the fork versions list is updated.
    struct ForkVersionsUpdatedEvent has drop, store {
        new_protocol_fork_versions: vector<Fork>
    }

    #[event]
    /// Event emitted when the light client store is updated.
    struct LightClientStoreEvent has store, drop {
        latest_slot: u64,
        sync_committee_threshold: u64,
        source_chain_id: u64,
        source_hypernova_contract_address: vector<u8>
    }

    #[event]
    /// Event emitted when a sync committee's validity is determined.
    struct CommitteeValidEvent has store, drop {
        committee_valid: bool,
        current_step: u64
    }

    #[event]
    /// Event emitted when the 's pause status changes.
    /// This event tracks when the service is paused or unpaused for maintenance or emergencies.
    struct HyperNovaPauseStatusEvent has drop, store {
        /// Boolean indicating whether the Service is being paused (true) or unpaused (false)
        is_paused: bool
    }

    #[event]
    /// Event emitted when the source event signature hash is updated.
    struct SourceEventSignatureHashUpdatedEvent has drop, store {
        new_source_event_signature_hash: vector<u8>
    }

    #[event]
    /// Event emitted when an update verification occurs.
    struct UpdateVerificationEvent has store, drop {
        next_sync_committee_public_keys: Option<vector<vector<u8>>>,
        next_sync_committee_aggregate_public_key: Option<vector<u8>>,
        current_sync_committee_public_keys: vector<vector<u8>>,
        current_sync_committee_aggregate_public_key: vector<u8>
    }

    // === InitializerScratchSpace ===
    /// Initializes the module state for the given account.
    ///
    /// This function sets up the initial state by constructing a default beacon block genesis_header
    /// and an InitializerScratchSpace instance with empty values. The state is then moved
    /// to the provided account.
    fun init_module(account: &signer) {
        let beacon_block_header = construct_beacon_block_header(
            0,
            0,
            x"0000000000000000000000000000000000000000000000000000000000000000",
            x"0000000000000000000000000000000000000000000000000000000000000000",
            x"0000000000000000000000000000000000000000000000000000000000000000"
        );

        let (resource_signer, signer_cap) =
            account::create_resource_account(account, HYPERNOVA_SEED);

        coin::register<SupraCoin>(&resource_signer);

        move_to(account, InitializerScratchSpace {
            current_step: 0,
            committee_member_key_hashes: vector[vector::empty<u8>()],
            committee_aggregate_key_hash: vector::empty<u8>(),
            genesis_header: beacon_block_header,
            current_sync_committee_branch: vector[vector::empty<u8>()]
        });

        move_to(&resource_signer, SignerCap { signer_cap })
    }


    /// === Admin Functions ===

    /// Withdraws accumulated verification fees to the deposit account.
    /// Only the core bridge admin can withdraw collected fees.
    ///
    /// # Parameters
    /// * admin: Signer of the admin account requesting withdrawal
    /// * withdrawal_amount: Amount of fees to withdraw
    public entry fun withdraw_collected_fee(
        account: &signer, withdrawal_amount: u64
    ) acquires LightClientState, SignerCap {
        ensure_core_admin(account);
        assert!(withdrawal_amount != 0, ENO_FEE_COLLECTED);
        assert!(
            withdrawal_amount <= get_total_balance(),
            EINSUFFICIENT_FUNDS_FOR_WITHDRAWAL
        );

        let deposit_account = signer::address_of(account);
        coin::transfer<SupraCoin>(&create_hypernova_signer(), deposit_account, withdrawal_amount);
        emit(FeeWithdrawalEvent { deposit_account, withdrawal_amount });
    }

    /// Adds or updates the Hypernova fee configuration stored in the global LightClientState.
    ///
    /// # Access
    /// - Only callable by the core admin. The caller must pass the &signer of the core admin account.
    ///
    /// # Parameters
    /// - account: The signer of the core admin authorized to update the fee config.
    /// - committee_updater_gas_cost: The gas cost (in Quants) incurred by the committee updater.
    ///   Represented as a u256 to prevent overflow during percentage calculations.
    /// - committee_updater_margin: The percentage margin (as a u64) to reward the committee updater.
    /// - verifier_margin: The percentage margin (as a u64) to reward the verifier.
    /// - traffic_per_day: Expected number of verifications per day (used to amortize the total reward).
    ///
    /// # Behavior
    /// - Ensures only the core admin can invoke this function.
    /// - Validates that margins are within acceptable bounds.
    /// - Ensures that both traffic_per_day and committee_updater_gas_cost are non-zero.
    /// - Calculates:
    ///   - committee_updater_reward: The total reward including the updater's margin.
    ///   - verification_fee: The per-verification fee charged to users.
    /// - Validates:
    ///   - traffic_per_day must be less than committee_updater_reward, to avoid zero-fee computation.
    ///   - verification_fee must be less than u64::MAX.
    ///
    /// # Errors
    /// - EINVALID_INPUT_VALUE: If either traffic_per_day or committee_updater_gas_cost is zero.
    /// - EINVALID_MARGIN: If either committee_updater_margin or verifier_margin is outside the valid range.
    /// - ETRAFFIC_PER_DAY_CANNOT_BE_MORE: If traffic_per_day > committee_updater_reward, which could result in zero fees.
    ///
    /// # Updates
    /// - Overwrites or fills the hn_fee_config field in LightClientState with a new HNFeeConfig.

    public entry fun add_or_update_hypernova_config(
        account: &signer,
        // GasCost in Quants = gas_used * gas_unit_price => u64 * u64 => uint128 is enough. But In percentage calculation it might get overflowed. So, using u256
        committee_updater_gas_cost: u256,
        committee_updater_margin: u64,
        verifier_margin: u64,
        traffic_per_day: u64
    ) acquires LightClientState {
        ensure_core_admin(account);
        assert_hn_is_paused();
        // Not checking cm, vm because the margins can be 0 %
        assert!(
            traffic_per_day != (ZERO_VALUE as u64)
                && committee_updater_gas_cost != (ZERO_VALUE as u256),
            EINVALID_INPUT_VALUE
        );
        assert!(
            is_valid_margin(verifier_margin)
                && is_valid_margin(committee_updater_margin),
            EINVALID_MARGIN
        );

        let committee_updater_reward =
            compute_committee_updater_reward(
                committee_updater_gas_cost, committee_updater_margin
            );

        assert!(
            traffic_per_day <= committee_updater_reward,
            ETRAFFIC_PER_DAY_CANNOT_BE_MORE
        );

        let verification_fee = compute_verification_fee(
            committee_updater_reward, traffic_per_day, verifier_margin
        );


        let light_client_state = borrow_global_mut<LightClientState>(@hypernova_core);

        let hn_fee_config_old = option::swap_or_fill(
            &mut light_client_state.hn_fee_config,
            HNFeeConfig {
                committee_updater_margin,
                verifier_margin,
                // GasCost in Quants = gas_used * gas_unit_price => u64 * u64 => uint128 is enough. But In percentage calculaiton it might get oeverflowed. So, using u256
                committee_updater_gas_cost,
                // x is the traffic in a day to hypernova u64 seems fine
                traffic_per_day,
                // verification fee in supra quants. v may become max(cr). So, u256
                verification_fee,
                // cr will be >= cg, >u128 will be enough. But In percentage calcuations might get overflowed so using u256
                committee_updater_reward,
            }
        );
        option::destroy(hn_fee_config_old, |e|{
            HNFeeConfig {
                committee_updater_margin: _,
                verifier_margin: _,
                committee_updater_reward: _,
                traffic_per_day: _,
                verification_fee: _,
                committee_updater_gas_cost: _
            } = e;
        });

        emit(
            HNFeeConfigUpdatedEvent {
                committee_updater_margin,
                verifier_margin,
                traffic_per_day,
                committee_updater_reward,
                verification_fee,
                committee_updater_gas_cost
            }
        )
    }

    /// Updates the pause state of the Hypernova contract.
    /// This function allows the bridge admin to enable or disable the pause state.
    /// When paused, certain bridge operations may be restricted.
    ///
    /// # Arguments
    /// * account - The signer attempting to modify the pause state (must be  admin)
    /// * is_paused - Boolean indicating whether to pause (true) or unpause (false) the bridge
    ///
    /// # Aborts
    /// * If the caller is not the  admin
    public entry fun set_hypernova_pause_state(
        account: &signer, is_paused: bool
    ) acquires LightClientState {
        ensure_core_admin(account);
        borrow_global_mut<LightClientState>(@hypernova_core).is_paused = is_paused;
        emit(HyperNovaPauseStatusEvent { is_paused });
    }

    /// Updates the expected source event signature hash used by the light client
    /// to validate incoming events from the source chain.
    ///
    /// Only the core bridge admin is authorized to perform this update.
    /// This is a critical configuration value, and changing it affects
    /// event validation logic on the bridge.
    public entry fun update_source_event_signature_hash(
        account: &signer, new_source_event_signature_hash: vector<u8>
    ) acquires LightClientState {
        ensure_core_admin(account);
        assert_source_event_signature_hash_len(&new_source_event_signature_hash);

        get_verifier_config_mut().source_event_signature_hash = new_source_event_signature_hash;

        emit(
            SourceEventSignatureHashUpdatedEvent { new_source_event_signature_hash }
        );
    }

    /// Updates sync committee threshold
    public entry fun update_sync_committee_threshold(
        account: &signer, sync_committee_threshold: u64
    ) acquires LightClientState {
        ensure_core_admin(account);
        assert_sync_committee_threshold(sync_committee_threshold);

        get_verifier_config_mut().sync_committee_threshold = sync_committee_threshold;
        emit(SyncCommitteeThresholdUpdatedEvent { sync_committee_threshold });
    }

    /// Updates source hypernova contract address
    public entry fun update_source_hypernova_contract_address_and_chain_id(
        account: &signer, source_hypernova_contract_address: vector<u8>, chain_id: u64
    ) acquires LightClientState {
        ensure_core_admin(account);
        assert_source_hypernova_contract_address(&source_hypernova_contract_address);
        let verifier_config = get_verifier_config_mut();
        verifier_config.source_hypernova_contract_address = source_hypernova_contract_address;
        verifier_config.source_chain_id = chain_id;
        emit(
            HypernovaSourceUpdatedEvent {
                source_hypernova_contract_address,
                chain_id
            }
        );
    }

    /// Updates fork version list (epoch & version vectors)
    public entry fun update_fork_versions(
        account: &signer, epochs: vector<u64>, versions: vector<vector<u8>>
    ) acquires LightClientState {
        ensure_core_admin(account);

        let epochs_length = vector::length(&epochs);

        assert!(epochs_length != 0, EEMPTY_FORK_LIST);
        assert!(epochs_length == vector::length(&versions), EPOCHS_VERSIONS_LENGTH_MISMATCH);

        let current_forks = &mut get_verifier_config_mut().protocol_fork_versions;
        let current_fork_len = vector::length(current_forks);
        let highest_fork = if (vector::is_empty(current_forks)) {
            0
        } else {
            get_epoch(vector::borrow(current_forks, current_fork_len - 1))
        };
        vector::zip(
            epochs,
            versions,
            |new_epoch, new_version| {
                let exists = vector::any(
                    current_forks,
                    |existing_fork| get_epoch(existing_fork) == new_epoch
                );
                if (!exists) {
                    assert!(new_epoch > highest_fork, EOUT_OF_ORDER_EPOCH);
                    let fork = construct_fork(new_epoch, new_version);
                    vector::push_back(current_forks, fork);
                    highest_fork = new_epoch;
                };
            }
        );

        emit(ForkVersionsUpdatedEvent {
            new_protocol_fork_versions: *current_forks
        });
    }

    /// Initializes the Light Client store with the provided parameters.
    /// This function sets up the initial state of the Light Client and stores the configuration
    /// details required for future light client updates.
    ///
    /// # Parameters:
    /// - account: The signer who is initializing the light client
    /// - slot: The slot number of the beacon block
    /// - proposer_index: The index of the proposer for the block
    /// - parent_root: The hash of the parent block root
    /// - state_root: The hash of the state root
    /// - body_root: The hash of the block body root
    /// - public_keys: The public keys of the current sync committee
    /// - aggregate_public_key: The aggregated public key of the sync committee
    /// - current_sync_committee_branch: Merkle branch proof for the current sync committee
    /// - source_chain_id: The chain identifier for the blockchain network
    /// - epochs: Vector of epoch values for different protocol_fork_versions
    /// - versions: Vector of version values for different protocol_fork_versions
    /// - source_hypernova_contract_address: The identifier for the source Hypernova core (32 bytes)
    /// - sync_committee_threshold: The threshold for sync committee signatures
    ///
    /// # Acquires:
    /// - InitializerScratchSpace: Ensures single initialization
    ///
    /// # Events:
    /// - Emits LightClientStoreEvent with initialization details
    ///
    /// # Errors:
    /// - EINITIALIZER_RESOURCE_NOT_FOUND: If InitializerScratchSpace doesn't exist
    /// - EINVALID_AGGREGATE_PUBLIC_KEY: If aggregate public key is invalid
    /// - EINVALID_SOURCE_HN_ADDRESS: If source Hypernova address is invalid length
    entry fun initialize_light_client_store(
        account: &signer,
        // Beacon block header parameters
        latest_slot: u64,
        latest_proposer_index: u64,
        latest_parent_root: vector<u8>,
        latest_state_root: vector<u8>,
        latest_body_root: vector<u8>,
        // Sync committee parameters
        public_keys: vector<vector<u8>>,
        aggregate_public_key: vector<u8>,
        current_sync_committee_branch: vector<vector<u8>>,
        // Chain configuration parameters
        source_chain_id: u64,
        epochs: vector<u64>,
        versions: vector<vector<u8>>,
        source_hypernova_contract_address: vector<u8>, //@notice: relayer change pass 32 bytes
        sync_committee_threshold: u64,
        source_event_signature_hash: vector<u8>
    ) acquires InitializerScratchSpace, LightClientState {
        // Verify initialization
        let hypernova_core_addr = signer::address_of(account);
        assert!(
            exists<InitializerScratchSpace>(hypernova_core_addr),
            EINITIALIZER_RESOURCE_NOT_FOUND
        );
        if (exists<LightClientState>(hypernova_core_addr)) {
            destroy_light_client_state();
            borrow_global_mut<InitializerScratchSpace>(hypernova_core_addr).current_step = 0;
        };
        // Setup sync committee
        let aggregate_pubkey_option = public_key_from_bytes(aggregate_public_key);
        assert!(
            option::is_some(&aggregate_pubkey_option), EINVALID_AGGREGATE_PUBLIC_KEY
        );

        let current_sync_committee =
            construct_sync_committee(
                convert_public_key_from_bytes_with_pop(public_keys),
                option::extract(&mut aggregate_pubkey_option)
            );

        // Initialize store
        let light_client_store = LightClientStore {
            last_update_slot: latest_slot,
            current_sync_committee,
            next_sync_committee: option::none()
        };

        // Validate address
        assert_source_hypernova_contract_address(&source_hypernova_contract_address);
        assert_sync_committee_threshold(sync_committee_threshold);
        assert_source_event_signature_hash_len(&source_event_signature_hash);

        let verifier_config = VerifierConfig {
            admin_address: hypernova_core_addr,
            source_chain_id,
            protocol_fork_versions: vector::empty(),
            source_hypernova_contract_address,
            sync_committee_threshold,
            source_event_signature_hash
        };

        //Store light client state
        move_to(
            account,
            LightClientState {
                is_paused: true,
                light_client_store,
                verifier_config,
                hn_fee_config: option::none()
            }
        );
        // Build fork versions
        update_fork_versions(account, epochs, versions);
        //Setup initialization scratch space
        let genesis_header =
            construct_beacon_block_header(
                latest_slot,
                latest_proposer_index,
                latest_parent_root,
                latest_state_root,
                latest_body_root
            );

        let scratch_space = borrow_global_mut<InitializerScratchSpace>(hypernova_core_addr);
        scratch_space.genesis_header = genesis_header;
        scratch_space.current_sync_committee_branch = current_sync_committee_branch;

        emit(
            LightClientStoreEvent {
                latest_slot,
                source_chain_id,
                source_hypernova_contract_address,
                sync_committee_threshold
            }
        );
    }

    /// Initializes a step in the light client process by validating committee proof and updating the scratch space.
    ///
    /// This function manages the initialization process of the light client in two steps:
    /// 1. Step 0: Prepares the sync committee data for validation
    /// 2. Step 1: Validates the committee proof and finalizes initialization
    ///
    /// # Process Flow:
    /// 1. Verifies the existence of required resources
    /// 2. Checks the current step count (must be <= 1)
    /// 3. For step 0:
    ///    - Prepares sync committee data
    ///    - Updates scratch space for next step
    /// 4. For step 1:
    ///    - Validates the committee proof
    ///    - Move the scratch space if valid proof
    ///    - Emits validation events
    entry fun initialize_step() acquires LightClientState, InitializerScratchSpace {
        let light_client = borrow_global_mut<LightClientState>(@hypernova_core);
        assert!(
            exists<InitializerScratchSpace>(@hypernova_core),
            EMISSING_INITIALIZER_SCRATCH_SPACE
        );
        let scratch_space = borrow_global_mut<InitializerScratchSpace>(@hypernova_core);
        let current_step = scratch_space.current_step;

        assert!(current_step <= 1, EALREADY_INITIALIZED);
        // Step 2: Process next steps if current step is 1
        if (current_step == 1) {
            let genesis_header = scratch_space.genesis_header;
            let current_sync_committee_pubkeys_htr =
                scratch_space.committee_member_key_hashes;
            let aggregate_key_htr = scratch_space.committee_aggregate_key_hash;
            let current_sync_committee_branch =
                scratch_space.current_sync_committee_branch;

            let pubkeys_htr = calculate_root(&mut current_sync_committee_pubkeys_htr);
            let leaf_hash_tree_root_current_committee =
                hash_pair(pubkeys_htr, aggregate_key_htr);

            let committee_valid =
                is_current_committee_proof_valid(
                    &genesis_header,
                    current_sync_committee_branch,
                    leaf_hash_tree_root_current_committee
                );
            if (!committee_valid) {
                destroy_light_client_state();

                scratch_space.current_step = 0;
                emit(CommitteeValidEvent { committee_valid, current_step });
                return
            };

            let InitializerScratchSpace {
                current_step: _,
                committee_member_key_hashes: _,
                committee_aggregate_key_hash: _,
                genesis_header: _,
                current_sync_committee_branch: _
            } = move_from<InitializerScratchSpace>(@hypernova_core);
            light_client.is_paused = false;
            emit(HyperNovaPauseStatusEvent { is_paused: false });
            emit(CommitteeValidEvent { committee_valid, current_step });
            return
        };

        // Step 1: Initialize committee data if current step is 1
        let current_sync_committee =
            light_client.light_client_store.current_sync_committee;

        let public_keys = vector::slice(
            get_sync_committee_public_keys(&current_sync_committee),
            current_step * SYNC_COMMITTEE_SIZE,
            (current_step + 1) * SYNC_COMMITTEE_SIZE
        );

        let pubkeys_htr = public_keys_hash_tree_root(&mut public_keys);
        let agg_public_key = get_aggregate_public_key(&current_sync_committee);
        let aggregate_pubkey_htr =
            hash_tree_root_public_key(public_key_to_bytes(agg_public_key));

        scratch_space.committee_member_key_hashes = pubkeys_htr;
        scratch_space.committee_aggregate_key_hash = aggregate_pubkey_htr;
        scratch_space.current_step = current_step + 1;
    }


    /// Initializes the sync committee update process in the light client.
    ///
    /// This function prepares the light client to process a new sync committee update.
    /// It validates and stores all relevant components including the attested and finalized
    /// block headers, next sync committee data, Merkle proofs, and sync committee signature.
    /// It also ensures temporary scratch space is properly initialized or overwritten.
    ///
    /// # Parameters
    /// - `sync_committee_updater`: Signer initiating the update.
    ///
    /// - *Attested Header*:
    ///   - `attested_slot`: Slot number of the attested block.
    ///   - `attested_header_proposer_index`: Proposer index of the attested block.
    ///   - `attested_header_parent_root`: Parent root of the attested block.
    ///   - `attested_header_state_root`: State root of the attested block.
    ///   - `attested_header_body_root`: Body root of the attested block.
    ///
    /// - *Next Sync Committee*:
    ///   - `next_sync_committee_public_keys`: BLS public keys of the next sync committee.
    ///   - `next_sync_committee_aggregate_public_key`: BLS aggregate public key of the next sync committee.
    ///   - `next_committee_merkle_proof`: Merkle proof for the next committee root in state.
    ///
    /// - *Finalized Header*:
    ///   - `finalized_header_slot`: Slot number of the finalized block.
    ///   - `finalized_header_proposer_index`: Proposer index of the finalized block.
    ///   - `finalized_header_parent_root`: Parent root of the finalized block.
    ///   - `finalized_header_state_root`: State root of the finalized block.
    ///   - `finalized_header_body_root`: Body root of the finalized block.
    ///   - `finality_merkle_proof`: Merkle proof for finalized checkpoint root in state.
    ///
    /// - *Sync Committee Signature*:
    ///   - `sync_committee_bits`: Bitfield indicating which committee members participated.
    ///   - `sync_committee_signature`: Aggregate BLS signature from the committee.
    ///   - `signature_slot`: Slot at which the aggregate signature was produced.
    ///
    /// # Acquires
    /// - `LightClientUpdateScratchSpace`
    /// - `LightClientState`
    ///
    /// # Behavior
    /// 1. Constructs the next sync committee from provided public keys and APK.
    /// 2. Builds attested and finalized block headers from inputs.
    /// 3. Constructs the sync aggregate from signature bits and the signature.
    /// 4. Initializes (or overwrites) scratch space with all above components.
    ///
    /// The function does not finalize the update or perform any on-chain validation
    /// of committee correctness. It only prepares the scratch state to be used
    /// in subsequent steps.
    public entry fun initial_sync_committee_update(
        sync_committee_updater: &signer,
        // Attested header parameters
        attested_slot: u64,
        attested_header_proposer_index: u64,
        attested_header_parent_root: vector<u8>,
        attested_header_state_root: vector<u8>,
        attested_header_body_root: vector<u8>,
        // Next sync committee parameters
        next_sync_committee_public_keys: vector<vector<u8>>,
        next_sync_committee_aggregate_public_key: vector<u8>,
        next_committee_merkle_proof: vector<vector<u8>>,
        // Finalized header parameters
        finalized_header_slot: u64,
        finalized_header_proposer_index: u64,
        finalized_header_parent_root: vector<u8>,
        finalized_header_state_root: vector<u8>,
        finalized_header_body_root: vector<u8>,
        finality_merkle_proof: vector<vector<u8>>,
        // Sync committee signature parameters
        sync_committee_bits: vector<bool>,
        sync_committee_signature: vector<u8>,
        signature_slot: u64
    ) acquires LightClientUpdateScratchSpace, LightClientState {
        assert_hn_is_paused();
        //Validate and construct next sync committee
        let next_apk_option = public_key_from_bytes(next_sync_committee_aggregate_public_key);
        assert!(
            option::is_some(&next_apk_option),
            ENEXT_AGGREGATE_PUBLIC_KEY_MISSING
        );
        let next_sync_committee =
            construct_sync_committee(
                convert_public_key_from_bytes_with_pop(next_sync_committee_public_keys),
                option::extract(&mut next_apk_option)
            );

        // Construct attested and finalized block headers
        let attested_block_header =
            construct_beacon_block_header(
                attested_slot,
                attested_header_proposer_index,
                attested_header_parent_root,
                attested_header_state_root,
                attested_header_body_root
            );

        let finalized_block_header =
            construct_beacon_block_header(
                finalized_header_slot,
                finalized_header_proposer_index,
                finalized_header_parent_root,
                finalized_header_state_root,
                finalized_header_body_root
            );

        // Create sync aggregate
        let sync_aggregate =
            construct_sync_aggregate(
                sync_committee_bits,
                sync_committee_signature
            );

        let account_addr = signer::address_of(sync_committee_updater);
        if (!exists<LightClientUpdateScratchSpace>(account_addr)) {
            move_to(
                sync_committee_updater,
                LightClientUpdateScratchSpace {
                    attested_block_header,
                    finalized_block_header,
                    next_sync_committee,
                    next_committee_merkle_proof,
                    finality_merkle_proof,
                    sync_aggregate,
                    signature_slot,
                    current_step: 0,
                    committee_member_key_hashes: vector::empty(),
                    committee_aggregate_key_hash: vector::empty(),
                    leaf_hash_tree_root_next_committee: vector::empty()
                }
            );
        }else {
            let light_client_scratch_space = borrow_global_mut<LightClientUpdateScratchSpace>(account_addr);
            light_client_scratch_space.attested_block_header = attested_block_header;
            light_client_scratch_space.finalized_block_header = finalized_block_header;
            light_client_scratch_space.next_sync_committee = next_sync_committee;
            light_client_scratch_space.next_committee_merkle_proof = next_committee_merkle_proof;
            light_client_scratch_space.finality_merkle_proof = finality_merkle_proof;
            light_client_scratch_space.sync_aggregate = sync_aggregate;
            light_client_scratch_space.signature_slot = signature_slot;
            light_client_scratch_space.current_step = 0;
            light_client_scratch_space.committee_member_key_hashes = vector::empty();
            light_client_scratch_space.committee_aggregate_key_hash = vector::empty();
            light_client_scratch_space.leaf_hash_tree_root_next_committee = vector::empty();
        }
    }

    /// Updates the sync committee state in the light client.
    /// This function handles the validation and application of sync committee updates,
    /// including committee transitions and state updates.
    ///
    /// # Parameters:
    /// - account: The signer performing the update
    ///
    /// # Errors:
    /// - ELIGHT_CLIENT_UPDATE_SCRATCH_SPACE_NOT_FOUND: If scratch space doesn't exist
    /// - EINVALID_STEP_COUNT: If current step is invalid
    ///
    /// # Process:
    /// 1. Verify scratch space exists and step is valid
    /// 2. If step 1:
    ///    - Calculate committee hashes
    ///    - Verify update validity
    ///    - Apply update if valid and better than current state
    ///    - Update sync committees if needed
    /// 3. If step 0:
    ///    - Prepare next committee data
    ///    - Calculate and store hashes
    ///    - Increment step counter
    public entry fun sync_committee_update(
        account: &signer
    ) acquires LightClientState, LightClientUpdateScratchSpace, SignerCap {
        let account_addr = signer::address_of(account);
        assert!(
            exists<LightClientUpdateScratchSpace>(account_addr),
            ELIGHT_CLIENT_UPDATE_SCRATCH_SPACE_NOT_FOUND
        );

        let light_client_update = borrow_global_mut<LightClientUpdateScratchSpace>(account_addr);
        let current_step = light_client_update.current_step;

        assert!(current_step <= 1, EINVALID_STEP_COUNT);

        // 2. Handle step 1: Verification and update application
        if (current_step == 1) {
            let next_sync_committee_pubkeys_htr =
                light_client_update.committee_member_key_hashes;
            let next_sync_committee_aggregate_pubkey_htr =
                light_client_update.committee_aggregate_key_hash;

            let pubkeys_htr = calculate_root(&mut next_sync_committee_pubkeys_htr);
            let next_committee_leaf_htr =
                hash_pair(pubkeys_htr, next_sync_committee_aggregate_pubkey_htr);

            light_client_update.leaf_hash_tree_root_next_committee =
                next_committee_leaf_htr;

            // Verification Process:
            // 1. Verify that the attested header is properly signed by the current sync committee
            //    - Checks the sync aggregate signature against the current committee's aggregate public key
            //    - Ensures the signature is valid and has sufficient participation
            // 2. Verify the finality proof
            //    - Validates the Merkle proof that links the finalized header to the attested header
            //    - Ensures the finalized header is properly included in the attested header's state
            // 3. Verifies the light client update.
            //    - Aborts with EUPDATE_VERIFICATION_FAILED if verification fails.
            assert!(update_verification(light_client_update), EUPDATE_VERIFICATION_FAILED);

            let client = borrow_global_mut<LightClientState>(@hypernova_core);

            // Apply update if better than current state
            if (is_better_update(light_client_update, client)) {
                let finalized_header_slot =
                    get_slot(&light_client_update.finalized_block_header);
                let client_update_slot = client.light_client_store.last_update_slot;

                let finalized_period = calc_sync_period(finalized_header_slot);
                let current_period = calc_sync_period(client_update_slot);

                // Update sync committees if needed
                if (option::is_none(&client.light_client_store.next_sync_committee)) {
                    option::fill(
                        &mut client.light_client_store.next_sync_committee,
                        light_client_update.next_sync_committee
                    );
                } else if (finalized_period == current_period + 1) {
                    let current_sync_committee = option::swap(
                        &mut client.light_client_store.next_sync_committee,
                        light_client_update.next_sync_committee
                    );
                    client.light_client_store.current_sync_committee = current_sync_committee;
                };

                if (finalized_header_slot > client.light_client_store.last_update_slot) {
                    client.light_client_store.last_update_slot = finalized_header_slot;
                }
            };
            process_committee_updater_reward(account_addr);
            emit(
                UpdateVerificationEvent {
                    next_sync_committee_public_keys: get_next_sync_committee_public_keys(),
                    next_sync_committee_aggregate_public_key: get_next_sync_committee_aggregate_public_key(),
                    current_sync_committee_public_keys: get_current_sync_committee_public_keys(),
                    current_sync_committee_aggregate_public_key: get_current_sync_committee_aggregate_public_key()
                }
            );
            return
        };

        //3. Handle step 0: Prepare next committee data
        let next_sync_committee = light_client_update.next_sync_committee;
        let next_sync_committee_public_keys = vector::slice(
            get_sync_committee_public_keys(&next_sync_committee),
            current_step * SYNC_COMMITTEE_SIZE,
            (current_step + 1) * SYNC_COMMITTEE_SIZE
        );

        let next_sync_committee_aggregate_public_key = get_aggregate_public_key(&next_sync_committee);

        // Calculate and store hashes
        let next_sync_committee_pubkeys_htr = public_keys_hash_tree_root(&mut next_sync_committee_public_keys);
        let aggregate_pubkey_htr = hash_tree_root_public_key(
            public_key_to_bytes(next_sync_committee_aggregate_public_key)
        );

        light_client_update.committee_member_key_hashes = next_sync_committee_pubkeys_htr;
        light_client_update.committee_aggregate_key_hash = aggregate_pubkey_htr;
        light_client_update.current_step = current_step + 1;
    }

    /// Verifies whether the given LightClientOptimisticUpdate meets the conditions for an optimistic update.
    /// This function performs comprehensive validation of the update by checking multiple criteria.
    ///
    /// # Parameters:
    /// - update: A mutable reference to LightClientOptimisticUpdate containing update details
    ///
    ///
    /// # Validation Steps:
    /// 1. Sync Committee Participation
    ///    - Verifies sufficient committee member participation
    /// 2. Timestamp Validation
    ///    - Ensures signature slot is within valid time window
    /// 3. Period Validation
    ///    - Verifies update period aligns with current state
    /// 4. Update Relevance
    ///    - Checks if update provides new information
    /// 5. Signature Verification
    ///    - Validates sync committee signature
    public(friend) fun process_light_client_optimistic_update(
        update: &mut LightClientUpdate
    ) acquires LightClientState {
        // 1. Verify sync committee participation
        let sync_aggregate = get_sync_aggregate_update(update);
        let committee_bits = get_sync_committee_bits(sync_aggregate);
        let participation_count = get_sync_commitee_participation_count(*committee_bits);

        assert!(
            participation_count >= get_sync_committee_threshold(),
            EINSUFFICIENT_PARTICIPATION
        );

        //Verify timestamp conditions
        let client_state = borrow_global_mut<LightClientState>(@hypernova_core);
        let signature_slot = get_signature_slot_update(update);
        let attested_slot = get_slot(get_attested_header_update(update));
        assert!(
            expected_current_slot() >= signature_slot
                && signature_slot > attested_slot,
            EINVALID_SIGNATURE_SLOT_ORDER
        );

        let current_period =
            calc_sync_period(client_state.light_client_store.last_update_slot);
        let update_period = calc_sync_period(signature_slot);
        let has_next_committee =
            option::is_some(&client_state.light_client_store.next_sync_committee);

        // Verify period validity
        let valid_period = (update_period == current_period) || (has_next_committee && update_period == current_period + 1);

        assert!(valid_period, EINVALID_UPDATE_PERIOD);

        // Check update relevance
        let attested_period = calc_sync_period(attested_slot);
        let needs_next_committee =
            !has_next_committee
                && attested_period == current_period;

        assert!(
            attested_slot > client_state.light_client_store.last_update_slot
                || needs_next_committee,
            ENOT_RELEVANT_UPDATE_SLOT
        );

        let active_committee =
            if (update_period == current_period) {
                client_state.light_client_store.current_sync_committee
            } else {
                *option::borrow(&client_state.light_client_store.next_sync_committee)
            };

        let participating_keys = get_participating_keys(
            &active_committee, committee_bits
        );
        let committee_signature = get_sync_committee_signature(sync_aggregate);

        let is_signature_valid =
            verify_sync_committee_signature(
                client_state,
                participating_keys,
                get_attested_header_update(update),
                &signature_to_bytes(committee_signature),
                signature_slot
            );
        assert!(is_signature_valid, EINVALID_SIGNATURE);
    }

    /// Verifies whether the given LightClientSafeUpdate meets the conditions for a safe update.
    /// This function ensures that the update provides sufficient safety guarantees by checking:
    /// - The safety level meets the minimum required threshold
    /// - The update can be converted to and validated as an optimistic update
    ///
    /// # Parameters:
    /// - update: A reference to the LightClientSafeUpdate containing the update details
    /// - target_slot: The target slot number for safety level calculation
    ///
    /// # Acquires:
    /// - LightClientState: The current state of the light client
    ///
    /// # Process:
    /// 1. Calculate safety level based on slot difference
    /// 2. Verify safety level meets minimum requirement
    /// 3. Convert safe update to optimistic update format
    /// 4. Validate the converted update using optimistic update rules
    public(friend) fun process_light_client_safe_update(
        update: &LightClientUpdate, target_slot: u64, min_safety_level_external: u8
    ) acquires LightClientState {
        // Calculate and verify safety level
        let attested_slot = get_slot(get_attested_header_update(update));
        let safety_level = attested_slot - target_slot;
        assert!(
            safety_level >= (min_safety_level_external as u64),
            EINVALID_SAFETY_LEVEL
        );

        // Convert and validate as optimistic update
        let lightclient_safe_update_build =
            construct_lightclient_update(
                get_signature_slot_update(update),
                option::none(),
                *get_attested_header_update(update),
                option::none(),
                *get_sync_aggregate_update(update)
            );
        process_light_client_optimistic_update(&mut lightclient_safe_update_build);
    }

    /// Verifies whether the given LightClientFinalityUpdate meets the conditions for a finality update.
    /// This function extends the optimistic update validation by ensuring that the finalized header
    /// in the update is valid and proves finality over the attested header.
    ///
    /// # Parameters:
    /// - update: A mutable reference to the LightClientFinalityUpdate containing the update details
    ///
    /// # Process:
    /// 1. Convert and validate as optimistic update
    /// 2. Verify slot ordering (attested header must be newer than finalized header)
    /// 3. Validate finality proof using Merkle proof
    public(friend) fun process_light_client_finality_update(
        update: &mut LightClientUpdate
    ) acquires LightClientState {
        // 1. Convert and validate as optimistic update
        let attested_header = get_attested_header_update(update);
        let optimistic_update =
            construct_lightclient_update(
                get_signature_slot_update(update),
                option::none(),
                *attested_header,
                option::none(),
                *get_sync_aggregate_update(update)
            );

        process_light_client_optimistic_update(&mut optimistic_update);

        let finalized_header_option = get_finalized_header_update(update);
        let finality_branch_option = get_finality_branch_update(update);

        assert!(
            option::is_some(&finalized_header_option),
            EINVALID_FINALIZED_HEADER_OPTION
        );
        assert!(
            option::is_some(&finality_branch_option), EINVALID_FINALITY_BRANCH_OPTION
        );

        let finalized_header = option::extract(&mut finalized_header_option);
        let finality_branch = option::extract(&mut finality_branch_option);
        // 2. Verify slot ordering
        let attested_slot = get_slot(attested_header);
        let finalized_slot = get_slot(&finalized_header);
        assert!(
            attested_slot > finalized_slot,
            EINVALID_SLOT_ORDER
        );

        // 3. Validate finality proof
        let is_finality_proof_valid =
            is_finality_proof_valid(
                attested_header,
                &finalized_header,
                finality_branch
            );
        assert!(is_finality_proof_valid, EINVALID_FINALITY_PROOF);
    }


    /// Checks if an account has core bridge admin privileges.
    ///
    /// # Parameters
    /// * account: The signer to check for admin privileges
    ///
    /// # Returns
    /// * bool: True if the account has admin privileges, false otherwise
    public(friend) fun ensure_core_admin(account: &signer) acquires LightClientState {
        assert!(
            get_verifier_config().admin_address == signer::address_of(account),
            EUNAUTHORIZED_CORE_ADMIN
        );
    }

    /// Processes the verification fee payment from a user.
    /// This function:
    /// 1. Verifies the payment amount meets the required fee
    /// 2. Extracts the fee from the user's payment
    /// 3. Adds the fee to the accumulated total
    ///
    /// # Parameters
    /// * user_payment: Reference to the user's payment coin
    ///
    /// # Aborts
    /// * If payment amount is less than required fee (error code 22)
    public(friend) fun process_verification_fee(account: &signer) acquires LightClientState {
        let hypernova_resource_addr = generate_resource_address();
        let verfication_fee = get_fee_per_verification() ;
        assert!(
            coin::balance<SupraCoin>(signer::address_of(account)) >= verfication_fee,
            EINSUFFICIENT_WALLET_BALANCE_FOR_VERIFICATION
        );

        coin::transfer<SupraCoin>(account, hypernova_resource_addr, verfication_fee)
    }


    // === Private Functions ===
    /// Returns a mutable reference to the verifier config from global LightClientState.
    inline fun get_verifier_config_mut(): &mut VerifierConfig acquires LightClientState {
        &mut borrow_global_mut<LightClientState>(@hypernova_core).verifier_config
    }

    /// Returns an immutable reference to the verifier config from global LightClientState.
    inline fun get_verifier_config(): &VerifierConfig acquires LightClientState {
        &borrow_global<LightClientState>(@hypernova_core).verifier_config
    }

    /// Asserts that the Hypernova protocol is not paused.
    inline fun assert_hn_is_paused() acquires LightClientState {
        assert!(!is_hypernova_paused(), EHYPERNOVA_PAUSED);
    }

    /// Asserts that the source event signature hash is exactly 32 bytes.
    inline fun assert_source_event_signature_hash_len(
        source_event_signature_hash: &vector<u8>
    ) {
        assert!(
            vector::length(source_event_signature_hash) == BYTES_32_LEN,
            EINVALID_SOURCE_EVENT_SIGNATURE_HASH_LEN
        );
    }

    /// Asserts that the sync committee threshold does not exceed the maximum allowed size.
    inline fun assert_sync_committee_threshold(sync_committee_threshold: u64) {
        assert!(
            sync_committee_threshold <= SYNC_COMMITTEE_SIZE,
            EINVALID_SYNC_COMMITTEE_THRESHOLD
        );
    }

    /// Asserts that the source Hypernova contract address is exactly 32 bytes.
    inline fun assert_source_hypernova_contract_address(
        source_hypernova_contract_address: &vector<u8>
    ) {
        assert!(
            vector::length(source_hypernova_contract_address) == BYTES_32_LEN,
            EINVALID_SOURCE_HN_ADDRESS
        );
    }

    /// Computes the sync period for a given slot in the Ethereum Beacon Chain.
    ///
    /// # Overview
    /// The Ethereum Beacon Chain uses a hierarchical time structure:
    /// - 1 slot = 12 seconds
    /// - 1 epoch = 32 slots = 6.4 minutes
    /// - 1 sync period = 256 epochs = 8192 slots = 27.3 hours
    ///
    /// # Parameters:
    /// - slot: The slot number to calculate the sync period for
    ///
    /// # Returns:
    /// - The sync period index (0-based) that the slot belongs to
    ///
    /// # Example:
    /// claim_minter_capability_for_tokenclaim_minter_capability_for_tokenclaim_minter_capability_for_tokenmove
    /// let slot = 16384;
    /// let epoch = slot / 32;    
    /// let sync_period = epoch / 256;
    /// claim_minter_capability_for_tokenclaim_minter_capability_for_tokenclaim_minter_capability_for_token
    ///
    /// # Constants:
    /// - SLOTS_PER_EPOCH: 32 slots
    /// - SYNC_PERIOD: 256 epochs
    inline fun calc_sync_period(slot: u64): u64 {
        slot / (SLOTS_PER_EPOCH * SYNC_PERIOD)
    }

    /// Unpacks and consumes the LightClientState resource stored at @hypernova_core.
    ///
    /// It performs the following:
    /// - Moves and destroys the LightClientState resource.
    /// - Deconstructs nested fields such as LightClientStore, VerifierConfig, and HNFeeConfig.
    /// - Silently discards all extracted values after unpacking.
    ///
    /// Note: This function does **not** return any data or perform any state mutation beyond consuming the resource.
    /// Use with caution, as it permanently removes the LightClientState from storage.
    inline fun destroy_light_client_state() {
        let LightClientState {
            is_paused: _,
            light_client_store,
            verifier_config,
            hn_fee_config
        } = move_from<LightClientState>(@hypernova_core);

        let LightClientStore {
            last_update_slot: _,
            current_sync_committee: _,
            next_sync_committee: _
        } = light_client_store;

        option::destroy(hn_fee_config, |v|{
            HNFeeConfig {
                committee_updater_margin: _,
                verifier_margin: _,
                committee_updater_gas_cost: _,
                committee_updater_reward: _,
                traffic_per_day: _,
                verification_fee: _
            } = v;
        });

        let VerifierConfig {
            sync_committee_threshold: _,
            source_chain_id: _,
            admin_address: _,
            source_hypernova_contract_address: _,
            protocol_fork_versions: _,
            source_event_signature_hash: _
        } = verifier_config;
    }

    /// Converts a vector of byte-encoded public keys into PublicKeyWithPoP structures.
    /// This function processes a list of public keys, converting each from its byte representation
    /// into a PublicKeyWithPoP structure with external verification.
    fun convert_public_key_from_bytes_with_pop(
        public_keys: vector<vector<u8>>
    ): vector<PublicKeyWithPoP> {
        let converted_keys = vector::empty<PublicKeyWithPoP>();

        vector::for_each(
            public_keys,
            |public_key_bytes| {
                let verified_key =
                    public_key_from_bytes_with_pop_externally_verified(public_key_bytes);
                assert!(option::is_some(&verified_key), EINVALID_POP_PUBLIC_KEY);
                vector::push_back(
                    &mut converted_keys, option::extract(&mut verified_key)
                )
            }
        );
        converted_keys
    }


    /// Determines whether a LightClient update should replace the current state.
    /// This function evaluates the quality and relevance of an update to decide if it's better than the current state.
    ///
    /// # Parameters:
    /// - update: Reference to the LightClientUpdateScratchSpace containing the proposed update
    /// - client: Mutable reference to the current LightClientState
    ///
    /// # Evaluation Criteria:
    /// 1. Committee Participation
    ///    - Must have more than super-majority(2/3) of sync committee members participating.
    /// 2. Update Relevance
    ///    - Either newer than current state OR
    ///    - Contains finalized next committee
    ///
    /// # Returns:
    /// - true: If the update meets all criteria and should be applied
    /// - false: If the update doesn't meet the criteria
    fun is_better_update(
        update: &LightClientUpdateScratchSpace, client: &mut LightClientState
    ): bool {
        // 1. Calculate committee participation
        let participation_bits = get_sync_committee_bits(&update.sync_aggregate);
        let participation_count =
            get_sync_commitee_participation_count(*participation_bits);
        // Ensure at least (inclusive) 2/3 of the sync committee participated.
        // We use an inclusive check (>) to allow exactly 2/3 participation as valid.
        let has_sufficient_participation = participation_count * 3 > SYNC_COMMITTEE_SIZE * 2;
        // 2. Calculate update timing and period information
        let finalized_slot = get_slot(&update.finalized_block_header);

        // 4. Return true only if both criteria are met
        has_sufficient_participation
            && (
            finalized_slot > client.light_client_store.last_update_slot
                || calc_sync_period(finalized_slot)
                == calc_sync_period(get_slot(&update.attested_block_header))
        )
    }

    /// Verifies the validity of a light client update by checking both finality and next committee proofs.
    ///
    /// # Parameters:
    /// - update: Mutable reference to LightClientUpdateScratchSpace containing update details
    ///
    /// # Process:
    /// 1. Construct and verify finality update
    /// 2. Verify next committee proof
    ///
    /// # Returns:
    /// - true: If both finality and next committee proofs are valid
    /// - false: If either proof fails validation
    fun update_verification(
        update: &mut LightClientUpdateScratchSpace
    ): bool acquires LightClientState {
        let attested_header = update.attested_block_header;
        // 1. Verify finality update
        let finality_update =
            construct_lightclient_update(
                update.signature_slot,
                option::some(update.finality_merkle_proof),
                attested_header,
                option::some(update.finalized_block_header),
                update.sync_aggregate
            );

        process_light_client_finality_update(&mut finality_update);

        // 2. Verify next committee proof
        is_next_committee_proof_valid(
            &attested_header,
            update.next_committee_merkle_proof,
            update.leaf_hash_tree_root_next_committee
        )
    }

    /// Verifies the validity of the current sync committee proof using Merkle branch validation.
    /// # Parameters:
    /// - attested_block_header: Reference to the attested block header
    /// - current_committee_branch: Merkle proof for the current committee
    /// - hash_tree_root_current_committee: Expected root hash of the current committee
    fun is_current_committee_proof_valid(
        attested_block_header: &BeaconBlockHeader,
        current_committee_branch: vector<vector<u8>>,
        hash_tree_root_current_committee: vector<u8>
    ): bool {
        is_valid_merkle_branch(
            *get_state_root(attested_block_header),
            hash_tree_root_current_committee,
            current_committee_branch,
            CURRENT_COMMITTEE_DEPTH,
            CURRENT_COMMITTEE_INDEX
        )
    }

    /// Verifies the validity of the next sync committee proof using Merkle branch validation.
    ///
    /// # Parameters:
    /// - attested_block_header: Reference to the attested block header
    /// - next_committee_branch: Merkle proof for the next committee
    /// - leaf_hash_tree_root_next_committee: Expected root hash of the next committee
    fun is_next_committee_proof_valid(
        attested_block_header: &BeaconBlockHeader,
        next_committee_branch: vector<vector<u8>>,
        leaf_hash_tree_root_next_committee: vector<u8>
    ): bool {
        is_valid_merkle_branch(
            *get_state_root(attested_block_header),
            leaf_hash_tree_root_next_committee,
            next_committee_branch,
            NEXT_COMMITTEE_DEPTH,
            NEXT_COMMITTEE_INDEX
        )
    }

    /// Verifies the validity of the finality proof using Merkle branch validation.
    ///
    /// # Parameters:
    /// - attested_block_header: Reference to the attested block header
    /// - finality_header: Reference to the finalized block header
    /// - finality_merkle_proof: Merkle proof for finality
    ///
    /// # Returns:
    /// - true: If the Merkle proof is valid
    /// - false: If the proof is invalid
    fun is_finality_proof_valid(
        attested_block_header: &BeaconBlockHeader,
        finality_header: &BeaconBlockHeader,
        finality_merkle_proof: vector<vector<u8>>
    ): bool {
        is_valid_merkle_branch(
            *get_state_root(attested_block_header),
            hash_tree_root_beacon_block_header(finality_header),
            finality_merkle_proof,
            FINALITY_DEPTH,
            FINALITY_INDEX
        )
    }


    /// Retrieves the public keys of sync committee members who participated in signing.
    ///
    /// # Overview
    /// This function processes a bitfield representing committee member participation
    /// and returns the public keys of all participating members. The bitfield is a
    /// vector of booleans where true indicates participation.
    ///
    /// # Parameters:
    /// - committee: Reference to the SyncCommittee containing all member public keys
    /// - bitfield: Vector of booleans indicating participation (true = participated)
    ///
    /// # Returns:
    /// - Vector of PublicKeyWithPoP for all participating committee members
    ///
    /// # Process:
    /// 1. Initialize empty vector for participating keys
    /// 2. Iterate through bitfield
    /// 3. For each true bit, add corresponding public key to result
    fun get_participating_keys(
        committee: &SyncCommittee, bitfield: &vector<bool>
    ): vector<PublicKeyWithPoP> {
        let participating_keys = vector::empty<PublicKeyWithPoP>();
        let committee_keys = get_sync_committee_public_keys(committee);

        vector::zip_ref(
            committee_keys,
            bitfield,
            |public_keys, bit| {
                if (*bit) {
                    vector::push_back(&mut participating_keys, *public_keys);
                }
            }
        );
        participating_keys
    }

    /// Counts the number of participating sync committee members based on the provided bitfield.
    ///
    /// # Overview
    /// This function processes a bitfield representing committee member participation
    /// and returns the total count of participating members. The bitfield is a
    /// vector of booleans where true indicates participation.
    ///
    /// # Parameters:
    /// - bitfield: Vector of booleans indicating participation (true = participated)
    ///
    /// # Returns:
    /// - u64: The total count of participating committee members
    ///
    /// # Process:
    /// 1. Initialize counter to zero
    /// 2. Iterate through bitfield
    /// 3. Increment counter for each true value
    fun get_sync_commitee_participation_count(bitfield: vector<bool>): u64 {
        vector::foldr(
            bitfield,
            0,
            |bit, acc| {
                if (bit) {
                    acc + 1
                } else { acc }
            }
        )
    }

    /// Transfers the accumulated reward to the designated committee updater.
    ///
    /// # Access
    /// - Only callable by internal logic that can derive the Hypernova signer (requires SignerCap).
    ///
    /// # Parameters
    /// - commitee_updator: The address of the committee updater who should receive the reward.
    ///
    /// - Fetches the committee_updater_reward from the fee config.
    /// - Ensures the Hypernova core signer has a sufficient balance of SupraCoin.
    /// - Transfers the reward to the commitee_updator.
    ///
    /// # Errors
    /// - EHYPERNOVA_CORE_BALANCE_INSUFFICIENT: If the Hypernova signer does not have enough funds.
    ///
    /// - Sends SupraCoin to the committee updater as their reward for participation.

    fun process_committee_updater_reward(
        commitee_updator: address
    ) acquires LightClientState, SignerCap {
        let hypernova_signer = &create_hypernova_signer();
        let committee_updater_reward = get_committee_updater_reward();

        assert!(
            coin::balance<SupraCoin>(signer::address_of(hypernova_signer))
                >= committee_updater_reward,
            EHYPERNOVA_CORE_BALANCE_INSUFFICIENT
        );

        coin::transfer<SupraCoin>(
            hypernova_signer, commitee_updator, committee_updater_reward
        );
    }


    /// Creates and returns a signer for the verifier using its signer capability.
    fun create_hypernova_signer(): signer acquires SignerCap {
        let hypernova_resource_addr = generate_resource_address();
        let signer_cap = &borrow_global<SignerCap>(hypernova_resource_addr).signer_cap;
        account::create_signer_with_capability(signer_cap)
    }

    /// Computes the expected current slot for the light client.
    ///
    /// This function calculates the expected current slot based on the elapsed time
    /// since the genesis time of the client's chain configuration. The time is divided
    /// by a fixed interval (12 seconds) to determine the slot number. It assumes that
    /// a new slot occurs every 12 seconds from the genesis time.
    fun expected_current_slot(): u64 {
        // current timestamp in seconds
        let current_time = timestamp::now_seconds();
        assert!(GENESIS_TIMESTAMP_SECONDS < current_time, EINVALID_GENESIS_TIMESTAMP);
        // time elapsed since genesis
        // lapsed time to slot number (12 seconds per slot)
        (current_time - GENESIS_TIMESTAMP_SECONDS)
            / SLOT_DURATION_SECONDS
    }

    /// Verifies the signature of a sync committee for a given block header.
    ///
    /// # Overview
    /// This function validates a sync committee's multi-signature for an attested block header.
    /// It performs BLS signature verification using the aggregated public keys of participating
    /// committee members.
    ///
    /// # Parameters:
    /// - client: Reference to the LightClientState containing chain configuration
    /// - pks: Vector of PublicKeyWithPoP for participating committee members
    /// - attested_block_header: The block header being attested
    /// - signature: The sync committee's aggregated signature
    /// - signature_slot: The slot number when the signature was created
    ///
    /// # Returns:
    /// - bool: true if signature is valid, false otherwise
    ///
    /// # Process:
    /// 1. Calculate header root hash
    /// 2. Derive signing root using header root and signature slot
    /// 3. Convert signature bytes to BLS signature
    /// 4. Aggregate public keys
    /// 5. Verify multi-signature
    fun verify_sync_committee_signature(
        client: &mut LightClientState,
        pks: vector<PublicKeyWithPoP>,
        attested_block_header: &BeaconBlockHeader,
        signature: &vector<u8>,
        signature_slot: u64
    ): bool {
        let header_root = hash_tree_root_beacon_block_header(attested_block_header);
        let signing_root = derive_committee_sign_root(
            client, header_root, signature_slot
        );
        // convert signature bytes to BLS signature
        let bls_signature = bls12381::aggr_or_multi_signature_from_bytes(*signature);
        let aggregated_pubkeys = bls12381::aggregate_pubkeys(pks);
        // verify multi-signature
        bls12381::verify_multisignature(
            &bls_signature, &aggregated_pubkeys, signing_root
        )
    }

    /// Computes the hash tree root for a list of public keys with Proof of Possession.
    ///
    /// # Overview
    /// This function processes a list of public keys with PoP and computes their
    /// hash tree root representation, which is used in Merkle proofs for sync committee
    /// validation.
    fun public_keys_hash_tree_root(
        public_keys: &mut vector<PublicKeyWithPoP>
    ): vector<vector<u8>> {
        let hash_tree_roots = vector::empty<vector<u8>>();
        vector::for_each_ref(
            public_keys,
            |public_key| {
                let key_bytes = public_key_with_pop_to_bytes(public_key);
                let key_root = hash_tree_root_public_key(key_bytes);
                vector::push_back(&mut hash_tree_roots, key_root)
            }
        );

        hash_tree_roots
    }

    /// Derives the committee signing root for a given block header and slot.
    ///
    /// # Overview
    /// This function computes the signing root used to verify sync committee signatures.
    /// It combines the block header with domain information to create a unique signing context.
    ///
    /// # Parameters:
    /// - client: Reference to LightClientState containing chain configuration
    /// - header: Block header bytes to sign
    /// - _slot: Slot number (currently unused)
    ///
    /// # Returns:
    /// - Vector of bytes representing the signing root
    ///
    /// # Process:
    /// 1. Get genesis block root hash
    /// 2. Define sync committee domain type (0x07000000)
    /// 3. Get current fork version
    /// 4. Derive domain from type, version, and genesis root
    /// 5. Compute signing root using header and domain
    fun derive_committee_sign_root(
        client: &mut LightClientState, header: vector<u8>, _slot: u64
    ): vector<u8> {
        let fork_version = get_fork_version(client.verifier_config.protocol_fork_versions);
        derive_signing_root(header, derive_domain(fork_version))
    }

    // Computes the domain for sync committee message signing.
    ///
    /// # Overview
    /// This function creates a domain identifier that combines:
    /// - Domain type (sync committee)
    /// - Fork version
    /// - Genesis block root
    ///
    /// # Parameters:
    /// - fork_version: Current fork version bytes
    ///
    /// # Returns:
    /// - 32-byte domain identifier
    ///
    /// # Process:
    /// 1. Compute fork data root from version and genesis root
    /// 2. Combine domain type with first 28 bytes of fork data root
    fun derive_domain(
        fork_version: vector<u8>
    ): vector<u8> {
        let fork_data_root = compute_fork_data_root(fork_version, &GENESIS_BLOCK_ROOT);
        let domain = DOMAIN_TYPE;
        let fork_data_slice = vector::slice(&fork_data_root, 0, DOMAIN_FORK_DATA_SIZE);
        vector::append(&mut domain, fork_data_slice);
        domain
    }

    /// Derives the signing root for an object using its root and domain.
    ///
    /// # Overview
    /// This function creates a unique signing context by combining an object's
    /// Merkle root with its signing domain.
    ///
    /// # Parameters:
    /// - object_root: Merkle root of the object being signed
    /// - domain: Signing domain bytes
    ///
    /// # Returns:
    /// - Vector of bytes representing the signing root
    ///
    /// # Process:
    /// 1. Construct signing data structure
    /// 2. Compute hash tree root of signing data
    fun derive_signing_root(object_root: vector<u8>, domain: vector<u8>): vector<u8> {
        let signing_data = construct_signing_data(object_root, domain);
        hash_tree_root_signing_data(&signing_data)
    }

    // === View Functions ===

    #[view]
    /// Checks if the Hypernova Core is currently paused.
    ///
    /// This function reads the LightClientState to determine whether Hypernova Core operations are paused.
    ///
    /// Returns:
    /// - true if the Hypernova Core is paused.
    /// - false otherwise.
    public fun is_hypernova_paused(): bool acquires LightClientState {
        borrow_global<LightClientState>(@hypernova_core).is_paused
    }

    #[view]
    /// Retrieves the source chain ID from the configuration.
    public fun get_source_chain_id(): u64 acquires LightClientState {
        get_verifier_config().source_chain_id
    }

    #[view]
    /// Retrieves the source event signature hash from the configuration.
    public fun get_source_event_signature_hash(): vector<u8> acquires LightClientState {
        get_verifier_config().source_event_signature_hash
    }


    #[view]
    /// Retrieves the list of protocol_fork_versions in the chain.
    public fun get_forks(): ForksView acquires LightClientState {
        let protocol_fork_versions = get_verifier_config().protocol_fork_versions;
        let (epochs, versions) = (vector::empty(), vector::empty());

        vector::for_each_ref(
            &protocol_fork_versions,
            |fork| {
                vector::push_back(&mut epochs, get_epoch(fork));
                vector::push_back(&mut versions, *get_version(fork))
            }
        );
        ForksView { epochs, versions }
    }

    #[view]
    /// Retrieves the Hypernova core address.
    public fun get_source_hypernova_core_address(): vector<u8> acquires LightClientState {
        get_verifier_config().source_hypernova_contract_address
    }

    #[view]
    /// Retrieves the Admin Address of Token Bridge
    ///
    /// Returns:
    ///  - Address of Token Bridge admin.
    public fun get_admin_address(): address acquires LightClientState {
        get_verifier_config().admin_address
    }

    #[view]
    /// Generates the resource address for the verifier contract.
    /// This address is used to store and manage verifier resources and fees.
    public fun generate_resource_address(): address {
        account::create_resource_address(&@hypernova_core, HYPERNOVA_SEED)
    }

    #[view]
    /// Retrieves the sync committee threshold value.
    public fun get_sync_committee_threshold(): u64 acquires LightClientState {
        get_verifier_config().sync_committee_threshold
    }

    #[view]
    /// Returns the latest slot at which the LightClientState was updated.
    public fun get_update_slot(): u64 acquires LightClientState {
        borrow_global<LightClientState>(@hypernova_core).light_client_store.last_update_slot
    }

    #[view]
    /// Retrieves the get_fee_per_verification
    ///
    /// Returns:
    ///  - get_fee_per_verification
    public fun get_fee_per_verification(): u64 acquires LightClientState {
        let hypernova_config =
            &borrow_global<LightClientState>(@hypernova_core).hn_fee_config;
        assert!(option::is_some(hypernova_config), EHYPERNOVA_CONFIG_NOT_SET);
        option::borrow(hypernova_config).verification_fee
    }

    #[view]
    /// Retrieves the public keys of the current sync committee.
    public fun get_current_sync_committee_public_keys(): vector<vector<u8>> acquires LightClientState {
        let sync_commitee =
            borrow_global<LightClientState>(@hypernova_core).light_client_store.current_sync_committee;
        let vec_pop = get_sync_committee_public_keys(&sync_commitee);
        let vec_pop_bytes = vector::empty<vector<u8>>();

        vector::for_each_ref(
            vec_pop,
            |pk_pop| {
                vector::push_back(
                    &mut vec_pop_bytes,
                    public_key_with_pop_to_bytes(pk_pop)
                )
            }
        );

        vec_pop_bytes
    }

    #[view]
    /// Retrieves the aggregated public key of the current sync committee.
    public fun get_current_sync_committee_aggregate_public_key(): vector<u8> acquires LightClientState {
        let sync_commitee =
            borrow_global<LightClientState>(@hypernova_core).light_client_store.current_sync_committee;
        let aggr_pk = get_aggregate_public_key(&sync_commitee);
        public_key_to_bytes(aggr_pk)
    }

    #[view]
    /// Retrieves the committee updater reward
    ///
    /// Returns:
    ///  - committee updater reward
    public fun get_committee_updater_reward(): u64 acquires LightClientState {
        let f = &borrow_global<LightClientState>(@hypernova_core).hn_fee_config;
        assert!(option::is_some(f), ECOMMITTEE_UPDATER_REWARD_NOT_SET);
        option::borrow(f).committee_updater_reward
    }

    #[view]
    /// Retrieves the public keys of the next sync committee if available.
    public fun get_next_sync_committee_public_keys(): Option<vector<vector<u8>>> acquires LightClientState {
        let sync_commitee =
            borrow_global<LightClientState>(@hypernova_core).light_client_store.next_sync_committee;

        if (option::is_none(&sync_commitee)) {
            return none()
        };

        let vec_pop = get_sync_committee_public_keys(
            &option::extract(&mut sync_commitee)
        );

        let vec_pop_bytes = vector::empty();
        vector::for_each_ref(
            vec_pop,
            |pk_pop| {
                vector::push_back(
                    &mut vec_pop_bytes,
                    public_key_with_pop_to_bytes(pk_pop)
                )
            }
        );

        some(vec_pop_bytes)
    }

    #[view]
    /// Retrieves the aggregated public key of the next sync committee if available.
    public fun get_next_sync_committee_aggregate_public_key(): Option<vector<u8>> acquires LightClientState {
        let sync_commitee = borrow_global<LightClientState>(@hypernova_core).light_client_store.next_sync_committee;

        option::map(
            sync_commitee,
            |ele| {
                let aggr_pk = get_aggregate_public_key(&ele);
                public_key_to_bytes(aggr_pk)
            }
        )
    }

    #[view]
    /// Retrieves the current state of the LightClientState, including sync committee details.
    ///
    /// Returns a tuple with the following elements:
    /// 1. u64 : The latest update slot.
    /// 2. vector<vector<u8>> : Current sync committee public keys.
    /// 3. vector<u8> : Current sync committee aggregate public key.
    /// 4. Option<vector<vector<u8>>> : Next sync committee public keys (if known).
    /// 5. Option<vector<u8>> : Next sync committee aggregate public key (if known).
    public fun get_light_client_store(): LightClientView acquires LightClientState {
        LightClientView {
            update_slot: get_update_slot(),
            current_sync_committee_pubkeys: get_current_sync_committee_public_keys(),
            current_sync_committee_aggregate_pubkey: get_current_sync_committee_aggregate_public_key(),
            next_sync_committee_pubkeys: get_next_sync_committee_public_keys(),
            next_sync_committee_aggregate_pubkey: get_next_sync_committee_aggregate_public_key(),
        }
    }

    #[view]
    /// Returns the total amount of fees collected so far.
    /// This represents the accumulated fees from all verification operations.
    ///
    public fun get_total_balance(): u64 {
        coin::balance<SupraCoin>(generate_resource_address())
    }

    //==== Test_only Functions ===
    #[test_only]
    use hypernova_core::helpers::pad_left;
    #[test_only]
    use supra_framework::timestamp::{
        update_global_time_for_test_secs,
        set_time_has_started_for_testing
    };
    #[test_only]
    use supra_framework::supra_coin;
    #[test_only]
    use supra_framework::coin::{BurnCapability, MintCapability};


    #[test_only]
    public fun test_process_light_client_safe_update(
        update: &LightClientUpdate,
        target_slot: u64,
        min_safety_level_external: u8
    ) acquires LightClientState {
        process_light_client_safe_update(update, target_slot, min_safety_level_external);
    }


    #[test_only]
    public fun test_only_init_module(account: &signer) {
        init_module(account)
    }

    #[test_only]
    public fun is_initializer_scratch_space(account: address): bool {
        exists<InitializerScratchSpace>(account)
    }


    #[test_only]
    public fun test_get_light_client_view(lv: LightClientView): (
        u64, vector<vector<u8>>, vector<u8>, Option<vector<vector<u8>>>, Option<vector<u8>>
    ) {
        (
            lv.update_slot,
            lv.current_sync_committee_pubkeys,
            lv.current_sync_committee_aggregate_pubkey,
            lv.next_sync_committee_pubkeys,
            lv.next_sync_committee_aggregate_pubkey
        )
    }

    #[test_only]
    public fun test_only_initialize_light_client_store(
        account: &signer,
        // lightclient_state
        slot: u64,
        proposer_index: u64,
        parent_root: vector<u8>,
        state_root: vector<u8>,
        body_root: vector<u8>,
        // SyncCommittee
        cureent_sync_public_keys: vector<vector<u8>>,
        aggregate_public_key: vector<u8>,
        current_sync_committee_branch: vector<vector<u8>>,
        // state: Option<LightClientState>,
        source_chain_id: u64,
        epochs: vector<u64>,
        versions: vector<vector<u8>>,
        source_hypernova_contract_address: vector<u8>, //@notice: relayer change pass 32 bytes
        sync_committee_threshold: u64,
        source_event_signature_hash: vector<u8>
    ) acquires InitializerScratchSpace, LightClientState {
        initialize_light_client_store(
            account,
            slot,
            proposer_index,
            parent_root,
            state_root,
            body_root,
            cureent_sync_public_keys,
            aggregate_public_key,
            current_sync_committee_branch,
            source_chain_id,
            epochs,
            versions,
            source_hypernova_contract_address,
            sync_committee_threshold,
            source_event_signature_hash
        );
        initialize_step();
        initialize_step();
        add_or_update_hypernova_config(account, 155500, 1000, 1000, 10);
    }

    #[test_only]
    public fun get_sync_commitee(): (vector<vector<u8>>, vector<u8>, vector<vector<u8>>) {
        let public_keys = vector[
            x"8f6da3598f875ac6eab33616ac0780286a1082e15ce3d87efa621be9bbe5ebc0da47fef2ed9edcfd435181d84b1662e3", x"a639587654e9363590ddda70a97a3ec746652eb1463925f5ec3bd31f831e83db6fccc6b466ba4b9f100aa6be958ed0aa", x"a58219e63b7a11891889c342fc5a6bfaf73e3a99699479bc1885ea560078d8180696d0831cd682faeba1f6b355c7c7b2", x"af17532b35bcb373ce1deebce1c84abe34f88a412082b97795b0c73570cb6b88ea4ba52e7f5eb5ca181277cdba7a2d6d", x"990ea2b09cddb2d2859a1c54e403b8dcec16505f6117afc8957aaf73d08b7c86f822f0db037b634d9614cf90a69bfc4b", x"97578474be98726192cb0eac3cb9195a54c7315e9c619d5c44c56b3f98671636c383416f73605d4ea7ca9fbeff8dd699", x"8f8daead3a740fe48dfc88b40737b81371abe6b7f53cf270d6993ac1cc913fce684a23d93afe644d59e7faa7634994dd", x"a5b3da08aad945effdb645c797a0a8bfa828c9d658df2783a214597acebda3ffc07ee48d0ce1147d77540b557d9ada91", x"81564bee5a3bd09476f658cf7719326c353485e2f4fea58d110071c5dddd3cabc349a8d1ecea45d589ed4479952a2ba2", x"8154f81d5bcab563895b68e0b3b26bee1019bfa16792c57a732e94fe6486425e661e822ec61437648bbbe6d8ee0e9a52", x"9131874b09aa95ba186bcaa9e040fabc811b9c7b905b7dc79e902cf2bb5816d7ee39b0b55be609f22bc8c538760b2037", x"b586e67ae1826a1cdd651ac785e4b38f8a0e042f103a9b7dbb0035626d5dec3ded04a4e2cc09e63b4b01aebe304e40d7", x"95aafa379cc6a2b4bdd0cad30b7f0a47839952af41f584219ec201c6c4d54610eb2c04b67b29080acb8cecc5e7543fbc", x"83a9cd621beecac8baebf7df4f7ee17bf4b70aac31df816ec3efb5cfef2dc5c0bf959c5227df3a7ef4c2b8d1e1b658a8", x"b2574396e4360c971ebd71aa7e50d1683bd899fb1f404497c2a97129ea9d7e0a2642dfa8e0bd232ffb6ca443dd7a9683", x"ac9ead4333cffa49ee925bdc47e2c1a0ca9d1a07239d107a2a8a2b0471fd9d4626ce44bf001d73975828237723de065d", x"919c81bd1f3d9918e121e4793690f9ddd96c925ae928536322d4b98132f21979c1f34731d393f0ae6e0871af4355a8ad", x"a356e5b70bc478c625e32a38d29f0a619fdeb665503eedc304d1bf34562d4b6814dfc30aee5aee94ca4bc6394e412765", x"a3ba4cc5da2a7c2fbc9b35d212c3ed130347e8edf67ddafe0536526930a57e3feec6a923641b9a9a0afe2d55a9c4d525", x"864d5d9858cd881eecb0dde5e3e0c6c5de623cd9ef619e87b82fd25c5edf45a1a025b1dc763c27c5f4d520fd564b464a", x"a59249e4dfb674dfdc648ae00b4226f85f8374076ecfccb43dfde2b9b299bb880943181e8b908ddeba2411843e288085", x"904d722d7ec51a476a852428d9a246a5ca3be87ae2281e2716e999f82cb9d8d75ade0929ad80c186ada55f839a78f57c", x"890def696fc04bbb9e9ed87a2a4965b896a9ae127bc0e1cc515549b88ddbcbc02647e983561cab691f7d25cf7c7eb254", x"a8c167b93023b60e2050e704fcaca8951df180b2ae17bfb6af464533395ece7ed9d9ec200fd08b27b6f04dafa3a7a0bd", x"b8d68610fdee190ec5a1f4be4c4f750b00ad78d3e9c96b576c6913eab9e7a81e1d6d6a675ee3c6efac5d02ed4b3c093a", x"84faf4d90edaa6cc837e5e04dc67761084ae24e410345f21923327c9cb5494ffa51b504c89bee168c11250edbdcbe194", x"a6d7e65bf9f889532090ae4f9067bb63f15b21f05f22c2540ff1bb5b0b5d98f205e150b1b1690e9aa13d0dee37222143", x"ab33c65587ecb3278325948c706aed26547e47ed2b4bc027e9119bb37bec67ddf5489fbc30304ef6c80699c10662d392", x"b46f481155df4c4d576e5d76f1d4054e1129cc49398533ed32d0f681701276cecad4759e47b818f20d6a087989449529", x"a9f261d19934fd26458421551e91f484d7a1522a7e7adbfb28f6371102a7650a5ae6efd49d9e33b03aefde647d134ce6", x"a3680e085b257d11e89f682db42c5693669c3e895d300be471917cbc051e9da36901263dac4b0c7e9047b35dbc8eae4c", x"a19e7db50604f6b82cc28bc97135025459c8eac107a1c482919df10b8be2e4f24fceb93b963c0b8ac9f402e2f6ebf387", x"ac79f5491dbbd0eb47669225e781f94b98d04947cbc55baf287365831c100248bd0b39c911ac09b518715ba1ef0602f3", x"9604da21e23c994a0a875ad5e0d279c79210f7a7de5c9699fac4aebbd76d39b703eeec5dd5efc9ad6b9dc58936089ddc", x"8853c582e86cf916750d670a621246a63c7fd78f68c556642053bcdfa7937de58885d728209736b7d5521b591387e9a7", x"8154f81d5bcab563895b68e0b3b26bee1019bfa16792c57a732e94fe6486425e661e822ec61437648bbbe6d8ee0e9a52", x"ad8e8e3b82f5b8c1a39efe704b0d1eddb6e2275a990aaccad0c509f3109e42ac49aeea6c2f6da02d2d0af6cfbe5598bc", x"85ee86a9de26a913148a5ced096ba46ee131d2975f991d6efcb3fec62975b01a1d429fc85d182f0d2af72d1adf5bfd2b", x"997f2b2bc0b67fba72980631b2f739196b503923d42347ae57659bb455801b6763ed4032fe59837a5abb475e4cfc79fe", x"b0ad3c61be779023290256142d6b30200b68ff41f5405757b1a1c634b4d6bafbdcbd31a1f9d2866f111d8601d6dcae35", x"b552707ec0d9124dc71f0076e56ca63878473c953663b1b8952e828ea0bd0945f2f410a72d413e9efdf536b4c9e280dd", x"887c837e3e30354a0c3f9ebe0e555406400dd882acf9b360fa848773f2f637b6586a84b4884d01e5ca3e896b89a5e331", x"949b8b056e465813496fbdd71929cfb506b75a7aca779002c437745f651527387afb84bfaacdd0c2501893a7209b4a5f", x"b6323818d163938314b407892be8decd9a84631bb7cb5c35c6766b11f531078c699779d890787cbd5ef868b21e7fca4e", x"8ba7b12d2aa2786e50a6e6fb96f8205ed32b245e363f883ec51047e30c5eccaedba701d84c2ccfb1e2988ea76d2f43c8", x"8a99b6193bd225e9b9b1f8dd668e2a69fe0c5284766d622784fec2bd74e65bb059706de24dfb2fc222568b663ee05c90", x"9579973ee2559da09b327c62b1cc0177f2859872885dca709e24dcfbb9bdf9224a6d26869aafce498f44c0e6bd8a996c", x"880b4ef2b278e1b2cccf36a3b5b7fbce94f106ed9fa2820cb9099a7a540a57e9fdeef5c0fb0a743049828fc2b8c46163", x"a485a082dee2987e528d1897dfc5ee99c8de9cdc0c955fc38c404c16c35b71bccd08770c93102110547381a2eb9d3782", x"96e7d1bbd42195360267c2a324b4d9bccad3231ed8a7f070278472a90371867e2ef2c29c9979a1ec6e194893afd992df", x"a308ed8737b3a9346ff20dc9f112efccc193472e6fde6aa218ceae11e288bbd2c35fa45c1d8bb238696a96767cd68b46", x"908d762396519ce3c409551b3b5915033cdfe521a586d5c17f49c1d2faa6cb59fa51e1fb74f200487bea87a1d6f37477", x"ad83b3c5e9a08161950b1df9261d332dda2602cc68e0f5ee75bfa7e03bbef9edfb4945ca1f139df1bcb8affe8ae025da", x"86ca8ed7c475d33455fae4242b05b1b3576e6ec05ac512ca7d3f9c8d44376e909c734c25cd0e33f0f6b4857d40452024", x"b4ef65b4c71fa20cd0ed863f43f6c652d4c35f2677bc2083f5a9808284e8bd8988703faaf0fb4cac8ecbda19541ecc65", x"a2538a9a793889d6bd6b4c5b0e874389494dfeba824eaf43b34ddbb311086e86912257e634fb5171f0164937c5632547", x"a718ac1dd2b3c49f077364b60815761bacd6ef59e364bdd5d6bef8fce970123ea21f676686e30c4256a3782fbd352452", x"893272a63650b08e5b8f9b3f17f8547b456192ad649c168bafd7166b4c08c5adf795c508b88fd2425f7be8334592afb2", x"8275eb1a7356f403d4e67a5a70d49e0e1ad13f368ab12527f8a84e71944f71dd0d725352157dbf09732160ec99f7b3b0", x"861b710d5ec8ce873e921655a2ca877429e34d432643f65d50e8b2669929be40a9ce11c6353b0ada1fe115e45396b2b7", x"b6e57034ed025ebb5e677911b47ad51fa2cdfa4de4caa158ae5727d33c94c27b5ffa63dffe2219fd17ea26dc6169fee1", x"abf7da952c9d8f75fcc67fa7969fac0b26d4dc3e022961ed674ce85d734f11620a950fb1fb0ef830fba1d8b5bc3eced4", x"85e8259980319bc750607f5004aa83f7d7eaf20eeb164fe3db13864e3d31e1f53ea42dd6d9b30ce710089f193c895d51", x"86bba46d0031989d0f1baccea4174fc3fa0d595e60d35a464e86c33c233e2d6def84fced7a00f59afe397cf4fb5b67c5", x"90aa5ea4327b4d46c562117b9b86d3c695eb458ff74bae8f04e0b1f739b14571a0a9734ea23081b02a8a380891ff4978", x"942a12ba2f7b8708afb97e8ecba8f4ce66df1f862ceb86b3452f9b80eff581ee729f0f3122c6234075c6970270e2c367", x"aa1d80401eca29d9e122ae44f95e0e1d2e49571ab4347843034b0e17e5f16f821ba925ed1316e4d5e18654882a647bf6", x"85b7ac279df87035b63aea300f6c751b84d299a78788123aba08ba26edc6f8c7352baac4f471d6f4bb6c45428e661249", x"8aee7bc01a8a1540858c09a4141532dc759ae45c402ffc5a07eca298dd63c4c097d09c253469bb818d13f0602a84af87", x"9104b5af82dbca914370eadb5518b26bee7ed7edeca74b741585ba8b249204e2c998bd47a02cef4335e236f8efafef94", x"a131f61a215d689938b1997ec40357b939bd2a2565df04cea7800674e23ba068d0ce28bad32f49f3099434f34445eb4a", x"b7e18647b9d147a620b4905caf4a535a5b98e6ff0de5cc95a7dbe9c32bf1ac195a788baf9f51a6d7d0d2233d75af6e85", x"824d0dc002e158adef06fc38d79b01553be5a3903566029cf0beddb2248b11da40e66feb168e8e3e2a63ea033a75f382", x"b586e67ae1826a1cdd651ac785e4b38f8a0e042f103a9b7dbb0035626d5dec3ded04a4e2cc09e63b4b01aebe304e40d7", x"824c8a1399ab199498f84e4baa49ff2c905cf94d6ac176e27ec5e2c7985140dbaa9cc6303d906a07ab5d8e19adf25d8a", x"87587504e819bc7f0349705a05c15e8504fd6b2c25c3fd264096cdb7aaa22d8078da776215925d9d775a7f9355b6f0c0", x"b0ad3c61be779023290256142d6b30200b68ff41f5405757b1a1c634b4d6bafbdcbd31a1f9d2866f111d8601d6dcae35", x"b7efcb232d3b639921ce21e80744c293ea77e25982b609e8cc82bd3999a734ca04ca43f41d9c7c15d162e0bbc3152495", x"a5fe3dfb5031517bb8db0d5ade1e9f438e84bcf23221de003b03d2a2f4ea97629e81c79abc3769bdb8c69a512c189b91", x"87fec026beda4217b0a2014a2e86f5920e6113b54ac79ab727da2666f57ff8a9bc3a21b327ad7e091a07720a30c507c9", x"b67c621d9b6313a9f6744dfcdd77d4e9cb4bd413fb5e3199cdcd7f675fc39f1ba492860749bfddf98f4088756e844a98", x"a61687511b627bde7b3977e9a34cb7fddc2aaa509a7b99b6b6c7b97133845c721e1e69f99758698d82cca265d8703610", x"92f0bf3257e775c5c469cd9a43249421c9fd223996aeda09654045b885a512e86bd834b2947aef216b4d9dd5f8f2e9aa", x"b471c72bd2971353f4b44248b8e6cf5316812861a88ccfc20fd0d89a5e010428c387228b2f6f14c12f79e31afc9d0753", x"b4f4ed1bd274a852189719a8808a8f214c8386e844ca9ba13161b75d04c74633b1d8a758ce0b23ccbce8052494c81c3f", x"938bbaa0ba14597067ff4c0a7cfc1529c44160d6f61cfad12246526d84fb7a1ba964d3bbb065a348cf7a98356ee15234", x"a97b80bf780fba51a5863e620317812418204d3d5a1001710aa0cca383cb40855d9da0ddfdd40e1d2e9336a4543ca1ad", x"b504cb87a024fd71b7ee7bed2833115567461d1ae8902cccd26809005c4a56078617ec5d3fa5b29a1c5954adc3867a26", x"825aca3d3dfa1d0b914e59fc3eeab6afcc5dc7e30fccd4879c592da4ea9a4e8a7a1057fc5b3faab12086e587126aa443", x"a8fd63da16dd6a4aa1532568058d7f12831698134049c156a2d20264df6539318f65ec1e1a733e0f03a9845076bb8df8", x"8e486e604ff5035ba3468464c9f7d88bf64c86efb739d76931d1e5a1005b28889f7c92fa63141c2d543c3e9130a75aa9", x"948dcd311147fcb8b28044e66d51d082e921db4183cf3fc42ae46becb9a12e7cc5c32c27d12f6d40d7d73a74f6bb6615", x"815f9906177910288cf1d8db5f8b496f662e5da6db4d719c628f128256df976e5044f816986bd6646ecc95d79054885e", x"ac6e7e9960207138d5b4b6a7f061756c01cc4a830e5988423d344f23544ed0eaa790aed63a22df375768f670cc9b9bd4", x"89019e9550648962420984e9fd03597a854ae824567d9aa6cd5db01a4616b4e1477230f2d1362a2d307e2425a3eeb898", x"87144976cb0d55de66f612725c6d89ab35a5222e8b003329b898e732629f5b7022a7223c9cc9ec820d3d1553e7b2267e", x"a9b0a06469c7746a0a23c459a2fe75dd474e2cb1e9806afe872febf054e6f13c2c183761ccb890c6bb4d87abe597de1e", x"8eaaa21c8955f15bbcfd5756421a045e7b4825576379cc6229fe9751f7a7738b90be19ba52261db01c1e13af955675b0", x"a42c46a7e617d78b12053d7783f0d175fd9103db06d0c6982b38893a20b72fd8ad8501eacb3d47be06fd7c3ad89a8159", x"a278bea51af1de8bbd2319f3a37ab14abc3bc0289ed31aae44f38897a7b24263a4dde1cb037e1441217bec0ddcf47266", x"a5a1f7d42220d3740b3f353de74469fbd3a75ceccb3c84d0a87e43444855be0c51116a32a56cb1980294724d36bdda16", x"ae36ab11be96f8c8fcfd75382bb7f4727511596bc08c25814d22f2b894952489d08396b458f7884d6b3c0adb69856a6d", x"b8a0003e949cf994b1bb25e270cb61358200c93b1c6f611a041cf8536e2e0de59342453c5a8d13c6d4cc95ed8ce058f3", x"aefedb8ede3080a73a6921ec5b817cd9e867a510c0f7bcae47c860797faab809420f761d78b216a1eb88835b6587fa10", x"b87a03970caa520f0026a0320c6c687dd50c22a7a59cca13275852c3c78e77f3c381ba23fc92d36b262c6e8544f7c8dd", x"9545f94c4e9056e360dd999985f8ad06210556fa6f07cff77136a2460605afb0ff1fb1d1a2abe4a4e319fd6c29fff80f", x"a41cf5d678a007044005d62f5368b55958b733e3fdde302ba699842b1c4ecc000036eda22174a8e0c6d3e7ef93663659", x"85292ad11beb20440425adfd23634ba34fb46dbf5e07bd216918a4a1e1d9ff49bbbe56f81e0aaa16bfd67d439e787306", x"908d762396519ce3c409551b3b5915033cdfe521a586d5c17f49c1d2faa6cb59fa51e1fb74f200487bea87a1d6f37477", x"a0b8e0ef0756255edd80938c4e555a3d992953cd43371915d7a7280dc1bd8433933382919d50a98faad918fc9083bc07", x"8eadfc31f2b305df9ce088a43c67f54df12a06aa19d453fbd9b9d8be50a438d8d74d8972504d646c8c09249adccfee3e", x"8553748da4e0b695967e843277d0f6efeb8ba24b44aa9fa3230f4b731caec6ed5e87d3a2fcd31d8ee206e2e4414d6cf4", x"85b63dd33e2cc178cfd55d67509717c3d8b81a40d6be468eb5579e4a1dee3d0be1a5f93c90e2f0cdd012efdffa7d9235", x"a8c167b93023b60e2050e704fcaca8951df180b2ae17bfb6af464533395ece7ed9d9ec200fd08b27b6f04dafa3a7a0bd", x"b3bd2fedbca3e0185bd4920bc0b9279da7d7031e39df2886a4c969b28df97181ad37ca4bab2b79f44d7bc4acb32b14ab", x"acdaa6263cb7ffa0fa159983888348fef7f0514abd4d897884bb6eaeb57c68e61044047215ccb0f32face09b0a72ea3b", x"b455f751232de0a48440d09983f4f4718b6169907979c9f282acf7177ab5b1f338fe1f2acd8d0bee4b4aad61d0340839", x"a42bcc5012a8b87caac4ec279f8cf7e43f88e36b65c321a835fd8a5ba427a635de79b93d2460f5e15258f09d8d51c7ce", x"95c810431c8d4af4aa2b889f9ab3d87892c65a3df793f2bfd35df5cfdb604ca0129010fa9f8acae594700bece707d67f", x"9366d86243f9d53bdd15d4cd6bf5dd348c2b89012c633b73a35d42fa08950073158ca0a1cfc32d64f56692c2374a020f", x"916391f70e2d543b0e69d1e8c5a1c0b754d2191497b96ceeec47b37bd6d97a5a21f8cc8d11435147f5a5eff85f3b3270", x"90bfbe37ac3992432e68c95c0d4342a9712126d1f50089239c9f4f6c0c202b54334e08604d245b97dc8e8f6706f6992c", x"8d4263e8a208ea0a6798e0cf956ca01d650a6e23a1beca11ed82f04db598546713dc716ec8ed81eaa8ffa48924b5dea8", x"9542760a620d27a9856c490c8f0fadd90bbf06f539ad11339d2a6cfc0f262a798c8905ee407f53f718a72c1468d756f0", x"90a908b47d0c29a2d0e7e65a212d7e1788454062f46458c519c7f2ccd794ff21d4c24b91acf42a71a509aff6544f676a", x"b0a4c136fb93594913ffcebba98ee1cdf7bc60ad175af0bc2fb1afe7314524bbb85f620dd101e9af765588b7b4bf51d0", x"86b706c5d3c5aca72cb23ddfb6452bc70dd3b1a98c8539a7c32f760778b401cbe90ef86c12d0468892dbcbd9a268a38b", x"89ab1e5c2565f154f92c9b3554160832d176613f1a2f872b6ed62ed925a33fb0b40b71b7443eaaa15099ab24693c8d13", x"99deb1c0acbc0e773df4a98e68bfe89cd0240903fd0564c4cdef27f0c20417e4506c9e2b173a4a6c9e20e637f9387b5e", x"a0230bdf83cd469c7248074bec535eba8280cfde587d7c63d307149e9626bc7642b4bacc9beff2d8e8f6ea398dc0ade7", x"b34d4d2e15079e7e80fdba30cddf4fc0e6c9a61f7ab06a6ea0a4e55fd5bf632c6d72e021d6264d935439d321de883bb6", x"90f1d6745ed9a2fb2248d35de8cc48698f9e006dd540f690c04038ff3d22bd7f9c3979f6b3f955cb397542b3ef1c52dd", x"93fda62b785757b465e6f396f74674d5b95a08c938cf694e66beed7d2f317a4c9d736cb54d7c221d61e8cb3d64dca3ab", x"a3fd9d8bbdc98394883022299fd9793e0c4f374d8e40d6ce89b2869d3173cb6a5476371d6095dad068ff217729f60af4", x"a4154b14b45f0683bd79a00cf07566e43b1eac7c80809cef233c7ed62a5abf8287f4ef3686f7130f10b6123cc3578601", x"b382fa28670a5e14dc954b2db8ace250c73df71ab095304bd8ee28f455ab26cc54f82775a831428e110d1a3a2af709bb", x"93655457967d1f62c3574c4bd85688c92dbdf256f3629818f8c2d75fe12acacc57b6fe78632bb22d4ac7bc1861e59fcf", x"941c8962debd2756f92a6a0451a2bf7fbc01f32ed03d0823dffd4a61186628a4c3c7c482b18589ff65e4c449fa35c2a4", x"a19f2ce14e09ece5972fe5af1c1778b86d2ab6e825eccdb0ac368bb246cfe53433327abfe0c6fa00e0553863d0a8128e", x"a0ebae60a998907a19baa396ae5a82bfe6aa22cf71bfca4e1b4df7d297bd9367bbeb2463bda37aa852ad8fd51803e482", x"b9def7aa584fbfd49683b1652bb24794129170244da113bc7b4b59f5a47dd08e41ce4403b0d8c47b35acf283390fad99", x"b3d41dcf67bc7467dafe414b1dd5e78edf158bfad5dcbe64e33ffb6bec5063b1575d0bb8ef768e5904f718cab7daa8ec", x"8605b88ce23190b1fa9d389b15e6907417239a72b97673d1479c4ccb8f4515c7921d14537775c74e738a9c3f122b1443", x"a1359866783af9031d20ac64380daee86c8054a9af62e4d2100f87c5aeffd0ca48769560fb9a550675e6cd1e6382f32f", x"b900a55013d0427e5da6b21611d6ae3e648f54f794cb099b2d2beebae0a957477a94dc415e8ec5e68e9029ce50d43843", x"a520d49095f76a5bd9dea0bbc8b2d863bd694d958b0d986c6876c3cfe05c017fea2f08ec79abc429f98b7f7b41315be9", x"b65e8b290bdec2fda05cd1c09f8508f662aa46d7d19556d0a4e3244b4ec20093aa37088105ea4c2b1e5b245410241445", x"ad2aee9a61242235f0ef6adadd5d314b18e514083d6a589ca65cc89f505e44b480724d7659a87c95b03c62caba53f487", x"877a37caf56ef7cd5037118f797cde1caecf472fa6bca7b2718ea55715136a2672d494c07a237606c7e7430a96a945e8", x"8180ffffb5abe78c38f2a42a3b7f1a408a6d70d3f698d047d5f1eef3018068256110fcb9fb028c8bdccbc22c0a4c3a20", x"a34eba9a41f2307891af1825ed501b74278f67eaef4bc57cae5c0c46202c19fa0d9a5dd8b91325f6c151a0644762ef29", x"94f4720c194e7ea4232048b0af18b8a920fde7b82869e2abcc7e14a9906530be1ef61132884bb159df019e66d83a0315", x"b87e5f481b938ac8a481b775cc58be2a06604549e3c810fc4734bab76099e5c617f0243c4c140cb7dd6d36a6dc2286bf", x"8d474636a638e7b398566a39b3f939a314f1cf88e64d81db0f556ca60951ec1dca1b93e3906a6654ed9ba06f2c31d4ea", x"b9aed2648cd189e453bb9b3e8e2ad43b40efbac6e73ebdcc196fbe4f4e71b3306d1dc6ccc39ff71f11fac957ff3b9594", x"ac9ead4333cffa49ee925bdc47e2c1a0ca9d1a07239d107a2a8a2b0471fd9d4626ce44bf001d73975828237723de065d", x"a7555d66719916a2be7a7f0c8b7001aa2925bcb79723f78288f10831f9cec64923228b0e4b89dfd4342de8f70ce03cb4", x"ab6e3180dae399d41243f23545e5e6d118844f9b8edba502a3503fd1162ed826f9fc610889a1d685d374b6c21e86067d", x"a7d76c88daa3ba893d4bd023e039e1f587565d317609cc9ddce73f2d3c4d6d9facee20fca31c85322f10fdf15267fbec", x"8645cc44d180c18a6d8f57ba57bae05879451997533cfe558cad4d3d586caec877e348915e32a09ee73483283c4df744", x"a35ee5c2d7800489723c78008b495e1742f0542dbb487172ef438f60424c81aa41c2397095821248066140662133f6f4", x"a9ee291de5997232c68c9f6c3b568b05f46bfedfa18eb3776699d98cc7c6320003b7d862564d07fd28fc3691d1d28b21", x"b0d69b3861ca6791632ec8a87114b463e0da571bc076c22a8f0d9e88a1a5eaef24683f3efa8f34900d0112412e3dc4fa", x"b8454e8438641340b7fc8ac55b869abe54806f873ec0f2d8fc5425a1ba76ed8471425440621763b6e9d834b6e5451b98", x"809c7a08fbef7caf4c137cd639f2e47a8ca60d13bca3990eac51ac2a9e4442cd1a1473bebb63c61d595b586525d7b027", x"962e2c706de6e0894666a9a0233760421bbd8cb8066e4e38259554ec32e25d257c4a06b387f312238743a6e4ac42602b", x"8275eb1a7356f403d4e67a5a70d49e0e1ad13f368ab12527f8a84e71944f71dd0d725352157dbf09732160ec99f7b3b0", x"a4e2df74c8e7257e3df1e4f6a9ad4141c8299f43f02bcc53bfeeaa1698faecf81a4ad2be7f5ddbd1be657c87110ea34c", x"95718b06017ba9d45894867fd67148645d25d9db2229aa89971f444641ba9db4c5c6f0785f3b25cf2cd7fadaa6adc5eb", x"94d4a1e3a3d28a948f14d1507372701ac6fc884a4905405a63663e170831578a2719714ef56f920baa0ca27954823e39", x"873ef003ebb75508a3e50def6a37627161f40edf6835cb927814020623a6f92810d5e869f0884a0d2ab37a3a1edc8481", x"b0053550040ab3a3996cba5caf9ad5718867b5f5df273ed8c6520761571f03a94e50b5f8a6a8c42d725383cce97d3cae", x"aa0b0ef6abddbb4931fea8c194e50b47ff27ea8a290b5ef11227a6b15ae5eda11c4ab8c4f816d8929b8e7b13b0b96030", x"aa3808613bf87c06c62070a04e2efd58f8bbf5085378e7fb6071dd4fd560043b4f1c88ebff83af4d1f2810838b3fdc09", x"af96a83f97ed0696fd29e59daa24e1857e16371f67089d08129f9c236753ea68c93590dce4d32c9e9818a21014da6f0d", x"ac9f0b44105cf77ad721b97b0f04a37fddb2bb62c345b0d22a29e2870b8964d7484aad30e454c74608ce9901043501a5", x"8cf06b34e7021e9401eb705dde411ecf7e7e7185f8c0b0aeed949097df31812a9fdd4db7d18f9383a8a5a8d2d58fa176", x"952cf6782b0ad3e85625391cc5f486a16bb5b1f8ea20defcb6857bd7d068dcd2701bc7ed5c3b773a869180d9042f772b", x"b102107527690d9324e9f121aad6b01f15d70140ff3b54e88a6743af913e95df9756f46c88c2525b6468f79497e1903e", x"80d492fbdbe9d5fcd08fe962b3ce2b9c245c068f686c4838f57db5b4e8b1bfc729c98e93dd4e5cc78b661845d7459809", x"b397ed7134f447d9bf1c511bf92f2d27d7b6d425b8b411365fbef696cff95c2175461cf5dd83d93bb700e50ebb99b949", x"824d0dc002e158adef06fc38d79b01553be5a3903566029cf0beddb2248b11da40e66feb168e8e3e2a63ea033a75f382", x"8b6ed54668f78a4a7624683b9bf3abf2bb0b6dccffccd8c0967df6297dadaf51732800fb9832b069437a6bf82ed7e6ae", x"aeeedb3c73a9eadef14396a474ca83ca9e3885fd5f2c1018652360481d0be49524de22fc1ea18bb7abca66df5dc7d309", x"8ed7790f87f6975e0f3e501901b0bec1778c88bf39588989014c5dda76c2163732e7e5703c9cb2c1a6144ffdac5dcbab", x"94d3c9406dc6dd7241a726355643d706e46b35f1ffe4509ac43e97c64c07592821156ba02ec9a78978e66709995a0ac8", x"8d474636a638e7b398566a39b3f939a314f1cf88e64d81db0f556ca60951ec1dca1b93e3906a6654ed9ba06f2c31d4ea", x"aaeb0005d77e120ef764f1764967833cba61f2b30b0e9fed1d3f0c90b5ad6588646b8153bdf1d66707ac2e59fd4a2671", x"948a89e9404f0b97c8ff2ddb334cbc3316aa29a94403d79843a619110efdb4873f4588c8930e64bc562e9d19ea32cf5d", x"8df72e18449c871578601cf6bb8e0a5ecad7bc5fef4fd5838d49afb47f6bf3b241d709dbe5681ec881933a8c71d895f4", x"a020404547407be6d42856780a1b9cf46b5bc48122902880909bdcf45b204c083f3b03447c6e90d97fd241975566e9bf", x"8bfd6a173a56b73480cc950ef266a18933ecafc86915a7453ded09efd8a0cf4466101f1373f05d48eae3e7fc5c0f7f54", x"8414962d05eedffc19d7fab3aea967f5386ed62faa0f0b9b8aede8fbd5a94231aef645d3abeb345a2571c9295af60912", x"a2538a9a793889d6bd6b4c5b0e874389494dfeba824eaf43b34ddbb311086e86912257e634fb5171f0164937c5632547", x"903f569a8de771406b9fd36384f1fea20d5d79374b8d9af24b4814f96c44739193662aa47be857543fa101aa70ab205d", x"b549cef11bf7c8bcf4bb11e5cdf5a289fc4bf145826e96a446fb4c729a2c839a4d8d38629cc599eda7efa05f3cf3425b", x"ad9725114b01152fff134c1a8ccb8d171b8cd11685ef6815b76f442d757d130bab9ef4c9845e66f4aa0237ee2b525c20", x"b33de3de106be61481ccb7f07a7a63cf4d1674010e462388fb8ab5ea08f444ed7a277905207e0b3aa2f00bb9efca984f", x"a5c225b7bd946deb3e6df3197ce80d7448785a939e586413208227d5b8b4711dfd6518f091152d2da53bd4b905896f48", x"91c5e0b9146fe5403fcc309b8c0eede5933b0ab1de71ab02fac6614753caac5d1097369bdeed3a101f62bbcae258e927", x"96791b2b8066b155de0b57a2e4b814bc9b6b7c5a1db3d2475a2183b09f9dcd9c6f273e2b0c922a23d1cf049a6ce602a3", x"ac66f3a7041586ac1576e33598f01921e16d99afbf4249c3350f0ee1654de98bd37a61c243eb6a18a942db529e36af0d", x"b72de0187809aaea904652d81dcabd38295e7988e3b98d5279c1b6d097b05e35ca381d4e32083d2cf24ca73cc8289d2b", x"857159fcfc2fc884a4d4b3a527c63cb9d749581ffc80b1bb61076228fb14e8e7340649b0a4d1bb3e6c967bfc99b54cc8", x"93947508e60df6a0bd8b3fa24a72ef783c9fde1c3d94de0101c75e0e73d8003d9beedfdf9f40375613180d77815950dd", x"a42c46a7e617d78b12053d7783f0d175fd9103db06d0c6982b38893a20b72fd8ad8501eacb3d47be06fd7c3ad89a8159", x"b1289ab2fd3070ba49b0cebc9cdfff1e8241414af022ea58b7a59aa7fdb066fd060b299796bbc811dec1bee81507d788", x"acbb398ea9d782388c834cf7b3d95b9ff80ee2a8d072acae8f9979595910849e657889b994531c949d2601b3ce7b235d", x"b552707ec0d9124dc71f0076e56ca63878473c953663b1b8952e828ea0bd0945f2f410a72d413e9efdf536b4c9e280dd", x"86fa3d4b60e8282827115c50b1b49b29a371b52aa9c9b8f83cd5268b535859f86e1a60aade6bf4f52e234777bea30bda", x"b3ed0906d97f72f0fd5fe01cbd06b77d61c69f059f1e87a143a5630073ab69ef8876bc2a5e261d467a7f00f0050388d5", x"99deb1c0acbc0e773df4a98e68bfe89cd0240903fd0564c4cdef27f0c20417e4506c9e2b173a4a6c9e20e637f9387b5e", x"95c0a30943ef34ef0a644439d857446e1c1736e18360f3f41803b0ca118e79af3fb9c608ec440a8de0f79d2c245b583c", x"9615800f8c95f95bf25055ae079b964e0a64fa0176cc98da272662014f57e7cd2745929daf838df0094b9f54be18b415", x"ac3195143035cdb4ddcd5f93c150035d327addee5503ea2087b1a10b2f73b02453ddd1a94d8e7d883e365f9f0e3c38c9", x"b306bec1a3a64231530aecb8e62b75ddc63abf0193496cb8bf0c84ac8a1c018d4fe91aa1c65871e7e05b26b6a5ec61ad", x"98b41b67eeaaec5696bfb492efa84248c386c9267a259270f214bf71874f160718b9c6dd1a1770da60d53c774490de68", x"a90d9502a9785e55c199630456fcb1e794bbeb0f5f8c022e66f238a0789998b126cf9911fd0b7d463b7706dc6f9ec128", x"94bb68c8180496472262455fd6ab338697810825fa4e82fc673f3ac2dacfd29ee539ac0bfe97eb39d4ef118db875bab6", x"a020404547407be6d42856780a1b9cf46b5bc48122902880909bdcf45b204c083f3b03447c6e90d97fd241975566e9bf", x"847b58626f306ef2d785e3fe1b6515f98d9f72037eea0604d92e891a0219142fec485323bec4e93a4ee132af61026b80", x"b1809f9fa306d63c6cef586a74de6373fb2fac0cd10c5cffa6559cf1a16a99502c16c204f803139d4f2fba5161f90a6d", x"92a488068e1b70bf01e6e417f81e1dc3bcec71d51e7eabbc53b6736e8afdb8b67d191940fe09c55783be9210e1cbd73c", x"b80e8516598c59dddcf13fdb7a42d8f5a52c84e01bd6a39880f4acaefe8e4b8f09cc1b1a2423cd5121f4952201f20078", x"8aa3d9dad1c122b9aed75e3cc94b3a9dab160fa4cad92ebab68a58c0151a5d93f0f6b40b86fba00e63d45bd29a93b982", x"8fbc274c5882666da39e7ef636a89cf36725820c8ada6eec0ab9b5af3760524b73a2173c286e155c597b4ed717d879e4", x"a639587654e9363590ddda70a97a3ec746652eb1463925f5ec3bd31f831e83db6fccc6b466ba4b9f100aa6be958ed0aa", x"b77416ea9a6b819e63ae427057d5741788bd6301b02d180083c7aa662200f5ebed14a486efae63c3de81572fe0d92a9c", x"93e4c18896f3ebbbf3cdb5ca6b346e1a76bee6897f927f081d477993eefbc54bbdfaddc871a90d5e96bc445e1cfce24e", x"b576c49c2a7b7c3445bbf9ba8eac10e685cc3760d6819de43b7d1e20769772bcab9f557df96f28fd24409ac8c84d05c4", x"ad2cdae4ce412c92c6d0e6d7401639eecb9e31de949b5e6c09941aeafb89753a00ea1eb79fa70b54699acbfa31eda6b7", x"a6e48325fadbb35c5fa97d35c0b8d997ac313161eb36bcd7cd5e35e38bbe3ad5880f3fd30a3d33f605e592710946d251", x"b3648f1815812f4afdfd73e4fe0c30c403d9a1d0949c0d456041e662405d23431fcbae7630345b7430d43576ab7f88cb", x"90a908b47d0c29a2d0e7e65a212d7e1788454062f46458c519c7f2ccd794ff21d4c24b91acf42a71a509aff6544f676a", x"b65e8b290bdec2fda05cd1c09f8508f662aa46d7d19556d0a4e3244b4ec20093aa37088105ea4c2b1e5b245410241445", x"b0a4c136fb93594913ffcebba98ee1cdf7bc60ad175af0bc2fb1afe7314524bbb85f620dd101e9af765588b7b4bf51d0", x"a04016e9e13ad845763cfe44af4e29fecf920b4aa42f581715fc34fb9ca27776feee45c82093c7274839eef1838b10c4", x"aca69a4095567331a665e2841210655636a3273d7b7590e021925fe50757617898e1883532f9cfd46428c2e3d854f9f7", x"831d72bcd210b8ba3cf93029473ac297f0bac9eded0d873e4b9990973434f9132584a66edaf651512235fb1875370ca5", x"aedf4a81999a5dba1a43c747d669a761998c4903d16a4ed46482701d167cad5fb913cf67f78edb29c4fa2a297919ecef", x"8c122bea78deee98f00a86184ded61c10c97335bd672dadddc8224a1da21a325e221f8a7cfd4e723608ebcd85a2f19fe", x"b82862fd65378b987475f98b06878418f5cd3d7d46cae08f01a631eceb8890db1995272ab869694287263bea2a8279d8", x"b2a01dc47dd98f089f28eee67ba2f789153516b7d3b47127f430f542869ec42dd8fd4dc83cfbe625c5c40a2d2d0633ea", x"a8b0bb9e1f8b0508c7d6e7382676663d27fb27e3f1c0e991a295e59498f4a5dbcc4cf89c73d3d587fb3b8f5838153885", x"8effe3fb27c9f76bbd78687b743b52e6f3330eddc81bc9006ca81fd640f149d73630af578694f4530833c2151522dcc1", x"b3f1319ae34ad1d59207288f01d3d7b7e1bad7733fb4a819a09b011d72a4d736bd3c7afeb74cf56da0e00cf712042ad2", x"b53fb1956a2a34a840de4ff0b5b1e0e2fb78a21ac8edbce6be6c26a4b4de6d37e9dce799110a802a344e8541912353d7", x"847b58626f306ef2d785e3fe1b6515f98d9f72037eea0604d92e891a0219142fec485323bec4e93a4ee132af61026b80", x"88e7a12a90428bb45bcf4b01442c11607433211fc2f9bee9545304eb66e0b4b5339360160bc782e185391385da7c5ad7", x"a013cc5e3fbb47951637426581c1d72764556798f93e413e1317849efd60f3ecb64c762f92544201eb5d6cfb68233050", x"83460a65269134c7626506d8c446d8929ed704469875a3ac2342290f63639fec7a62d6fb75bf55e60a1a953e6f621e2d", x"b2cf2cf8f9e750c1f28b72cae7e4e0091ee6015caac897c5e3b37148b57e64a7fc11efe99a4113a4ce0965d74cbd7a9c", x"a2b27f2a3f133d4f8669ddf4fccb3bca9f1851c4ba9bb44fbda1d259c4d249801ce7bd26ba0ee2ad671e447c54651f39", x"b3bd2fedbca3e0185bd4920bc0b9279da7d7031e39df2886a4c969b28df97181ad37ca4bab2b79f44d7bc4acb32b14ab", x"8cd1c73b7fe915e7169d351f88ade0f810d6a156fe20e4b52c7a697c3d93459e6d6c2f10dc1c6ec4114beae3e0a8c45a", x"850f932ef35fd8693816d950e6209bc04ce26762cf6747d0aee03770e386fa0189790a8295414c0b27695b70988a3c5a", x"91a812d377edddac3c848f65bc8fbb8a1692507dc699e353621df83440b8e463862057a2596c6c6a5c36b2a4888fdae5", x"8317974fb1bdd174c7ef81a2a6478f887f44c1e8680c21730974e5c440846c4d43a76a3e90334b39508f507163e2ff8f", x"8fbc274c5882666da39e7ef636a89cf36725820c8ada6eec0ab9b5af3760524b73a2173c286e155c597b4ed717d879e4", x"b4f583e10aa9af79b4ebd647e0fffe1c720112727e5ffac4313f236737491fceeee194537786c561cd5777b453e5b03c", x"997d3b82e4753f1fc3fc2595cfe25b22ac1956d89c0950767c6b9de20623d310b1d84aaa72ab967ef1ea6d397e13524b", x"969eb809ff2bbc9b51055d60ba635c175384c3d005c101a6c2d18efc6abd915671d6e37f2febd242d946e210a5506cdf", x"8499a8c3d67d1f6eccf1c69274393dc498cff862ea8e6c11ffb8107ae190d258ddc1d294f2a8f050488df0212063ece2", x"8c1de4264e04ff7e8282faf81c0bfb5943656451be52170211cb7adf4ff21bccbb789400735579c622f69982fcb8e9c6", x"b6d6482ad7b9b412ffbefbbdcc28eb3d091b1291f54f77bdd53c4ac85f705c454940f466dc272dde7b03c26f0cd6ecb3", x"802f512bd4a97487491c0e07ab8a94d5580c72212032e34c42b7039b860a7cf8f1e2e24b7185b80d3ee00a9cd4c92903", x"971882d02ad64729cc87251b49effc0b8db9880c25083bfa0ff34e7394e691288c7cefbb5cfdc76d6677ffb9da765dba", x"ac9f0b44105cf77ad721b97b0f04a37fddb2bb62c345b0d22a29e2870b8964d7484aad30e454c74608ce9901043501a5", x"9302bb41f741deaa5f2b6e3bca1427a6cf98b7ec2bf7967b7c0595efa258427323a022ef12f23426ff7a7c318462f07a", x"b71c11828ecad7731136cb1f5b80392a4add8d62f8866a781fdde797a201ebf6d483b2348aacbea2061a5108933b757d", x"944f722d9a4879b5997dc3a3b06299182d8f68d767229220a2c9e369c00539a7a076c95f998bea86595e8ec9f1b957bb", x"8cc8d279ec08d0a5a2a09ad07fabb0122eb65f48da2571d83f86efa2c1c5bc51b04ae94b145f0a8ef19a3988638b9380", x"a04016e9e13ad845763cfe44af4e29fecf920b4aa42f581715fc34fb9ca27776feee45c82093c7274839eef1838b10c4", x"b586e67ae1826a1cdd651ac785e4b38f8a0e042f103a9b7dbb0035626d5dec3ded04a4e2cc09e63b4b01aebe304e40d7", x"a23f3dec1ef45c126f040e5818a1ceea4283bc8ccbf9b8a2d3a770f93872777647893ff86fea463144a355c32a01564e", x"8982534f2c343dda20cccf5a9c8bf98240bba5f4e8eb2206e63a1847097deadb6bf0d24b358014d564c5ef1d0448c43e", x"8a75d70b3b9f735ffba32328eb5ecee9001216f6e96d456f47604ed1dcb297714a0912ef09331adc9dfbbd9199b52be5", x"8bfa106ada4914419bf1d8900c5981dd5b90c3023196d7e918d62879fc3a575bd0a25f939366f7fd2240df6108b069ec", x"ab2053c376c6bd113b89fdb2ae3b8401aa891135345885730c61cac7813f69ea7d906c531be752e28657f73af92d1f4e", x"a3204c9c6873ba52dbf89b975e71d68b650abb8c77dfe85611cf1ecf8d1b274fb3ffb4f704450cc36e15d706afc48ea1", x"b7dfbda841af9b908a43071b210a58f9b066b8f93e0ac23a1977c821d7752d1a390c5936d4c32435da2b20b05c2a80da", x"a7d1676816e81a752267d309014de1772b571b109c2901dc7c9810f45417faa18c81965c114be489ed178e54ac3687a1", x"8719485f6db54a101f19f574fc1fff3a446f3eb4e42c756febcea7b17c7ef4bfb581a84c5bad36831cde06fad79f4d61", x"b0d4231814e40e53ab4eed8333d418a6e2e4bd3910148b610dec5f91961df1ad63f4661d533137a503d809ea1ad576fa", x"b2cf2cf8f9e750c1f28b72cae7e4e0091ee6015caac897c5e3b37148b57e64a7fc11efe99a4113a4ce0965d74cbd7a9c", x"938bbaa0ba14597067ff4c0a7cfc1529c44160d6f61cfad12246526d84fb7a1ba964d3bbb065a348cf7a98356ee15234", x"975c3261f0f32d59473e588f89593be38f5694cfa09394a861e4330b7800fb2528ea832106a928c54c76a303d49140e2", x"96aee5be8da3c75413e7ab87913a286fe497b7c86e7b943b1fd62e8ed191746bb91ee5c35e81b411e78358eea99dfba0", x"a91d95d81ca36e9a8017889165fcd8a12dcd989ce975240ea3f54cab567dc64feefe1668edd9368aaa780f81ea0c8c3f", x"a26cc8594de3d8dc93065636bf0c6a71a337e544678f5a019a05a529123496baff8b3496f0bab510487f9d0c28d8e508", x"b544c692b046aad8b6f5c2e3493bc8f638659795f06327fff1e9f4ffc8e9f7abdbf4b7f6fcdfb8fe19654d8fa7d68170", x"a8a77936ca91df3b2ee7394ea821f2bfe91c6ad8193f44651466c170b6ecca97ab356fa7d947ebb4b767e8967092f143", x"a252dc9469375102f2cdeb913cd7e206e8539c472359ece98074be6abc0ccc818e57a65e8426b0485d2ed55294eb622f", x"85e8259980319bc750607f5004aa83f7d7eaf20eeb164fe3db13864e3d31e1f53ea42dd6d9b30ce710089f193c895d51", x"a8fd63da16dd6a4aa1532568058d7f12831698134049c156a2d20264df6539318f65ec1e1a733e0f03a9845076bb8df8", x"907c827a4fb5f698bf0e6f10ca07741c5b8e3ecb26aa53f938ba34ceb50c01be80c4afc5ac4358a5fda88eadea0cbe73", x"b1afaefc9fb0e436c8fb93ba69feb5282e9f672c62cbb3a9fc56e5377985e9d8d1b8a068936a1007efa52ef8be55ce9c", x"98c8f45e348091164a71a06b8166a992dc692177e7e06063f2a62adbee2028c882dc8225891c59386e69dee53cefe2ec", x"98181e9291622f3f3f72937c3828cee9a1661ca522250dfbbe1c39cda23b23be5b6e970faf400c6c7f15c9ca1d563868", x"ae07ebd0266efd616e56fb5101aa71bafbed8c2bddaaed27c3b069d74ec75601fc6a3cecbd917d8ac133903b1d33285c", x"a8b0bb9e1f8b0508c7d6e7382676663d27fb27e3f1c0e991a295e59498f4a5dbcc4cf89c73d3d587fb3b8f5838153885", x"b45c5652db4baab95300e81c0e280bfb9be75741d56545ff33b64d7f195e157ba9ecf909005a2fff59a8ee4dfab71be1", x"84b619bd0d103a993f1d30bfd72961e361727918775121c01b7b091848dd9e4a8880d8cd2348379316795e38f9b949c8", x"8cd9d7e953c7ae07ee785d68a999e702565960d376692d9ea468556ad141229b1f3bc97926818c078901f73ecc578e93", x"908d762396519ce3c409551b3b5915033cdfe521a586d5c17f49c1d2faa6cb59fa51e1fb74f200487bea87a1d6f37477", x"b79b9289dbc045e1d6ab747360696e0a2e4ba4ab7013ca7f977b6ef6e9ce9c4aa41f2b526ec3e5209df3d2cacd548da6", x"b1c56f028f31f0ff86bdf55788703b4d809becaf3e4d9d349f1b660a07d2f15e127eb72a0e2a5a2742313785a3de43a5", x"af25cf204acd84f9833b7c16ce3716d2a2cad640a28e3562f10260925efe252d3f7145839784c2ce1490522b45d1ce9a", x"a668c3994ffa9294f9571424b6063c63393de1b2e431b51f8c55898657186e81694cca65610e765228ba7e08a7abda7b", x"8548774c52eb42b88c53d9d07498eb8a3bd087a48316f7ed309b47e009daac3eb06b9cb5eebfa6a9f54042f4a5fd3923", x"b2df29442b469c8e9e85a03cb8ea6544598efe3e35109b14c8101a0d2da5837a0427d5559f4e48ae302dec73464fec04", x"a718ac1dd2b3c49f077364b60815761bacd6ef59e364bdd5d6bef8fce970123ea21f676686e30c4256a3782fbd352452", x"8bb4d08318386c91a0136d980a42da18c05743a5c52a861ce52a436e66a8ebe472dac7f7461db32ea5da59a23e9bd6c9", x"aefc682f8784b18d36202a069269be7dba8ab67ae3543838e6d473fbc5713d103abcc8da1729a288503b786baac182d3", x"88d417467d9286577913b2ba793d43c3a0202388f793187e9e38cee9e83eae1f6ac7f9138fd9c9b105e1c7560ad298d7", x"8a3987de0131b7461bbbe54e59f6cefe8b3f5051ed3f35e4ad06e681c47beee6614b4e1fba2baa84dff8c94080dddda0", x"b0526c028e1c9a945e340d05087ff0e4b0e465a99369d3fdb8b929e79d02fa34f316741a1610076d33212ba7d357d4b1", x"8b7cb5b8de09a6dfceddcbaa498bc65f86297bcf95d107880c08854ed2289441a67721340285cfe1749c62e8ef0f3c58", x"b2affe048c187d311a185503d8958cacbe03796edf79bc32e8533941004d9178bd2e376e627e1ba61ed43850c0c455cf", x"99db0063338bd58b85c9caffbbd94e411dd17d41ab2ef5db23cc0afd4007ae4b1c120a3abbfdd148f94ab8dcd45cd3db", x"a58219e63b7a11891889c342fc5a6bfaf73e3a99699479bc1885ea560078d8180696d0831cd682faeba1f6b355c7c7b2", x"8605b88ce23190b1fa9d389b15e6907417239a72b97673d1479c4ccb8f4515c7921d14537775c74e738a9c3f122b1443", x"b1afaefc9fb0e436c8fb93ba69feb5282e9f672c62cbb3a9fc56e5377985e9d8d1b8a068936a1007efa52ef8be55ce9c", x"b6d6482ad7b9b412ffbefbbdcc28eb3d091b1291f54f77bdd53c4ac85f705c454940f466dc272dde7b03c26f0cd6ecb3", x"a54e104339286d3ce8271828fbac20f6cf7afd3b72d9b194b7cbaf65f6612416117be492bf4aa88faf6ada56cf4b6462", x"aa25208385573caee2a4830f09e1cc9bd041cdb78d3ee27a4b011815a62d0d2e0295c222480947ae427b1578fb5509f5", x"a129c9cf33df42b5a98ad98be9d940207ae154c715d3bde701b7160dfe45304679fb0481a4f9dde242c22a9849fc2d9c", x"94bbc6b2742d21eff4fae77c720313015dd4bbcc5add8146bf1c4b89e32f6f5df46ca770e1f385fdd29dc5c7b9653361", x"99dad12f78e1a554f2163afc50aa26ee2a3067fc30f9c2382975d7da40c738313eaae7adbc2521f34c1c708f3a7475b7", x"b505d99f6a9492641c6a3d62144a70fd5d83ca74b20b61d173e9aa83a88a0cbd0cf48aa8fa1b3621e15ff43646152912", x"b76cb8cb446eb3cb4f682a5cd884f6c93086a8bf626c5b5c557a06499de9c13315618d48a0c5693512a3dc143a799c07", x"94179fcc1fa644ff8a9776a4c03ac8bff759f1a810ca746a9be2b345546e01ddb58d871ddac4e6110b948173522eef06", x"adc806dfa5fbf8ce659aab56fe6cfe0b9162ddd5874b6dcf6d658bd2a626379baeb7df80d765846fa16ad6aad0320540", x"a978fb8ce8253f58e1a87da354f06af989b0bafaafec2fb3100bee272dd8664d2690f8ada7dd4817bc8b06ffb1fe23f9", x"8eafbb7002f5bc4cea23e7b1ba1ec10558de447c7b3e209b77f4df7b042804a07bb27c85d76aea591fa5693542c070de", x"81c850f419cf426223fc976032883d87daed6d8a505f652e363a10c7387c8946abee55cf9f71a9181b066f1cde353993", x"aedf4a81999a5dba1a43c747d669a761998c4903d16a4ed46482701d167cad5fb913cf67f78edb29c4fa2a297919ecef", x"a322b5d2a6e3cb98b8aaa4c068e097188affef5dec2f08c3e9ce29e73687340d4e5a743a8be5f10e138f9cabbe0c7211", x"a9d9a295590641b2b09d8473b50c0f6e036e1a009dcd1a0b16d84406763b4b078d5de6ca90898232e34f7f7bf147f61c", x"b0ed68167a67490bd7d7d49e83341606d6e6fdd99b82e46747c2190d270719f81c5f5f8733646c246260f438a695aa3a", x"8414962d05eedffc19d7fab3aea967f5386ed62faa0f0b9b8aede8fbd5a94231aef645d3abeb345a2571c9295af60912", x"8e58219fde5e9525e525b16b5332ef27fb6269e08e8c0bd3c20abb89397864b2c5bb55f5b6e03e8f0a0e0b04e5f72b14", x"b4c5aa21659b3ae37fde62233b0bf41182fdd57c22fb5f47a236048e725a0e8636b9a595b13d9ecdf18c445f156ad7ee", x"938bbaa0ba14597067ff4c0a7cfc1529c44160d6f61cfad12246526d84fb7a1ba964d3bbb065a348cf7a98356ee15234", x"a2b85a731c49309a679c76db51334fa87d55ee5833167ad321f39449e0022a2ea100412894e5e85970d31c6b406bfaeb", x"8be72c12bfaa845ea0c736b7ebe6d4dcb04ee9535c0d016382754e35a898c574fd5de3fe8f0ab6f7e58ba07500536e9f", x"94becbadca9f8209375477a85794e489d65159d09642da087e72208c2124812d9469b1621d877ebabdd63c165eab8fa9", x"a094cca9d120d92c0e92ce740bc774a89667c6f796b438b0d98df0b7aef0935d8c915d5b0dad4b53e383dc9f095c29fa", x"afe779a9ca4edc032fed08ee0dd069be277d7663e898dceaba6001399b0b77bbce653c9dc90f27137b4278d754c1551a", x"b5036d4c241685bcd67156e4ab0eba42b97f639947d54b17af2c88fbcc5fc57359c7df4bc7f8df955a524fb1501a6fda", x"b930ecc2a26183240f8da107e80979b59da4e05f090316d982815ed6151d7750490b85273187ec4e07eb221813a4f279", x"825359cfe68ad6a75578a94be6419179e0aa088170b6c20fc5c249dc3be7a260d687c93d8d8a343c7c72c2ed6a716de3", x"ac9f0b44105cf77ad721b97b0f04a37fddb2bb62c345b0d22a29e2870b8964d7484aad30e454c74608ce9901043501a5", x"b4de7f20e5d141f5682b7e0f0326a3429e00e0236fb8ae58e84c20ed7a986b951cda30d5e2e7e7196119dbd9b0ef5ea1", x"971997a5c2bbce1e8e1520da7cc84d59d6973773e541758486856856082bfba0dfc3f8ee578c69a4412b74a5fa7c808c", x"839d65a5c224c5d04352529a5071ea997ff39916dabb38b7adfb2b10b7bf09d83e052d32a5cd56f06b61836d95a1d997", x"8e662149e22ce32383461ceb489b912f3c6320293d6edf61499164beaab7a265ffb9de3e0af6c95ca824d800718e1506", x"845a4a09941f48677e6c03699770f9a56ba72695089e432a6f232294dd8da6d34e394116a9a87f3b0902c78332af9439", x"963a298fc8876b702424a697929c7a1938d298075e38b616c8711f1c7116f74868113a7617e0b4783fc00f88c614e72d", x"8dc3c6478fe0150a2cc11b2bfb1b072620335516ad322dc5a644676a4a6aee71a8680eafb37db9065b5aa2f37696de07", x"8d474636a638e7b398566a39b3f939a314f1cf88e64d81db0f556ca60951ec1dca1b93e3906a6654ed9ba06f2c31d4ea", x"b306bec1a3a64231530aecb8e62b75ddc63abf0193496cb8bf0c84ac8a1c018d4fe91aa1c65871e7e05b26b6a5ec61ad", x"97070a33393a7c9ce99c51a7811b41d477d57086e7255f7647fd369de9d40baed63ce1ea23ad82b6412e79f364c2d9a3", x"b380ee52038a0b622cd7eccf4bd52966573fadde4fe8f70f43fa9c43a5a99b3eaf58335a1948b561f5b368ab4e0710f6", x"903f569a8de771406b9fd36384f1fea20d5d79374b8d9af24b4814f96c44739193662aa47be857543fa101aa70ab205d", x"b8d68610fdee190ec5a1f4be4c4f750b00ad78d3e9c96b576c6913eab9e7a81e1d6d6a675ee3c6efac5d02ed4b3c093a", x"893272a63650b08e5b8f9b3f17f8547b456192ad649c168bafd7166b4c08c5adf795c508b88fd2425f7be8334592afb2", x"8c26d4ec9fc8728b3f0340a457c5c05b14cc4345e6c0b9b9402f73e882812999e2b29b4bffdcb7fe645171071e2add88", x"8aa3d9dad1c122b9aed75e3cc94b3a9dab160fa4cad92ebab68a58c0151a5d93f0f6b40b86fba00e63d45bd29a93b982", x"8e956ca6050684b113a6c09d575996a9c99cc0bf61c6fb5c9eaae57b453838821cc604cf8adb70111de2c5076ae9d456", x"b1afaefc9fb0e436c8fb93ba69feb5282e9f672c62cbb3a9fc56e5377985e9d8d1b8a068936a1007efa52ef8be55ce9c", x"8a277710379ba4fababb423026d9db3d8dcd484b2ee812439eb91b4b5177d03433b7a4486e43efbf2d2ce8ccfeabf323", x"9171a7b23f3dbb32ab35712912ebf432bcc7d320c1e278d652200b5d49ad13a49ec8e56a0c85a90888be44de11fc11b5", x"91b0ac6cd2c9dcd2ffe3022b477c3490be344e9fadd15716157237b95625b77c67e59021687c54a0ec87625be0d1631e", x"9542760a620d27a9856c490c8f0fadd90bbf06f539ad11339d2a6cfc0f262a798c8905ee407f53f718a72c1468d756f0", x"b2c51c121acff7c0237d2e85e8e36a9e593eba4de2031ec58a2e6a375c447872756ef6e24c10601d1477249888113a8c", x"b38e558a5e62ad196be361651264f5c28ced6ab7c2229d7e33fb04b7f4e441e9dcb82b463b118e73e05055dcc9ce64b6", x"a62fa028c6e34e4e7eeadfd5b4e4b71edaa78ebe724fd13d976b5c94b0b4ad49f8e318d1f342519ca5ee0abd458425dc", x"85822227f6a96d3b6d6f5cf943e9fb819c8eaf42a9aa0bdd1527055442b1caf672522762831b2dac397af37a1c5ed702", x"b1a3e6baed1cc37b9a67f38648f4fe365d23fb982027ab4202c3392d5459d7995264c2e9bb8e821a3e75e71390b6dc7c", x"adacfecc129526720fb62d82f5fa830b7fc8456a1ba471d40674130406735399ff75a42e87272b08eb41e3d7a7d56b5e", x"a131f61a215d689938b1997ec40357b939bd2a2565df04cea7800674e23ba068d0ce28bad32f49f3099434f34445eb4a", x"b87e5f481b938ac8a481b775cc58be2a06604549e3c810fc4734bab76099e5c617f0243c4c140cb7dd6d36a6dc2286bf", x"8982534f2c343dda20cccf5a9c8bf98240bba5f4e8eb2206e63a1847097deadb6bf0d24b358014d564c5ef1d0448c43e", x"8f7bbaaac458bada6d852fe665c87c646133bab16c0d5136c3dc922095b9d647d93a9de7671cb7bfd4cbd138ae0709d1", x"935f616bc620ddcde07f28b19a66c996798792b953264d1471f686e84f3c6f125e2a3d3a7a535c4175973c7ed2e4bece", x"8adb748d5fa5c22ce4c76a1debf394b00d58add9f4e08524cf9c503f95981b36b8d0cb2dfaef0d59d07768e555733ecc", x"b97447233c8b97a8654749a840f12dab6764209c3a033154e045c76e0c8ed93b89788aac5cd1e24ed4a18c36de3fbf60", x"a53658aaddc51e20752454dcbc69dac133577a0163aaf8c7ff54018b39ba6c2e08259b0f31971eaff9cd463867f9fd2f", x"b549d272a7f3180826a978d747507e4dc80d82784abb655cfcd3a69cc72e7d58c70febea1ce002a89852a8f934ea70fb", x"a308ed8737b3a9346ff20dc9f112efccc193472e6fde6aa218ceae11e288bbd2c35fa45c1d8bb238696a96767cd68b46", x"94402d05dbe02a7505da715c5b26438880d086e3130dce7d6c59a9cca1943fe88c44771619303ec71736774b3cc5b1f6", x"90d32e6a183a5bb2d47056c25a1f45cebccb62ef70222e0066c94db9851dffcc349a2501a93052ee3c9a5ee292f70b92", x"9920c52effcbd2a54502957fabc7c560250c08941bc30fba42d1a5101cd987359ab5725152e3638f6fb3b675e12d1060", x"904d722d7ec51a476a852428d9a246a5ca3be87ae2281e2716e999f82cb9d8d75ade0929ad80c186ada55f839a78f57c", x"b5d6f664ec92e5343792d5d6b629919c5fd8cfb874677df2264daf02bcd9d12facf9b859d5402839c9022396e20d260b", x"a9901df92e2d3abbb25f3bf4b913692c4cd57da327b01c8ee2362c02fbefcf66cdb792c17a81dcbde3c9b9dba313e4a1", x"a0b3dff15982a38a2f56d8c6cfc5c5543c045bf2db24571d23387ccab42abe2756f34d5f0bf6a426bbad3c358b8bdb00", x"b2a4000ce0ddd3f0543ebfe4906570853a85350d75418a1ff2608099c069f03510df576ea0cbb406b7ae8e4f21576811", x"ae7446b29ca1584f418191760c804348b431dda04eee8bb0afe584dd057eb238e61213d5b1daf4acfc19541f15b6eae6", x"99dc948385a816fd6131525b959c3c9a956ea187958958a5c28e7a210d87b4590599a5d14000161949187f8b62836991", x"8acf2c566ab7a822dbfc1e535443cd1b634d0048829cf1a77421a26997ae062cd34de318ffa543528646d7732d4d5b7b", x"93c1b107eed20ea64c303f53819aede3fc3df85ecf1009174398a8be1441e374657697936af1b9f6e655797478557cea", x"95614544f65808f096c8297d7cf45b274fc9b2b1bd63f8c3a95d84393f1d0784d18cacb59a7ddd2caf2764b675fba272", x"83c991703a7aac7ed7e88fe02ffdded1a5044143ac2cd038b687b2ccd37a69d6f9359de10508b3d282a9585475136f81", x"9340bfc34ffab8c28b1870a4125c559978ac2b278f76f462b5c859a00c3ba3426b176dc2c689096ad575b4cd4dbb76ae", x"b9def7aa584fbfd49683b1652bb24794129170244da113bc7b4b59f5a47dd08e41ce4403b0d8c47b35acf283390fad99", x"a38c974b57da968f0c4611f5d85d8014fd48594c8cd763ef2f721cfd2c738e828d41ff029e3591d7447e3125641db8ef", x"b9ed23f3f26fc9f31e1e30e8ae88482352fab6ef79a2eb8939dc78110580708f482ba3ab306ed6e09030653b9704a80e", x"951b27456e2af80436608aadec54ebd03bda37fa58452631da63bc5ff3eecb5ffb73d356b19f6c9c4225fcb0da8fda20", x"a094cca9d120d92c0e92ce740bc774a89667c6f796b438b0d98df0b7aef0935d8c915d5b0dad4b53e383dc9f095c29fa", x"825aca3d3dfa1d0b914e59fc3eeab6afcc5dc7e30fccd4879c592da4ea9a4e8a7a1057fc5b3faab12086e587126aa443", x"987dd977d6b8d27c4065b61b3c078ec9ce3871fec02844ed00f5ad28c42f9cedecbe830ddd19e11a5c879b01eb0f8f80", x"83f21dfe0272a5a8682c3c7814c5e0e4db6a9098f1fa80fda725f77ea81fdfd2fa36b0c8db013503a89bd035f86306fa", x"ae96dc808c316a677977831bad1e529ef965dadb5d6aea25ab008fe7bb1543e596e33052cfbe4279fa060201199d2c34", x"afbb939073c28492a46f8028a010297e395c7449fd8a1e24322e605c1db6cda1581f2810cdb45c273189084b82e74b22", x"af917d086e2e327d8d9e37ff85702536d7b15f444310d4aa832a61d850c7c3f09d31b3f5fd2a073e7fd64601275b6fca", x"80e44d3577f12cabaed7074feeb57162ff80b61f86cce8f41d1d1250bc455070b09f6ea9d0c263b7b4824701480f4c14", x"82ffe4de0e474109c9d99ad861f90afd33c99eae86ea7930551be40f08f0a6b44cad094cdfc9ed7dd165065b390579d0", x"8757e9a6a2dac742ab66011c53fa76edb5ebc3c2fbd9a7265529a3e5608b5c24b4482fed095725e9b8fed5a8319c17a4", x"8154f81d5bcab563895b68e0b3b26bee1019bfa16792c57a732e94fe6486425e661e822ec61437648bbbe6d8ee0e9a52", x"b8fdf21b57d1d5eecd93f76c37230d379b652dcd9026a158151adc38c7ee4273cc2b99e47b89ec05f57dafdcaa7a3b4e", x"912750d2f1b21756662a400236f797b8ba76c73e5af95941a8c6ef9427838c4826715c80942cf8cb7ed01566bc490754", x"8fa2d7b22af8e6b82679ebdfa13efdcb34289a554653ea6c1b16efb9f957f7fe64df787e7b03d8cdc8a732b91c916bd1", x"9377aab082c8ae33b26519d6a8c3f586c7c7fccc96ec29a6f698b67d72d9266ad07378ba90d18e8c86a2ec77ecc7f137", x"8982534f2c343dda20cccf5a9c8bf98240bba5f4e8eb2206e63a1847097deadb6bf0d24b358014d564c5ef1d0448c43e", x"8ebfbcaccddd2489c4a29a374a2babc26987c3312607eadb2c4b0a53a17de97107c54eab34def09144b3098c082c286b", x"b043156fcd02b75dbe940c763fa8e8a7c7f6d74c1d5395db5ce544af3b6097eab61686950535a810aa95889ced12f74d", x"96b15806d9009962fa07f8c32e92e3bc30be4ded0645ab9f486962a1b317e313830992179826d746ea26d4d906bdb7b6", x"868c13bb6bec7d56afd4e518f2f02b857a58d224fbe698be0e00bc178c1858e6bf5f0f7824fa013d5c8dd6f6e4147974", x"a308ed8737b3a9346ff20dc9f112efccc193472e6fde6aa218ceae11e288bbd2c35fa45c1d8bb238696a96767cd68b46", x"af9d13103868c854821ba518907b067cfba025d739125f1e9cce0a04fffc3a2a1f25506c1209a0cfe1d6c1572c229ff0", x"a26c326f3b48758157f74993971a1bf0913ae292a4eb4a4653ee53a2a916782466cbcced54c71685668ae0a7ef0e210b", x"b792b08f3b1048c8883d0ca34e1d693d411819dc990c117923d42bf1cde7b0e7193e92941f7d9c520cc6f9eab0f7bf6d", x"a91d95d81ca36e9a8017889165fcd8a12dcd989ce975240ea3f54cab567dc64feefe1668edd9368aaa780f81ea0c8c3f", x"a0ebae60a998907a19baa396ae5a82bfe6aa22cf71bfca4e1b4df7d297bd9367bbeb2463bda37aa852ad8fd51803e482", x"98d6d46f603afebcbc561c130e416d5a588a7e6c1f17f89ed6e30538b7f8dbf4b3c75b8a3331425c4ca21e03fe8b57f3", x"a4348ad30c12bb7dd03dd014cca599c3499ddf348e7795b0392a18f998289979478374e374a8297b5b6c427441e2b5af", x"8d74f4c192561ce3acf87ffadc523294197831f2c9ff764734baa61cbad179f8c59ef81c437faaf0480f2b1f0ba1d4c8", x"b63ace9e3893ec7b7c853023b359c34d4baaa0ac23908b476ce67c07d29f5e5e895e90c3d3f58f8433ac5d06df894d0d", x"8c26d4ec9fc8728b3f0340a457c5c05b14cc4345e6c0b9b9402f73e882812999e2b29b4bffdcb7fe645171071e2add88", x"8aa3d9dad1c122b9aed75e3cc94b3a9dab160fa4cad92ebab68a58c0151a5d93f0f6b40b86fba00e63d45bd29a93b982", x"81351fd284d6d07092875f366bc5e53bfd7944b81eece85eab71a00443d1d2a9fc0337aaf34c980f6778dd211caa9f64", x"b6e6277b86cd5284299ced867d37ab98090ac44a94deef6898aeadd177e64605440c15b9609c07e71fe54c95b61873b0", x"b2f168afc35ed9b308ab86c8c4aaf1dcd6833ce09153bb5e124dad198b006e86a941832d387b1bd34b63c261c6b88678", x"820f164a16c02e136911dadbc61b9f6859a7c53d0ea17b8f64b783f7f2f4f549775d3f16e21634dc6d54aef8d56517b2", x"b800be1788175a01a9228b0d3e7eb4302484a2654eb2a86c0f0900b593da0a436ef031ac230e2b05e968b33e90a342ce", x"a7c2174eea2b66b2a71cc8095fae39c423a353c7d5020ec2d0551317a66202fcf082c6119ba768755523fff49791bb4e", x"a931bb29b6200899e8a8c257166400eff9888594daa1e37501390a1d219b019ed1b730d921a8f6d6fe62dff7b86ee387", x"99dad12f78e1a554f2163afc50aa26ee2a3067fc30f9c2382975d7da40c738313eaae7adbc2521f34c1c708f3a7475b7", x"b2eedff11e346518fa54e161be1d45db77136b724d497e337a55edfc896417de3a180bf90dd5f9d92c19db48e8574760", x"9310722e360a5652737362f6b9cb6e9c3969a0c9bb79b488b3c7d19d9e8c42ebd841df346258ded2e393895c99b413cf", x"a22b351f139096f9ed5baafe27affde1351685765805d458381e392e0bfc51cbd8af5909b3a1da05d0d176877028eb32", x"94d3c9406dc6dd7241a726355643d706e46b35f1ffe4509ac43e97c64c07592821156ba02ec9a78978e66709995a0ac8", x"830e70476c6093d8b9c621ddf0468a7890942589cae744300416639a8b3bc59a57a7e1150b8207b6ab83dafcc5b65d3c", x"a3e1fe11f38d3954a7f48c8b68ff956ea0b6f8a3e603fd258c9406ec2b685ff48241db5257179ea020a83c31dc963854", x"b34d4d2e15079e7e80fdba30cddf4fc0e6c9a61f7ab06a6ea0a4e55fd5bf632c6d72e021d6264d935439d321de883bb6", x"ac722bd742374f925185ea7d4d62d7510b2d8a6ebf5c750af6ce83e2d8a28c95a3e298870ec8254ab2d1d0aa2a063c60", x"a4a052a95cdb71be46a05657cbc598124af42e11e9bc5ef24d5ebfd8663e5636cbbb1aebca5bbcebfa7aa4cb0c7db1ce", x"b42d53fb4e5390729381b74ab96f48551f9105c2256d547cd7be0eed5bd5e7b7ce87033c55d0ddfbfe08ebb782f18be0", x"a6e1951cbbb19c0aad6e9251c2c4dcae1d2e50550a32813a47dde9f41e42e2dd0433cddf7e63ab3d320edca48a6d34fb", x"b928a1a20f078a50f9c67da1d909e6656c3980f20b96bb8d06c0cc42557ccd290ed64cd78f9c9ca090cfdb9327eebd89", x"88e1e459ee5aeb8b36ed004f6d03da296101106fbe1b18f9bbf63e92321db51670c34050fd3b7dc56a4bad76403823ee", x"a9fdf721dc72206c760681424edfdea16b92dcbb287e6c3eecae8cfaf5cf163b967f125cb2e4546ffd7369b451bb56b2", x"8d264fbfeeebb6c4df37ff02224e75e245e508f53fb3446192cd786ecf10d0f704c4fc2e53e7f7318ae1407e46fc0fb8", x"a8d152e5d94b75cb9e249230db21af31de4d4f3d4ef60ccbf2212babf69aed2a38435a993ee2f13cca410ad55a4875ab", x"a2b410b66ff050ab42cb56f8037577662801043c7dfa3cd37a9aa72bb4fe3983507c17f4fb7e73ccdecf5c536b1a2cb7", x"a4baa3dbcaa9bbdbbea7d3052d739b5dfb248eb910aa246cf494b07292faaf5537dab0971f2cfdaf8c60aea018a51575", x"91a3676c677c28c96817d6eb0aaee4c66b1c051b4c7cd2b98af6dd873c363c6da6e7fc29d7a87596ce751f84fd5e711e", x"8295f613c162159f368340ca0fc2fd7776f7ad64eeafbd132bd3be1f1c30b5fbdc5f107f12fb0cff15b12c08621f457f", x"99dc48a054f448792523dcdeec819e1b928b1bd66f60f457261f0554f8532eedd7152792df70ae5316ab2f9c02a57cdc", x"95c98e3b6b62f84edf7f297cae93ee5f82593478877f92fb5bf43fd4422c3c78e37d48c1ee7ca474f807ab3e848d4496", x"a3a6d1ee35cc0ed9290a135086b32f136028b320650e1f3443434af7ff52dd74c546ffe2a1bebfc329f1b52cd72aca34", x"b3648f1815812f4afdfd73e4fe0c30c403d9a1d0949c0d456041e662405d23431fcbae7630345b7430d43576ab7f88cb", x"87970b6946fc6f64010ce3e78de71a365814266707b23f871890dbdc6c5d1ad47dd3baa94da9eefc87523798cef84ff2", x"895ebab1992f6a81ec82efb291d7daba11fb231edf67fc1a8415b5fffdc03b10e86af93d4a7ffd1fb9735102b7ad7ce3", x"8144a5c583a61f809f6a9f5ba97dbed42f4086de71af955f5df5774f66a3581335926663502d7cc7b5129216da225f9c", x"b1e604fc3e1827c6d6c58edd4bc42b1529b2da46e2438591317258be9147359278f154e02465b938c727bb3b0c0cf8f4", x"b43fdb2ba9128fd24721209e958be7b9c84dca08387c982723f93ed4a272f933823ae084f1b1399ff6271e0da6f5aa3f", x"831d72bcd210b8ba3cf93029473ac297f0bac9eded0d873e4b9990973434f9132584a66edaf651512235fb1875370ca5", x"a99cde5c7c85ae291c74c893e598cc0e6eb2dda2a81dbb504a638eb21dd2c41d6e5caf7baa29e3c1c32e94dca0d791f1", x"925f3bb79c89a759cbf1fabdaa4d332dfe1b2d146c9b782fe4a9f85fee522834e05c4c0df8915f8f7b5389604ba66c19", x"8117fbcf61d946bee1ce3dff9e568b83716907acfde9b352c3521cfed44158874af8dd5b3906b4a6b49da2fb212ef802", x"a2ab566033062b6481eb7e4bbc64ed022407f56aa8dddc1aade76aa54a30ce3256052ce99218b66e6265f70837137a10", x"acb7069fe0428d350b8b710a702f56790bdaa4d93a77864620f5190d1ac7f2eed808019ca6910a61ec48239d2eca7f2a", x"b0c707313762e66c681b0efe03ca11a49791173c1e5d42b235c3370e98c37ca4393e6babaabc3933e3d54e72843337d8", x"a639bdcc6f167b3d488cf2d28ebe4782c4f37a5de4ee3d8f4845eef50c81ab7ee421db99c02c6404fa9d45a948b6d37f", x"a25e16820baca389c78a8a72e9b244a4db0399d146eba4f61c24b6280f7cf6a13ddd04de1df6331b2483e54fd2018de6", x"b7dfbda841af9b908a43071b210a58f9b066b8f93e0ac23a1977c821d7752d1a390c5936d4c32435da2b20b05c2a80da", x"982f7114772f7a4e74a9a1194784c983e9b8b4c6c25b42b417050b9194180f1f44028a88b95f4a9b1a63326017cdf60c", x"af61f03e3ceef5bef36afa29ba2edc7a3b01ca26cec2589edbc9d124dd46e41410e0e3afbae959c83a6f839bbcf8049a", x"840a53b12c5bb26dfcbfbc6f6ec4b1520547382b704ba545c65adcbf80eddfa0ac3cfa25eb44707608435f8cbbd07aa4", x"a6565a060dc98e2bfab26b59aff2e494777654015c3292653ecdcefbeeebd2ce9091a4f3d1da10f0a4061f81d721f6ec", x"a71d2c8374776f773bad4de6edfc5f3ff1ea41f06eb807787d3fba5b1f0f741aae63503dbca533e7d4d7d46ab8e4988a", x"a77e6e0de5381d8df6a79cfb8c606e3cd92ff937f4589222bca6ff3a18aa10f408c8463a500fd094bde5eddf12c1dfc2", x"8b886448cbbbeb40be3e71ccee251632186dccb51697f69eb5c746000b4327fd85be3a58fbd49f1df642a37f6388a8f2", x"941cd102228aa81ef99506313a4492a17c506e7169808c6b14dd330164e9e8b71b757cbe6e1bb02184372a8c26f7ad1f", x"9574f43bf9da6bab6c21411d2886fa5d5717cbcee226eda84646ca4c1835f0f798d9a6523e0e007309e52deb7bf645b5", x"893272a63650b08e5b8f9b3f17f8547b456192ad649c168bafd7166b4c08c5adf795c508b88fd2425f7be8334592afb2", x"8235a3f09078dd34ce2fc17cc625e061298713b113dda12d354b3d2ba80e11c443b1dd59c9eb5a29513a909645ae97d4", x"aed7c98567a3a9bd7e3c8893fb1433caef1b4d185adf81e4db30777a9fa37309f1f28c0de86f027e7bda1721819e411a", x"afe779a9ca4edc032fed08ee0dd069be277d7663e898dceaba6001399b0b77bbce653c9dc90f27137b4278d754c1551a", x"a683d4865ddcc099f7b698153007b92f853b80f49b3be75163ea8cd1f8ff584b43a68e68de3ae61cda8ad4b41f355c87", x"a4aabd1890ebf35423565dbff3477a09eea4e35f5a26ed449eab38e0a21fb89e9ddfe3a2003cddc457db648a1b5891a3", x"a10788831a0cb2c3d14d8bc214d92bee6e2a9e92c423d2974760d84a6872a9465d12b628f9bd8a6e777a7db6f509b3a0", x"802f512bd4a97487491c0e07ab8a94d5580c72212032e34c42b7039b860a7cf8f1e2e24b7185b80d3ee00a9cd4c92903", x"b00d95908e72c6051478a422eb2231b5f797c2fa5c696ed1e6b9c9996ba1d8236f512443f18c01ce63312c38fa383fd4", x"93947508e60df6a0bd8b3fa24a72ef783c9fde1c3d94de0101c75e0e73d8003d9beedfdf9f40375613180d77815950dd", x"81564bee5a3bd09476f658cf7719326c353485e2f4fea58d110071c5dddd3cabc349a8d1ecea45d589ed4479952a2ba2", x"80d492fbdbe9d5fcd08fe962b3ce2b9c245c068f686c4838f57db5b4e8b1bfc729c98e93dd4e5cc78b661845d7459809", x"8c01b901e1067a89471927d911246a8b2f1284e93be9913406d7c88aba784694317e22a0a7635583dae7db45cafb73ed", x"8ee41011424da5e2ecea941cbf069ea32420749f2519434d3d8f9725ac789753404687a6745cffe4bd5dfc8fec71a719"
        ];
        let aggregate_public_key =
            x"80f113008bfe69ec8cc827c45afdf8c78fd10f5615cd9d30108b2db3d5264cd10304af8057995931e12efa5e9c7cf384";
        let current_sync_committee_branch = vector[
            x"54dff2180c9ec654c9a790adaf33027ca90a3495d0603a294074bd7417f56989",
            x"9bf7d5977e79ac96cce3ccdd429a467e323680033141b5640518f931c41dfa05",
            x"08b4fa44ec9c5582fc9382d4bb1a8d302354f7f47e006a11449fa23582cac42a",
            x"676c47e9a4379d053201dc3266bef1851f4f66dc45e8eae7ccf30adda6a66230",
            x"627a3ef270d8cce3cf8e2a1957aa6dc004a238ce9ff2e96a2dd2469abd3b7c51",
            x"b83fd15f77764c922f7289fc7f438eb58651ef588f2dac66333f3d6632edc154"
        ];
        (public_keys, aggregate_public_key, current_sync_committee_branch)
    }

    #[test_only]
    public fun test_initializer_scratch_space_not_exists(test_account: &signer) {
        assert!(
            !exists<InitializerScratchSpace>(signer::address_of(test_account)),
            22
        );
    }


    #[test_only]
    public fun test_process_light_client_optimistic_update(
        update: &mut LightClientUpdate
    ) acquires LightClientState {
        process_light_client_optimistic_update(update);
    }


    #[test_only]
    public fun test_process_light_client_finality_update(
        update: &mut LightClientUpdate
    ) acquires LightClientState {
        process_light_client_finality_update(update);
    }


    #[test_only]
    struct FakeMoneyCapabilities has key {
        burn_cap: BurnCapability<SupraCoin>,
        mint_cap: MintCapability<SupraCoin>
    }

    #[test_only]
    public fun test_init_module_init(test_account: &signer, user: &signer) acquires SignerCap {
        account::create_account_for_test(signer::address_of(test_account));
        account::create_account_for_test(signer::address_of(user));
        let (burn_cap, mint_cap) = supra_coin::initialize_for_test(user);

        coin::register<SupraCoin>(test_account);
        let coins_minted = coin::mint<SupraCoin>(1000000, &mint_cap);
        coin::deposit(signer::address_of(test_account), coins_minted);

        let coins_minted_11 = coin::mint<SupraCoin>(100000000, &mint_cap);
        move_to(
            test_account,
            FakeMoneyCapabilities { burn_cap, mint_cap }
        );
        let hypernova_resource_addr = generate_resource_address();
        init_module(test_account);
        let hypernova_resource_signer = create_hypernova_signer();
        coin::register<SupraCoin>(&hypernova_resource_signer);
        coin::deposit(hypernova_resource_addr, coins_minted_11);
    }


    #[test_only]
    public fun test_convert_public_key_from_bytes_with_pop(
        public_keys: vector<vector<u8>>
    ): vector<PublicKeyWithPoP> {
        convert_public_key_from_bytes_with_pop(public_keys)
    }


    #[test_only]
    public fun test_light_client_state_not_exists(account: address) {
        assert!(
            !exists<LightClientState>(account),
            2
        );
    }

    #[test_only]
    public fun test_initialize_step() acquires LightClientState, InitializerScratchSpace {
        initialize_step();
    }

    #[test_only]
    public fun test_initialize_light_client_store_v2(
        account: &signer,
        latest_slot: u64,
        latest_proposer_index: u64,
        latest_parent_root: vector<u8>,
        latest_state_root: vector<u8>,
        latest_body_root: vector<u8>,
        public_keys: vector<vector<u8>>,
        aggregate_public_key: vector<u8>,
        current_sync_committee_branch: vector<vector<u8>>,
        source_chain_id: u64,
        epochs: vector<u64>,
        versions: vector<vector<u8>>,
        source_hypernova_contract_address: vector<u8>,
        sync_committee_threshold: u64,
        source_event_signature_hash: vector<u8>
    ) acquires LightClientState, InitializerScratchSpace {
        initialize_light_client_store(
            account,
            latest_slot,
            latest_proposer_index,
            latest_parent_root,
            latest_state_root,
            latest_body_root,
            public_keys,
            aggregate_public_key,
            current_sync_committee_branch,
            source_chain_id,
            epochs,
            versions,
            source_hypernova_contract_address,
            sync_committee_threshold,
            source_event_signature_hash
        );
    }


    #[test_only(test_account = @0xdead, user = @0x1)]
    fun test_initialize_light_client_store(
        test_account: &signer, user: &signer
    ) acquires LightClientState, InitializerScratchSpace {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741902303);

        let slot = 7163770;
        let proposer_index = 783;
        let parent_root =
            x"d299bb40f46be36b835e179a88a7a9e6bb693c83d1d76050a56ce3b8c638ed53";
        let state_root =
            x"87821c21585fa61d4b11721a799bb3387e02636ec0d54d5c00d46ecad00db821";
        let body_root =
            x"39b047fbf4367aa82e7b1b3afb0b9d0cc9e653d0269f1d1c7f5a5fb6bb918438";
        let (cureent_sync_public_keys, aggregate_public_key, current_sync_committee_branch) =

            get_sync_commitee();
        let source_chain_id = 1;
        let epochs = vector[50, 100, 56832, 132608, 222464];
        let versions = vector[
            x"9000007000000000000000000000000000000000000000000000000000000000",
            x"9000007100000000000000000000000000000000000000000000000000000000",
            x"9000007200000000000000000000000000000000000000000000000000000000",
            x"9000007300000000000000000000000000000000000000000000000000000000",
            x"9000007400000000000000000000000000000000000000000000000000000000"
        ];
        let source_hypernova_contract_address =
            x"000000000000000000000000dfdd98eee3f944ab987ad7b2f2d12df1f48777e7";
        let sync_committee_threshold = 400;
        initialize_light_client_store(
            test_account,
            slot,
            proposer_index,
            parent_root,
            state_root,
            body_root,
            cureent_sync_public_keys,
            aggregate_public_key,
            current_sync_committee_branch,
            source_chain_id,
            epochs,
            versions,
            source_hypernova_contract_address,
            sync_committee_threshold,
            x"6253c4239a235930c4597a4076cc8351362a2a8107a4acdeb5e2f7aeafb87e49"
        );
        initialize_step();
        initialize_step();
        assert!(
            !exists<InitializerScratchSpace>(signer::address_of(test_account)),
            22
        );
        let lv = get_light_client_store();
        let (
            update_slot,
            current_sync_committee_pubkeys,
            _current_sync_committee_aggregate_pubkey,
            next_sync_committee_pubkeys,
            next_sync_committee_aggregate_pubkey
        ) = test_get_light_client_view(lv);
        assert!(update_slot == slot, 11);
        assert!(vector::length(&current_sync_committee_pubkeys) == SYNC_COMMITTEE_SIZE, 11);
        assert!(vector::length(&current_sync_committee_pubkeys) == SYNC_COMMITTEE_SIZE, 11);
        let x = vector::borrow(&current_sync_committee_pubkeys, 23);
        let y = vector::borrow(&cureent_sync_public_keys, 23);

        assert!(x == y, 22);
        assert!(option::is_none(&next_sync_committee_pubkeys), 11);
        assert!(option::is_none(&next_sync_committee_aggregate_pubkey), 11);
        assert!(
            get_source_hypernova_core_address()
                == pad_left(source_hypernova_contract_address, 32),
            11
        );

        assert!(get_source_chain_id() == source_chain_id, 11);

        assert!(get_sync_committee_threshold() == sync_committee_threshold, 11);
        assert!(get_admin_address() == signer::address_of(test_account), 11);
    }
}
