/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
module hypernova_core::message_types {
    use std::vector;
    use std::option::{Self, Option, some, none};
    use aptos_std::from_bcs;
    use hypernova_core::helpers::{
        to_be_bytes_trimmed,
        static_left_pad,
        from_be_bytes
    };

    friend hypernova_core::proof_verifier;

    //=== Error Codes ===

    /// The RLP type provided is invalid. The receipt type is of an unsupported or malformed type, indicating an incorrect or corrupted RLP encoding.
    const EINVALID_RLP_TYPE: u64 = 6000;

    /// The receipt type is invalid. It must be in the range of 0 to 3 according to the EIP-2718 specification.
    const EINVALID_RECEIPT_TYPE: u64 = 6001;

    /// The RLP header is invalid. The RLP-encoded data should begin with a list header, but the header is not recognized as a valid list.
    const EINVALID_RLP_HEADER: u64 = 6002;

    /// Error code for missing option value during extraction of RLP header (invalid option).
    const EINVALID_RLP_HEADER_OPTION: u64 = 6003;

    /// Invalid receipt status. The receipt status is not valid or does not match the expected value.
    const EINVALID_RECEIPT_STATUS: u64 = 6004;

    /// The logs list header is invalid. The RLP-encoded logs section must be a list, but the header is not recognized as a valid list.
    const EINVALID_RLP_LOGS_LIST_HEADER: u64 = 6005;

    /// Error code for missing option value during extraction of logs list header.
    const EINVALID_LOGS_LIST_HEADER_OPTION: u64 = 6006;

    /// The RLP log item is invalid. Each log must be a list, but a non-list was encountered.
    const EINVALID_LOG_ITEM: u64 = 6007;

    /// Error code for missing option value when extracting log item during decoding.
    const EINVALID_LOG_ITEM_OPTION: u64 = 6008;

    /// Error code for missing option value when extracting event data during decoding.
    const EINVALID_HEADER_OPTION: u64 = 6009;

    /// Error code for missing option value when extracting event topics during decoding.
    const EINVALID_LOG_TOPIC_LIST_HEADER_OPTION: u64 = 6010;

    /// Invalid data length. The data length is invalid or does not match the expected value.
    const EINVALID_DATA_LENGTH: u64 = 6011;

    /// Error code for missing option value when extracting header status option during decoding.
    const EINVALID_HEADER_STATUS_OPTION: u64 = 6012;

    //=== Constants ===

    /// Encoding identifier for an empty string (RLP base for short strings).
    const EMPTY_STRING_CODE: u8 = 0x80;

    /// Encoding identifier for an empty list (RLP base for short lists).
    const EMPTY_LIST_CODE: u8 = 0xC0;

    /// RLP prefix for long strings (length-of-length encoding starts after this).
    const LONG_STRING_PREFIX: u8 = 0xB7;

    /// RLP prefix for long lists (length-of-length encoding starts after this).
    const LONG_LIST_PREFIX: u8 = 0xF7;

    /// Maximum RLP prefix byte for long strings.
    const LONG_STRING_MAX: u8 = 0xBF;

    /// Maximum RLP prefix byte for long lists.
    const LONG_LIST_MAX: u8 = 0xFF;

    /// Maximum byte value for single byte RLP encoding.
    const SINGLE_BYTE_MAX: u8 = 0x7F;

    /// Maximum valid receipt type according to the specification (EIP-2718).
    const MAX_RECEIPT_TYPE: u8 = 3;

    //=== Structs ===
    /// Represents a cross-chain message in the Hypernova network.
    ///
    /// # Overview
    /// This struct encapsulates all necessary information to uniquely identify,
    /// verify, and process a message between two chains in the Hypernova network.
    ///
    /// # Fields
    /// - event_log_index: Index in the source chains event log (for ordering and lookup)
    /// - source_chain_id: Identifier of the originating blockchain
    /// - dest_chain_id: Identifier of the target blockchain
    /// - source_hypernova_addr: Hypernova contract address on source chain
    /// - dest_hypernova_addr: Hypernova contract address on destination chain
    /// - message_id: Unique identifier for deduplication and tracking
    /// - event_log_hash: Hash of the event log entry for verification
    struct Message has copy, drop {
        event_log_index: u64,
        source_chain_id: u64,
        dest_chain_id: u64,
        source_hypernova_addr: address,
        dest_hypernova_addr: address,
        message_id: vector<u8>,
        event_log_hash: vector<u8>
    }

    /// Represents an event log extracted from a blockchain transaction.
    ///
    /// # Overview
    /// Contains the essential components of an Ethereum-style event log,
    /// prepared for cross-chain message processing.
    ///
    /// # Fields
    /// - contract_addr: Address of the contract that emitted the event (20 bytes)
    /// - event_topics: List of indexed event parameters (32 bytes each)
    /// - event_data: Non-indexed event parameters
    struct ExtractedLog has copy, drop {
        contract_addr: vector<u8>,
        event_topics: vector<vector<u8>>,
        event_data: vector<u8>
    }

    /// Container for multiple event logs from a single transaction.
    ///
    /// # Overview
    /// Holds a collection of ExtractedLog entries from one transaction execution.
    ///
    /// # Fields
    /// - logs: Vector of individual event logs
    struct ExtractedLogs has copy, drop {
        logs: vector<ExtractedLog>
    }

    /// Represents the header of an RLP-encoded item.
    /// Contains metadata about the encoded item's structure.
    /// 
    /// # Overview
    /// This struct is used to decode RLP headers and determine
    /// the type and length of the encoded data.
    /// 
    /// # Fields
    /// - is_list: Indicates if the RLP item is a list (true) or a string (false)
    /// - payload_length: Length of the RLP-encoded payload in bytes
    struct RlpHeader has copy, drop {
        is_list: bool,
        payload_length: u64
    }

    /// Constructor and Getters for Message
    public(friend) fun construct_message(
        message_id: vector<u8>,
        source_chain_id: u64,
        source_hn_address: address,
        destination_chain_id: u64,
        destination_hn_address: address,
        log_hash: vector<u8>,
        log_index: u64
    ): Message {
        Message {
            event_log_index: log_index,
            source_chain_id,
            dest_chain_id: destination_chain_id,
            source_hypernova_addr: source_hn_address,
            dest_hypernova_addr: destination_hn_address,
            message_id,
            event_log_hash: log_hash
        }
    }

    // Getters for Message
    public(friend) fun get_msg_id(msg: &Message): &vector<u8> {
        &msg.message_id
    }

    public(friend) fun get_source_chain_id(msg: &Message): u64 {
        msg.source_chain_id
    }

    public(friend) fun get_source_hn_address(msg: &Message): address {
        msg.source_hypernova_addr
    }

    public(friend) fun get_destination_chain_id(msg: &Message): u64 {
        msg.dest_chain_id
    }

    public(friend) fun get_destination_hn_address(msg: &Message): address {
        msg.dest_hypernova_addr
    }

    public(friend) fun get_log_hash(msg: &Message): &vector<u8> {
        &msg.event_log_hash
    }

    public(friend) fun get_log_index(msg: &Message): u64 {
        msg.event_log_index
    }

    // Getters for ExtractedLogs
    public(friend) fun get_log(
        extracted_logs: &ExtractedLogs, log_index: u64
    ): ExtractedLog {
        *vector::borrow<ExtractedLog>(&extracted_logs.logs, log_index)
    }

    public(friend) fun get_address(log: &ExtractedLog): &vector<u8> {
        &log.contract_addr
    }

    public(friend) fun get_topic(log: &ExtractedLog, index: u64): &vector<u8> {
        vector::borrow(&log.event_topics, index)
    }

    public fun get_topics(log: &ExtractedLog): &vector<vector<u8>> {
        &log.event_topics
    }

    public fun get_data(log: &ExtractedLog): &vector<u8> {
        &log.event_data
    }

    /// Encodes a u64 value into RLP format as a byte vector.
    ///
    /// RLP rules for encoding unsigned integers:
    /// - 0 is encoded as the single byte 0x80 (empty string marker).
    /// - Values less than 128 (0x80) are encoded as a single byte (literal value).
    /// - Values >= 128 are encoded as: [0x80 + length_of_big_endian_bytes] + big_endian_bytes.
    public(friend) fun rlp_encode_u64(data: u64): vector<u8> {
        let encoded_data = vector::empty<u8>();
        if (data == 0) {
            vector::push_back(&mut encoded_data, EMPTY_STRING_CODE);
            return encoded_data
        };
        if (data < (EMPTY_STRING_CODE as u64)) {
            vector::push_back(&mut encoded_data, (data as u8));
            return encoded_data
        };
        let be_data = to_be_bytes_trimmed(data);
        vector::push_back(
            &mut encoded_data,
            (((EMPTY_STRING_CODE as u64) + vector::length(&be_data)) as u8)
        );
        vector::append(&mut encoded_data, be_data);
        encoded_data
    }

    /// Decodes an RLP-encoded receipt and extracts logs from it.
    public(friend) fun decode(buf: &mut vector<u8>): ExtractedLogs {
        // Read the first byte to determine the RLP type.
        let rlp_type = *vector::borrow(buf, 0);

        // Ensure the RLP type is not an empty list.
        assert!(rlp_type != EMPTY_LIST_CODE, EINVALID_RLP_TYPE);

        // If it's a string type (not a list), check for typed receipts (EIP-2718).
        if (rlp_type < EMPTY_LIST_CODE) {
            let receipt_type = *vector::borrow(buf, 0);

            // Ensure the receipt type is valid (0 to 3).
            assert!(receipt_type <= MAX_RECEIPT_TYPE, EINVALID_RECEIPT_TYPE);

            // Remove the receipt type prefix byte.
            vector::remove(buf, 0);
        };

        // Initialize an empty list to collect extracted logs.
        let logs_list = ExtractedLogs {
            logs: vector::empty<ExtractedLog>()
        };

        let b = &mut *buf;

        // Decode the outer header for the full receipt.
        let rlp_head = extract_or_abort(&mut decode_header(b), EINVALID_RLP_HEADER_OPTION);
        // Ensure the RLP item is a list.
        assert!(rlp_head.is_list, EINVALID_RLP_HEADER);

        // Decode the header of the status field.
        let head_status = extract_or_abort(&mut decode_header(b), EINVALID_HEADER_STATUS_OPTION);
        let status = vector::slice(b, 0, head_status.payload_length);

        // Ensure the status is true (EIP-658: status == 1 means success).
        assert!(from_bcs::to_bool(status), EINVALID_RECEIPT_STATUS);

        // Skip gas used, bloom filter, etc., by decoding and advancing over 3 elements.
        for (_i in 0..3) {
            let head = extract_or_abort(&mut decode_header(b), EINVALID_HEADER_OPTION);
            advance(b, head.payload_length);
        };

        // Decode the logs list header.
        let logs_head = extract_or_abort(&mut decode_header(b), EINVALID_LOGS_LIST_HEADER_OPTION);
        // Ensure the logs head is a list.
        assert!(logs_head.is_list, EINVALID_RLP_LOGS_LIST_HEADER);

        // Iterate while there is data in the buffer.
        while (!vector::is_empty(b)) {
            let log = ExtractedLog {
                contract_addr: vector::empty<u8>(),
                event_topics: vector::empty<vector<u8>>(),
                event_data: vector::empty<u8>()
            };

            // Decode each log entry (RLP list expected).
            let item_head = extract_or_abort(&mut decode_header(b), EINVALID_LOG_ITEM_OPTION);

            // Ensure the log item is a list.
            assert!(item_head.is_list, EINVALID_LOG_ITEM);

            // Decode the contract address from the log.
            log.contract_addr = option::extract(&mut decode_bytes(b));

            // Decode the topic list header and extract topics.
            let topic_list_head = extract_or_abort(&mut decode_header(b), EINVALID_LOG_TOPIC_LIST_HEADER_OPTION);
            let len = topic_list_head.payload_length / 32;
            decode_topics(&mut log, b, len);
            // Decode event data and push the log to the list.
            log.event_data = option::extract(&mut decode_bytes(b));
            vector::push_back(&mut logs_list.logs, log)
        };

        // Return the successfully decoded logs list.
        logs_list
    }

    //=== Private Functions ===

    fun decode_topics(log: &mut ExtractedLog, buf: &mut vector<u8>, len: u64) {
        for (_i in 0..len) {
            vector::push_back(
                &mut log.event_topics, option::extract(&mut decode_bytes(buf))
            );
        };
    }

    fun advance(b: &mut vector<u8>, cnt: u64) {
        let len = vector::length(b);
        assert!(len >= cnt, EINVALID_DATA_LENGTH);
        *b = vector::slice(b, cnt, len);
    }

    fun decode_header(buf: &mut vector<u8>): Option<RlpHeader> {
        let payload_length: u64;
        let is_list: bool = false;

        let b = get_next_byte(buf);

        if (b <= SINGLE_BYTE_MAX) {
            // Single literal byte (e.g., 0x01).
            payload_length = 1;
        } else if (b >= EMPTY_STRING_CODE && b <= LONG_STRING_PREFIX) {
            // Short string: payload length is directly encoded.
            vector::remove(buf, 0);
            payload_length = ((b - EMPTY_STRING_CODE) as u64);

            // Reject non-canonical single byte (e.g., 0x01 encoded as 0x81 0x01).
            if (payload_length == 1 && get_next_byte(buf) < EMPTY_STRING_CODE) {
                return none()
            }
        } else if ((b > LONG_STRING_PREFIX
            && b <= LONG_STRING_MAX)
            || (b > LONG_LIST_PREFIX
            && b <= LONG_LIST_MAX)) {
            // Long string or list with a length-of-length encoding.
            vector::remove(buf, 0);
            is_list = b >= LONG_LIST_PREFIX;

            let base_prefix =
                if (is_list) {
                    LONG_LIST_PREFIX
                } else {
                    LONG_STRING_PREFIX
                };
            let len_of_len = ((b - base_prefix) as u64);

            if (len_of_len == 0 || len_of_len > 8) {
                return none()
            };
            if (vector::length(buf) < len_of_len) {
                return none()
            };

            let len_bytes = vector::slice(buf, 0, len_of_len);
            advance(buf, len_of_len);

            let len = from_be_bytes(static_left_pad(len_bytes));
            payload_length = len;

            // Ensure canonical encoding (long strings/lists must have payload_length >= 56).
            if (payload_length < 56) {
                return none()
            }
        } else if (b >= EMPTY_LIST_CODE && b <= LONG_LIST_PREFIX) {
            // Short list: payload length is directly encoded.
            vector::remove(buf, 0);
            is_list = true;
            payload_length = ((b - EMPTY_LIST_CODE) as u64);
        } else {
            // Invalid or unsupported RLP encoding.
            return none()
        };

        // Ensure theres enough data left in the buffer.
        if (vector::length(buf) < payload_length) {
            return none()
        };

        some(RlpHeader { is_list, payload_length })
    }

    /// Decodes an RLP-encoded byte string from the input buffer.
    /// Returns Some(bytes) if successful, or None if:
    /// - The RLP item is a list (not a string),
    /// - The buffer does not have enough data to read the declared payload length.
    fun decode_bytes(buf: &mut vector<u8>): Option<vector<u8>> {
        let header = option::extract(&mut decode_header(buf));
        if (header.is_list || vector::length(buf) < header.payload_length) {
            return none() // Unexpected type error
        };
        extract_payload(buf, header.payload_length)
    }


    fun extract_payload(buf: &mut vector<u8>, payload_length: u64): Option<vector<u8>> {
        let bytes = vector::slice(buf, 0, payload_length);
        advance(buf, payload_length);
        some(bytes)
    }


    /// Extracts a value from an option or aborts with the given error code if it is `none`.
    ///
    /// # Parameters
    /// * `opt` - The option to extract from.
    /// * `error_code` - The error code to abort with if the option is `none`.
    ///
    /// # Returns
    /// * The unwrapped value.
    fun extract_or_abort(opt: &mut Option<RlpHeader>, error_code: u64): RlpHeader {
        assert!(option::is_some(opt), error_code);
        option::extract(opt)
    }

    /// Returns the first byte in a vector.
    /// Assumes the vector has at least one byte.
    inline fun get_next_byte(buf: &vector<u8>): u8 {
        *vector::borrow(buf, 0)
    }

    //=== test functions ===
    #[test_only]
    public fun test_decode(buf: &mut vector<u8>): ExtractedLogs {
        decode(buf)
    }
    #[test_only]
    public fun test_construct_extracted_log(
        contract_addr: vector<u8>,
        event_topics: vector<vector<u8>>,
        event_data: vector<u8>
    ): ExtractedLog {
        ExtractedLog {
            contract_addr,
            event_topics,
            event_data
        }
    }
    #[test_only]
    public fun test_get_msg_id(msg: &Message): &vector<u8> {
        get_msg_id(msg)
    }
    #[test_only]
    public fun test_get_source_chain_id(msg: &Message): u64 {
        get_source_chain_id(msg)
    }
    #[test_only]
    public fun test_get_source_hn_address(msg: &Message): address {
        get_source_hn_address(msg)
    }
    #[test_only]
    public fun test_get_destination_chain_id(msg: &Message): u64 {
        get_destination_chain_id(msg)
    }
    #[test_only]
    public fun test_get_log_hash(msg: &Message): &vector<u8> {
        get_log_hash(msg)
    }
    #[test_only]
    public fun test_get_log_index(msg: &Message): u64 {
        get_log_index(msg)
    }

    #[test_only]
    public fun test_get_destination_hn_address(msg: &Message): address {
        get_destination_hn_address(msg)
    }

    #[test_only]
    public fun test_get_data(log: &ExtractedLog): &vector<u8> {
        get_data(log)
    }

    #[test_only]
    public fun test_get_address(log: &ExtractedLog): &vector<u8> {
        get_address(log)
    }
    #[test_only]
    public fun test_get_topic(log: &ExtractedLog, index: u64): &vector<u8> {
        get_topic(log, index)
    }
    #[test_only]
    public fun test_get_topics(log: &ExtractedLog): &vector<vector<u8>> {
        get_topics(log)
    }
    #[test_only]
    public fun test_construct_extracted_logs(
        logs: vector<ExtractedLog>
    ): ExtractedLogs {
        ExtractedLogs { logs }
    }
    #[test_only]
    public fun test_construct_message(
        message_id: vector<u8>,
        source_chain_id: u64,
        source_hn_address: address,
        destination_chain_id: u64,
        destination_hn_address: address,
        log_hash: vector<u8>,
        log_index: u64
    ): Message {
        construct_message(
            message_id,
            source_chain_id,
            source_hn_address,
            destination_chain_id,
            destination_hn_address,
            log_hash,
            log_index
        )
    }


    #[test_only]
    public fun test_rlp_encode_u64(data: u64): vector<u8> {
        rlp_encode_u64(data)
    }
    #[test_only]
    public fun test_advance(b: &mut vector<u8>, cnt: u64) {
        advance(b, cnt);
    }
    #[test_only]
    public fun test_get_log(
        extracted_logs: &ExtractedLogs,
        log_index: u64
    ): ExtractedLog {
        get_log(extracted_logs, log_index)
    }


    #[test_only]
    public fun create_extracted_log(
        address: vector<u8>,
        // 20 bytes
        topics: vector<vector<u8>>,
        // List of 32-byte topics
        data: vector<u8>
    ): ExtractedLog {
        ExtractedLog {
            contract_addr: address,
            // 20 bytes
            event_topics: topics,
            // List of 32-byte topics
            event_data: data
        }
    }

}