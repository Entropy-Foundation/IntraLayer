/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
module hypernova_core::proof_verifier {
    use std::option;
    use std::vector;
    use supra_std::eth_trie::verify_eth_trie_inclusion_proof;
    use aptos_std::aptos_hash::keccak256;

    use hypernova_core::hypernova_core::{
        get_source_hypernova_core_address,
        process_light_client_optimistic_update,
        process_light_client_safe_update,
        process_light_client_finality_update,
        process_verification_fee,
        get_source_event_signature_hash
    };

    use hypernova_core::eth_types::{
        BeaconBlockHeader,
        construct_beacon_block_header,
        get_state_root,
        hash_tree_root_beacon_block_header,
        verify_merkle_proof,
        construct_sync_aggregate,
        construct_lightclient_update,
        get_slot,
        next_power_of_two

    };
    use hypernova_core::message_types::{
        Message,
        construct_message,
        ExtractedLogs,
        ExtractedLog,
        get_address,
        get_log,
        get_log_hash,
        get_log_index,
        get_data,
        get_topics,
        decode,
        rlp_encode_u64
    };
    use hypernova_core::helpers::pad_left;

    /// ================================ Errors ================================

    /// Invalid source contract. The source contract is invalid or unrecognized.
    const EINVALID_SOURCE_CONTRACT: u64 = 2000;

    /// Invalid topic count. The number of topics in the event log is incorrect.
    const EINVALID_TOPIC_COUNT: u64 = 2001;

    /// Invalid verification method. The verification did not pass optimistic verification checks.
    const EINVALID_VERIFICATION_METHOD: u64 = 2002;

    /// Invalid block summary root proof. The provided block summary root proof is invalid.
    const EINVALID_BLOCK_SUMMARY_ROOT_PROOF: u64 = 2003;

    /// Invalid block root proof. The provided Merkle proof for the block root is invalid.
    const EINVALID_BLOCK_ROOT_PROOF: u64 = 2004;

    /// Invalid Ethereum trie proof. The provided Ethereum trie proof is invalid.
    const EINVALID_ETH_TRIE_PROOF: u64 = 2005;

    /// Invalid receipt proof. The receipt proof provided is invalid.
    const EINVALID_RECEIPT_PROOF: u64 = 2006;

    /// Log hash mismatch. The computed log hash does not match the expected value.
    const ELOG_HASH_MISMATCH: u64 = 2007;

    /// Invalid source event signature hash. The first topic does not match the expected signature hash.
    const EINVALID_SOURCE_EVENT_SIGNATURE_HASH: u64 = 2008;

    /// Not a finality verification. This error is triggered when the verification method used is not set to finality, which is required for certain operations.
    const ENOT_FINALITY_VERIFICATION: u64 = 2009;

    /// ================================ Constants ================================

    /// Represents the finality verification method. This is used when finality guarantees are required.
    const FINALITY_VERIFICATION_METHOD: u8 = 1;

    /// Represents the safe verification method.
    const SAFE_VERIFICATION_METHOD: u8 = 2;

    /// Represents the optimistic verification method.
    const OPTIMISTIC_VERIFICATION_METHOD: u8 = 3;

    /// The length of an Ethereum address when padded to 32 bytes.
    const ETHEREUM_PADDED_ADDRESS_LEN: u64 = 32;

    /// Number of slots per each historical root.
    const SLOTS_PER_HISTORICAL_ROOT: u64 = 8192;

    /// The expected number of topics extracted from the source event log.
    /// This is used to validate or parse logs where a fixed number of topics is required,
    /// such as Ethereum logs Post Message emit 4 topics.
    const EXPECTED_TOPIC_COUNT_FROM_SOURCE: u8 = 4;

    /// Size in bytes of each chunk used in SSZ Merkleization.
    /// Each element in the historical root vector is a 32-byte hash (Node).
    /// Since the vector holds 8192 elements, each of 32 bytes, this constant reflects that unit size.
    const SSZ_MERKLE_CHUNK_SIZE: u64 = 32;

    /// ================================ Public Functions ================================

    /// Processes and verifies cross-chain data using optimistic/safe verification method.
    /// This function handles the complete verification process including:
    /// 1. Fee processing
    /// 2. Block header construction and verification
    /// 3. Message construction and validation
    /// 4. Light client update processing
    /// 5. Block proof verification
    ///
    /// # Parameters
    /// ## Block Headers
    /// * recent_block_slot: Slot number of the recent block
    /// * recent_block_proposer_index: Index of the block proposer
    /// * recent_block_parent_root: Parent root hash of the recent block
    /// * recent_block_state_root: State root hash of the recent block
    /// * recent_block_body_root: Body root hash of the recent block
    ///
    /// ## Sync Committee Data
    /// * recent_block_sync_committee_bits: Sync committee participation bits
    /// * recent_block_sync_committee_signature: Sync committee signature
    /// * recent_block_signature_slot: Slot number for the signature
    ///
    /// ## Block Roots Verification
    /// * is_historical: Flag indicating if historical verification is needed
    /// * block_roots_index: Index in the block roots array
    /// * block_root_proof: Merkle proof for block roots
    ///
    /// ## Historical Roots Verification
    /// * historical_block_root_proof: Proof for historical block roots
    /// * historical_block_summary_root: Root of historical block summary
    /// * historical_block_summary_root_proof: Proof for historical summary root
    /// * historical_block_summary_root_gindex: Generalized index for historical root
    ///
    /// ## Target Block Data
    /// * slot: Slot number of the target block
    /// * proposer_index: Index of the target block proposer
    /// * parent_root: Parent root hash of the target block
    /// * state_root: State root hash of the target block
    /// * body_root: Body root hash of the target block
    ///
    /// * tx_index: Index of the transaction in the block
    ///
    /// ## Receipt Proof
    /// * receipts_root_proof: Proof for receipts root
    /// * receipts_root_gindex: Generalized index for receipts root
    /// * receipt_proof: Proof for the receipt
    /// * receipts_root: Root hash of receipts
    ///
    /// ## Message Data
    /// * msg_id: Unique identifier of the message
    /// * source_chain_id: Chain ID of the source chain
    /// * source_hn_address: Address of source Hypernova contract
    /// * destination_chain_id: Chain ID of the destination chain
    /// * destination_hn_address: Address of destination Hypernova contract
    /// * log_hash: Hash of the event log
    /// * log_index: Index of the event log
    /// ## Verification Method
    /// * verification_method_external: Expected to be set to optimistic or safe verification identifier
    /// * safety_level_external: Expected to be set to the desired safety level for the safe verification method
    ///
    /// # Returns
    /// * (Option<ExtractedLog>, vector<u8>): Tuple containing the verified log and its hash
    ///
    /// # Aborts
    /// * If verification method is not optimistic or safe  (EINVALID_VERIFICATION_METHOD)
    public fun process_data_optimistic_or_safe(
        account: &signer,
        // Recent Block Header
        recent_block_slot: u64,
        recent_block_proposer_index: u64,
        recent_block_parent_root: vector<u8>,
        recent_block_state_root: vector<u8>,
        recent_block_body_root: vector<u8>,
        // Sync Committee Data
        recent_block_sync_committee_bits: vector<bool>,
        recent_block_sync_committee_signature: vector<u8>,
        recent_block_signature_slot: u64,
        //-----------------------
        // Block Roots Verification
        is_historical: bool,
        block_roots_index: u64,
        block_root_proof: vector<vector<u8>>,
        // Historical Roots Verification
        historical_block_root_proof: vector<vector<u8>>,
        historical_block_summary_root: vector<u8>,
        historical_block_summary_root_proof: vector<vector<u8>>,
        historical_block_summary_root_gindex: u64,
        // Target Block Data
        slot: u64,
        proposer_index: u64,
        parent_root: vector<u8>,
        state_root: vector<u8>,
        body_root: vector<u8>,
        tx_index: u64,
        // Receipt Proof
        receipts_root_proof: vector<vector<u8>>,
        receipts_root_gindex: u64,
        receipt_proof: vector<vector<u8>>,
        receipts_root: vector<u8>,
        // Message
        msg_id: vector<u8>,
        source_chain_id: u64,
        source_hn_address: address,
        destination_chain_id: u64,
        destination_hn_address: address,
        log_hash: vector<u8>,
        log_index: u64,
        verification_method_external: u8,
        safety_level_external: u8
    ): (ExtractedLog, vector<u8>) {
        assert!(
            verification_method_external == OPTIMISTIC_VERIFICATION_METHOD
                || verification_method_external == SAFE_VERIFICATION_METHOD,
            EINVALID_VERIFICATION_METHOD
        );
        process_verification_fee(account);

        // Construct block headers
        let recent_block_header_build =
            construct_beacon_block_header(
                recent_block_slot,
                recent_block_proposer_index,
                recent_block_parent_root,
                recent_block_state_root,
                recent_block_body_root
            );

        let target_block_header_build =
            construct_beacon_block_header(
                slot,
                proposer_index,
                parent_root,
                state_root,
                body_root
            );
        let message =
            construct_message(
                msg_id,
                source_chain_id,
                source_hn_address,
                destination_chain_id,
                destination_hn_address,
                log_hash,
                log_index
            );

        // Process light client update
        let lightclient_update_build =
            construct_lightclient_update(
                recent_block_signature_slot,
                option::none(),
                recent_block_header_build,
                option::none(),
                construct_sync_aggregate(
                    recent_block_sync_committee_bits,
                    recent_block_sync_committee_signature
                )
            );

        if (verification_method_external == OPTIMISTIC_VERIFICATION_METHOD) {
            process_light_client_optimistic_update(&mut lightclient_update_build)
        } else {
            process_light_client_safe_update(
                &mut lightclient_update_build, slot, safety_level_external
            )
        };

        // Process and verify block proof
        process_block_proof(
            &recent_block_header_build,
            &target_block_header_build,
            is_historical,
            block_roots_index,
            block_root_proof,
            historical_block_root_proof,
            historical_block_summary_root,
            historical_block_summary_root_proof,
            historical_block_summary_root_gindex,
            tx_index,
            receipts_root_proof,
            receipts_root_gindex,
            receipt_proof,
            receipts_root,
            &message,
            &get_source_hypernova_core_address()
        )
    }

    /// Processes and verifies cross-chain data using finality-based verification method.
    /// This function performs complete validation through a light client finality update,
    /// ensuring that the target block and message are correctly verified against finalized headers.
    ///
    /// # Steps Involved
    /// 1. Validates verification method
    /// 2. Processes verification fee
    /// 3. Constructs recent, finalized, and target block headers
    /// 4. Constructs cross-chain message
    /// 5. Builds and processes the light client finality update
    /// 6. Verifies the block proof and message inclusion
    ///
    /// # Parameters
    /// ## Recent Block Header
    /// * recent_block_slot: Slot of the recent block
    /// * recent_block_proposer_index: Proposer index of the recent block
    /// * recent_block_parent_root: Parent root of the recent block
    /// * recent_block_state_root: State root of the recent block
    /// * recent_block_body_root: Body root of the recent block
    ///
    /// ## Finalized Block Header
    /// * recent_block_slot_finalized: Finalized block slot
    /// * recent_block_proposer_index_finalized: Finalized block proposer index
    /// * recent_block_parent_root_finalized: Finalized block parent root
    /// * recent_block_state_root_finalized: Finalized block state root
    /// * recent_block_body_root_finalized: Finalized block body root
    /// * recent_block_finality_branch: Merkle proof for the finality of the recent block
    ///
    /// ## Sync Committee
    /// * recent_block_sync_committee_bits: Sync committee participation bits
    /// * recent_block_sync_committee_signature: Signature from the sync committee
    /// * recent_block_signature_slot: Slot associated with the sync aggregate
    ///
    /// ## Block Roots (Current and Historical)
    /// * is_historical: Indicates if historical proof is being used
    /// * block_roots_index: Index in the block roots array
    /// * block_root_proof: Proof for the block root in recent blocks
    /// * historical_block_root_proof: Proof for the block root in historical summary
    /// * historical_block_summary_root: Root of the historical block summary
    /// * historical_block_summary_root_proof: Merkle proof for historical summary
    /// * historical_block_summary_root_gindex: Generalized index in the summary proof
    ///
    /// ## Target Block
    /// * slot: Slot number of the block containing the message
    /// * proposer_index: Proposer index of the target block
    /// * parent_root: Parent root hash of the target block
    /// * state_root: State root hash of the target block
    /// * body_root: Body root hash of the target block
    /// * tx_index: Index of the transaction in the block
    ///
    /// ## Receipt and Log Verification
    /// * receipts_root_proof: Merkle proof of receipts root
    /// * receipts_root_gindex: Gindex in receipts root tree
    /// * receipt_proof: Merkle proof of specific receipt
    /// * receipts_root: Root hash of receipts trie
    ///
    /// ## Cross-Chain Message
    /// * msg_id: Unique identifier of the message
    /// * source_chain_id: Origin chain ID
    /// * source_hn_address: Origin Hypernova contract address
    /// * destination_chain_id: Destination chain ID
    /// * destination_hn_address: Destination Hypernova contract address
    /// * log_hash: Hash of the emitted log
    /// * log_index: Index of the log in the receipt
    ///
    /// ## Verification Method
    /// * verification_method_external: Expected to be set to finality verification identifier
    ///
    /// # Returns
    /// * (ExtractedLog, vector<u8>): The verified and extracted log along with its hash
    ///
    /// # Aborts
    /// * ENOT_FINALITY_VERIFICATION: If the verification method is not set to finality

    public fun process_data_finality(
        account: &signer,
        // attested_header: BeaconBlockHeader,
        recent_block_slot: u64,
        recent_block_proposer_index: u64,
        recent_block_parent_root: vector<u8>,
        recent_block_state_root: vector<u8>,
        recent_block_body_root: vector<u8>,
        // finalized_header: BeaconBlockHeader,
        recent_block_slot_finalized: u64,
        recent_block_proposer_index_finalized: u64,
        recent_block_parent_root_finalized: vector<u8>,
        recent_block_state_root_finalized: vector<u8>,
        recent_block_body_root_finalized: vector<u8>,
        recent_block_finality_branch: vector<vector<u8>>,
        // sync_aggregate: SyncAggregate,
        recent_block_sync_committee_bits: vector<bool>,
        recent_block_sync_committee_signature: vector<u8>,
        recent_block_signature_slot: u64,
        // BlockRoots
        is_historical: bool,
        block_roots_index: u64,
        block_root_proof: vector<vector<u8>>,
        // Historical_Roots
        historical_block_root_proof: vector<vector<u8>>,
        historical_block_summary_root: vector<u8>,
        historical_block_summary_root_proof: vector<vector<u8>>,
        historical_block_summary_root_gindex: u64,
        slot: u64,
        proposer_index: u64,
        parent_root: vector<u8>,
        state_root: vector<u8>,
        body_root: vector<u8>,
        tx_index: u64,
        // Receipt Proof
        receipts_root_proof: vector<vector<u8>>,
        receipts_root_gindex: u64,
        receipt_proof: vector<vector<u8>>,
        receipts_root: vector<u8>,
        // Message
        msg_id: vector<u8>,
        source_chain_id: u64,
        source_hn_address: address,
        destination_chain_id: u64,
        destination_hn_address: address,
        log_hash: vector<u8>,
        log_index: u64,
        verification_method_external: u8
    ): (ExtractedLog, vector<u8>) {
        assert!(
            verification_method_external == FINALITY_VERIFICATION_METHOD,
            ENOT_FINALITY_VERIFICATION
        );
        process_verification_fee(account);
        let recent_block_header_build =
            construct_beacon_block_header(
                recent_block_slot,
                recent_block_proposer_index,
                recent_block_parent_root,
                recent_block_state_root,
                recent_block_body_root
            );
        let recent_block_header_finalized_build =
            construct_beacon_block_header(
                recent_block_slot_finalized,
                recent_block_proposer_index_finalized,
                recent_block_parent_root_finalized,
                recent_block_state_root_finalized,
                recent_block_body_root_finalized
            );
        let target_block_header_build =
            construct_beacon_block_header(
                slot,
                proposer_index,
                parent_root,
                state_root,
                body_root
            );
        let message =
            construct_message(
                msg_id,
                source_chain_id,
                source_hn_address,
                destination_chain_id,
                destination_hn_address,
                log_hash,
                log_index
            );
        let lightclient_finality_update_build =
            construct_lightclient_update(
                recent_block_signature_slot,
                option::some(recent_block_finality_branch),
                recent_block_header_build,
                option::some(recent_block_header_finalized_build),
                construct_sync_aggregate(
                    recent_block_sync_committee_bits,
                    recent_block_sync_committee_signature
                )
            );
        process_light_client_finality_update(&mut lightclient_finality_update_build);

        process_block_proof(
            &recent_block_header_finalized_build,
            &target_block_header_build,
            is_historical,
            block_roots_index,
            block_root_proof,
            historical_block_root_proof,
            historical_block_summary_root,
            historical_block_summary_root_proof,
            historical_block_summary_root_gindex,
            tx_index,
            receipts_root_proof,
            receipts_root_gindex,
            receipt_proof,
            receipts_root,
            &message,
            &get_source_hypernova_core_address()
        )
    }

    /// ================================ Private Functions ================================

    /// Processes and verifies a block proof, including:
    /// 1. Ancestry proof verification
    /// 2. Receipt proof decoding and verification
    /// 3. Message verification against extracted logs
    ///
    /// # Parameters
    /// ## Block Headers
    /// * recent_block_header: Reference to the recent block header
    /// * target_block_header: Reference to the target block header
    ///
    /// ## Block Roots Verification
    /// * is_historical: Flag indicating if historical verification is needed
    /// * block_roots_index: Index in the block roots array
    /// * block_root_proof: Merkle proof for block roots
    ///
    /// ## Historical Roots Verification
    /// * historical_block_root_proof: Proof for historical block roots
    /// * historical_block_summary_root: Root of historical block summary
    /// * historical_block_summary_root_proof: Proof for historical summary root
    /// * historical_block_summary_root_gindex: Generalized index for historical root
    ///
    /// * tx_index: Index of the transaction in the block
    ///
    /// ## Receipt Proof
    /// * receipts_root_proof: Proof for receipts root
    /// * receipts_root_gindex: Generalized index for receipts root
    /// * receipt_proof: Proof for the receipt
    /// * receipts_root: Root hash of receipts
    ///
    /// ## Message Data
    /// * message: Reference to the message to verify
    /// * source_hypernova_core_address: Reference to the source hypernova corecontract address
    ///
    /// # Returns
    /// * (Option<ExtractedLog>, vector<u8>): Tuple containing the verified log and its hash
    ///
    /// # Aborts
    /// * If receipt proof is invalid (EINVALID_RECEIPT_PROOF)
    ///
    fun process_block_proof(
        recent_block_header_build: &BeaconBlockHeader,
        target_block_header_build: &BeaconBlockHeader,
        is_historical: bool,
        // Block Roots Verification
        block_roots_index: u64,
        block_root_proof: vector<vector<u8>>,
        // Historical Roots Verification
        historical_block_root_proof: vector<vector<u8>>,
        historical_block_summary_root: vector<u8>,
        historical_block_summary_root_proof: vector<vector<u8>>,
        historical_block_summary_root_gindex: u64,
        tx_index: u64,
        // Receipt Proof
        receipts_root_proof: vector<vector<u8>>,
        receipts_root_gindex: u64,
        receipt_proof: vector<vector<u8>>,
        receipts_root: vector<u8>,
        // Message
        message: &Message,
        source_hypernova_core_address: &vector<u8>
    ): (ExtractedLog, vector<u8>) {
        let hash_tree_root_target_block_header = hash_tree_root_beacon_block_header(target_block_header_build);
        verify_ancestry_proof(
            is_historical,
            block_roots_index,
            block_root_proof,
            historical_block_root_proof,
            historical_block_summary_root,
            historical_block_summary_root_proof,
            historical_block_summary_root_gindex,
            recent_block_header_build,
            target_block_header_build,
            hash_tree_root_target_block_header
        );

        let extracted_logs =
            decode_logs_from_receipt_proof(
                receipts_root_proof,
                receipts_root_gindex,
                receipt_proof,
                receipts_root,
                tx_index,
                hash_tree_root_target_block_header
            );
        message_verification(
            message,
            &extracted_logs,
            source_hypernova_core_address
        )
    }

    /// This function supports two types of verification:
    /// 1. Historical verification: For older blocks using historical roots
    /// 2. Recent verification: For recent blocks using block roots
    ///
    /// # Parameters
    /// * is_historical: Boolean flag indicating whether to use historical verification
    /// * block_roots_index: Index in the block roots array for recent verification
    /// * block_root_proof: Merkle proof for block roots verification
    /// * historical_block_root_proof: Merkle proof for historical block roots
    /// * historical_block_summary_root: Root of the historical block summary
    /// * historical_block_summary_root_proof: Proof for historical block summary root
    /// * historical_block_summary_root_gindex: Generalized index for historical root
    /// * recent_block_header: Reference to the more recent block header
    /// * target_block_header: Reference to the target block header to verify
    /// * target_block_header_hash_tree_root: Hash tree root of the target block header
    ///
    /// # Verification Process
    /// * For historical blocks: Uses historical roots and summary proofs
    /// * For recent blocks: Uses block roots and direct merkle proofs
    fun verify_ancestry_proof(
        is_historical: bool,
        // Block Roots Verification Parameters
        block_roots_index: u64,
        block_root_proof: vector<vector<u8>>,
        // Historical Roots Verification Parameters
        historical_block_root_proof: vector<vector<u8>>,
        historical_block_summary_root: vector<u8>,
        historical_block_summary_root_proof: vector<vector<u8>>,
        historical_block_summary_root_gindex: u64,
        // Block Headers
        recent_block_header: &BeaconBlockHeader,
        target_block_header: &BeaconBlockHeader,
        target_block_header_hash_tree_root: vector<u8>
    ) {
        if (is_historical) {
            verify_historical_roots_proof(
                historical_block_root_proof,
                historical_block_summary_root_proof,
                historical_block_summary_root,
                historical_block_summary_root_gindex,
                target_block_header,
                *get_state_root(recent_block_header)
            );
        } else {
            verify_block_roots_proof(
                block_roots_index,
                block_root_proof,
                target_block_header_hash_tree_root,
                *get_state_root(recent_block_header)
            );
        };
    }

    /// Verifies the merkle proof for block roots in the beacon state.
    /// This function checks if a given block root is properly included in the beacon state's
    /// block roots array using a merkle proof.
    ///
    /// # Parameters
    /// * block_roots_index: Index in the block roots array
    /// * block_root_proof: Merkle proof for the block root
    /// * leaf_root: Hash of the block root being verified
    /// * root: Root hash of the merkle tree
    ///
    /// # Aborts
    /// * If the merkle proof is invalid (EINVALID_BLOCK_ROOT_PROOF)
    fun verify_block_roots_proof(
        block_roots_index: u64,
        block_root_proof: vector<vector<u8>>,
        leaf_root: vector<u8>,
        root: vector<u8>
    ) {
        assert!(
            verify_merkle_proof(
                leaf_root,
                block_root_proof,
                block_roots_index,
                root
            ),
            EINVALID_BLOCK_ROOT_PROOF
        );
    }

    /// Verifies the historical roots proof for a given block header.
    /// This function checks if the historical block root and summary root are correctly included
    /// in the beacon state using merkle proofs.
    /// # Parameters
    /// * historical_block_root_proof: Merkle proof for the historical block root
    /// * historical_block_summary_root_proof: Merkle proof for the historical block summary root
    /// * historical_block_summary_root: Root hash of the historical block summary
    /// * historical_block_summary_root_gindex: Generalized index of the historical block summary root
    /// * target_block_header: Reference to the target block header being verified
    /// * recent_block_state_root: State root of the recent block
    ///
    /// # Aborts
    /// * If the historical block root proof is invalid (EINVALID_BLOCK_ROOT_PROOF)
    /// * If the historical block summary root proof is invalid (EINVALID_BLOCK_SUMMARY_ROOT_PROOF)
    fun verify_historical_roots_proof(
        historical_block_root_proof: vector<vector<u8>>,
        historical_block_summary_root_proof: vector<vector<u8>>,
        historical_block_summary_root: vector<u8>,
        historical_block_summary_root_gindex: u64,
        target_block_header: &BeaconBlockHeader,
        recent_block_state_root: vector<u8>
    ) {
        verify_block_roots_proof(
            get_historical_gindex(get_slot(target_block_header)),
            historical_block_root_proof,
            hash_tree_root_beacon_block_header(target_block_header),
            historical_block_summary_root
        );
        let valid_block_summary_root_proof =
            verify_merkle_proof(
                historical_block_summary_root,
                historical_block_summary_root_proof,
                historical_block_summary_root_gindex,
                recent_block_state_root
            );
        assert!(valid_block_summary_root_proof, EINVALID_BLOCK_SUMMARY_ROOT_PROOF);
    }

    /// Computes the generalized index (gindex) of a block root within the historical root vector.
    /// This is used when verifying Merkle proofs against the historical block root storage.
    ///
    /// The gindex calculation here mimics the structure of:
    /// &Vector::<Node, SLOTS_PER_HISTORICAL_ROOT>::default(), block_root_index as u64
    ///
    /// - slot: the slot number of the block to locate in the historical root vector.
    /// - returns: the Merkle tree generalized index corresponding to the block root.
    fun get_historical_gindex(slot: u64): u64 {
        let block_root_index = slot % SLOTS_PER_HISTORICAL_ROOT;
        // Computes the Merkle leaf position of an element based on its index.
        // In SSZ, each element is broken into 32-byte chunks, so this determines
        // which leaf index in the tree corresponds to the given slot's data.
        // Compute the leaf position in the tree based on index and chunk size.
        let pos = (block_root_index * SSZ_MERKLE_CHUNK_SIZE) / 32;

        // Computes the total number of 32-byte chunks in the historical vector.
        // This determines the number of leaf nodes required for the SSZ Merkle tree.
        let chunk_count = (SLOTS_PER_HISTORICAL_ROOT * SSZ_MERKLE_CHUNK_SIZE + 31) / 32;
        // Base gindex offset for the vector subtree.
        // Since we are working with a vector of elements (e.g., &Vector<Node, 8192>::default()),
        // and not a list of sub-vectors, the base index is 1.
        // If it were a list of elements or a nested structure, base index would start from 2.
        // Compute total gindex using tree layout: 1 * base * padded_chunk_count + offset , root = 1 , base_index = 1 , root * babase_index = 1 -> didnt consider here
        (next_power_of_two(chunk_count) + pos)
    }

    /// Decodes and verifies logs from an Ethereum receipt proof.
    /// This function performs a two-step verification:
    /// 1. Verifies the receipt root is included in the block
    /// 2. Verifies the receipt is included in the receipt trie
    ///
    /// # Parameters
    /// * receipts_root_proof: Merkle proof for the receipts root
    /// * receipts_root_gindex: Generalized index of the receipts root
    /// * receipt_proof: Proof for the receipt in the receipt trie
    /// * receipts_root: Root hash of the receipts trie
    /// * tx_index: Index of the transaction in the block
    /// * target_block_header_hash_tree_root: Root hash of the target block header
    ///
    /// # Returns
    /// * Option<ExtractedLogs>: Decoded logs if verification succeeds, None otherwise
    ///
    /// # Aborts
    /// * If the receipt proof is invalid (EINVALID_RECEIPT_PROOF)
    /// * If the Ethereum trie proof is invalid (EINVALID_ETH_TRIE_PROOF)
    fun decode_logs_from_receipt_proof(
        // Receipt Proof
        receipts_root_proof: vector<vector<u8>>,
        receipts_root_gindex: u64,
        receipt_proof: vector<vector<u8>>,
        receipts_root: vector<u8>,
        tx_index: u64,
        target_block_header_hash_tree_root: vector<u8>
    ): ExtractedLogs {
        // Step 1: Verify receipt root is included in block
        let is_valid_receipt_root =
            verify_merkle_proof(
                receipts_root,
                receipts_root_proof,
                receipts_root_gindex,
                target_block_header_hash_tree_root
            );
        assert!(is_valid_receipt_root, EINVALID_RECEIPT_PROOF);

        // Step 2: Verify receipt is included in receipt trie
        let (is_valid_receipt, encoded_receipt) =
            verify_eth_trie_inclusion_proof(
                receipts_root,
                rlp_encode_u64(tx_index),
                receipt_proof
            );
        assert!(is_valid_receipt, EINVALID_ETH_TRIE_PROOF);

        // Decode and return the logs
        decode(&mut encoded_receipt)
    }

    /// Verifies a cross-chain message against extracted logs.
    /// This function performs several checks:
    /// 1. Verifies the log hash matches the message's log hash
    /// 2. Verifies the source contract address matches
    ///
    /// # Parameters
    /// * message: Reference to the cross-chain message
    /// * extracted_logs: Reference to the extracted logs
    /// * source_contract_address: Expected source hypernova contract address
    ///
    /// # Returns
    /// * (Option<ExtractedLog>, vector<u8>): Tuple containing:
    ///   - The verified log if successful
    ///   - The computed log hash
    ///
    /// # Aborts
    /// * If the log hash doesn't match (ELOG_HASH_MISMATCH)
    /// * If the source contract address is invalid (EINVALID_SOURCE_CONTRACT)
    fun message_verification(
        message: &Message,
        extracted_logs: &ExtractedLogs,
        source_contract_address: &vector<u8>
    ): (ExtractedLog, vector<u8>) {
        // Get the relevant log
        let log_index = get_log_index(message);
        let verified_log = get_log(extracted_logs, log_index);

        let log_hash = *get_address(&verified_log);
        let topics = get_topics(&verified_log);

        assert!(
            (vector::length(topics) as u8) == EXPECTED_TOPIC_COUNT_FROM_SOURCE,
            EINVALID_TOPIC_COUNT
        );
        assert!(
            *vector::borrow(topics, 0) == get_source_event_signature_hash(),
            EINVALID_SOURCE_EVENT_SIGNATURE_HASH
        );

        vector::for_each_ref(
            topics,
            |topic| {
                vector::append(&mut log_hash, *topic);
            }
        );
        vector::append(&mut log_hash, *get_data(&verified_log));
        let calculated_log_hash = keccak256(log_hash);

        assert!(
            calculated_log_hash == *get_log_hash(message),
            ELOG_HASH_MISMATCH
        );

        assert!(
            &pad_left(*get_address(&verified_log), ETHEREUM_PADDED_ADDRESS_LEN)
                == source_contract_address,
            EINVALID_SOURCE_CONTRACT
        );

        (verified_log, calculated_log_hash)
    }

    // === Test Functions ===
    #[test_only]
    public fun test_verify_ancestry_proof(
        is_historical: bool,
        block_roots_index: u64,
        block_root_proof: vector<vector<u8>>,
        historical_block_root_proof: vector<vector<u8>>,
        historical_block_summary_root: vector<u8>,
        historical_block_summary_root_proof: vector<vector<u8>>,
        historical_block_summary_root_gindex: u64,
        recent_block_header: &BeaconBlockHeader,
        target_block_header: &BeaconBlockHeader,
        target_block_header_hash_tree_root: vector<u8>
    ) {
        verify_ancestry_proof(
            is_historical,
            block_roots_index,
            block_root_proof,
            historical_block_root_proof,
            historical_block_summary_root,
            historical_block_summary_root_proof,
            historical_block_summary_root_gindex,
            recent_block_header,
            target_block_header,
            target_block_header_hash_tree_root
        );
    }

}
