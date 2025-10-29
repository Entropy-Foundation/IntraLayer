/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
module hypernova_core::helpers {
    use std::vector;
    use std::hash;
    use std::bcs;
    use std::from_bcs;
    use aptos_std::math64::floor_log2;

    //Error codes

    /// Invalid padding length. The input vector length exceeds the padding amount.
    const EINVALID_PADDING_LENGTH: u64 = 4000;

    /// Invalid data length. The data length is invalid or does not match the expected value.
    const EINVALID_DATA_LENGTH: u64 = 4001;

    /// Invalid byte length. The byte vector length is invalid or does not match the expected value.
    const EINVALID_BYTE_LENGTH: u64 = 4002;

    /// Computed committee updater reward exceeds u64::MAX
    const ECOMMITTEE_REWARD_OVERFLOW: u64 = 4003;

    /// Error code indicating that the committee updater margin is too high, which would cause underflow in denominator.
    /// Triggered when `cm >= PERCENTAGE_BASE`
    const ECOMMITTEE_MARGIN_TOO_HIGH: u64 = 4004;

    /// Error code indicating a division by zero while computing the committee reward.
    /// This happens if the denominator becomes zero (should not happen if `cm < PERCENTAGE_BASE`)
    const ECOMMITTEE_DIVISION_BY_ZERO: u64 = 4005;

    /// Error code indicating a division by zero while computing the verification fee.
    /// Triggered when `x == 0`
    const EVERIFICATION_DIVISION_BY_ZERO: u64 = 4006;

    /// Error code indicating that the verifier margin is too high, which would cause underflow in denominator.
    /// Triggered when `vm >= PERCENTAGE_BASE`
    const EVERIFICATION_MARGIN_TOO_HIGH: u64 = 4007;


    // constant
    /// The expected length of an input  (8 bytes).
    const BYTES_8_LEN: u64 = 8;

    /// The expected length of an input  (32 bytes).
    const BYTES_32_LEN: u64 = 32;

    /// The base for percentage calculations.
    const PERCENTAGE_BASE: u64 = 10000;
    /// The maximum possible value for a 64-bit unsigned integer (u64).
    const U64_MAX: u64 = 18446744073709551615;


    #[view]
    /// Trims the bytes vector from the specified `start_index`, returning a new vector from that point onward.
    public fun trim_start(bytes: vector<u8>, start_index: u64): vector<u8> {
        vector::slice(&bytes, start_index, vector::length(&bytes))
    }

    #[view]
    /// Converts a u64 integer to its big-endian byte representation (8 bytes, reversed).
    public fun to_be_bytes(x: u64): vector<u8> {
        let bytes = bcs::to_bytes<u64>(&x);
        vector::reverse(&mut bytes);
        bytes
    }

    #[view]
    /// Counts the number of leading zero bits in a u64 integer.
    public fun count_leading_zeros(x: u64): u64 {
        if (x == 0) {
            return 64
        };
        63 - (floor_log2(x) as u64)
    }

    #[view]
    /// Converts a u64 to big-endian bytes and removes leading zero bytes based on bit precision.
    public fun to_be_bytes_trimmed(x: u64): vector<u8> {
        let be_bytes = to_be_bytes(x);
        let leading_zeros = count_leading_zeros(x);
        let start_index = leading_zeros / BYTES_8_LEN;
        trim_start(be_bytes, start_index)
    }

    #[view]
    /// Converts an 8-byte big-endian vector to a u64 integer.
    /// Panics if the input vector is not exactly 8 bytes long.
    public fun from_be_bytes(bytes: vector<u8>): u64 {
        assert!(vector::length(&bytes) == BYTES_8_LEN, EINVALID_BYTE_LENGTH);
        let result: u64 = 0;
        vector::reverse(&mut bytes);
        while (!vector::is_empty(&bytes)) {
            result = (result << (BYTES_8_LEN as u8)) | (vector::pop_back(&mut bytes) as u64);
        };
        result
    }


    #[view]
    /// Pads the input vector `data` with leading zero bytes to make its total length exactly 8 bytes.
    /// Panics if the data is already 8 bytes or more.
    public fun static_left_pad(data: vector<u8>): vector<u8> {
        let data_len = vector::length(&data);
        assert!(data_len < BYTES_8_LEN, EINVALID_DATA_LENGTH);
        let v = vector::empty<u8>();
        let pad_len = BYTES_8_LEN - data_len;
        let i = 0;
        while (i < pad_len) {
            vector::push_back(&mut v, 0);
            i = i + 1
        };
        vector::reverse(&mut data);
        let j = 0;
        while (j < data_len) {
            vector::push_back(&mut v, vector::pop_back(&mut data));
            j = j + 1
        };
        v
    }

    #[view]
    /// Converts a reversed byte vector to u64 by interpreting it as a little-endian u256 and casting.
    public fun bytes_to_u64(x: vector<u8>): u64 {
        vector::reverse(&mut x);
        (from_bcs::to_u256(x) as u64)
    }


    #[view]
    /// Converts a 64-bit unsigned integer (u64) into a little-endian byte representation
    /// and pads it to 32 bytes by appending zeroes.
    public fun u64_to_le_bytes32(value: u64): vector<u8> {
        let bytes = bcs::to_bytes<u64>(&value);
        pad_right(bytes, BYTES_32_LEN)
    }

    #[view]
    /// Pads the input vector with zeros on the right until the desired length is reached.
    /// If the input vector length is already equal to or greater than the pad amount, an assertion fails.
    public fun pad_right(input: vector<u8>, pad_amount: u64): vector<u8> {
        let len = vector::length<u8>(&input);
        assert!(len <= pad_amount, EINVALID_PADDING_LENGTH);
        let ret = input;
        let zeros_remaining = pad_amount - len;
        while (zeros_remaining > 0) {
            vector::push_back<u8>(&mut ret, 0);
            zeros_remaining = zeros_remaining - 1
        };
        ret
    }

    #[view]
    /// Pads a vector of bytes with leading zeros up to the specified length.
    ///
    /// # Arguments
    /// - input: The input byte vector to be padded.
    /// - pad_amount: The total desired length after padding.
    ///
    /// # Returns
    /// - A new vector of bytes padded with leading zeros.
    ///
    /// # Requirements
    /// - The input length must not exceed pad_amount.
    public fun pad_left(input: vector<u8>, pad_amount: u64): vector<u8> {
        let len = vector::length<u8>(&input);
        assert!(len <= pad_amount, EINVALID_PADDING_LENGTH);
        let ret = vector::empty<u8>();
        let zeros_remaining = pad_amount - len;
        while (zeros_remaining > 0) {
            vector::push_back<u8>(&mut ret, 0);
            zeros_remaining = zeros_remaining - 1;
        };
        vector::append<u8>(&mut ret, input);
        ret
    }

    #[view]
    /// Hashes two vectors using SHA-256.
    public fun hash_pair(left: vector<u8>, right: vector<u8>): vector<u8> {
        vector::append(&mut left, right);
        hash::sha2_256(left)
    }

    #[view]
    /// Checks if the given value is a valid margin.
    public fun is_valid_margin(value: u64): bool {
        value < PERCENTAGE_BASE
    }

    #[view]
    /// Computes the committee updater reward based on the committer updater gas cost (cg) and committee updater margin (cm).
    public fun compute_committee_updater_reward(cg: u256, cm: u64): u64 {
        assert!(cm < PERCENTAGE_BASE, ECOMMITTEE_MARGIN_TOO_HIGH); // Prevents underflow
        let denominator = ((PERCENTAGE_BASE - cm) as u256);
        assert!(denominator != 0, ECOMMITTEE_DIVISION_BY_ZERO); // Prevents division by zero

        let cr = (cg * (PERCENTAGE_BASE as u256)) / denominator;
        assert!(cr <= (U64_MAX as u256), ECOMMITTEE_REWARD_OVERFLOW);
        (cr as u64)
    }

    #[view]
    /// Computes the verification fee based on the committee updater reward (cr), expected per day traffic (x), and verifier margin (vm).
    public fun compute_verification_fee(cr: u64, x: u64, vm: u64): u64 {
        assert!(x != 0, EVERIFICATION_DIVISION_BY_ZERO);
        assert!(vm < PERCENTAGE_BASE, EVERIFICATION_MARGIN_TOO_HIGH); // prevents underflow

        let v = ((cr / x) * PERCENTAGE_BASE) / (PERCENTAGE_BASE - vm);
        v
    }
}
