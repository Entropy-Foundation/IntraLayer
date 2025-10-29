/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
/// 
/// This module defines the interaction between ethereum chain and hypernova protocol and poel 
///
module dfmm_framework::evm_hypernova_adapter {
    use hypernova_core::proof_verifier::{
        process_data_optimistic_or_safe
    };
    use hypernova_core::message_types::{ExtractedLog, get_topics, get_data};
    use std::block;
    use std::vector;
    use std::chain_id;
    use aptos_std::signer;
    use aptos_std::error;
    use aptos_std::object;
    use aptos_std::from_bcs;
    use supra_framework::event;
    use supra_framework::timestamp;
    use dfmm_framework::iAsset;
    use dfmm_framework::config;
    use dfmm_framework::asset_util;
    use dfmm_framework::poel::{borrow_request};
    use aptos_std::smart_table::{Self, SmartTable};

    const EINVALID_MESSAGE_DATA_SIZE: u64 = 1;

    const EEVENT_ALREADY_EXECUTED: u64 = 2;

    const EINVALID_SOURCE_TOKEN_BRIDGE_ADDRESS: u64 = 3;

    const EINVALID_EVENT_TOPICS_LENGTH: u64 = 4;

    const EPAUSED: u64 = 5;

    /// Maximum verification strategy types exceeded. The number of verification strategies exceeds the maximum allowed.
    const EINVALID_VERIFICATION_STRATEGY_TYPE_RANGE: u64 = 6;

    const MESSAGE_DATA_SIZE: u64 = 320;

    const NUM_EVENT_TOPICS: u64 = 3;

    const STORAGE_SEED: vector<u8> = b"EvmHypernovaAdapterStorage";

    /// Represents the finality verification method.
    const FINALITY_VERIFICATION_METHOD: u8 = 1;

    /// Represents the optimistic verification method.
    const OPTIMISTIC_VERIFICATION_METHOD: u8 = 3;

    /// Minimum supported verification strategy type.
    const MIN_VERIFICATION_STRATEGY_TYPE: u8 = 1;

    /// Maximum supported verification strategy type.
    const MAX_VERIFICATION_STRATEGY_TYPE: u8 = 3;

    #[event]
    struct ExtractedMessageDataEvent has store, drop {
        /// verification method used for the transaction
        verification_strategy_type: u8,
        /// safety level used for the transaction
        safety_level: u8,
        /// Amount of tokens being transferred
        amount: u64,
        /// Fee charged by the bridge service
        bridge_service_fee: u64,
        /// Reward for the relayer who processed the transaction
        relayer_reward: u64,
        /// Chain ID where tokens are being delivered
        dest_chain_id: u8,
        /// Block height when processed
        dest_block_height: u64,
        /// When the transaction was processed
        dest_timestamp: u64,
        /// Address of the wrapped token on destination
        dest_token_addr: address,
        /// Chain ID of the source blockchain
        source_chain_id: u64,
        /// Unique identifier for the cross-chain transaction
        message_id: vector<u8>,
        /// Address of the token bridge on the source chain
        source_token_bridge_addr: vector<u8>,
        /// Address of the token sender on the source chain
        sender_addr: vector<u8>,
        /// Address of the original token on the source chain
        source_token_addr: vector<u8>,
        /// Additional data associated with the transfer
        payload: vector<u8>,
        /// Address receiving the wrapped tokens
        recipient_addr: vector<u8>
    }

    #[event]
    struct ExecutionEvent has store, drop {
        /// Index of the log entry in the source chains event log
        log_index: u64,
        /// Unique identifier for the message, used for deduplication
        message_id: vector<u8>,
        /// Hash of the log entry containing the message, used for verification
        extracted_log_hash: vector<u8>
    }

    #[event]
    struct VerificationStrategyUpdatedEvent has store, drop {
        verification_strategy_type: u8,
        safety_level: u8,
    }

    struct TokenBridgeState has key {
        verification_strategy_type: u8,
        safety_level: u8,
        paused: bool,
        processed_event_hashes: SmartTable<vector<u8>, bool>,
    }

    fun init_module(account: &signer) {
        let constructor_ref = &object::create_named_object(account, STORAGE_SEED);
        let obj_signer = &object::generate_signer(constructor_ref);

        move_to(
            obj_signer,
            TokenBridgeState {
                verification_strategy_type: OPTIMISTIC_VERIFICATION_METHOD,
                safety_level: 20, // initial; value
                paused: false,
                processed_event_hashes: smart_table::new(),
            }
        );
    }

    entry fun execute_optimistic_or_safe(
        account: &signer,
        recent_block_slot: u64,
        recent_block_proposer_index: u64,
        recent_block_parent_root: vector<u8>,
        recent_block_state_root: vector<u8>,
        recent_block_body_root: vector<u8>,
        recent_block_sync_committee_bits: vector<bool>,
        recent_block_sync_committee_signature: vector<u8>,
        recent_block_signature_slot: u64,
        is_historical: bool,
        block_roots_index: u64,
        block_root_proof: vector<vector<u8>>,
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
        receipts_root_proof: vector<vector<u8>>,
        receipts_root_gindex: u64,
        receipt_proof: vector<vector<u8>>,
        receipts_root: vector<u8>,
        message_id: vector<u8>,
        source_chain_id: u64,
        source_hn_address: vector<u8>,
        destination_chain_id: u64,
        destination_hn_address: vector<u8>,
        log_hash: vector<u8>,
        log_index: u64,
    ) acquires TokenBridgeState {
        let bridge_ref = get_bridge_state_mut();
        assert!(!bridge_ref.paused, error::invalid_state(EPAUSED));

        let source_hn_address = from_bcs::to_address(source_hn_address);
        let destination_hn_address = from_bcs::to_address(destination_hn_address);

        let (extracted_log, extracted_log_hash) = process_data_optimistic_or_safe(
            account,
            recent_block_slot,
            recent_block_proposer_index,
            recent_block_parent_root,
            recent_block_state_root,
            recent_block_body_root,
            recent_block_sync_committee_bits,
            recent_block_sync_committee_signature,
            recent_block_signature_slot,
            is_historical,
            block_roots_index,
            block_root_proof,
            historical_block_root_proof,
            historical_block_summary_root,
            historical_block_summary_root_proof,
            historical_block_summary_root_gindex,
            slot,
            proposer_index,
            parent_root,
            state_root,
            body_root,
            tx_index,
            receipts_root_proof,
            receipts_root_gindex,
            receipt_proof,
            receipts_root,
            message_id,
            source_chain_id,
            source_hn_address,
            destination_chain_id,
            destination_hn_address,
            log_hash,
            log_index,
            bridge_ref.verification_strategy_type,
            bridge_ref.safety_level
        );
        record_executed_event_hash(bridge_ref, extracted_log_hash);
        process_rent_event(signer::address_of(account), bridge_ref.verification_strategy_type, bridge_ref.safety_level, extracted_log);

        event::emit(ExecutionEvent { log_index, message_id, extracted_log_hash });
    }

    public entry fun set_verification_strategy_type(account: &signer, verification_strategy_type: u8, safety_level: u8) acquires TokenBridgeState {
        config::assert_admin(account);

        let ref = get_bridge_state_mut();
        assert!(!ref.paused, error::invalid_state(EPAUSED));
        assert!(
            verification_strategy_type >= MIN_VERIFICATION_STRATEGY_TYPE
                && verification_strategy_type <= MAX_VERIFICATION_STRATEGY_TYPE,
            error::invalid_state(EINVALID_VERIFICATION_STRATEGY_TYPE_RANGE)
        );

        ref.verification_strategy_type = verification_strategy_type;
        ref.safety_level = safety_level; // no validation for the safety level for now

        event::emit(VerificationStrategyUpdatedEvent { verification_strategy_type, safety_level });
    }

    public entry fun set_pause(account: &signer, paused: bool) acquires TokenBridgeState {
        config::assert_admin(account);
        let bridge_state = get_bridge_state_mut();
        bridge_state.paused = paused;
    }

    fun process_rent_event(relayer: address, verification_strategy_type: u8, safety_level: u8, extracted_log: ExtractedLog) {
        // Extract and validate message data
        let message_data = get_data(&extracted_log);
        assert!(
            vector::length(message_data) == MESSAGE_DATA_SIZE,
            error::invalid_state(EINVALID_MESSAGE_DATA_SIZE)
        );

        let event_topics = get_topics(&extracted_log);
        assert!(
            vector::length(event_topics) >= NUM_EVENT_TOPICS,
            error::invalid_state(EINVALID_EVENT_TOPICS_LENGTH)
        );

        let source_bridge_address = *vector::borrow(event_topics, 1);
        let message_id = *vector::borrow(event_topics, 2);

        let (sender_address,
            source_token_address,
            source_chain_id_bytes
        ) = parse_header_fields(message_data);

        vector::reverse(&mut source_chain_id_bytes);
        let source_chain_id = (from_bcs::to_u256(source_chain_id_bytes) as u64);

        assert!(
            iAsset::is_bridge_valid(source_token_address, source_chain_id, source_bridge_address),
            error::invalid_state(EINVALID_SOURCE_TOKEN_BRIDGE_ADDRESS)
        );

        let (transfer_payload,
            final_amount,
            service_fee,// it includes relayer reward as well
            relayer_reward,
            recipient_address
        ) = parse_transfer_details(message_data);

        let reciever = from_bcs::to_address(recipient_address);
        let iasset = iAsset::get_iasset_metadata(source_token_address, source_chain_id);
        let (_, _, source_token_decimals, _) = iAsset::deconstruct_iasset_source(&iAsset::get_iasset_source(iasset));

        // Solidity contract normalizes the amount ONLY if token has > 8 decimals.
        // But poel model expects that any iasset has 8 decimals. So, it is required to scale up
        // if original token decimals < 8

        // normalized asset amount for the user
        let n_user_amount = scale_up_to_fa_decimals(final_amount, source_token_decimals);
        // normalized asset amount as a service fee (service_fee contains relayer rewards)
        let n_service_fee_amount = scale_up_to_fa_decimals((service_fee - relayer_reward), source_token_decimals);
        // normalzed asset amount for the relayer
        let n_relayer_fee_amount = scale_up_to_fa_decimals(relayer_reward, source_token_decimals);

        borrow_request(iasset,
            n_user_amount, reciever,  // user portion
            n_service_fee_amount, config::get_service_fees_address(), // services fees includes rewards fee
            n_relayer_fee_amount,  relayer // relayer rewards
        );

        event::emit(
            ExtractedMessageDataEvent {
                verification_strategy_type,
                safety_level,
                amount: final_amount,
                bridge_service_fee : service_fee,
                relayer_reward,
                dest_chain_id: chain_id::get(),
                dest_block_height: block::get_current_block_height(),
                dest_timestamp: timestamp::now_seconds(),
                dest_token_addr: iAsset::get_asset_address(iasset),
                source_chain_id: source_chain_id,
                message_id,
                source_token_bridge_addr: source_bridge_address,
                sender_addr: sender_address,
                source_token_addr : source_token_address,
                payload: transfer_payload,
                recipient_addr : recipient_address
            }
        );
    }

    fun scale_up_to_fa_decimals (value:u64, source_token_decimals:u16):u64 {
        if (source_token_decimals < 8)
            (asset_util::scale((value as u128), source_token_decimals, 8) as u64)
        else value
    }

    fun parse_header_fields(message_data: &vector<u8>): (vector<u8>, vector<u8>, vector<u8>) {
        let sender_address = vector::slice(message_data, 64, 96);
        let source_token_address = vector::slice(message_data, 96, 128);
        let source_chain_id_bytes = vector::slice(message_data, 128, 160);
        (sender_address, source_token_address, source_chain_id_bytes)
    }

    fun record_executed_event_hash(ref: &mut TokenBridgeState, hash: vector<u8>) {
        let processed_event_hashes = &mut ref.processed_event_hashes;
        assert!(
            !smart_table::contains(processed_event_hashes, hash),
            error::invalid_state(EEVENT_ALREADY_EXECUTED)
        );
        smart_table::add(processed_event_hashes, hash, true);
    }

    fun parse_transfer_details(message_data: &vector<u8>): (vector<u8>, u64, u64, u64, vector<u8>) {
        let transfer_payload = vector::slice(message_data, 160, 192);
        let final_amount = asset_util::bytes_to_u64(vector::slice(message_data, 192, 224));
        let fee_cut_to_service = asset_util::bytes_to_u64(vector::slice(message_data, 224, 256));
        let relayer_reward = asset_util::bytes_to_u64(vector::slice(message_data, 256, 288));
        let recipient_address = vector::slice(message_data, 288, 320);

        (transfer_payload, final_amount, fee_cut_to_service, relayer_reward, recipient_address)
    }

    fun get_storage_address(): address {
        object::create_object_address(&@dfmm_framework, STORAGE_SEED)
    }

    #[view]
    public fun has_executed_event_hash(hash: vector<u8>): bool acquires TokenBridgeState {
        let processed_event_hashes =
            &borrow_global<TokenBridgeState>(get_storage_address()).processed_event_hashes;
        smart_table::contains(processed_event_hashes, hash)
    }

    #[view]
    /// Returns paused, verification_strategy_type, safety_level
    public fun status(): (bool, u8, u8) acquires TokenBridgeState {
        let ref = borrow_global<TokenBridgeState>(get_storage_address());
        (ref.paused, ref.verification_strategy_type, ref.safety_level)
    }

    inline fun get_bridge_state_mut(): &mut TokenBridgeState acquires TokenBridgeState {
        borrow_global_mut<TokenBridgeState>(get_storage_address())
    }

    #[test_only]
    public fun init_module_for_test(deployer: &signer) {
        init_module(deployer);
    }

    #[test_only]
    public fun process_extracted_log (relayer:address, extracted_log: ExtractedLog, extracted_log_hash: vector<u8>) acquires TokenBridgeState {
        let bridge_ref = get_bridge_state_mut();
        record_executed_event_hash(bridge_ref, extracted_log_hash);
        process_rent_event(relayer, bridge_ref.verification_strategy_type, bridge_ref.safety_level, extracted_log);
    }

    #[test_only]
    public fun record_executed_event_hash_for_test (log_hash: vector<u8>) acquires TokenBridgeState {
        let bridge_ref = get_bridge_state_mut();
        record_executed_event_hash(bridge_ref, log_hash);
    }    
}