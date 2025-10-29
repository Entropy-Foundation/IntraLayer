/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
module hypernova_core::eth_types {
    use std::vector;
    use std::hash;
    use std::option::Option;
    use aptos_std::bls12381::{
        Signature,
        signature_from_bytes,
        PublicKey,
        PublicKeyWithPoP
    };
    use aptos_std::math64::floor_log2;
    use hypernova_core::helpers::{u64_to_le_bytes32, pad_right, hash_pair};

    //  Friend modules
    friend hypernova_core::hypernova_core;
    friend hypernova_core::proof_verifier;

    //==Error codes==
    /// Invalid sync committee size. The sync committee size does not match the expected value(512).
    const EINVALID_SYNC_COMMITTEE_SIZE: u64 = 3000;

    /// Invalid proof length. The length of a proof is incorrect or malformed.
    const EINVALID_PROOF_LENGTH: u64 = 3001;

    /// Invalid sync committee bits size. The sync committee bits size does not match the expected value.
    const EINVALID_SYNC_COMMITTEE_BITS_SIZE: u64 = 3002;

    /// Invalid object root length. The length of the object root is incorrect or malformed.
    const EINVALID_OBJECT_ROOT_LENGTH: u64 = 3003;

    /// Invalid domain length. The length of the domain is incorrect or does not match the expected value (32 bytes).
    const EINVALID_DOMAIN_LENGTH: u64 = 3004;

    /// Invalid root hash length. One or more root hashes (parent_root, state_root, body_root) do not have the expected length of 32 bytes.
    const EINVALID_ROOT_LENGTH_32: u64 = 3005;

    /// Invalid fork version length. The length of the fork version is incorrect or does not match the expected value (32 bytes).
    const EINVALID_FORK_VERSION_LENGTH: u64 = 3006;

    //=== Constants ===
    /// The number of participants in the sync committee
    const SYNC_COMMITTEE_SIZE: u64 = 512;

    /// The length (in bytes) of a 32-byte value
    const BYTES_32_LEN: u64 = 32;
    

    //=== Structs ===
    /// Represents a Beacon Block Header in Ethereum's consensus layer.
    /// This header contains essential metadata about a block.
    struct BeaconBlockHeader has store, drop, copy {
        /// The slot number in which this block was proposed. Slots are time units (12 seconds each)
        /// in the beacon chain, determining when validators can propose blocks.
        slot: u64,

        /// The index of the validator who proposed this block in the validator registry.
        /// Each validator has a unique index that identifies them in the beacon chain.
        proposer_index: u64,

        /// The 32-byte hash of the parent block's beacon block header.
        /// Forms the chain structure by referencing the previous block.
        parent_root: vector<u8>,

        /// The 32-byte hash of the beacon state after processing this block.
        /// Represents the state of the beacon chain at this point.
        state_root: vector<u8>,

        /// The 32-byte hash of the beacon block body.
        /// Contains the hash of block contents (attestations, deposits, etc.).
        body_root: vector<u8>
    }

    /// Represents a Sync Committee, which is a group of validators
    /// responsible for assisting with block finalization.
    struct SyncCommittee has copy, store, drop {
        /// The aggregated public key of all validators in the sync committee.
        /// This is used for verifying aggregated signatures from the committee.
        aggregate_public_key: PublicKey,

        /// A vector of individual public keys with proof of possession (PoP)
        /// for each validator in the sync committee.
        /// Each entry includes both the public key and its proof of possession.
        public_keys: vector<PublicKeyWithPoP>
    }

    /// Represents a sync committee's aggregate signature data.
    /// This structure contains the aggregated signatures and participation bits.
    struct SyncAggregate has copy, store, drop {
        /// A vector of boolean values indicating which validators in the sync committee
        /// participated in signing. Each bit corresponds to a validator's participation.
        sync_committee_bits: vector<bool>,

        /// The aggregated BLS signature from participating sync committee members.
        /// This signature is used to verify the committee's approval of a block.
        sync_committee_signature: Signature
    }

    /// Represents a Fork in the blockchain protocol,
    /// which defines versioning changes at specific epochs.
    struct Fork has copy, store, drop {
        /// The epoch number at which this fork becomes active.
        /// Epochs are time periods (32 slots each) in the beacon chain.
        epoch: u64,

        /// The version identifier for this fork.
        /// This is typically a 4-byte value that uniquely identifies the fork version.
        version: vector<u8>
    }

    /// Holds fork versioning data for Ethereum.
    /// This struct is used to differentiate between protocol forks.
    struct ForkData has copy, store, drop {
        /// The current version identifier of the fork.
        /// This is used to determine which fork rules to apply.
        current_version: vector<u8>,

        /// The root hash of the genesis validators' Merkle tree.
        /// This serves as a unique identifier for the chain.
        genesis_validators_root: vector<u8>
    }

    /// Contains signing data used for BLS signature verification.
    /// This struct holds the necessary data for verifying BLS signatures in the Ethereum consensus layer.
    struct SigningData has copy, drop {
        /// The root hash of the object being signed.
        /// This is typically a 32-byte hash that represents the state or data being verified.
        object_root: vector<u8>,

        /// The domain separator used in BLS signature verification.
        /// This is a 32-byte value that helps prevent signature replay attacks
        /// by providing context for the signature's purpose.
        domain: vector<u8>
    }


    /// Represents a update for the light client.
    /// This struct contains the information needed to update the light client's
    /// view of finalized blocks and their associated proofs.
    struct LightClientUpdate has drop, copy {
        /// Slot number at which the signature was created
        signature_slot: u64,
        /// Merkle proof branch for verifying the finalized header
        finality_branch: Option<vector<vector<u8>>>,
        /// The beacon block header that was attested to
        attested_block_header: BeaconBlockHeader,
        /// The beacon block header that was finalized
        finalized_block_header: Option<BeaconBlockHeader>,
        /// The aggregate signature and participation data from the sync committee
        sync_aggregate: SyncAggregate
    }

    /// Constructs BeaconBlockHeader with the provided slot, proposer index, and root values
    public(friend) fun construct_beacon_block_header(
        slot: u64,
        proposer_index: u64,
        parent_root: vector<u8>,
        state_root: vector<u8>,
        body_root: vector<u8>
    ): BeaconBlockHeader {
        assert!(
            is_input_length_32(&parent_root)
                && is_input_length_32(&state_root)
                && is_input_length_32(&body_root),
            EINVALID_ROOT_LENGTH_32
        );
        BeaconBlockHeader { slot, proposer_index, parent_root, state_root, body_root }
    }

    /// Returns the slot from the BeaconBlockHeader
    public(friend) fun get_slot(header: &BeaconBlockHeader): u64 {
        header.slot
    }

    /// Returns the proposer index from the BeaconBlockHeader
    public(friend) fun get_proposer_index(header: &BeaconBlockHeader): u64 {
        header.proposer_index
    }

    /// Returns the parent root from the BeaconBlockHeader
    public(friend) fun get_parent_root(header: &BeaconBlockHeader): &vector<u8> {
        &header.parent_root
    }

    /// Returns the state root from the BeaconBlockHeader
    public(friend) fun get_state_root(header: &BeaconBlockHeader): &vector<u8> {
        &header.state_root
    }

    /// Returns the body root from the BeaconBlockHeader
    public(friend) fun get_body_root(header: &BeaconBlockHeader): &vector<u8> {
        &header.body_root
    }

    /// Computes the hash tree root for the given BeaconBlockHeader by hashing its components.
    ///
    /// This function takes a BeaconBlockHeader and creates a Merkle tree from its components:
    /// - slot, proposer_index, parent_root, state_root, and body_root.
    /// It then computes and returns the hash tree root by applying the calculate_root function.
    ///
    /// The following components of the BeaconBlockHeader are hashed in order:
    /// 1. slot: The block slot number, encoded as a 32-byte little-endian value.
    /// 2. proposer_index: The index of the proposer, encoded as a 32-byte little-endian value.
    /// 3. parent_root: The hash of the parent block header.
    /// 4. state_root: The root of the state, representing the state of the beacon chain at this block.
    /// 5. body_root: The root of the body of the block, containing transactions and other block data.
    ///
    /// Arguments:
    /// - data: The BeaconBlockHeader containing the components to be hashed.
    ///
    /// Returns:
    /// - A vector of bytes representing the computed hash tree root of the BeaconBlockHeader.
    ///
    /// The components are hashed together to form a Merkle root, which is then returned.
    public(friend) fun hash_tree_root_beacon_block_header(
        data: &BeaconBlockHeader
    ): vector<u8> {
        let leaves = vector::empty();
        let slot = u64_to_le_bytes32(data.slot);
        let proposer_index = u64_to_le_bytes32(data.proposer_index);
        vector::push_back(&mut leaves, slot);
        vector::push_back(&mut leaves, proposer_index);
        vector::push_back(&mut leaves, data.parent_root);
        vector::push_back(&mut leaves, data.state_root);
        vector::push_back(&mut leaves, data.body_root);
        calculate_root(&mut leaves)
    }

    /// Computes the root hash for the fork data, which includes the current version and genesis validators root.
    ///
    /// This function takes the current version and the genesis validators root and calculates a root hash for the
    /// fork data. The version and genesis validators root are each expected to be of a fixed length (32 bytes).
    ///
    /// The ForkData struct is created with these two pieces of data, and then the function calculates the hash tree root
    /// for that struct. The current_version is padded with 28 zeros to ensure the hash calculation works as expected.
    ///
    /// Arguments:
    /// - current_version: A vector representing the current version of the protocol or chain.
    /// - genesis_validators_root: A vector representing the root hash of the genesis validators list.
    public(friend) fun compute_fork_data_root(
        //Note : Current version is of len 4 but need to pad 28 zeros at the end to compute the hash_tree_root
        current_version: vector<u8>,
        genesis_validators_root: &vector<u8>
    ): vector<u8> {
        assert!(is_input_length_32(&current_version), EINVALID_FORK_VERSION_LENGTH);
        let fork_data = ForkData {
            current_version,
            genesis_validators_root: *genesis_validators_root
        };
        hash_tree_root_fork_data(&fork_data)
    }

    /// Computes the hash tree root of a ForkData object.
    ///
    /// This function takes a ForkData object containing the current_version and genesis_validators_root
    /// and calculates the hash tree root of the data. It creates a list of leaves from the two fields and then uses
    /// the calculate_root function to compute the final root hash.
    ///
    /// Arguments:
    /// - data: A reference to a ForkData object containing current_version and genesis_validators_root.
    public(friend) fun hash_tree_root_fork_data(data: &ForkData): vector<u8> {
        let leaves = vector::empty<vector<u8>>();
        vector::push_back(&mut leaves, data.current_version);
        vector::push_back(&mut leaves, data.genesis_validators_root);
        calculate_root(&mut leaves)
    }

    /// Creates a SyncCommittee with the given public keys and aggregate   public key.
    ///
    /// This function initializes a new SyncCommittee struct, which consists of:
    /// - A list of public keys (public_keys).
    /// - An aggregated public key (aggregate_public_key).
    ///
    /// It ensures that the number of public keys provided is exactly the expected size (SYNC_COMMITTEE_SIZE).
    /// If the provided list of public keys does not match the expected size, the function will panic with the specified error message.
    ///
    /// Arguments:
    /// - public_keys: A vector of PublicKeyWithPoP structures, representing the public keys of the sync committee members.
    /// - aggregate_public_key: A PublicKey that is the aggregation of the individual public keys in the sync committee.
    public(friend) fun construct_sync_committee(
        public_keys: vector<PublicKeyWithPoP>, aggregate_public_key: PublicKey
    ): SyncCommittee {
        assert!(
            vector::length(&public_keys) == SYNC_COMMITTEE_SIZE,
            EINVALID_SYNC_COMMITTEE_SIZE
        );
        SyncCommittee { public_keys, aggregate_public_key }
    }

    //=== SyncCommittee Getters ===

    /// Returns the public keys of the sync committee
    public(friend) fun get_sync_committee_public_keys(
        sync_committee: &SyncCommittee
    ): &vector<PublicKeyWithPoP> {
        &sync_committee.public_keys
    }

    /// Returns the aggregate public key of the sync committee
    public(friend) fun get_aggregate_public_key(
        sync_committee: &SyncCommittee
    ): &PublicKey {
        &sync_committee.aggregate_public_key
    }

    // === SyncAggregate Getters===
    /// Creates a new SyncAggregate with the given bits and signature
    public(friend) fun construct_sync_aggregate(
        sync_committee_bits: vector<bool>, sync_committee_signature: vector<u8>
    ): SyncAggregate {
        assert!(
            vector::length(&sync_committee_bits) == SYNC_COMMITTEE_SIZE,
            EINVALID_SYNC_COMMITTEE_BITS_SIZE
        );
        SyncAggregate {
            sync_committee_bits,
            sync_committee_signature: signature_from_bytes(sync_committee_signature)
        }
    }

    /// Returns the sync committee bits from the SyncAggregate
    public(friend) fun get_sync_committee_bits(
        sync_aggregate: &SyncAggregate
    ): &vector<bool> {
        &sync_aggregate.sync_committee_bits
    }

    /// Returns the sync committee signature from the SyncAggregate
    public(friend) fun get_sync_committee_signature(
        sync_aggregate: &SyncAggregate
    ): &Signature {
        &sync_aggregate.sync_committee_signature
    }

    /// Computes the hash tree root of a compressed public key by appending padding.
    ///
    /// This function takes a compressed public key (compressed_pubkey), appends padding
    /// to ensure it reaches a total length of 64 bytes, and then computes the SHA-256 hash of the resulting byte array.
    /// The compressed public key is expected to be 48 bytes long before padding.
    ///
    /// The resulting hash represents the root hash in a hash tree structure for the given public key.
    ///
    /// Arguments:
    /// - compressed_pubkey: A vector of bytes representing the compressed public key. This should be 48 bytes long.
    public(friend) fun hash_tree_root_public_key(
        compressed_pubkey: vector<u8>
    ): vector<u8> {
        let compressed_pubkey = pad_right(compressed_pubkey, 64);
        hash::sha2_256(compressed_pubkey)
    }

    
    //=== Signing Data Getters ===

    /// Constructs a SigningData struct with the given object root and domain.
    public(friend) fun construct_signing_data(
        object_root: vector<u8>, domain: vector<u8>
    ): SigningData {
        assert!(
            is_input_length_32(&object_root),
            EINVALID_OBJECT_ROOT_LENGTH
        );
        assert!(
            is_input_length_32(&domain),
            EINVALID_DOMAIN_LENGTH
        );
        SigningData { object_root, domain }
    }

    /// Returns the object root from the SigningData struct.
    public(friend) fun get_object_root(signing_data: &SigningData): &vector<u8> {
        &signing_data.object_root
    }

    /// Returns the domain from the SigningData struct.
    public(friend) fun get_domain(signing_data: &SigningData): &vector<u8> {
        &signing_data.domain
    }

    /// Constructs a Fork type
    /// Creates a new fork with the given epoch and version.
    public(friend) fun construct_fork(epoch: u64, version: vector<u8>): Fork {
        assert!(is_input_length_32(&version), EINVALID_FORK_VERSION_LENGTH);
        Fork { epoch, version }
    }

    //=== Fork Getters ===

    /// Retrieves the epoch number of a given fork.
    public(friend) fun get_epoch(fork: &Fork): u64 {
        fork.epoch
    }

    /// Retrieves the fork version.
    public(friend) fun get_version(fork: &Fork): &vector<u8> {
        &fork.version
    }

    /// Retrieves the version of the latest fork.
    public(friend) fun get_fork_version(forks: vector<Fork>): vector<u8> {
        let fork = vector::pop_back(&mut forks);
        fork.version
    }

    /// construct LightClientUpdate
    public(friend) fun construct_lightclient_update(
        signature_slot: u64,
        finality_branch: Option<vector<vector<u8>>>,
        attested_block_header: BeaconBlockHeader,
        finalized_block_header: Option<BeaconBlockHeader>,
        sync_aggregate: SyncAggregate
    ): LightClientUpdate {
        LightClientUpdate {
            attested_block_header,
            finalized_block_header,
            finality_branch,
            sync_aggregate,
            signature_slot
        }
    }

     //== LightClientUpdate Getters ===
    /// Retrieves the attested header from a finality update.
    public(friend) fun get_attested_header_update(
        update: &LightClientUpdate
    ): &BeaconBlockHeader {
        &update.attested_block_header
    }

    /// Retrieves the finalized header from a finality update.
    public(friend) fun get_finalized_header_update(
        update: &LightClientUpdate
    ): Option<BeaconBlockHeader> {
        update.finalized_block_header
    }

    /// Retrieves the finality branch from a finality update.
    public(friend) fun get_finality_branch_update(
        update: &LightClientUpdate
    ): Option<vector<vector<u8>>> {
        update.finality_branch
    }

    /// Retrieves the sync aggregate data from a finality update.
    public(friend) fun get_sync_aggregate_update(
        update: &LightClientUpdate
    ): &SyncAggregate {
        &update.sync_aggregate
    }

    /// Retrieves the signature slot from a finality update.
    public(friend) fun get_signature_slot_update(
        update: &LightClientUpdate
    ): u64 {
        update.signature_slot
    }

    /// Computes the hash tree root of the SigningData struct.
    ///
    /// This function hashes the object_root and domain fields in the SigningData struct
    /// and returns the resulting root hash.
    ///
    /// # Arguments
    /// - data: The SigningData struct containing the object_root and domain fields to be hashed.
    ///
    /// # Returns
    /// - A vector<u8> representing the computed hash tree root of the SigningData.
    public(friend) fun hash_tree_root_signing_data(data: &SigningData): vector<u8> {
        let leaves = vector::empty<vector<u8>>();
        vector::push_back(&mut leaves, data.object_root);
        vector::push_back(&mut leaves, data.domain);
        calculate_root(&mut leaves)
    }

    /// Computes the Merkle root from a list of leaves using SHA-256 hashing.
    public(friend) fun calculate_root(leaves: &mut vector<vector<u8>>): vector<u8> {
        let num_leaves = next_power_of_two(vector::length(leaves));
        let empty_leaf =
            x"0000000000000000000000000000000000000000000000000000000000000000";
        while (vector::length(leaves) < num_leaves) {
            vector::push_back(leaves, empty_leaf);
        };

        while (num_leaves > 1) {
            let next_level = vector::empty<vector<u8>>();
            let i = 0;
            vector::reverse(leaves);
            while (i < num_leaves) {
                let left = vector::pop_back(leaves);
                let right = vector::pop_back(leaves);
                let combined_hash = hash_pair(left, right);
                vector::push_back(&mut next_level, combined_hash);
                i = i + 2;
            };
            *leaves = next_level;
            num_leaves = vector::length(leaves);
        };

        *vector::borrow(leaves, 0)
    }

    /// Computes the next power of two greater than or equal to n.
    /// This function finds the smallest power of two that is greater than or equal to n.
    ///
    ///  Example:
    ///
    ///next_power_of_two(3)  -> 4
    ///  next_power_of_two(7)  -> 8
    /// next_power_of_two(10) -> 16
    ///  next_power_of_two(33) -> 64
    /// next_power_of_two(64) -> 64
    public(friend) fun next_power_of_two(n: u64): u64 {
        if (n <= 1) {
            return 1
        };
        let log = floor_log2(n - 1) + 1;
        1 << log
    }

    /// Computes the Merkle root based on the leaf, proof, and index.
    ///
    /// This function calculates the Merkle root using a given leaf, proof (Merkle branch),
    /// and a GeneralizedIndex to determine the path of hashing. It traverses the Merkle
    /// proof based on the bits of the index and hashes the corresponding values in the proof
    /// to compute the root hash.
    ///
    /// # Arguments
    /// - leaf: The leaf node (data to be hashed) of the Merkle tree.
    /// - proof: A vector of Merkle proof elements (hashes) that guide the computation of the root.
    /// - index: A GeneralizedIndex object containing the index to guide the proof path.
    ///
    /// # Returns
    /// - A vector representing the computed Merkle root.
    public(friend) fun compute_merkle_root(
        leaf: vector<u8>, proof: vector<vector<u8>>, index: u64
    ): vector<u8> {
        let path_length = (floor_log2(index) as u64);
        let result = leaf;
        let proof_len = vector::length(&proof);
        assert!(proof_len == path_length, EINVALID_PROOF_LENGTH);

        vector::enumerate_ref(
            &proof,
            |i, next| {
                if (is_bit_set(index, i)) {
                    // When index bit is 1, hash next first, then result
                    result = hash_pair(*next, result);
                } else {
                    // When index bit is 0, hash result first, then next
                    result = hash_pair(result, *next);
                };
            }
        );

        result
    }

    /// Verify the Merkle proof by comparing the calculated root with the expected root
    public(friend) fun verify_merkle_proof(
        leaf: vector<u8>,
        proof: vector<vector<u8>>,
        index: u64,
        root: vector<u8>
    ): bool {
        compute_merkle_root(leaf, proof, index) == root
    }

    /// Verifies if a Merkle branch is valid by checking if the leaf hash can lead to the given root.
    ///
    /// This function takes a leaf, a Merkle branch (proof), the depth of the tree, and the expected root,
    /// then computes the hash path by iterating over the branch. It uses the index to determine the order of hashing.
    ///
    /// Arguments:
    /// - leaf: The leaf node (starting point) in the Merkle tree.
    /// - branch: The Merkle branch (proof) containing the hashes needed to verify the leaf's inclusion in the tree.
    /// - depth: The depth of the Merkle tree, i.e., the number of steps to process in the branch.
    /// - index: The index of the leaf node in the tree, used to guide the hash path with binary logic.
    /// - root: The expected root hash of the Merkle tree.
    ///
    /// Returns:
    /// - true if the leaf can be verified as part of the Merkle tree, false otherwise.
    public(friend) fun is_valid_merkle_branch(
        root: vector<u8>,
        leaf: vector<u8>,
        branch: vector<vector<u8>>,
        depth: u64,
        index: u64
    ): bool {
        let result = leaf;
        vector::reverse(&mut branch);
        for (i in 0..depth) {
            let next_node = vector::pop_back(&mut branch);
            if (is_bit_set(index, i)) {
                result = hash_pair(next_node, result);
            } else {
                result = hash_pair(result, next_node);
            }
        };


        (result == root)
    }

    //== Private Functions ===

    /// Checks if the length of the given vector is 32 bytes.
    ///
    /// # Arguments
    /// * `input` - A reference to a vector of bytes.
    ///
    /// # Returns
    /// * `true` if the length of the vector is 32 bytes, otherwise `false`.
    fun is_input_length_32(input: &vector<u8>): bool {
        vector::length(input) == BYTES_32_LEN
    }

    /// Returns true if the bit at position `i` in `index` is set (1), false otherwise.
    inline fun is_bit_set(index: u64, i: u64): bool {
        ((index >> (i as u8)) & 1) != 0
    }



    //=== Test Functions ===

    #[test_only]
    fun get_sync_commitee(): (vector<vector<u8>>, vector<u8>) {
        let public_keys = vector[
            x"afe3b6323ee16b10849404f2cb8eecc06ecef0c5ca05185f6640093948b36512d9896e7558dea0943d7e2eee8f65fdb1", x"90c04eb3f3679cd630434418cb3a225a73254887692429960bd45b1613f85b2c14723cd8c7f1e875588ed82b7f5576b7", x"82daf8d4185bc828f1aa70ef0fbf235df8f44563d154b2d85af9a55977ed619fcba78bd0bf4cec4e565569a40e47b8f5", x"942a12ba2f7b8708afb97e8ecba8f4ce66df1f862ceb86b3452f9b80eff581ee729f0f3122c6234075c6970270e2c367", x"832c4c788c7e60326e29bd47d4840729e676c198af42abb040f4b99bd69609668883b04fafaaf1f13f14a6ac34e1ad2f", x"8289b65d6245fde8a768ce48d7c4cc7d861880ff5ff1b110db6b7e1ffbfdc5eadff0b172ba79fd426458811f2b7095eb", x"8210c8bcb8d07be0cb55a5ea5708d7d66e207e675f97de88a78db92abe21336f1a04d481ab2a3e0a6bca4f7cf63b8512", x"8ef9b456c6abbc1b912e4b5c9420e8af1a5860eb670894d3ac250ee57f2421f2e4eaa1a7f85df0f3f9b34a24169195fe", x"b4bf70468eff528bf8815a8d07080a7e98d1b03da1b499573e0dbbd9846408654535657062e7a87a54773d5493fc5079", x"b5726aee939d8aee0d50bf15565f99e6d0c4df7388073b4534f581f572ad55893c5566eab1a7e22db8feeb8a90175b7d", x"b886f7a3476adb0818c62efe1124ad90a177c7628a53ce2b5db87661dfa2018d3c5a1862a88cb9bd207fc5cab0915c5a", x"a347b5c70fa3cfd77e859a486dcb38c896ccabdf42764691bef1a1b98e7e49e3fd87e8710a396a69fa212f4c4a904060", x"b792b08f3b1048c8883d0ca34e1d693d411819dc990c117923d42bf1cde7b0e7193e92941f7d9c520cc6f9eab0f7bf6d", x"8fb51e3ef3c1047ae7c527dc24dc8824b2655faff2c4c78da1fcedde48b531d19abaf517363bf30605a87336b8642073", x"ac2c98a0ab3f9d041fc115d9be4a6c77bd2219bb4b851cbee0d9257a4de5791251735b5b8fad09c55d16eb0d97080eff", x"a8e03a26e88e4ed03751ccf6eeed6215becbf4c2d58be27361f61d1cc4ac9b692fc6ecdb839f9b3c17f54fc2f2f4756e", x"973091c0e72354e0df4488c9078d11eec554c8cc84771955595aa1dd7a7a9dc9e29597924678aa20ecefe5be394fd2ae", x"93ccd8c5f82374e0bef6562e16576f742d79b6f400e3485ef36e148088b61fbd882c3d2bb38ab0b43fa1dac77f31d543", x"abac08f4df786b2d524f758bca43b403b724d12601dc0a8362b7a2779d55b060c6682a5618fffea2e4def169fcbd2bfb", x"8296f8caf58316af535def398a43357e48cb3b1e674b857eba1bd1b970da3dd045e22fe6d17dee4e9117f62ece3ec31c", x"84fe145491d145fbe0c7f9104c9cca07c4f77746dbb93cfefd066b8a1ee61be8fe5d592c18b153f40f41ffdd8020f11c", x"aa3446aac25f6c23ea16e8f7d19c58d187746ef3c2ac7d8fdf9bdc329409a07589ec8eebafbe2b156e7ba60addc15af8", x"81c850f419cf426223fc976032883d87daed6d8a505f652e363a10c7387c8946abee55cf9f71a9181b066f1cde353993", x"a6b434ac201b511dceeed63b731111d2b985934884f07d65c9d7642075b581604e8a66afc7164fbc0eb556282e8d83d2", x"a8f2572a2cc2ecba151a3d5f4040a70172067ddadd8c12ba9d60f993eb0eab6698cb35932949c9a42e45b36a822af40e", x"b4446c92edb7716294700c6e0ed1da6f4531a8f1774100fd1d12cfef7e9405e6747408b10ae02e98e2b87dc2cc586a43", x"ae95ddcf3db88f6b107dcf5d8aa907b2035e0250f7d664027656146395a794349d08a6a306ce7317b728ca83f70f3eaf", x"87c5670e16a84e27529677881dbedc5c1d6ebb4e4ff58c13ece43d21d5b42dc89470f41059bfa6ebcf18167f97ddacaa", x"a4d4f2e41aa4dd511fb737582118587503ae3e03fa658748709ab639c7e5ebba93f9b179e158b6ceb912323d906c0001", x"a23710308d8e25a0bb1db53c8598e526235c5e91e4605e402f6a25c126687d9de146b75c39a31c69ab76bab514320e05", x"8c17ccc763fcdf2ba7e27ea643654e52f62a6e3943ba25f66e1003fd52f728e38bfd1036c0d50eb3e3e878378bcc2e9d", x"a413befdecf9441fa6e6dd318af49173f19e8b95b8d928ebe1cc46cacc78b1377afa8867083be473457cd31dfff88221", x"99bd3fca280b3ad67f5b2d193de013287cade76d7414f4828ca6fa2506e6e8e9dab300207af0897b9db14608ae15fb02", x"89cdbd610e7f57e86438e50874c3c7ba85afa63f5adcab9e454b5c203e4da65d74bb7cac5995a8652d10a6e438a1c2b8", x"9662a2319dc40d54af893a787a611af3f172f2bd96b0c71d4246f4c0774c0533b7d77e9a1c2c96eb9701725a2ccf274a", x"b611e52def8da2a83989f5b8391fef61774b980ce82ee2fe0acdf24e4efb81f40b9c9abb0a2010e843101efc170f9832", x"b44357a263dd74f57b8c155aa19454e762423e26ef08ba78f2f25f7801978beaa9d6208c07e4449aa3a04bc2ef633930", x"b7c66da483b18f08344fc3c27bdf4914dabbcefd7ee7672fab651d05127d85d25ce363b0c338d6eed55c4e31f57bcb35", x"aa2b36d71d18c8a64193a0ea460f5390a274d0eb80b6cb21083dd33e9bbe6eaa0a7c1662d72a682ea788ca3f7ee802dd", x"b8137fd57ce7d3cfaf8bdbaa28704734d567d0e7a2d87fb84716722c524bb93acb2c1284249027f3c87bccc264c01f4e", x"b118f77f99ac947df97e7682f0fb446175185b842380af4ee7394531e4f93002c72b41a57a7c1b923a4f24b10924c84f", x"8b62902fb2855300580e94830a4bc825d997ede33bf356fe3b7c08d6a8bd85a37879433fc6bee58f9b44ca280f4e8dfd", x"a156e24fba7e966105307e89b102106710e2021e694c090decf32012e8794c6a090b27063ee605db40e435bf8b6ebf9f", x"949b8b056e465813496fbdd71929cfb506b75a7aca779002c437745f651527387afb84bfaacdd0c2501893a7209b4a5f", x"86b5ad456a3d9f838b76de84c40abadcd4bf555d0a06fece54e8523653b68e621ce045945d0ef54cae39e6921dd51e6a", x"b5d6f664ec92e5343792d5d6b629919c5fd8cfb874677df2264daf02bcd9d12facf9b859d5402839c9022396e20d260b", x"8c5a9f6eb0a3ea95e75362b06e5cd23968447a212cf22e1419c984d74432c51d290b717f80e8ed3e76b1232216f99758", x"81e4e885ee0203428056b4cf13ab4f3a21b4e11cbeca5aa262bd216121f84ee859835af55955c43484a934d431db4b83", x"86f5a9bdeebd38fef93bf20a7451ef4c851d63f08e025a59109c68b46f4c61069a6c8c5fe90eb5af36943acc35e62f51", x"9330a8d49b52cc673adc284c5297f961c45ec7997ced2a397b2755290981104c8d50b2fea9a3036ac2b1c329feaf4c7f", x"86edef59ab60ce98ae8d7a02e693970ca1cc6fa4372a59becc7ccca2a95e8f20a419899c8ccbb9c3e848f24178c15123", x"963a298fc8876b702424a697929c7a1938d298075e38b616c8711f1c7116f74868113a7617e0b4783fc00f88c614e72d", x"8cd1c73b7fe915e7169d351f88ade0f810d6a156fe20e4b52c7a697c3d93459e6d6c2f10dc1c6ec4114beae3e0a8c45a", x"8cc453954fb40a01929d529edca1cecdd162f1c7bf0bba99ff85e2b309cf46a04fcc817eb9c4837927f95b54d2aa816c", x"87a51e0011dd0488009baac9c611fbde01878f9cf1584ea407599742bb32ef10586d9040dae3e9800a125de54f80c047", x"b3acfe8f25eb5153b880a03e07760f7fa30beca475843581b4878ac0412cd2038117f25a48c152e6d60ec16e4b1e9a45", x"96e1482bc27d1b4158b4d482ca7ded9082b543d232b3185a579981a46501aa4dade1b579eb2aa4410039a0a4c5ccec7a", x"91bf4c32fa8888d3829d3c33e12550d2ecb70762d5eeecd044d4902e4a7f8b7a2592cf6cb7736eb6bd9d312f85c2777c", x"a866633b4293e726accf6e97ac90c1898cac83e8531a25b50ae99f0ecb477a692e6a5f2488447ccd83ed869ab5abc406", x"a7b8e78a69f126e1955242893582fe6093a0aa67c472aeee6212ad5fdbd7d2ca927ce02b65bafed15730a3dfa5f77e1b", x"b897fa90529458bdf3cede5ced3f3823dfb9b6d93b96b81429bf05e8f1a80f7c857d458045cfee58296b3ccbc4119abb", x"8df8b35861e00e82826b3a39069e9f3f0fcba18da2370e2fd792b4fbeec8a27111c7dd7e0acef5f4bd9b7a5cc2d6ece9", x"a10f19657a9bc5a5c16ebab9f9fddc3f1d812749cd5d80cb331f51de651873ff899e0670f1b079b29a194572de387a17", x"b1afaefc9fb0e436c8fb93ba69feb5282e9f672c62cbb3a9fc56e5377985e9d8d1b8a068936a1007efa52ef8be55ce9c", x"b45b285863f7303a234173b06e8eb63c8e2b70efe0dfb9872e3efddd31d52accf0f1292cfd1239b5a57492f3617a19e8", x"8934e9a3feababa12ed142daa30e91bd6d28b432d182ac625501fe1dc82f973c67f0fe82d39c9b1da3613bb8bfe2f77b", x"98aebd4bf15916512508a5fe89d814d5d76423c562cd3f0a0af504c8cde53be30f4df00e3ba0229cbf8528e198a0df11", x"a9b0a06469c7746a0a23c459a2fe75dd474e2cb1e9806afe872febf054e6f13c2c183761ccb890c6bb4d87abe597de1e", x"92ec1aeb2aa24c51cd5f724972c8b6095e77b237d83f93ed34ca0bc91a1dbf1ad95adccc59e0f0abbfef33f331f3298c", x"84991ca8ef255610ebc6aff6d66ea413a768e4d3a7764750fd02b5cd4735d41df399b36e87647fc83cf73421a39d09e9", x"ac2955c1d48354e1f95f1b36e085b9ea9829e8de4f2a3e2418a403cb1286e2599ba00a6b82609dd489eda370218dcf4c", x"8ef0930db046c45ca5c69d565d54681d2b6d249e27092736aee582b29de3aac3fd96e1066a57cadd851b4e5334261594", x"8e9bccb749e66fbe47296f5dec33bd86e52987516263240f35ce9a212dbcf71348b60a016f830f2acd05482962403542", x"8cbbc2d0e840d91f2c7d6f18303180ef8b2251438d4dee08dccae55a2926c5d2db0562375ba8252bcb9c850666cb6db4", x"b187e0a317aa92aee1c6bd78abf3439c9acfc68123e0249ad799972d0f41e5cd32a8e9df200f848c0e73ad8d2fddbca7", x"b1bb33607d10ea8c954064ecb00c1f02b446355ef73763a122f43b9ea42cd5650b54c5c9d1cfa81d4a421d17a0a451aa", x"88015bec478fd3ddff72efda0e8fc54b74faf804b0a3473cca38efbe5a7e6dc0be1cfe3dd62b8ac5a6a7a21971dcc58c", x"861b710d5ec8ce873e921655a2ca877429e34d432643f65d50e8b2669929be40a9ce11c6353b0ada1fe115e45396b2b7", x"8a501497cdebd72f9b192c8601caa425072e8e6ef438c2e9493675482808522e488779dcb670367cf6d68edea02a12af", x"afdc091a224486e7bfac169e6a7b4e008d2d04144508a337fd93b6f4d385ee3f0d927b1f5c1cd79a15e0fd6078e45dd4", x"95fa868db7592c5fb651d5d9971fc4e354dff969d6b05085f5d01fb4da1abb420ecad5ecb0e886e0ced1c9de8f3d5cfe", x"ac1af27a7c67b1c6c082f0fe733046f8b155a7d66caa8ccc40a53ac5a55a4903d598b5f80543ea52c25205b02959f4f5", x"8658925a5447c8013ec33fa917bcb5fa418af910cf46d840ffc8b8a4ff471d4d1ca993839121b69de1e6735291e5a9e6", x"a567b621878cbdbf0f93fb0910dc7291ca2de85344ade3407d57475d1fe4f1b7407a562390db3871a0e9c0582791a932", x"a6266fca079b955d49cccb8532fad7e44d5e7656c54613d415d2fe28702b4dcbc2e43e280a919320a4fcf789fbf3e2f6", x"a83b036b01e12cadd7260b00a750093388666aff6d9b639e2ce7dfc771504ef8b2090da28ec4613988f2ec553d1d749e", x"af3d8623e44947a1caba6fed648a943e22ebc2d8c6bd18739b05bbc59c088a9f1bec7aa454e21bbb2c279f84561cbb2f", x"a53d2a4bef5f3d412fed35ac375f632eb72a6650efe811e2131a6ddcb530f88044f65b80b7d739998115b9f961bbe391", x"975c3261f0f32d59473e588f89593be38f5694cfa09394a861e4330b7800fb2528ea832106a928c54c76a303d49140e2", x"95370f2c7c8c14976e5380b300451eee0dbce987b68ed96f2d13f2340f4e4e4cfac52987377b20e4e6cddf58c7975606", x"8100b48ac2785477a123a7967bfcea8bacef59391680a411692880098a08771ff9786bd3b8dfb034cae00d5a7665621c", x"adb198f70a7f1969ed0958be4a9a60dcc1806bced79c63692b9aad6c5648ffea1fed60b24bf4b1862e817cf229e93e83", x"8784a8fa62e0ce23283386175007bb781a8ec91b06fd94f22a20cd869929de37259847a94a0f22078ab14bb74709fac6", x"b8c41c09c228da62a548e49cfa107630166ac5c1469abf6d8aab55938ed1d142d5ddbc4f1043eed9496e9002cac99945", x"b9c8a3894365780842a2096da49e48f7e77f05972e2acdeae8e8fed8ddc52a1e2fd754547087bc9292cf0c868155fbcd", x"aee36de701879ca9d4f954e3ecdb422842fccd72930ff09977705d8da9282284b160b6485319d1e48259b984c5e38700", x"b919391ac60e21fbf25cb2d6a3ce6edf9ddc493073e5e19c43d319cc488ea7fa2b4c6c9fcae5477d83065edb7f92b7f1", x"a12fc78b8d3334a3eb7b535cd5e648bb030df645cda4e90272a1fc3b368ee43975051bbecc3275d6b1e4600cc07239b0", x"9267c0e9c176eefab67362ddfcd423a3986b5301c9a7c1c8c0dab93fdb15e562d343a7a9884a0a3378818b1aa1e4091a", x"85822227f6a96d3b6d6f5cf943e9fb819c8eaf42a9aa0bdd1527055442b1caf672522762831b2dac397af37a1c5ed702", x"a0617db822d559764a23c4361e849534d4b411e2cf9e1c4132c1104085175aa5f2ce475a6d1d5cb178056945ca782182", x"aef7205b83123d06496fb23188c2edd527728200f8f01486b9e27d3d075d713c7092dcfa2445459fc85b798128fca051", x"879bcbbeab235bdb1e3b1cd59b70cedba4772a616934d48195a01c38f745d61f3ab31e60538937e65450150e9314e481", x"b3648f1815812f4afdfd73e4fe0c30c403d9a1d0949c0d456041e662405d23431fcbae7630345b7430d43576ab7f88cb", x"8d797819318cdf7b26405d1a327d80d4c289e56f830b28d4e303bcb019aeb0b3d69bfed58adcde8a2445dd5281b86af1", x"aa2c3ef95b8d4265f01666129646004b6950d3e8ce74b4ca12aa3b90fbb445079a569178df772c272463a44d48922b8f", x"af25cf204acd84f9833b7c16ce3716d2a2cad640a28e3562f10260925efe252d3f7145839784c2ce1490522b45d1ce9a", x"a5b213f1d8ddcd9e42570f61f57c0e59cd6379740e50239257395f2fe7fac982c9861685e0fbee6c75bced5aa6b64849", x"94179fcc1fa644ff8a9776a4c03ac8bff759f1a810ca746a9be2b345546e01ddb58d871ddac4e6110b948173522eef06", x"997a91da55801acb6134d067ad65a9a44ead0b53d3871bb97b46ec36149d25e712d7230d38605479796190abd3d134b7", x"a02883d525e251708bcecf6cfaf7d07fc5e1be92fba24ca8f805e96b7dfe385af449f5687de1dc6707a62ccb08c1d590", x"b0d69b3861ca6791632ec8a87114b463e0da571bc076c22a8f0d9e88a1a5eaef24683f3efa8f34900d0112412e3dc4fa", x"ab5b363ed9551e32042e43495a456e394cbc6d53b15d37a8859850162608bdf36d3d4564b88fdbaf36ff391bb4090b8c", x"a40a83176a3890c867c34803e0f2571125c2cf1596767468a74107ba9b2d663c74e7c56a3de61bd7ed0c8db39534c7b4", x"af7cc29753903e70fcca8333fb7fadf4d7f6b8c20716bbb831815bbfab819b48c1e9b19148cf62392ad95c67c7bb0229", x"af01bc08e61c9387fe91ee29bfba20f4af56a1ca7f700e99c7c54d31e5bf9a2c3206cee758e53895921146bb2dcbbc8c", x"a42bcc5012a8b87caac4ec279f8cf7e43f88e36b65c321a835fd8a5ba427a635de79b93d2460f5e15258f09d8d51c7ce", x"908d762396519ce3c409551b3b5915033cdfe521a586d5c17f49c1d2faa6cb59fa51e1fb74f200487bea87a1d6f37477", x"abcf138d9363a73131f5bca56679d15606216bae1647c59c2857cb56818a0529c1b4b45e382273c993d62b7bcd552ded", x"93a1ff358d565658d3382f37c6e057e3c55af8aa12b46ff2cb06f3dd7f4bb83b04ea445c8f3af594f9ea3b0cca04c680", x"a70132fe0c9580ecce2e3c0d4a531cabe48bbf6e7d1c1daf9ed2f315e81705bf1616b4cfda1c903b074e239ac6ab4c47", x"8f4e902bc762394d65f6b543e68f64c13b5e5d6866d1ef75bfb786fdcc0fcd46ec1317a8cab4f2f97d6d3cf58926aeab", x"b312aad0a82565f02b8db1a8cb99bfa80e774b13575ffde9dcb7e6720fe96496bcc4ec1b4d42a5f06d137630b738e987", x"94ffda31c9e7cca085dd988092d72e5ae78befbb14a85179fac7bcd6e89628a8f70f586c1fedd81be34d8577a0f66fd7", x"8be72c12bfaa845ea0c736b7ebe6d4dcb04ee9535c0d016382754e35a898c574fd5de3fe8f0ab6f7e58ba07500536e9f", x"932d72ae4952031f9070b1d7cc2e827e06eb606e0e10594d19f56d9460cb5d1675bb3e19ce5752512e3bec256a0d88bf", x"8f9aededb605db4e499d3c383b0984b1322007c748dea18dc2f1c73da104a5c0bece6bb41d83abdfac594954801b6b62", x"9500df9a85cd8ee801329651bb15d7b77c4a59216005ff61769cdbf9de18da2fdb0d1afe6d5d922353fe22bdc8a8f772", x"a0ebae60a998907a19baa396ae5a82bfe6aa22cf71bfca4e1b4df7d297bd9367bbeb2463bda37aa852ad8fd51803e482", x"99c38717a416a5f41a42e8161cc4d949004cea736044d869e0b431713b85eb2d9144bb20b69d699e810421cddef513ad", x"85b7ac279df87035b63aea300f6c751b84d299a78788123aba08ba26edc6f8c7352baac4f471d6f4bb6c45428e661249", x"951b27456e2af80436608aadec54ebd03bda37fa58452631da63bc5ff3eecb5ffb73d356b19f6c9c4225fcb0da8fda20", x"a92dfa798798ba9e92f9886bfeb6d659b11ddc1228c3e4b8dd804bffa089d648173dc286846679df30acb4b5b5f4fd11", x"880b4ef2b278e1b2cccf36a3b5b7fbce94f106ed9fa2820cb9099a7a540a57e9fdeef5c0fb0a743049828fc2b8c46163", x"8dca376df4847cb8fc2e54a31894c820860c30b5e123b76670a37435e950f53312f089a8e9bd713f68f59fd1bf09202f", x"8e2e9a1a8bae9fffa594324a2c643ba0609f291146a104ceb9fc1f26d4a25604b97e9fb392c01689c88cac90c310333c", x"b726fc1cc7d94e13b156e2b27a5a5ca4173c073dfed4de60aba3b569a7467d3f678d81129da700686f38e6c496de9e0d", x"b48490c5a3bc9e66cdc78994f7c73e0f2724fec8a304b4147799e5142396df155ef7c42065ed6d2c0393d138fb4d2a0b", x"a58c3a4ba86d0d6b81c8411bb73a528b4f3bc2debac0e0208f788c080a3a96541d57c927143c165f595070afe14b0517", x"84465a264bc0dc2e8a6f96b1d396812eef35cd2476e0aeda857ccf16198251c31607725acb912038dec78a3669b1dd35", x"9194bc45e11d7276ed1c9ef3ad5a33d6a27372f5568563ca8ee213e2e7029dee404ab5acbaecaef698129798d35fd895", x"a373408beb5e4e0d3ebd5ca3843fe39bb56b77a5d3d2121d4a7a87f9add3ec7376388e9d4b8da0ba69164850cb4b077d", x"b4a1d185c770ed41021ab0497a2ecf724fbd046784418b8a4af8d654dd9b10c2f3333e6f4f9e6ce385916546a2cb6a8e", x"b15460725c0d6bc3a6a7006dcf3c3e3561d9acd674c52d4199daa8598ee29eef053ae521f1271aebc66943938c9f4b7e", x"ad2cdae4ce412c92c6d0e6d7401639eecb9e31de949b5e6c09941aeafb89753a00ea1eb79fa70b54699acbfa31eda6b7", x"a15ebe9ab6de62a4d1ff30b7fc58acfb14ea54d7fa513cbcb045af3070db22bf9c1e987fa26c0c54356b9e38fa412626", x"8465bd8be9bd9c2c6116d4ae44ec6618c109cb9aaee2d241e7a6ed906d398ef15a6fc18bc8b1d3398184241405954bba", x"ad9e1b4579bc335d176f2d1cb700b3e9cf74acc31a5ea9fbb9a9c3071963648017aa2e9331dac0c42e6482f9141657a5", x"96b1c82b85cdb8a7026fd3431bea9cd008f0261ee7f4179f4e69a399872837ab836a14e2dd45f5448d54800a4ae7c7f2", x"b1cca4f417063a861f6c5b4bbe2b129bc72003de58bab895325283ff5f1045af808da9048fa72217863e3de5ac87286d", x"973dcf44ab60f55f5d10a8753ea16db9faedd839466a130729538f3a0724f00f74b3ca1de16987d7c6e24e9467f62bc7", x"96be7deae0729f3d4bbd39b46d028a9a1e83ce863730b97e59422bb2508d88642393d544701b90bc15c33dab8e663297", x"a4b0732fcc79d82f3e5117a67571d498779afe6c20b8c56c90c76e3163c20726b584e02a0243de302b0a5c95f593cb66", x"8f44c43b80a3c5f488118859fab054745cfe5b0824821944b82fcf870fda6d93489ea9ca4220c24db2f4ad09c6080cb7", x"8ed7790f87f6975e0f3e501901b0bec1778c88bf39588989014c5dda76c2163732e7e5703c9cb2c1a6144ffdac5dcbab", x"a57bacada151d6521c6f40371e80cc8e44bb76389dfa7da5deba7675bb9a253c59a901df26c6f1069205b37f18048b1c", x"aa48afa77d5a81cd967b285c0035e941ca6d783493e1840d7cbc0f2829a114ace9146a8fbe31ecbd8e63e9b3c216a8c5", x"ad19e38fbc31a1f99e8ead1437016333ba9b15dffa43fe617d410fe82775f06fe5abd2d5f2118802914903d2c2301748", x"962e2c706de6e0894666a9a0233760421bbd8cb8066e4e38259554ec32e25d257c4a06b387f312238743a6e4ac42602b", x"907054244ae66504bdf29bd5bd0389d20687264d19d4b36272ef7762c00c1ef7a32e2c5ed04a2cc5f2403ecaca764f20", x"b38e558a5e62ad196be361651264f5c28ced6ab7c2229d7e33fb04b7f4e441e9dcb82b463b118e73e05055dcc9ce64b6", x"a8b593de2c6c90392325b2d7a6cb3f54ec441b33ed584076cc9da4ec6012e3aaf02cec64cc1fd222df32bf1c452cc024", x"aaeb0005d77e120ef764f1764967833cba61f2b30b0e9fed1d3f0c90b5ad6588646b8153bdf1d66707ac2e59fd4a2671", x"ab69cf79750436d310dc3c5e96c2b97003f4394f31dfa8a9ac420595dc7b4d96dad5787d93347ba2bc6f196c241a3dbf", x"b9cd71ebd50b024e32558ab1ddbb50c222503492e5c9e1d282731948c0b59458fbd85cac56bab0ba47a4c6dec8549c5f", x"853184f246d098139230962e511585368b44d46a115c5f06ccaeef746773951bead595fb6246c69975496bac61b42a4f", x"9834f66e5c946c3a8241ca2bbde046a7e88072124911d5d15c037a95b61e82b88b5c2058fa4a3721537dee39dee5da18", x"97578474be98726192cb0eac3cb9195a54c7315e9c619d5c44c56b3f98671636c383416f73605d4ea7ca9fbeff8dd699", x"abf7da952c9d8f75fcc67fa7969fac0b26d4dc3e022961ed674ce85d734f11620a950fb1fb0ef830fba1d8b5bc3eced4", x"b505941fed274189346ac4822c06eead45c56b9c12e8caceebf79e3096ce6e081f423c205dbe7839df1d6c3fbe626193", x"a9239a0e1250d355615eae3f43a9395d5c2943aaa37f22a1b36ed04aba544b0fb83cb5fa93b76c67c13d3f73e5e845cf", x"ab88f81dc77f09a2b62078e7baf4b6c7503925a7a077bb30d72f4baeff8225039c5333242e325e824f7192d4d132b596", x"b6c7360054cf250ac48c41fce8da7a15b4c6f226688a60da737ea2e19b00c94ba728aa588ee72a7ac65f2d63f216285a", x"b42d53fb4e5390729381b74ab96f48551f9105c2256d547cd7be0eed5bd5e7b7ce87033c55d0ddfbfe08ebb782f18be0", x"90c402a39cd1237c1c91ff04548d6af806663cbc57ff338ed309419c44121108d1fbe23f3166f61e4ab7502e728e31fd", x"b3bd2fedbca3e0185bd4920bc0b9279da7d7031e39df2886a4c969b28df97181ad37ca4bab2b79f44d7bc4acb32b14ab", x"b3c2adbe02028b88109ad0129ef0fe7a895c69317dfe877f420074c349ac0e66bcc9346a865f6af4f074fdb312f6edd3", x"a32a5bd9b7bec31dd138c44d8365186b9323afbba359550414a01e1cdb529426bfa0b6f7daaf3536e9402821faa80003", x"b075db32979df905cef986cfcd6db823ac21dd4013cecfe088885390ff8acd18d76dec793b80db5f7779426127daed7b", x"93655457967d1f62c3574c4bd85688c92dbdf256f3629818f8c2d75fe12acacc57b6fe78632bb22d4ac7bc1861e59fcf", x"94696bbf459f3a21b7d038923b621b5b599f60d24077452c23a8900d8ea40c016cf2f9b446ef008a3b6e2a0c6ff1cecf", x"ad54241ba3de6a4426c788690d3f78d2eb678814edc49d3fb988d7fc752e43512972567bb384bcc1b18d083d15e376da", x"90823dc2e5ab8a52a0b32883ea8451cbe4c921a42ce439f4fb306a90e9f267e463241da7274b6d44c2e4b95ddbcb0ad3", x"a649208372f44f32eb1cd895de458ca1b8be782746356f08ac8ef629429d0780a0799fcff85736e19aead0b79bfff261", x"ae5ea228c1b91ef23c245928186fbafa1275ff1817535018d7d2d913abff0fd76bf41fd04a96d816f2f1891bd16e9264", x"afc555559b435c585b61096a34a15b8ad8722b2d3306ac8cbf158b46c135b293b08a5f37b109b138350dbcd1e0da9f8e", x"ac7983d50ec447b65e62ed38054d8e8242c31b40030f630098ce0a4e93536da9179c3f3ae0b34a0b02aad427a97ee60d", x"a37cb755eeda22a48f0478ba0d18cd4e7be4a5d9d20edfb2030dbe5367a39ed9caef9a81969b34d098ec3f802214176f", x"b56b0519b37192a2ff19e975e218b0237feeadd94dfd4be7363fb12dacd61151a524023294ea08ead6d461faea2c425f", x"956ecb233b3529b2d9cb80ae49e48667f2a3120e4a0d7131d1e9ec36db3a59dc2ef2a579cbb99d6f14880ca83f02b64c", x"b90a5fe05303e9b367782483fd9fa07fd6a0509a5fbebf0fff3092f3aca2f5e99d40ca55bc067f63ad06a4a25d0e4842", x"a92beb343caf6a945990adcf84302c55d1fccdef96c34a21f2c00d3e206a9b2c6c6b412f66e5d4fafe26ef6446cde705", x"b1632f726d2aea275be4d132e0cda008caf03c91640959b3c62568d87c24adbeb6883a32828bfa99abeca8294cc5e9ce", x"92b53ea758e85cd81b877eca25c01519e03c33df55bdfb6c8508b8f1b11b2f573339048eb741ed64a3d12d78bf6b3929", x"82fd68050fcb8a203b78217aa89ccbe01482f5ecadab015ec13b605f64ecd5ce7b98e3403b0681de2852570bc7b7e845", x"83bbd31e799ac14686085868e8ea7587c7c7969c7015bfe45fd8e3a3847ad5338005f9cdf58396b2ea833c4af98bd9ca", x"8c627caf25eae6764501b9eff35aa90bd4f24952cad712aae20344579e83ecd104ad1f7915edc4f9023b17fddbdb4cd7", x"a4aabd1890ebf35423565dbff3477a09eea4e35f5a26ed449eab38e0a21fb89e9ddfe3a2003cddc457db648a1b5891a3", x"a5cf6f4fd67aecb845eebc8d7304c98c69806d774d4c468350f7f82ff0f5baeecc56837705e39432a8d246aa2a7075ed", x"9466afdb35d113733c0bc10b2e08ceba1132881c126524417602fc5a3fa4a626f6474b5f3f6c6dff49d74b9d8e91051b", x"a9ee291de5997232c68c9f6c3b568b05f46bfedfa18eb3776699d98cc7c6320003b7d862564d07fd28fc3691d1d28b21", x"ad77fcac9753efba7a9d9ef8ff4ec9889aa4b9e43ba185e5df6bf6574a5cf9b9ad3f0f3ef2bcbea660c7eef869ce76c8", x"a3e909196f447e492200cc67000c5d7f0f585fb98e966cf9bf08257597fea8d92a90ceb054d4b5553d561330b5d0c89a", x"94becbadca9f8209375477a85794e489d65159d09642da087e72208c2124812d9469b1621d877ebabdd63c165eab8fa9", x"937ccbf8cd19b82af2755b4856cfcca3d791e33ae37e4881982ea89d3b21d205a9402d754fac63037243e699484d21f6", x"906d7a8f06b7b78df6a6d2b67014e381e4b89806b9e106450fc6d424eaa1be047c3fde896430df1b7a2077364c544ea4", x"a2b27f2a3f133d4f8669ddf4fccb3bca9f1851c4ba9bb44fbda1d259c4d249801ce7bd26ba0ee2ad671e447c54651f39", x"af6e6cad67e54efe92976851bb789d79debfa2c78757103b69e43d1aac3d768d496017b8402ebc6e0b176be5aa6eecdb", x"b46a818f3e492e231d8fa8de8848c16f0d648a2e0d1c816adf9306a8596fdf45922e59cbf745430570a19e54f45e28f7", x"a2d7c628a47e4e948332b2faf6ed63316090b6fedd4d9c92cc2c12d93ea0615b79d133058579b9a6ff48a4e9918848fa", x"ac8436e33619e2907659741d66082acbda32612d245fcc8ae31e55f99703fac1a15657342fa66751d3be44fc35d71c36", x"a97b80bf780fba51a5863e620317812418204d3d5a1001710aa0cca383cb40855d9da0ddfdd40e1d2e9336a4543ca1ad", x"952a95612aecce4321d2c17aabd2fb260b1cb41df5f76f5b82b46cf818d7a4f18e5e2944cddcd2280a993c0af4f834fe", x"855474478de6f0f17168294a676f5a92db8d7f87b3e7e66f5ceee66dadeb5c94d740f0e0997e532409c2934175b6131c", x"b659c05488f778fca3c918505d2d849c667471af03369ad9fa29e37bac4cc9caa18e749c62fcff22856945a74ef51356", x"9366d86243f9d53bdd15d4cd6bf5dd348c2b89012c633b73a35d42fa08950073158ca0a1cfc32d64f56692c2374a020f", x"9604659740f6d473bd2c470c6751f2a129328e74e01b23368f692ad9b6cce0fe1509c3f82e9f01019b72f6bf3a8e4600", x"997f2b2bc0b67fba72980631b2f739196b503923d42347ae57659bb455801b6763ed4032fe59837a5abb475e4cfc79fe", x"b800be1788175a01a9228b0d3e7eb4302484a2654eb2a86c0f0900b593da0a436ef031ac230e2b05e968b33e90a342ce", x"87144976cb0d55de66f612725c6d89ab35a5222e8b003329b898e732629f5b7022a7223c9cc9ec820d3d1553e7b2267e", x"a131f61a215d689938b1997ec40357b939bd2a2565df04cea7800674e23ba068d0ce28bad32f49f3099434f34445eb4a", x"b4f4ed1bd274a852189719a8808a8f214c8386e844ca9ba13161b75d04c74633b1d8a758ce0b23ccbce8052494c81c3f", x"94bb68c8180496472262455fd6ab338697810825fa4e82fc673f3ac2dacfd29ee539ac0bfe97eb39d4ef118db875bab6", x"8d52413f981bc611427ad0534d25e914113d0ebcd6960aab6421608bec6648b89ae4b2ca2153c57d3cf4f1f37212aa5c", x"b77c967d0802218a206b8994ce4407b7b8272c812d64cd222701de3a35754a83ed9f16bebc9b69975f04ecc6a6bfec07", x"85c9217b6f7b8baffda06ffead7174ab9d1d9ec4b10b78d99e742835796a522d6e2b5ddc5c7282757dd896c76698eafb", x"a40ef3d2291d8782540961ce285054678b3d322d3cf7fc154207228c290708b1abfc37a4d7762dab3dfea582a112444a", x"b97447233c8b97a8654749a840f12dab6764209c3a033154e045c76e0c8ed93b89788aac5cd1e24ed4a18c36de3fbf60", x"885c3475185e7a857c789f148944fafddb5a118163d221e87d7126dd03ad8fd56f9be90c536ebd52c0a7a31b6ee40a4f", x"a013cc5e3fbb47951637426581c1d72764556798f93e413e1317849efd60f3ecb64c762f92544201eb5d6cfb68233050", x"86561f796ff1dc82581dcc22baddbc6c630c27ecc4402c75deb4559318c093656951b5fe91aad6efeafcc6266f9b7963", x"97ffcbf88b668cde86b2839c7f14d19cb7f634a4cf05d977e65f3cd0e8051b2670e521ae74edc572d88201cff225e38a", x"a83371f44e007c708dc4bcafa7bd3581f9080a4583c9be88624265014fd92f060127e628de5af3c442a25f049c7e7766", x"8719485f6db54a101f19f574fc1fff3a446f3eb4e42c756febcea7b17c7ef4bfb581a84c5bad36831cde06fad79f4d61", x"8741dee75fccba26eeefe0e14ef23820979fe509163ce75634a297cbc719eb840c3f044ed1ac740a7b5ef0a7ff314cf8", x"903b9bf66c147ddfddacce63c8f12f62e45638383bf91b50e2fef29013ce54a3fd8c3eccc9b8961d91ca2920ba5b0c1e", x"a69f0a66173645ebda4f0be19235c620c1a1024c66f90e76715068804b0d86a23dc68b60bca5a3e685cce2501d76de97", x"98c8f45e348091164a71a06b8166a992dc692177e7e06063f2a62adbee2028c882dc8225891c59386e69dee53cefe2ec", x"b40a3bae2b08c13db00f993db49e2042be99cde3d6f4f03d9991e42297933d6049394c659e31f316fcb081b60461dabf", x"b2235bdf60dde5d0d78c72cb69e6e09153b0154efdbab97e1bc91f18d3cec4f660a80311fe6a1acd419a448ab65b18f1", x"a94ccbf61b3a857744aa1540fc6d633afb8ab3c92d07fceef90a0dc54ecd2133490cbaac8832b26cf2f4b956471f36fe", x"87fd7e26a0749350ebdcd7c5d30e4b969a76bda530c831262fc98b36be932a4d025310f695d5b210ead89ee70eb7e53b", x"a6565a060dc98e2bfab26b59aff2e494777654015c3292653ecdcefbeeebd2ce9091a4f3d1da10f0a4061f81d721f6ec", x"997d3b82e4753f1fc3fc2595cfe25b22ac1956d89c0950767c6b9de20623d310b1d84aaa72ab967ef1ea6d397e13524b", x"8c7ccbea47f3fb6c15863c84c99a9094a00f2b5836200eeb73dbf84fc8e7856369dc7ab09f9d51ae42909fa94c895afc", x"ae7446b29ca1584f418191760c804348b431dda04eee8bb0afe584dd057eb238e61213d5b1daf4acfc19541f15b6eae6", x"b76cb8cb446eb3cb4f682a5cd884f6c93086a8bf626c5b5c557a06499de9c13315618d48a0c5693512a3dc143a799c07", x"948f808c6b8e3e109a999657ef966e1e02c96a7aae6eecaf912344e1c7bf7ea51c911cecd3cea2b41ff55acc31df9454", x"a448516054e31866b54f1951b9a03f0a54fb13d938b105e3f67396ed3fbb015f290a37fa538baeb077fb4f9ac86c8305", x"b4ef65b4c71fa20cd0ed863f43f6c652d4c35f2677bc2083f5a9808284e8bd8988703faaf0fb4cac8ecbda19541ecc65", x"85ab3c57517e3c348e7ec13a878b9303ff9aad78ec95b13242e087ec41f05f4a19366ae169fda8afec5300065db58f2f", x"a0dfa8c1614a05f1d73502f228f2f4f3d1d1f4946b26b99031bb4f01277d8c2718d632c88a6c7be8aaf67455a562b23e", x"86fa3d4b60e8282827115c50b1b49b29a371b52aa9c9b8f83cd5268b535859f86e1a60aade6bf4f52e234777bea30bda", x"87fec026beda4217b0a2014a2e86f5920e6113b54ac79ab727da2666f57ff8a9bc3a21b327ad7e091a07720a30c507c9", x"a9d9a295590641b2b09d8473b50c0f6e036e1a009dcd1a0b16d84406763b4b078d5de6ca90898232e34f7f7bf147f61c", x"884c769ff3dabc132330e4a72ecf5331490ff08a59b7dd51cf2a9cf803a1a3dbff838f40451b243786661eb1630a60d0", x"807c510df25c0ba10d4aa06a462e02f050c69a977c64c071401ab74f9ac1e60788aa504743b4cc1982da835ff9ac2541", x"af7271043f8b37491778588a8c09409a1326abeda4cc72bc59714f552c6e47ac5f16692a0c9c54a42d60bfea743a6d9e", x"99cb1728157a1b7cdd9607cf15911bbcb56b64d52fb0d0117b457853a81ec55913f977850f26e188fa2652579efe9ddf", x"a9b120a77d70c1cbc0178a12d97a78b2dd0b98d0584e8e780b937800ceb18c90eaa1f0a83c5b50e34cae1c20468f004f", x"94bbc6b2742d21eff4fae77c720313015dd4bbcc5add8146bf1c4b89e32f6f5df46ca770e1f385fdd29dc5c7b9653361", x"92096ebf98ebac5c82345d3ef0db0f5a14af23ceea73279087426b281d6701997fe131fe65a7df7d624b4ff91d997ae8", x"87ae7d29e5e2f0ad0fb347c2977b256d70861f505edae4adff37e07552d55fe87e9c240d82b96e114517ee4d9f178737", x"8154f81d5bcab563895b68e0b3b26bee1019bfa16792c57a732e94fe6486425e661e822ec61437648bbbe6d8ee0e9a52", x"a79ef16ee66514c2a4f34605a624dbb40d446f2637f943a4acdf0154c162fa12b30e151f03fb1a1cf100052186f94ce8", x"b2a01dc47dd98f089f28eee67ba2f789153516b7d3b47127f430f542869ec42dd8fd4dc83cfbe625c5c40a2d2d0633ea", x"a14d8d3f02de36328f3f55ac45331baafe5ba3611bd8b362464d69742b214cb703f37b5f39ed1b23cdcf0bf3eb90a81e", x"b3b7af9258af054362d461a74fcfeb6dcf3a37b6e33b6df32f8317d50d8be8e1970818a6e41c8232b89e1c8f964c6c1d", x"a606e46771815260be8800e6092dd340ea8630b51bae3962fec369b7dbec61c2ce340fe38bcac51f5ad5b36121e0f975", x"a734a3c947be4c7e6704639d4400aec2ccf5f1af0901b41a29e336afb37c53bf168774939ce51f32d4496bce1a32e612", x"ab37a400dafa918d28ef43294b18dabcb4dd942261832f9839e59e53747c7b1bc44230967a9610b261f3abbd648e3dd8", x"b7f146a357e02a63cd79ca47bf93998b193ce1174446953f12fa751f85dc2a54c9ed00c01a9308509152b3bad21d7230", x"81fc724846b5781f3736795c32b217458bb29972af36cc4483dd98ab91680d3d9bc18842db2661487d3a85430dc9e326", x"92b0b1e1301b1f7404789b911a672a32d96ce0e52d64f0d97f2a4c923d0824dfc8a9faef63bc93cb00f894f95e4470a0", x"86bba46d0031989d0f1baccea4174fc3fa0d595e60d35a464e86c33c233e2d6def84fced7a00f59afe397cf4fb5b67c5", x"a6e387cfc0e2f11eb72c7d94693a28d23250c45e4dfdbb2fa588519bc7afe60d454c6b545b1e97f2b1100f564fe0f220", x"b4f034f2b53ff9989e8a0f12c1484c58ed7942432a429af58a6659feaf23f7d2bf20ff7b9a7e0a28a2e09c9a730681d8", x"b455f751232de0a48440d09983f4f4718b6169907979c9f282acf7177ab5b1f338fe1f2acd8d0bee4b4aad61d0340839", x"a80ac2a197002879ef4db6e2b1e1b9c239e4f6c0f0abf1cc9b9b7bf3da7e078a21893c01eaaab236a7e8618ac146b4a6", x"876561bba29e656b7122f1cb51a02dff1ac7d470217d8a4799c01e61816c4660eea91843a5a42502ddf842d2daeb0586", x"b58396bce7d32ba6c70adbd37156d859e153c1932d2b0c7c874a1182ba831439e80d6fc6d7d88a870e193f515aef2264", x"921109a390e4d7fbc94dff3228db755f71cb00df70a1d48f92d1a6352f5169025bb68bcd04d96ac72f40000cc140f863", x"9702ebb1f2eeb3a401b0a65166fa129d829041984fe22b3f51eedfaf384578d33dab73d85164a101ecbb86db9d916419", x"9517cd84390fbbfb7862ca3e0171750b4c75a15ceb6030673e76b6fc1ce61ac264f6dd1758d817662abfc50095550bd3", x"aa19a75f21a14ad5f170e336a0bd07e0c98b9f5d71f91e784d1dc28a5f5eb6870a4eb35bb41edcf9e6efe982ae5c2c5b", x"b9def7aa584fbfd49683b1652bb24794129170244da113bc7b4b59f5a47dd08e41ce4403b0d8c47b35acf283390fad99", x"a3e1fe11f38d3954a7f48c8b68ff956ea0b6f8a3e603fd258c9406ec2b685ff48241db5257179ea020a83c31dc963854", x"a13bf1fc1826b61cceefcc941c5a4865cefdfa6c91e5223308fa6a0aa6e7b13a0499a63edf5d9fff48fdeae83e38dcbf", x"b7eb6a49bf8f942dd8c37c41c1b35df43e4536e07ca9f4c1cfbbf8a8c03f84c54c1a0d8e901c49de526900aeac0f922f", x"aa744c552b5fc41e1ac6ca53184df87a1b7e54d73500751a6903674041f5f36af25711e7bc8a6fbba975dc247ddad52d", x"a4a052a95cdb71be46a05657cbc598124af42e11e9bc5ef24d5ebfd8663e5636cbbb1aebca5bbcebfa7aa4cb0c7db1ce", x"89681684a4f5a2e56a4acd37836c06cfe8613b0694d2258f8ccee67796e76f49dd9da349b1c23a36f9438097c1e6415e", x"8b50e4e28539270576a0e8a83f5dedcd1e5369e4cd0be54a8e84069e7c3fdcc85483678429fd63fe2aa12db281012af2", x"adcb5800f23406e752002d49d5edfdcf48466e6d3f2c39169693cc9a043ef5d2ee960ed767a12cfcf1ce5f4cd25ac11f", x"883f38af3b2c1d50f6e7c515a5e02468d76890f6e669f7acd2df89365862fa65877095deb001b4e2868bc5b59439dbb1", x"b2349265be33d90aaf51362d015ce47c5ffe33e9e6e018c8c6e39336d9327ccdd13d25e792eb33b43ed89a162f6ac2fd", x"85626305abd33d464b345f59df3f2f912d159f742b13ad238e318adb58cc4afb66e2376af5ddc96b0fe03bb7b0f5f0f0", x"acb7069fe0428d350b8b710a702f56790bdaa4d93a77864620f5190d1ac7f2eed808019ca6910a61ec48239d2eca7f2a", x"a7179d338fe5a0e4669364a364e17f8d00cb6c59a80a069afd5f4f14510df2eee90c07826553e4f7fe46d28f72b2903e", x"851fcadebee06930186f35293feefd40d7daedec9b94e6fe5967536c2c0e4cc68f58d3f5fbc76f1e77b90c9580074f98", x"b9ed23f3f26fc9f31e1e30e8ae88482352fab6ef79a2eb8939dc78110580708f482ba3ab306ed6e09030653b9704a80e", x"a64210fc1ec26ec77704c002a6fc418c4edaf07bd0f8008c434b5ffd5a685adbe61b0319b3646e813f920590179c9859", x"b306bec1a3a64231530aecb8e62b75ddc63abf0193496cb8bf0c84ac8a1c018d4fe91aa1c65871e7e05b26b6a5ec61ad", x"b031e6abed40655d5271531bd5536f5c07b19f9a99afe326aca0b0544b9bd8e6d20c01b0bb89e39c5881e49fcacaaa72", x"a3fd9d8bbdc98394883022299fd9793e0c4f374d8e40d6ce89b2869d3173cb6a5476371d6095dad068ff217729f60af4", x"b3b2e3dec38d55c57a428c0cbae723f3c95ba75e51cf27e9bbb2a6398dc922069ae3d1aafbb42ebb46a2d8b356045fa2", x"90d32e6a183a5bb2d47056c25a1f45cebccb62ef70222e0066c94db9851dffcc349a2501a93052ee3c9a5ee292f70b92", x"86ca8ed7c475d33455fae4242b05b1b3576e6ec05ac512ca7d3f9c8d44376e909c734c25cd0e33f0f6b4857d40452024", x"824fde65f1ff4f1f83207d0045137070e0facc8e70070422369a3b72bbf486a9387375c5ef33f4cb6c658a04c3f2bd7e", x"b4d07d50fbc9634e5f4aeb884974068ea6b94e67e4527207f5f9c41a244943347d69d3c73af74d8de9ab3659d06c6d6a", x"ae2d3f75cecd24685994d5f04a268b22ea568cc143b81107282325b5257b023428d4ce45784c50b6a0006f5e70bbf257", x"8cf8412bd48b21b008f0207b1f430ed96bc6512c3712dffbbecb66e493e33698c051b27a2998c5bddd89d6c373d02d06", x"93fda62b785757b465e6f396f74674d5b95a08c938cf694e66beed7d2f317a4c9d736cb54d7c221d61e8cb3d64dca3ab", x"8a978ee4be90254fd7003ee1e76e5257462cbb14a64dbca0b32cea078908d7da47588a40ffeb42af11a83a304608c0f7", x"934fa8d9bc9cd0ff2492c5c97e63a98bdef63a6e8889c9ba7009d6c6472441750ab37ce5d1ac3bc0d73d074af223e446", x"ae07ebd0266efd616e56fb5101aa71bafbed8c2bddaaed27c3b069d74ec75601fc6a3cecbd917d8ac133903b1d33285c", x"8d562d6c0e0d8325032e1fbf836022c82a8f600a6fbb56c553ee5d1fac0f052c7ce2504c0fd48c9fa6494a6bff63c9fc", x"b586e67ae1826a1cdd651ac785e4b38f8a0e042f103a9b7dbb0035626d5dec3ded04a4e2cc09e63b4b01aebe304e40d7", x"b1e604fc3e1827c6d6c58edd4bc42b1529b2da46e2438591317258be9147359278f154e02465b938c727bb3b0c0cf8f4", x"a3681ac11c5426767a2f1cdc89557746d5501d70add50bf4f2c9165fb5055af0644f3013603209cbaa0414d3dc794ee7", x"acdaa6263cb7ffa0fa159983888348fef7f0514abd4d897884bb6eaeb57c68e61044047215ccb0f32face09b0a72ea3b", x"94402d05dbe02a7505da715c5b26438880d086e3130dce7d6c59a9cca1943fe88c44771619303ec71736774b3cc5b1f6", x"ac7e49f2059e99ff65505742978f8d61a03f73f40141a2bd46fde5a2346f36ce5366e01ed7f0b7e807a5ce0730e9eaa9", x"9348cf0fbd4414944935b61d9c99a9ad4c1b1825a7059e698a2709b0f07adaa26b32db557f32388b44461285959d25d3", x"aff9a5903b2531bdf658c28fea5b8ebafdc4f0c562b97a7236442359fbb9c9184eaad619d40d49a6314062240c2757bf", x"820f164a16c02e136911dadbc61b9f6859a7c53d0ea17b8f64b783f7f2f4f549775d3f16e21634dc6d54aef8d56517b2", x"a2ee6c29efa982e9b9abd3c5e4f14b99d5d0369d7bfc3c8edae1ab927398dc8a147a89e127b3324d7f4e3a7494c5d811", x"aca69a4095567331a665e2841210655636a3273d7b7590e021925fe50757617898e1883532f9cfd46428c2e3d854f9f7", x"8d5de60e934ea0471d9e0a46489f21e03abb9722f5b3633631a9a099b9524beac5d67716969c83d824498796d9c106b7", x"9104ac7ad13b441c6b2234a319e1c54e7f172c9a3efcb8c5fab0ac1d388b01895a9a208f59910bc00fb998b0adab1bc3", x"9427579975e81128057097972bedda9f0240c97233631a23c50ce1a007c0d0d5898deb0daccf4e1518dfb9abba81bf71", x"aa5ad6e6ff8d959149828f32242ce589f8581689a87c084d73ecfdf4ab95d64ba7397cf3424f6be03debfa0c1630a8fa", x"86cef0506d35ac8afa7509561aa90bbc89663f7f880a86b0aa838464a33a36f27808cd8b68fa6f729e6eede4ab0583da", x"87c2989f377be3751da3bc19172c5987d21c095cc3d851ee5120f67a5b3986d387b058688d54336d8510c49c6a66d754", x"ab6e3180dae399d41243f23545e5e6d118844f9b8edba502a3503fd1162ed826f9fc610889a1d685d374b6c21e86067d", x"b7a0edd359a49390cad1002317a80a1b4618d152e12e1fc96b2eb1cc89548162e5fe0185cdd2ee913da421361299a255", x"a5d7e847ce7793386e17fe525f82aabb790d5417c3c6e3f6312f8e5ff52efa8b345c1ff60c4c9bf7636f5ff17b7a0061", x"83e264b1d3d4622826ab98d06f28bbbd03014cc55a41aaf3f2a30eec50430877d62b28c9d6d4be98cb83e1e20f3b13db", x"a5562fbaa952d4dcfe234023f969fa691307a8dfa46de1b2dcff73d3791d56b1c52d3b949365911fdff6dde44c08e855", x"abe68d5cac6809960b97b09c8b834f6672a66211dbdfc6fba08342453eca026455f904ad215d07d438652e18d1d19cb6", x"b4745c71c45bcc30163ed4fad7ad706b188fc1e19cf962f547d5500ff1972493539d2787c0e5ace5a85f7c39d1be4bbb", x"a2b1ea43f51460b3cb83657b4e296944658945d3ad6ae7b392e60f40829ba1da6a812d89f0380474578cbd0ab09801ac", x"b382fa28670a5e14dc954b2db8ace250c73df71ab095304bd8ee28f455ab26cc54f82775a831428e110d1a3a2af709bb", x"85e2013728a13c41601d4f984f0420a124db40154a98bbe8fddc99e87188b4a1272d20360406a9dbae9e49bfe3f1c11c", x"993726e0b1c2277b97b83c80192e14b67977bf21b6ebcde2bda30261aa1897251cd2e277cfcb6193517f1eb156d2fe86", x"94f4720c194e7ea4232048b0af18b8a920fde7b82869e2abcc7e14a9906530be1ef61132884bb159df019e66d83a0315", x"841d9c04009af59c646e65cb79be10bff240fec75d756c8b8b9c4f54a2463561510f5b2f3d09eacce57cfa4a856d72f7", x"925f3bb79c89a759cbf1fabdaa4d332dfe1b2d146c9b782fe4a9f85fee522834e05c4c0df8915f8f7b5389604ba66c19", x"a3c6cf60e891f64fc384b2d35651cc84976fa98bdba22a196bf70d95a68575a7451854c5c30c469427f63698eb574613", x"8853eff72fa4c7b4eda77e448e12bc8ee75f5cb0f35b721c7ee8184cf030a11e3e0278a4e76b326416fd645a9645d901", x"a4632399c1a813e41fb2055ef293466098ea7752a9d3722d019aa01620f8c5ecdc5954f176c6c0901a770cbe6990eb11", x"985af1d441b93fa2a86c86b6d7b70b16973d3971e4e89e093b65f0ae626d702202336869af8e3af3923e287547d5384b", x"ab7c058199294c02e1edf9b790004f971cb8c41ae7efd25592705970141cdd5318e8eb187959f1ac8bf45c59f1ead0d9", x"96cf5760c79cfc830d1d5bd6df6cfd67596bef24e22eed52cee04c290ad418add74e77965ea5748b7f0fb34ee4f43232", x"b7ea5e0d3cfcf0570204b0371d69df1ab8f1fdc4e58688ecd2b884399644f7d318d660c23bd4d6d60d44a43aa9cf656d", x"a71d2c8374776f773bad4de6edfc5f3ff1ea41f06eb807787d3fba5b1f0f741aae63503dbca533e7d4d7d46ab8e4988a", x"ad83b3c5e9a08161950b1df9261d332dda2602cc68e0f5ee75bfa7e03bbef9edfb4945ca1f139df1bcb8affe8ae025da", x"86a6560763e95ba0b4c3aa16efd240b1873813386871681d075266511063b2f5077779a4fe49ffc35e1f320b613b8c94", x"84ed656b5291cbb2843ecc8371cbf1447955256059bef4a77133f1a37e7529fb64cefaa2ea973c680329f6110999b22f", x"b53fb1956a2a34a840de4ff0b5b1e0e2fb78a21ac8edbce6be6c26a4b4de6d37e9dce799110a802a344e8541912353d7", x"b13b5cb86dc8b8fe87125f1a51fe98db36bdde4f600401408b75059a44e70b1bbfefd874e539691f3f1bf6f54db883c8", x"927c030d5a69f0908c08f95715f7a8d1e33bed5e95fc4cfb17f7743cb0262755b1e6b56d409adcfb7351b2706c964d3b", x"80e58680edb62d6ef04727a36e41e5ba63fe787aa173171486caee061dcb6323f8b2de07fc0f1f229c0a838ed00e3e31", x"a113b889be5dcc859a7f50421614a51516b3aadc60489a8c52f668e035c59d61640da74ba1a608856db4ff1fa1fe2dfd", x"973ab82026d360e2cf5676d883906186bc61b43f60767ca58f11d0995e40780b163961e6e096299ccf1c86175203abde", x"acbb398ea9d782388c834cf7b3d95b9ff80ee2a8d072acae8f9979595910849e657889b994531c949d2601b3ce7b235d", x"ae0beb452af7479134a7fbc31a5f59d248e8a67d4c7f73a0e30a51db9cd33a1da3f0ae947fa7e5983aea1343e7daf06a", x"8b6bc5b51ba51ba6cd8925766b9266c59f5c1af2e029fe5c51d9332cbde1d0399afa967aca5119fafca623ed0f465354", x"abbfb501071148e98b6aa56308197356fd993c93e27fd58987eca82036c1ae0ea89f9fb1a06c82851234643904c58453", x"8c122bea78deee98f00a86184ded61c10c97335bd672dadddc8224a1da21a325e221f8a7cfd4e723608ebcd85a2f19fe", x"946948e31311703f64d34dc6faaae992e39b7ced92ecdc01df9761e3819a6db1266be718fdf434fbec912da37d1986f1", x"aa0b0ef6abddbb4931fea8c194e50b47ff27ea8a290b5ef11227a6b15ae5eda11c4ab8c4f816d8929b8e7b13b0b96030", x"b0a32f5ee1e22853d6557c59517234abf7af5bd5984274fc084f25dbd8a07d026715b23b776fe47f8a3686c69a77cb8c", x"93706f8d7daca7c3b339538fb7087ddbf09c733662b55c35f2a71073f4a17c91741955d4d549c2ee6c22eaa84193c1ad", x"a26c326f3b48758157f74993971a1bf0913ae292a4eb4a4653ee53a2a916782466cbcced54c71685668ae0a7ef0e210b", x"b5036d4c241685bcd67156e4ab0eba42b97f639947d54b17af2c88fbcc5fc57359c7df4bc7f8df955a524fb1501a6fda", x"81c3a8c00cfe4e82f3d8cb48de7d4926d5ec2f7689f9cb85c1886a23758bc107a4bc6e978601c3519156a169d0bf6779", x"854410e6fb856da8b997ebf28ae2415ce6e1f9f6a4579fad15b5df61709c924a925397b33fe67c89ffad6143a39d756a", x"b2f168afc35ed9b308ab86c8c4aaf1dcd6833ce09153bb5e124dad198b006e86a941832d387b1bd34b63c261c6b88678", x"8553748da4e0b695967e843277d0f6efeb8ba24b44aa9fa3230f4b731caec6ed5e87d3a2fcd31d8ee206e2e4414d6cf4", x"897eed8c65712e9b1ed8213abb85a6252ec30ab47eda4e36aeb8a72447ce7972861bc97957bc321714328c64af27544b", x"95614544f65808f096c8297d7cf45b274fc9b2b1bd63f8c3a95d84393f1d0784d18cacb59a7ddd2caf2764b675fba272", x"92ff79402d5005d463006e0a6991eaacc3136c4823487d912cc7eec1fe9f61caf24cd10022afdab5f6b4f85bfb3eee4f", x"ab99038a2a6f9228d5d7e67f47107abaf06af293586c3a6ab1adaf02aae373e3434ae3e26bb617302b8e3a7ce5107bd0", x"aa6cfb3a25f4d06c3ce1e8fd87496a74a5b951ab72557472a181a2e278c5e982d290dd4facf40bd2f4f8be62263dadb0", x"938dc1e182f19f40ba9a4eb5530407e58dac27a237b259fad4ff070c8abf98a0fb107db6017e1da25a855c8867e80bae", x"88d8a32231ff2bfc39f1f9d39ccf638727b4ead866660b1b8bfbdf59c5ab4d76efddd76930eff49ea0af048b2e396b6c", x"81e0992e7c1c54c21cac32e36b90b25e1e5b72aac99c953c3c4d019eced64d7e316cbc0840204a4a51a4ad17d8b1d508", x"ad7d2e3820e9c9afb8afe3d01b62bf7e05d1d5c3697045562059a4421892e37515ad87251c780f917e3cc72fbd318be5", x"b3c0847c126b8ee7d52dc13bbb6a1bb1ebd6a4840fa07a90c1b10aaf0837f53226c378be43c0d13bb2fad9cae21a8d18", x"935d93df3c8d375718e2be93a7a6ba9ef94286f1bd47f7d8b958f55cdf242e1ec6936bb6d044e11e56899f8a2ff3a86b", x"ae36ab11be96f8c8fcfd75382bb7f4727511596bc08c25814d22f2b894952489d08396b458f7884d6b3c0adb69856a6d", x"b4538a2f4ba534e71e83c023a7a0cb02151a4190398c12944c20402a556d5eb43ec4eba7eeb85b665506623b8301f627", x"96b15806d9009962fa07f8c32e92e3bc30be4ded0645ab9f486962a1b317e313830992179826d746ea26d4d906bdb7b6", x"a6d6ef51a361df2e8f1d993980e4df93dbbb32248a8608e3e2b724093936f013edabb2e3374842b7cce9630e57c7e4dd", x"842ba3c847c99532bf3a9339380e84839326d39d404f9c2994821eaf265185c1ac87d3dc04a7f851df4961e540330323", x"ae8af784224b434b4dfa9ae94481da4c425602097936623e8abb875f25deb907aa7530bce357786a26ed64ef53d5e6b3", x"87cac423d0847ee3547f45ac5babf53bddb154814e291f368cbb62ddd4f2c6f18d77a1c39fddb482befe1a0e77d5b7fd", x"8068da6d588f7633334da98340cb5316f61fcab31ddfca2ab0d085d02819b8e0131eb7cdef8507262ad891036280702c", x"87c6cb9ca628d4081000bc6c71425b95570291eb32ef2cf62416bd1ce3666eb2ce54accd69f79d506cefbfe6feb5a1da", x"af3d3dffbe55842dfb4417295a6ed1a82d26a579199494b305445215045785759be4cb57dc870c7ddaffbc101a854a92", x"a19f2ce14e09ece5972fe5af1c1778b86d2ab6e825eccdb0ac368bb246cfe53433327abfe0c6fa00e0553863d0a8128e", x"afe779a9ca4edc032fed08ee0dd069be277d7663e898dceaba6001399b0b77bbce653c9dc90f27137b4278d754c1551a", x"830e70476c6093d8b9c621ddf0468a7890942589cae744300416639a8b3bc59a57a7e1150b8207b6ab83dafcc5b65d3c", x"82d09556978fa09b3d110e6066c20db31da2e18de90f973930f752970046f2df96b2a0248fdd833cbc50abad5c756026", x"91412f6f2d5662c541f77a4fb884daaadb305765e148dc2f5495cbf9ca29fdb3f53af6fce4493f3f5fd7c867901e98f3", x"834932258f3f97e601fe915651449c046274779ab86054a3a040c2b006c88d2a78a9cd552c0a735a45304d1624497a62", x"a54e104339286d3ce8271828fbac20f6cf7afd3b72d9b194b7cbaf65f6612416117be492bf4aa88faf6ada56cf4b6462", x"a3d327f48eb34998a3b19a745bca3fade6a71360022c9180efb60d5a6f4126c3f4dfa498f45b9a626ca567fdd66ffbff", x"87e39895ee4bcf83f007c7e8c560304d55674cdfef16e3fb5a309061dd97f37b12da2acf5b2f05c0d07fd594277d49ff", x"acd4d1e11f81f4833353b09d4473ec8b15b8ff31dbf39e97654f5338a26c4020306d51018f1f4b9c4efdb92992408a6e", x"887a4277ee8754733f3692a90416eeac1ebee52ff23173a827f0ba569bd84efd806eb9139049f66cc577e370d3f0962d", x"a1c84730a5c41dcab9a5ef9e1508a48213dbc69b00c8f814baf3f5e676355fc0b432d58a23ad542b55b527a3909b3af6", x"84926cf2265981e5531d90d8f2da1041cb73bdb1a7e11eb8ab21dbe94fefad5bbd674f6cafbcaa597480567edf0b2029", x"b6fdf7016529321bf715ec46c98633e08c53d04ba065cc6d59612c6c8e3970ac41b0c3923031a53c1a4689e5ca9d084a", x"970df2314849c27daa16c6845f95b7be178c034d795b00a5b6757cc2f43c4c8d8c2e4d082bec28d58dd4de0cb5718d61", x"80bdb82b7d583bf1e41653966b0ba3b4fec0e7df2ff08e3fa06fd9064bca0364263e075e1582741a5243bde786c9c32e", x"ad28fe70a8606f87bcb5d6f44e1fca499c24bcee791971f599ffef1f403dc7aec2ab6ebed73c1f8750a9b0ff8f69a1e6", x"ad8e8e3b82f5b8c1a39efe704b0d1eddb6e2275a990aaccad0c509f3109e42ac49aeea6c2f6da02d2d0af6cfbe5598bc", x"953fd87ef722c6f4222819e3ec5cee85cb64c9fc6a6e982e38b3ca531a027f5cba9e554424489c7a64e144d83a1a9830", x"a9ef845ab489f61dbfdcd71abcc29fc38f3494a00243b9c20b9cd0dd9e8a0f23304df84939b9652cdf5542d9b3ee085e", x"a356e5b70bc478c625e32a38d29f0a619fdeb665503eedc304d1bf34562d4b6814dfc30aee5aee94ca4bc6394e412765", x"b9691fb57be7aeb9d43995b8022051f199978d6ad635e1623a1bc1754b250fb8a94985cdc1e623e98767690a417e92a0", x"8085c60b6b12ac8a5be8a7e24977663125c34827842aa3b2730854ab199dd0d2eaa93084c9599f0939be8db6758b198b", x"b5f69b7614fe07889b58142d7b438186d70214ff4cb209b6f271a3bf2bcdef5e6f1c7e95dbf5f2785aa471f0294cd029", x"acd17cba1203748b55bd9d7b940a16bb7c02988c93007a80b87e0bdb049b91f5ecce577e3e4ea68a0abe998a72cd300d", x"916e770af2939ae3d933db81d8fedff334591380b379ef4a6e0d873b67ba92f5ccf514805a38b961b8e1a346b054506e", x"b21785008910a949804d1291e7533752641d31beae3cb518806488f81d58c38a5efe5ed9534ac692e68c3121e2f9d97d", x"b3285148b91dab139b053442bdd14d627ba1e1250fe469f0f2df854b6e6ff4a18671ae3879ec9f7d8091f99f092162e9", x"818202d7cb60e4148c71633ccbe1ce311de7b7ff93a1988e86ba29cc58037189f0f275b3323a6719dc9bdcfbc49c35c3", x"a0bc362946a373566c0fbd0b8bdd62ac76d972c960c0b0d8589304d18252286f7277e3b58229e6aa8a8bbf2ee2d99163", x"b380ee52038a0b622cd7eccf4bd52966573fadde4fe8f70f43fa9c43a5a99b3eaf58335a1948b561f5b368ab4e0710f6", x"8658a15df961c25648fd444bdf48a8f7bb382d9212c0c65d56bf9cdb61aab3bd86604c687fb682260dbc0ad2dc84bf01", x"b07d7c3f1d486f5657d5935e3d67403024ffdcf25da5c460fdadc980d8d6b931de623c4f8a3da5eb6af346193eb36573", x"b7eba9659ad46354f710b94476e8fcad4ecf74c584c1b6252960e7e7759c8a064127929bbec71f2b868d098140b3de40", x"ac0f000ab9d0e6fdfa78e708b0d829ff1dd6a71f0c9af20e29df7eff924f526e2d9a042aec03c6f5afb04c2377a218eb", x"aa103a329b699d4102f948101ce5fae27226419f75d866d235da8956f11367e71db5c0a179dd63007ed53f7eec333aaa", x"a7b86e4f1366da44fd59a3ee68018a99c23ba3588789463bd88b0177a9b94030b58cb879a506e64421af966f261eaa86", x"97b43a6d1a47a1c415278344dba0cdfa952663a71fdcaf58d313c161e479ab5d1b980d8870055cc8f0d283bec8f97425", x"8f6fde2ebbd7682c69026069cfe93aa5410071f05de9ccd7070c8c3299a6539b39b3798f01a0b4e9b1330510bdb51de7", x"a58219e63b7a11891889c342fc5a6bfaf73e3a99699479bc1885ea560078d8180696d0831cd682faeba1f6b355c7c7b2", x"b97b2f1b2d6d744f2322812825ea1cf91453dfe1bbbb2678776e40e7d0fe682239d0dc8053f94d97e5a9678232b7a71f", x"88e7a12a90428bb45bcf4b01442c11607433211fc2f9bee9545304eb66e0b4b5339360160bc782e185391385da7c5ad7", x"8ba45888012549a343983c43cea12a0c268d2f7884fcf563d98e8c0e08686064a9231ae83680f225e46d021a4e7959bb", x"8391e3ad6ec2686bdc686671d579edac2d5efa8cf0923577df28fe0735e4d5103173d44452816e3c2b2a7fcc1fcc20d9", x"b76f598fd5c28d742bc1a81af84f35f1284d62239989f1025e9eba9bece2d746a52f246f9bb6bcfde888b9f7b67fc4f6", x"af18cf1e3d094b4d8423da072f98b3023d296f6a1f2a35d500f02bde522bb81dc65e9741c5bc74f7d5613bd78ce6bc03", x"b01a30d439def99e676c097e5f4b2aa249aa4d184eaace81819a698cb37d33f5a24089339916ee0acb539f0e62936d83", x"b083c4cefb555576bb37b71f30532822cb4b1e1998e35cb00ffb80ca14e2853193c16a6756417853d4a74d625744dd76", x"989fa046d04b41fc95a04dabb7ab8b64e84afaa85c0aa49e1c6878d7b2814094402d62ae42dfbf3ac72e6770ee0926a8", x"b6652440bd01316523feefceb460158cd9ba268dd8dbe860a0271f0176230f057767597e4197885ba907318ca202ba06", x"a988cfed9f481bc98beb5fc188ed3f6893a3ebba27c3ebace669792f6abf0997727023c3b6930a6421224f5b257b8b49", x"a333abf3cfa6b46599e210f7ae33cb6bd378ffa4e11fb5bf9d2cdc2787cc34e6e088e010321c193ce46495009e88b780", x"a3ee8fd53158dad3b6d9757033abf2f3d1d78a4da4022643920c233711ff5378ac4a94eadcaf0416fdcca525391d0c64", x"94f327bc57ed1ce88ce4504b4810cc8af5bd21a7e07b280a7866ce08e39b6cf7a6560bf73a5f10671271624cd7893970", x"b7dfbda841af9b908a43071b210a58f9b066b8f93e0ac23a1977c821d7752d1a390c5936d4c32435da2b20b05c2a80da", x"a9760afaa51002be0948acf7aebd90ec4e60e0dba8456e445aea93408a0468b62bb6da4984b92f8f6061561c9d56f4c4", x"a2bf96cd119e8c75807c32df3f3b19ca01fb185802d58f2d4d35af407abfdec6f4784c54d315818da77a3ff433811668", x"94ee5e97e8b57f0fad7bf1fa75d8ad535a571b706964b1bf2761d41f24a37c9c9d1fc2c7986dae41d6e15d276e6140b7", x"ae89e41d8cfbf26057a4078f8a5146978e658801b08814190cbce017d79beaeb71558231a72bde726fa592fb0828c01c", x"b9574edb9567f07f85c7c2e6ca6c02d90ad7c7b87d49796f1e2fb7240ad071fb755cf13ca8678668a56217c62df168eb", x"b7c4e55e2b48ba55a71f72387475886e5b4715100e93cd2ae09582fd37e5646b54bd93fba311b65c842bd0aae1424bc7", x"a21477f0b51d73b0816b4b411c12db1e3a83698113ff9299ab2827e8da59baa85dbcc70afb831f5b0c038e0470562f00", x"ac722bd742374f925185ea7d4d62d7510b2d8a6ebf5c750af6ce83e2d8a28c95a3e298870ec8254ab2d1d0aa2a063c60", x"918c1408978c5be7d482876d47ab97e70424b9b9d27a2c95f017d847bb7f152db27b63929514653e28be644c3c92a9a3", x"b6cec65e5268818c82c0a4a029b02f8d23de98b68730a445119fee670118eb34027c23c987fac950f9b0151631328a4e", x"a57d5de556853484b1d88808d2529450238bc467376ded84cfd7b4a1ba258f6d43b5958220f962c57b033abcef1d5158", x"8be8d356bbf35ccd5980848662b5d6361eef583b535da90cef6c07904ccfb5963aaa230ac30ad63441f60e807434497f", x"b926a21f555c296603dc9e24e176243199a533914f48994b20abca16f19c30cfd0baf319268139fe3f83ce69afdc324d", x"8553bfd1a163df0d8bb1424383552b85a1c0d288dc1f46fdde90ce2d9be7e2688d7d06e1d6be06252c7099588d3488e5", x"859426bf6211e68924eefdb26cdc168ac0deab291aaff7036163997bff34d45809932f91e12d113784c05553ca773b15", x"a065363b9c4b731b08fd361081f93d987ad336475487dd28bbda2dca92b0b5da4edf326995a4ae923a4b2add7aa1df4d", x"968d44188e2d9d1508b0659e96d6dabd0b46aa22df8d182e977c7f59e13aa05d5da09f293f14f6f2ee1b996071cd2f25", x"aad9577501d7f3a5dbac329f2c1fe711710869cc825740f365488fc55a278d687bb72423560f7cb2cbd60546a82ea1e6", x"a3b109249ac2900806f0f39338da72d4f2cc6d1ac403b59834b46da5705cf436af8499fa83717f954edb32312397c8d9", x"a910ab63aef54d8da04a839995ef38893d2cf884539ec81f97b8a4dde1061a27f6d3fe41186d1b7af872c12d44f36397", x"a0f72705628b1ff0bd6f6c80a1878c9f66b5f99e2e2cf97e5c32c7c662466b3c2553cec24169716b20e06407b092db5f", x"84f43aa4e2a9d10e6590314981b5eb2a5e486c1593a4f82bc3a82b67f6ccc29652ab82a689a9454bcb6c1f9bf7a10e2b", x"a1047401598b1e6e2613d746bb4689e0406eccdbadf319a6609a3261cd09deec215d90eba6d0ddc50dd3787d60104e7f", x"8982534f2c343dda20cccf5a9c8bf98240bba5f4e8eb2206e63a1847097deadb6bf0d24b358014d564c5ef1d0448c43e", x"8f11ee58ef82b1bbd2240d3f548d8681e22bed5ce118d605bed4523b4bb39899ac78e15337daab92666750dfcaf32aff", x"a95bec86a7c8417a8df3a0158199327ba0924d3b7dd94cd7c1ef8489b10270ae64b8537ed39cd3699a48942bfc80c35d", x"8f7dbe5a57f7b0a45b7c9d87338b8ff67ce9977e2ec669f5502e77d1be30889a7976819c45c787b279b4dd96423b3715", x"871656153e1f359ea1cf77914a76de34b77cb62e670c99f3584e7cb2c500c04f65f36bcb5321f4630df5c3de9245a7c0", x"897f0316496f0c775bf63d546103df711a4b0915c3bf893e22a6837c9585c0e5f2f4740513e0bad4839b76fce3877844", x"a23431589f3a25070a188deead9adb0ed423d6b00af267f3f125cdd4391c1527909b5cfa88130dc4b67915f5002128fa", x"8fd9711c2c4f7af282555989ba43e968da4a6b1143b9a6681a8ac3e52abbf916b8ac9036d7c628432969d2001c9623b2", x"a9f261d19934fd26458421551e91f484d7a1522a7e7adbfb28f6371102a7650a5ae6efd49d9e33b03aefde647d134ce6", x"81d6fc2f01633e8eab3ba4d72588e14f45b00e68ab887bdd4ec5e8558965db21189310df973837106216777b07fc0805", x"85292ad11beb20440425adfd23634ba34fb46dbf5e07bd216918a4a1e1d9ff49bbbe56f81e0aaa16bfd67d439e787306", x"ac9ead4333cffa49ee925bdc47e2c1a0ca9d1a07239d107a2a8a2b0471fd9d4626ce44bf001d73975828237723de065d", x"b298aa927713c86adfe0de1a8d6f4083b718c8be27156da9fd11abd8edb3a54a926ad487801eb39cfc9363a0a3be0d44", x"b6e9fe9fa3d4c833c3beae7f798f30f07e3cdf6f6c8eb8e2b70cad51b37af2549dc9f2e7f97f194e5897d4dedb904a45", x"85745bd84c92ddfc55df11fe134cf70e3c340aa1c7cdd6188a03308cf3a840f4f19629f9730b2e6426424989ff03000d", x"957ec198679edd0c35f83eb2ae6fde01050104c0ee3d1c18e520f9a16d04f119994e0ebbb46777f9c6de4e4408aae8a4", x"8a3987de0131b7461bbbe54e59f6cefe8b3f5051ed3f35e4ad06e681c47beee6614b4e1fba2baa84dff8c94080dddda0", x"8d47a7c2c62b459b91e8f67e9841b34a282ceb11e2c4b0549883b627c8526d9e0ebd7333ba70630bc0ec2478114b6ae8", x"8499a8c3d67d1f6eccf1c69274393dc498cff862ea8e6c11ffb8107ae190d258ddc1d294f2a8f050488df0212063ece2", x"a75bcd04fcb44ce5cbab7eef6649155ec0bef46202e4eb86c88b4ced65e111f764ee7fb37e9f68e38067040fedf715ee", x"a641eaa149c366de228a2833907ad60eea423dd3edf47e76042fdf6f5dc47a5b5fc1f1b92c8b96c70e6d8a68d3b8896c", x"8dd55efbf4f9cf6aba47c16730bbc5dc3d332bf2e9f1be8695f755362ad2f8e6f6e2426e52cdf0ba9feb9e17533c4b06", x"841d77b358c4567396925040dffe17b3b82c6f199285ac621b2a95aa401ddb2bc6f07ebd5fa500af01f64d3bb44de2df", x"8a1f575515fe8f98ea0da9de76bed0b3f871f3fc7254651e63c31a5ec47f0f8e64f9a0dc62a3b79d1d4b6d7ffbe040b6", x"825aca3d3dfa1d0b914e59fc3eeab6afcc5dc7e30fccd4879c592da4ea9a4e8a7a1057fc5b3faab12086e587126aa443", x"a222ec6b756b0533dce7e903c24a69b3d48db0d1e93c4c41a882461b8939b9cc90645745d89fa0873739f812dd3b2cb3", x"95915d8ff2df795e7baac5433887c39ec6bbb9281c5d3406a4a1a2008f96c6f266adad4824c6c46429a158e36f5e1210", x"951d69f32685615df304c035151bd596d43bc3250f966e0c777544c506e3035d031afa4a3fcca1b85c41a4a041aefc01", x"88712da029cb3d8b9d5b819d8390b3e31e95debc89636d8e4d46ba8777ee57f16ec04097a6aab1ad9c74f52634fda7f6", x"afd6ea5e66f0e3ab835091ad51a98f891411238098196ed63c1cbf45d5428d1fcac4fb7b7129f2c880b06220d3ee8cec", x"946d585d7aa452d37a8c89d404757c3cce2adf2410e18613483c19199abd88f7a12e206f87a43f6009e42f4e31ed20c0", x"85ee86a9de26a913148a5ced096ba46ee131d2975f991d6efcb3fec62975b01a1d429fc85d182f0d2af72d1adf5bfd2b", x"93121aa60f904a48e624e00f5410cf8c8925d2b0719f90c20e00cba584626f833de7c8a18dbfa6a07df24b916156bfc0"
        ];
        let aggregate_public_key =
            x"86ccdd2972224ba2b0b0cb0092d3e117e96b1ca29425d9d40be571fb6bab166f435a07eb8fe941462217fdbccbac6a31";
        (public_keys, aggregate_public_key)
    }

    #[test_only]
    public fun test_get_slot(header: &BeaconBlockHeader) : u64 {
        get_slot(header)
    }

    #[test_only]
    public fun test_get_proposer_index(header: &BeaconBlockHeader) : u64 {
        get_proposer_index(header)
    }
    #[test_only]
    public fun test_construct_sync_aggregate(
        bits: vector<bool>,
        sig: vector<u8>
    ) : SyncAggregate{
        construct_sync_aggregate(bits, sig)
    }
    #[test_only]
    public fun test_construct_lightclient_update(
        signature_slot: u64,
        finality_branch: Option<vector<vector<u8>>>,
        attested_block_header: BeaconBlockHeader,
        finalized_block_header: Option<BeaconBlockHeader>,
        sync_aggregate: SyncAggregate
    ) : LightClientUpdate {
        construct_lightclient_update(
            signature_slot,
            finality_branch,
            attested_block_header,
            finalized_block_header,
            sync_aggregate
        )
    }

    #[test_only]
    public fun test_get_sync_committee_signature(
        sync_aggregate: &SyncAggregate
    ) : &Signature{
        get_sync_committee_signature(sync_aggregate)
    }

    #[test_only]
    public fun test_get_attested_header_update(
        update: &LightClientUpdate
    ) : &BeaconBlockHeader{
        get_attested_header_update(update)
    }
    #[test_only]
    public fun test_compute_fork_data_root(
        current_version: vector<u8>,
        genesis_validators_root: &vector<u8>
    ) : vector<u8>{
        compute_fork_data_root(current_version, genesis_validators_root)
    }
    #[test_only]
    public fun test_hash_tree_root_signing_data(data: &SigningData): vector<u8> {
        hash_tree_root_signing_data(data)
    }
    #[test_only]
    public fun test_get_fork_version(forks: vector<Fork>): vector<u8> {
        get_fork_version(forks)
    }

    #[test_only]
    public fun test_is_valid_merkle_branch(
        root: vector<u8>,
        leaf: vector<u8>,
        branch: vector<vector<u8>>,
        depth: u64,
        index: u64
    ): bool {
        is_valid_merkle_branch(root, leaf, branch, depth, index)
    }

    #[test_only]
    public fun test_get_signature_slot_update(
        update: &LightClientUpdate
    ) : u64{
        get_signature_slot_update(update)
    }
    #[test_only]
    public fun test_get_finality_branch_update(update: &LightClientUpdate):Option<vector<vector<u8>>>  {
        get_finality_branch_update(update)
    }
    #[test_only]
    public fun test_get_finalized_header_update(update: &LightClientUpdate) : Option<BeaconBlockHeader> {
        get_finalized_header_update(update)
    }
    #[test_only]
    public fun test_get_body_root(header: &BeaconBlockHeader) : &vector<u8> {
        get_body_root(header)
    }
    #[test_only]
    public fun test_construct_sync_committee(
        public_keys: vector<PublicKeyWithPoP>,
        aggregate_public_key: PublicKey
    ): SyncCommittee {
        construct_sync_committee(public_keys, aggregate_public_key)
    }

    #[test_only]
    public fun test_construct_signing_data(
        object_root: vector<u8>,
        domain: vector<u8>
    ): SigningData {
        construct_signing_data(object_root, domain)
    }
    #[test_only]
    public fun test_get_object_root(signing_data: &SigningData): &vector<u8> {
        get_object_root(signing_data)
    }
    #[test_only]
    public fun test_get_sync_committee_bits(sync_aggregate: &SyncAggregate): &vector<bool> {
        get_sync_committee_bits(sync_aggregate)
    }

    #[test_only]
    public fun test_hash_tree_root_public_key(compressed_pubkey: vector<u8>): vector<u8> {
        hash_tree_root_public_key(compressed_pubkey)
    }

    #[test_only]
    public fun test_get_domain(signing_data: &SigningData): &vector<u8> {
        get_domain(signing_data)
    }

    #[test_only]
    public fun test_construct_fork(
        epoch: u64,
        version: vector<u8>
    ): Fork {
        construct_fork(epoch, version)
    }
    #[test_only]
    public fun test_get_epoch(fork: &Fork): u64 {
        get_epoch(fork)
    }
    #[test_only]
    public fun test_get_version(fork: &Fork): &vector<u8> {
        get_version(fork)
    }

    #[test_only]
    public fun test_get_sync_aggregate_update(
        update: &LightClientUpdate
    ) : SyncAggregate{
        *get_sync_aggregate_update(update)
    }
    #[test_only]
    public fun test_construct_beacon_block_header(
        slot: u64,
        proposer_index: u64,
        parent_root: vector<u8>,
        state_root: vector<u8>,
        body_root: vector<u8>
    ) :BeaconBlockHeader{
        construct_beacon_block_header(slot, proposer_index, parent_root, state_root, body_root)
    }
    #[test_only]
    public fun test_hash_tree_root_beacon_block_header(
        data: &BeaconBlockHeader
    ): vector<u8> {
        hash_tree_root_beacon_block_header(data)
    }

    #[test_only]
    public fun test_get_parent_root(header: &BeaconBlockHeader) : &vector<u8> {
        get_parent_root(header)
    }
    #[test_only]
    public fun test_calculate_root(leaves: &mut vector<vector<u8>>) : vector<u8>{
        calculate_root(leaves)
    }

    #[test_only]
    public fun test_get_state_root(header: &BeaconBlockHeader)  : &vector<u8>{
        get_state_root(header)
    }
    #[test_only]
    public fun test_next_power_of_two(n: u64) : u64{
        next_power_of_two(n)
    }
    #[test_only]
    public fun test_verify_merkle_proof(
        leaf: vector<u8>,
        proof: vector<vector<u8>>,
        index: u64,
        root: vector<u8>
    ):bool {
        verify_merkle_proof(leaf, proof, index, root)
    }

}