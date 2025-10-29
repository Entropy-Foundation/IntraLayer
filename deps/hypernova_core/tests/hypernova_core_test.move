/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
#[test_only]
module hypernova_core::hypernova_core_test {
    use hypernova_core::hypernova_core::{test_get_light_client_view};
    use hypernova_core::eth_types::{
        LightClientUpdate,
        test_construct_sync_committee,
        test_construct_beacon_block_header,
        test_get_sync_committee_bits,
        test_construct_fork,
        test_is_valid_merkle_branch,
        test_hash_tree_root_beacon_block_header,
        test_hash_tree_root_signing_data,
        test_hash_tree_root_public_key,
        test_get_epoch,
        test_get_version,
        test_compute_fork_data_root,
        test_verify_merkle_proof,
        test_next_power_of_two,
        test_get_proposer_index,
        test_get_parent_root,
        test_calculate_root,
        test_get_state_root,
        test_get_body_root,
        test_get_finalized_header_update,
        test_get_finality_branch_update,
        test_get_sync_committee_signature,
        test_get_slot,
        test_construct_sync_aggregate,
        test_construct_lightclient_update,
        test_get_signature_slot_update,
        test_get_sync_aggregate_update,
        test_get_attested_header_update,
        test_construct_signing_data,
        test_get_object_root,
        test_get_domain
    };
    use aptos_std::option;
    use std::debug::print;

    use hypernova_core::message_types::{

        test_construct_message,
        test_get_log,
        test_get_msg_id,
        test_get_source_chain_id,
        test_get_source_hn_address,
        test_get_destination_chain_id,
        test_get_destination_hn_address,
        test_get_log_hash,
        test_advance,
        test_get_log_index,
        get_topics,
        get_data,
        test_decode,
        test_rlp_encode_u64,
    };
    use hypernova_core::proof_verifier::{
        test_verify_ancestry_proof,
        process_data_optimistic_or_safe,
        process_data_finality
    };
    use hypernova_core::hypernova_core::{
        get_sync_commitee,
        test_only_init_module,
        test_only_initialize_light_client_store,
        generate_resource_address
    };
    use supra_framework::coin;
    use supra_framework::coin::{BurnCapability, MintCapability};
    use supra_framework::supra_coin::SupraCoin;
    use aptos_std::from_bcs::to_address;
    use supra_framework::account;
    use std::features::change_feature_flags_for_testing;
    use supra_framework::supra_coin;
    struct FakeMoneyCapabilities has key {
        burn_cap: BurnCapability<SupraCoin>,
        mint_cap: MintCapability<SupraCoin>
    }
    use supra_framework::signer;
    use supra_framework::timestamp::{
        update_global_time_for_test_secs,
        set_time_has_started_for_testing
    };


    use hypernova_core::hypernova_core::{
        test_convert_public_key_from_bytes_with_pop,
        get_light_client_store,
        initial_sync_committee_update,
        sync_committee_update,
        test_process_light_client_finality_update,
        test_process_light_client_safe_update,
        add_or_update_hypernova_config,
        test_initializer_scratch_space_not_exists,
        test_process_light_client_optimistic_update,
        test_light_client_state_not_exists,
        test_initialize_step,
        test_initialize_light_client_store_v2,
        get_fee_per_verification,
        test_init_module_init,
        get_source_chain_id,
        get_source_hypernova_core_address,
        get_sync_committee_threshold,
        get_source_event_signature_hash,
        update_source_event_signature_hash,
        update_fork_versions,
        update_source_hypernova_contract_address_and_chain_id,

        is_initializer_scratch_space,
        update_sync_committee_threshold
    };
    use aptos_std::bls12381::{signature_from_bytes,
        public_key_from_bytes};

    #[test_only]
    public fun get_finality_update_data_EINVALID_FINALITY_PROOF(invalid: bool): (LightClientUpdate) {
        // LightClientOptimisticUpdate {

        let attested_block_header =
            test_construct_beacon_block_header(
                7164096,
                511,
                x"4f4314d3bd771a577e9c7d55ffe4a3ad747205ef97dbf2366375f106f99ccf3b",
                x"e27113c6dcca28cc3ffcd6352679508480cc754bc7c1848a96a3468783a00696",
                x"0e2b4460f3c20697abda64221246566c97fd52f0a50f3ff6c55b65f715825985"
            );

        let finalized_block_header =
            test_construct_beacon_block_header(
                7164032,
                1452,
                x"2c0d1afc76fbc3f72a3f0002f5ec853969f713c0d7a1cf219523a5359fe2bc55",
                x"a092c6296fa35f9efeaad0bb87469161f2896350cd978c973bddc3589b340df9",
                x"49021303782f1ddc9cd975b26133760c1816bbc8ada5fe6dd5be0716762f076f"
            );

        let finality_merkle_proof = vector[
            x"846a030000000000000000000000000000000000000000000000000000000000",
            x"76079561d1557730adc1508ffea1152d1943b7fc81f94e0224cd46c87dc33411",
            x"920c391726624169471fc7b64a78926333a88f5cd2d91b2f7d935071d2c011aa",
            x"593d2e6e2eca8c5d1123892b5c3b7e3f68a979519dd9ddb7b4bcf2f87a692671",
            x"6aae61f4a5bebfc5e58a9963b3618dfe357ec7b29a5168c0bf8977fb46687edc",
            x"69260a7ff87b57d2d425d5e449c9da37c174296b24a38a37b19347867fe44a16",
            x"b83fd15f77764c922f7289fc7f438eb58651ef588f2dac66333f3d6632edc154"
        ];
        let sync_committee_bits = vector[
            true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, false, true, false, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, true, false, false, true, true, false, true, true, false, false, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, false, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, true, false, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true
        ];
        let sync_aggr =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"a421e337c8f125d40e155ae1886bfc7635181fad3eec1a0cc9aa5086b483362c5ef34c49c98a99253271ed1cff472c2c0ed5d7376ac0972374068c70a4a0636a8a02637fea41ff579ea1b747e1c96995a9def46e80906443ce92d941765a8711"
            );
        let signature_slot = 7164097;

        let sync_aggr_invalid_sig =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"a691a92811636beb56e71e228532a1f8897b56d496f0e7aab6494ad92739a0afecf43ccae4fed143d84ec8207f449d93001c02ed97c9d8062602ef938cca866792f894521f7c4a8fe62170af5c1c87ef22f44142828d92cab0a32fa60bf315e5"
            );

        if (invalid) {
            return test_construct_lightclient_update(
                signature_slot,
                option::some(finality_merkle_proof),
                attested_block_header,
                option::some(finalized_block_header),
                sync_aggr_invalid_sig
            )
        };
        test_construct_lightclient_update(
            signature_slot,
            option::some(finality_merkle_proof),
            attested_block_header,
            option::some(finalized_block_header),
            sync_aggr
        )
    }

    #[test_only]
    public fun get_finality_update_data_EINVALID_TIMESTAMP(invalid: bool): (LightClientUpdate) {
        // LightClientOptimisticUpdate {

        let attested_block_header =
            test_construct_beacon_block_header(
                7164096,
                511,
                x"4f4314d3bd771a577e9c7d55ffe4a3ad747205ef97dbf2366375f106f99ccf3b",
                x"e27113c6dcca28cc3ffcd6352679508480cc754bc7c1848a96a3468783a00696",
                x"0e2b4460f3c20697abda64221246566c97fd52f0a50f3ff6c55b65f715825985"
            );

        let finalized_block_header =
            test_construct_beacon_block_header(
                7164112,
                1452,
                x"2c0d1afc76fbc3f72a3f0002f5ec853969f713c0d7a1cf219523a5359fe2bc55",
                x"a092c6296fa35f9efeaad0bb87469161f2896350cd978c973bddc3589b340df9",
                x"49021303782f1ddc9cd975b26133760c1816bbc8ada5fe6dd5be0716762f076f"
            );

        let finality_merkle_proof = vector[
            x"846a030000000000000000000000000000000000000000000000000000000000",
            x"76079561d1557730adc1508ffea1152d1943b7fc81f94e0224cd46c87dc3e511",
            x"920c391726624169471fc7b64a78926333a88f5cd2d91b2f7d935071d2c083aa",
            x"593d2e6e2eca8c5d1123892b5c3b7e3f68a979519dd9ddb7b4bcf2f87a692671",
            x"6aae61f4a5bebfc5e58a9963b3618dfe357ec7b29a5168c0bf8977fb46687edc",
            x"69260a7ff87b57d2d425d5e449c9da37c174296b24a38a37b19347867fe44a16",
            x"b83fd15f77764c922f7289fc7f438eb58651ef588f2dac66333f3d6632edc154"
        ];
        let sync_committee_bits = vector[
            true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, false, true, false, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, true, false, false, true, true, false, true, true, false, false, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, false, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, true, false, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true
        ];
        let sync_aggr =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"a421e337c8f125d40e155ae1886bfc7635181fad3eec1a0cc9aa5086b483362c5ef34c49c98a99253271ed1cff472c2c0ed5d7376ac0972374068c70a4a0636a8a02637fea41ff579ea1b747e1c96995a9def46e80906443ce92d941765a8711"
            );
        let signature_slot = 7164097;

        let sync_aggr_invalid_sig =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"a691a92811636beb56e71e228532a1f8897b56d496f0e7aab6494ad92739a0afecf43ccae4fed143d84ec8207f449d93001c02ed97c9d8062602ef938cca866792f894521f7c4a8fe62170af5c1c87ef22f44142828d92cab0a32fa60bf315e5"
            );

        if (invalid) {
            return test_construct_lightclient_update(
                signature_slot,
                option::some(finality_merkle_proof),
                attested_block_header,
                option::some(finalized_block_header),
                sync_aggr_invalid_sig
            )
        };
        test_construct_lightclient_update(
            signature_slot,
            option::some(finality_merkle_proof),
            attested_block_header,
            option::some(finalized_block_header),
            sync_aggr
        )
    }
    #[test_only]
    public fun test_get_finality_update_data(invalid: bool): (LightClientUpdate) {
        // LightClientOptimisticUpdate {

        let attested_block_header =
            test_construct_beacon_block_header(
                7164096,
                511,
                x"4f4314d3bd771a577e9c7d55ffe4a3ad747205ef97dbf2366375f106f99ccf3b",
                x"e27113c6dcca28cc3ffcd6352679508480cc754bc7c1848a96a3468783a00696",
                x"0e2b4460f3c20697abda64221246566c97fd52f0a50f3ff6c55b65f715825985"
            );

        let finalized_block_header =
            test_construct_beacon_block_header(
                7164032,
                1452,
                x"2c0d1afc76fbc3f72a3f0002f5ec853969f713c0d7a1cf219523a5359fe2bc55",
                x"a092c6296fa35f9efeaad0bb87469161f2896350cd978c973bddc3589b340df9",
                x"49021303782f1ddc9cd975b26133760c1816bbc8ada5fe6dd5be0716762f076f"
            );

        let finality_merkle_proof = vector[
            x"846a030000000000000000000000000000000000000000000000000000000000",
            x"76079561d1557730adc1508ffea1152d1943b7fc81f94e0224cd46c87dc3e511",
            x"920c391726624169471fc7b64a78926333a88f5cd2d91b2f7d935071d2c083aa",
            x"593d2e6e2eca8c5d1123892b5c3b7e3f68a979519dd9ddb7b4bcf2f87a692671",
            x"6aae61f4a5bebfc5e58a9963b3618dfe357ec7b29a5168c0bf8977fb46687edc",
            x"69260a7ff87b57d2d425d5e449c9da37c174296b24a38a37b19347867fe44a16",
            x"b83fd15f77764c922f7289fc7f438eb58651ef588f2dac66333f3d6632edc154"
        ];
        let sync_committee_bits = vector[
            true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, false, true, false, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, true, false, false, true, true, false, true, true, false, false, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, false, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, true, false, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true
        ];
        let sync_aggr =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"a421e337c8f125d40e155ae1886bfc7635181fad3eec1a0cc9aa5086b483362c5ef34c49c98a99253271ed1cff472c2c0ed5d7376ac0972374068c70a4a0636a8a02637fea41ff579ea1b747e1c96995a9def46e80906443ce92d941765a8711"
            );
        let signature_slot = 7164097;

        let sync_aggr_invalid_sig =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"a691a92811636beb56e71e228532a1f8897b56d496f0e7aab6494ad92739a0afecf43ccae4fed143d84ec8207f449d93001c02ed97c9d8062602ef938cca866792f894521f7c4a8fe62170af5c1c87ef22f44142828d92cab0a32fa60bf315e5"
            );

        if (invalid) {
            return  test_construct_lightclient_update(
                signature_slot,
                option::some(finality_merkle_proof),
                attested_block_header,
                option::some(finalized_block_header),
                sync_aggr_invalid_sig
            )
        };
        test_construct_lightclient_update(
            signature_slot,
            option::some(finality_merkle_proof),
            attested_block_header,
            option::some(finalized_block_header),
            sync_aggr
        )
    }
    #[test_only]
    public fun get_optimistic_update_data(invalid: bool): (LightClientUpdate) {
        // LightClientOptimisticUpdate {
        let attested_block_header =
            test_construct_beacon_block_header(
                7163770,
                783,
                x"d299bb40f46be36b835e179a88a7a9e6bb693c83d1d76050a56ce3b8c638ed53",
                x"87821c21585fa61d4b11721a799bb3387e02636ec0d54d5c00d46ecad00db821",
                x"39b047fbf4367aa82e7b1b3afb0b9d0cc9e653d0269f1d1c7f5a5fb6bb918438"
            );
        let sync_committee_bits = vector[
            true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, false, true, false, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, true, false, false, true, true, false, true, true, false, true, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true
        ];
        let sync_aggr =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"85f005397cfedd9b7a402d7e730a3531ec2ae5d3d3606aa26433df874d7c8ccf82af17c7aad1a8626fcb5f58ec9041eb141d18630ad8d8f82207d711d97f281adf165010c207f27995efa29eb068f27e39565bdac9ee7c90e1e59bc5977f76d2"
            );
        let signature_slot = 7163771;
        let sync_aggr_invalid_sig =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"319e936870d27832c1d5e0d34064c74198c97520fe08f820259363388cd724d45d803d43a5bb18455e617f2e5d8da2a117645065d1394219c622e224dab62da865c3ea116b4e4b11eacf7ae37b035ead1550c6c83ebbe43ba859fd146f722835"
            );

        if (invalid) {
            return  test_construct_lightclient_update(
                signature_slot,
                option::none(),
                attested_block_header,
                option::none(),
                sync_aggr_invalid_sig
            )
        };
        test_construct_lightclient_update(
            signature_slot,
            option::none(),
            attested_block_header,
            option::none(),
            sync_aggr
        )
    }


    #[test]
    fun test_get_safe_update_data_test() {
        // LightClientOptimisticUpdate {
        let attested_block_header =
            test_construct_beacon_block_header(
                7017910,
                732,
                x"71ec0bc39296af5b3ea3b0dccf3651210e1e2ab66b78b3c3ff5c037643cf25e4",
                x"ccb69b188338b1d5893c18c8cd58761129b9c763f3dd381e7f445e02a7d6974e",
                x"9267f650bb9c795bb780ca4067e43474428ce870b0b76a525eb136a5c8d2d838"
            );
        let sync_committee_bits = vector[
            true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, false, true, false, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, true, false, false, true, true, false, true, true, false, true, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true
        ];
        let sync_aggr =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"b09e936870d27832c1d5e0d34064c74198c97520fe08f820259363388cd724d45d803d43a5bb18455e617f2e5d8da2a117645065d1394219c622e224dab62da865c3ea116b4e4b11eacf7ae37b035ead1550c6c83ebbe43ba859fd146f722835"
            );
        let signature_slot = 7017911;
        let _sync_aggr_invalid_sig =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"c19e936870d27832c1d5e0d34064c74198c97520fe08f820259363388cd724d45d803d43a5bb18455e617f2e5d8da2a117645065d1394219c622e224dab62da865c3ea116b4e4b11eacf7ae37b035ead1550c6c83ebbe43ba859fd146f722835"
            );

        let lc =
            test_construct_lightclient_update(
                signature_slot,
                option::none(),
                attested_block_header,
                option::none(),
                sync_aggr
            );
        assert!(test_get_signature_slot_update(&lc) == 7017911, 22);
        assert!(
            test_get_sync_committee_signature(&test_get_sync_aggregate_update(&lc))
                == &signature_from_bytes(
                x"b09e936870d27832c1d5e0d34064c74198c97520fe08f820259363388cd724d45d803d43a5bb18455e617f2e5d8da2a117645065d1394219c622e224dab62da865c3ea116b4e4b11eacf7ae37b035ead1550c6c83ebbe43ba859fd146f722835"
            ),
            22
        );
        assert!(test_get_slot(test_get_attested_header_update(&lc)) == 7017910, 22);
    }

    #[test]
    fun get_finality_update_data() {
        // LightClientOptimisticUpdate {
        let attested_block_header =
            test_construct_beacon_block_header(
                7018689,
                247,
                x"b873b96ade77b22e806336089f433540c7756cf8d20fef30c356545ffed45f0c",
                x"5b1c62634f5136cb05052496f8d0561d7a65a31e525330c05ec3e6ee87ceac88",
                x"298340092e539741eeec4f83fe3e9d8841a2f455df71c1bb3b1c6d9aec4aae56"
            );

        let finalized_block_header =
            test_construct_beacon_block_header(
                7018624,
                1589,
                x"e386d30efcfb41bb65a5f4e5f3e260da1858743e7a7538227c46560ea9a3fac1",
                x"ad366dceaaee87190be00f244678f2641f06f45ca14f2f6cfcf2e388f272c73d",
                x"16420a978ef1221c599c9001814e803f646d08345d376877ee1f7f5d71bd3476"
            );

        let finality_branch = vector[
            x"c458030000000000000000000000000000000000000000000000000000000000",
            x"28d022a5baf9d84070b414953c3cb9ab4f50db3dfe903ed6737e3b612ef48e0a",
            x"f976efe6271e50010589ccb468341fc2c12a00b6a58be7559b753ed2f3d87e45",
            x"6d7c4edf89d4087b0df43bbbf74ce037fcae821f327290caf0bf469787e52e2e",
            x"3e3382215e9aa50e826fd0adc92fa22e3c5de2a6f99252149d3861b96561d4d6",
            x"5dc817d8a07ad7e62104ebed06fb62cf430831baea2b171feecb54dff9223c35"
        ];
        let sync_committee_bits = vector[
            true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true
        ];
        let sync_aggr =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"a691a92811636beb56e71e228532a1f8897b56d496f0e7aab6494ad92739a0afecf43ccae4fed143d84ec8207f449d93001c02ed97c9d8062602ef938cca866792f894521f7c4a8fe62170af5c1c87ef22f44142828d92cab0a32fa60bf315e5"
            );
        let signature_slot = 7018691;

        let x =
            test_construct_lightclient_update(
                signature_slot,
                option::some(finality_branch),
                attested_block_header,
                option::some(finalized_block_header),
                sync_aggr
            );
        assert!(test_get_slot(test_get_attested_header_update(&x)) == 7018689, 22);
        assert!(test_get_slot(&option::extract(&mut test_get_finalized_header_update(&x))) == 7018624, 22);
        assert!(test_get_finality_branch_update(&x) == option::some(finality_branch), 22);
        assert!(
            test_get_sync_committee_signature(&test_get_sync_aggregate_update(&x))
                == &signature_from_bytes(
                x"a691a92811636beb56e71e228532a1f8897b56d496f0e7aab6494ad92739a0afecf43ccae4fed143d84ec8207f449d93001c02ed97c9d8062602ef938cca866792f894521f7c4a8fe62170af5c1c87ef22f44142828d92cab0a32fa60bf315e5"
            ),
            22
        );
        assert!(test_get_signature_slot_update(&x) == 7018691, 22);
    }

    #[test]
    fun get_optimistic_update_data_test() {
        // LightClientOptimisticUpdate {
        let attested_block_header =
            test_construct_beacon_block_header(
                7017910,
                732,
                x"71ec0bc39296af5b3ea3b0dccf3651210e1e2ab66b78b3c3ff5c037643cf25e4",
                x"ccb69b188338b1d5893c18c8cd58761129b9c763f3dd381e7f445e02a7d6974e",
                x"9267f650bb9c795bb780ca4067e43474428ce870b0b76a525eb136a5c8d2d838"
            );
        let sync_committee_bits = vector[
            true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true
        ];
        let sync_aggr =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"b09e936870d27832c1d5e0d34064c74198c97520fe08f820259363388cd724d45d803d43a5bb18455e617f2e5d8da2a117645065d1394219c622e224dab62da865c3ea116b4e4b11eacf7ae37b035ead1550c6c83ebbe43ba859fd146f722835"
            );
        let signature_slot = 7017911;
        let _sync_aggr_invalid_sig =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"c19e936870d27832c1d5e0d34064c74198c97520fe08f820259363388cd724d45d803d43a5bb18455e617f2e5d8da2a117645065d1394219c622e224dab62da865c3ea116b4e4b11eacf7ae37b035ead1550c6c83ebbe43ba859fd146f722835"
            );

        let x =
            test_construct_lightclient_update(
                signature_slot,
                option::none(),
                attested_block_header,
                option::none(),
                sync_aggr
            );
        assert!(test_get_slot(test_get_attested_header_update(&x)) == 7017910, 22);
        assert!(
            test_get_sync_committee_signature(&test_get_sync_aggregate_update(&x))
                == &signature_from_bytes(
                x"b09e936870d27832c1d5e0d34064c74198c97520fe08f820259363388cd724d45d803d43a5bb18455e617f2e5d8da2a117645065d1394219c622e224dab62da865c3ea116b4e4b11eacf7ae37b035ead1550c6c83ebbe43ba859fd146f722835"
            ),
            22
        );
        assert!(test_get_signature_slot_update(&x) == 7017911, 22);
    }

    #[test]
    fun test_new_beacon_block_header() {
        let slot = 6989171;
        let proposer_index = 1447;
        let parent_root =
            x"5c09a958f5847e2ffd891db21600eba8d5bffed5bb0ade719ccd1919ab42864f";
        let state_root =
            x"e4636d9902307a5a605de694caeec9ee07606beb63c5f974e285ac5c10c8cf45";
        let body_root =
            x"8e8f126732624a4341a7fd0585bfb360055d638c632646aaaa8b57d0d90d446d";
        let bbh =
            test_construct_beacon_block_header(
                slot,
                proposer_index,
                parent_root,
                state_root,
                body_root
            );
        assert!(test_get_slot(&bbh) == slot, 333);
        assert!(test_get_proposer_index(&bbh) == 1447, 333);
        assert!(
            *test_get_parent_root(&bbh)
                == x"5c09a958f5847e2ffd891db21600eba8d5bffed5bb0ade719ccd1919ab42864f",
            333
        );
        assert!(
            *test_get_state_root(&bbh)
                == x"e4636d9902307a5a605de694caeec9ee07606beb63c5f974e285ac5c10c8cf45",
            333
        );
        assert!(
            *test_get_body_root(&bbh)
                == x"8e8f126732624a4341a7fd0585bfb360055d638c632646aaaa8b57d0d90d446d",
            333
        );
        let _gI = 20;

        // assert!(get_path_length(gI) == 4, 333);
        // parent(&gI);
        // child_right(&gI);
        // child_left(&gI);
        // sibling(&gI);
    }

    #[test]
    fun calculate_root() {
        // Test case 1: Empty leaves (edge case)
        let leaves: vector<vector<u8>> = vector[];
        let expected_root: vector<u8> =
            x"0000000000000000000000000000000000000000000000000000000000000000"; // Hash of the empty leaf
        assert!(test_calculate_root(&mut leaves) == expected_root, 1);

        // Test case 2: Single leaf
        let leaf = x"0100000000000000000000000000000000000000000000000000000000000000"; // Example leaf
        let leaves: vector<vector<u8>> = vector[leaf];
        let expected_root: vector<u8> = leaf; // Root is the leaf itself
        assert!(test_calculate_root(&mut leaves) == expected_root, 2);

        // Test case 3: Two leaves (no padding required)
        let leaf1 = x"0100000000000000000000000000000000000000000000000000000000000000";
        let leaf2 = x"0200000000000000000000000000000000000000000000000000000000000000";
        let leaves: vector<vector<u8>> = vector[leaf1, leaf2];
        let expected_root: vector<u8> = hash_pair(leaf1, leaf2); // Root is the hash of the two leaves
        assert!(test_calculate_root(&mut leaves) == expected_root, 3);

        // Test case 4: Three leaves (padding required)
        let leaf1 = x"0100000000000000000000000000000000000000000000000000000000000000";
        let leaf2 = x"0200000000000000000000000000000000000000000000000000000000000000";
        let leaf3 = x"0300000000000000000000000000000000000000000000000000000000000000";
        let leaves: vector<vector<u8>> = vector[leaf1, leaf2, leaf3];
        let empty_leaf =
            x"0000000000000000000000000000000000000000000000000000000000000000";
        let _padded_leaves = vector[leaf1, leaf2, leaf3, empty_leaf]; // Padded to 4 leaves
        let hash1 = hash_pair(leaf1, leaf2);
        let hash2 = hash_pair(leaf3, empty_leaf);
        let expected_root: vector<u8> = hash_pair(hash1, hash2); // Root is the hash of the two intermediate hashes
        assert!(test_calculate_root(&mut leaves) == expected_root, 4);

        // Test case 5: Four leaves (no padding required)
        let leaf1 = x"0100000000000000000000000000000000000000000000000000000000000000";
        let leaf2 = x"0200000000000000000000000000000000000000000000000000000000000000";
        let leaf3 = x"0300000000000000000000000000000000000000000000000000000000000000";
        let leaf4 = x"0400000000000000000000000000000000000000000000000000000000000000";
        let leaves: vector<vector<u8>> = vector[leaf1, leaf2, leaf3, leaf4];
        let hash1 = hash_pair(leaf1, leaf2);
        let hash2 = hash_pair(leaf3, leaf4);
        let expected_root: vector<u8> = hash_pair(hash1, hash2); // Root is the hash of the two intermediate hashes
        assert!(test_calculate_root(&mut leaves) == expected_root, 5);

        // Test case 6: Five leaves (padding required)
        let leaf1 = x"0100000000000000000000000000000000000000000000000000000000000000";
        let leaf2 = x"0200000000000000000000000000000000000000000000000000000000000000";
        let leaf3 = x"0300000000000000000000000000000000000000000000000000000000000000";
        let leaf4 = x"0400000000000000000000000000000000000000000000000000000000000000";
        let leaf5 = x"0500000000000000000000000000000000000000000000000000000000000000";
        let leaves: vector<vector<u8>> = vector[leaf1, leaf2, leaf3, leaf4, leaf5];
        let empty_leaf =
            x"0000000000000000000000000000000000000000000000000000000000000000";
        let _padded_leaves = vector[
            leaf1,
            leaf2,
            leaf3,
            leaf4,
            leaf5,
            empty_leaf,
            empty_leaf,
            empty_leaf
        ]; // Padded to 8 leaves
        let hash1 = hash_pair(leaf1, leaf2);
        let hash2 = hash_pair(leaf3, leaf4);
        let hash3 = hash_pair(leaf5, empty_leaf);
        let hash4 = hash_pair(empty_leaf, empty_leaf);
        let hash5 = hash_pair(hash1, hash2);
        let hash6 = hash_pair(hash3, hash4);
        let expected_root: vector<u8> = hash_pair(hash5, hash6); // Root is the hash of the two intermediate hashes
        assert!(test_calculate_root(&mut leaves) == expected_root, 6);
    }

    #[test]
    fun next_power_of_two() {
        // Test case 1: n = 0 (edge case)
        let n: u64 = 0;
        let expected: u64 = 1; // The smallest power of two is 1
        assert!(test_next_power_of_two(n) == expected, 1);

        // Test case 2: n = 1 (already a power of two)
        let n: u64 = 1;
        let expected: u64 = 1;
        assert!(test_next_power_of_two(n) == expected, 2);

        // Test case 3: n = 2 (already a power of two)
        let n: u64 = 2;
        let expected: u64 = 2;
        assert!(test_next_power_of_two(n) == expected, 3);

        // Test case 4: n = 3 (not a power of two)
        let n: u64 = 3;
        let expected: u64 = 4; // Next power of two after 3 is 4
        assert!(test_next_power_of_two(n) == expected, 4);

        // Test case 5: n = 15 (not a power of two)
        let n: u64 = 15;
        let expected: u64 = 16; // Next power of two after 15 is 16
        assert!(test_next_power_of_two(n) == expected, 5);

        // Test case 6: n = 16 (already a power of two)
        let n: u64 = 16;
        let expected: u64 = 16;
        assert!(test_next_power_of_two(n) == expected, 6);

        // Test case 7: n = 1023 (not a power of two)
        let n: u64 = 1023;
        let expected: u64 = 1024; // Next power of two after 1023 is 1024
        assert!(test_next_power_of_two(n) == expected, 7);

        // Test case 8: n = 1024 (already a power of two)
        let n: u64 = 1024;
        let expected: u64 = 1024;
        assert!(test_next_power_of_two(n) == expected, 8);

        // Test case 9: n = u64::MAX (maximum value of u64)
        // let n: u64 = 18446744073709551615; // u64::MAX
        // let expected: u64 = 18446744073709551615; // Overflow case, as there is no next power of two for u64::MAX
        // assert!(test_next_power_of_two(n) == expected, 9);
    }

    #[test]
    #[expected_failure]
    fun test_next_power_of_two_which_dont_have_next_power() {
        let n: u64 = 18446744073709551615 / 2 + 2; // u64::MAX and actually we dont get these much number of proofs
        test_next_power_of_two(n); // This should panic
    }

    #[test]
    fun verify_merkle_proof() {
        // this need to hash_tree_root
        let leaf =
            b"\x8f\x59\x4d\xbb\x4f\x42\x19\xad\x49\x67\xf8\x6b\x9c\xcc\xdb\x26\xe3\x7e\x44\x99\x5a\x29\x15\x82\xa4\x31\xee\xf3\x6e\xcb\xa4\x5c";

        let proof = vector::empty<vector<u8>>();

        vector::push_back(
            &mut proof,
            b"\xf8\xc2\xed\x25\xe9\xc3\x13\x99\xd4\x14\x9d\xca\xa4\x8c\x51\xf3\x94\x04\x3a\x6a\x12\x97\xe6\x57\x80\xa5\x97\x9e\x3d\x7b\xb7\x7c"
        );

        vector::push_back(
            &mut proof,
            b"\x33\x93\x4e\x7f\x5f\xa8\xdf\xbf\xa5\xca\xb0\x74\x74\xc7\x3f\xd6\xde\xb3\x27\xa4\x7c\x71\x80\xfd\xd7\x63\x6b\x43\x26\x89\xe9\xda"
        );

        vector::push_back(
            &mut proof,
            b"\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        );

        let root =
            b"\x07\x54\xe1\xb2\xa1\xd6\x8e\x69\x64\x7c\x78\x67\xff\x44\x59\xf4\xff\xd0\xed\xc2\xcd\x52\xb5\x3d\x89\xdf\x0c\x2d\x06\xa1\xee\x6d";

        let k = test_verify_merkle_proof(leaf, proof, 8, root);
        assert!(k, 1);
    }

    #[test]
    #[expected_failure]
    fun test_verify_merkle_proof_EINVALID_PROOF_LENGTH() {
        // this need to hash_tree_root
        let leaf =
            b"\x8f\xcb\xa4\x5c";

        let proof = vector::empty<vector<u8>>();

        vector::push_back(
            &mut proof,
            b"\x33\x93\x4e\x7f\x5f\xa8\xdf\xbf\xa5\xca\xb0\x74\x74\xc7\x3f\xd6\xde\xb3\x27\xa4\x7c\x71\x80\xfd\xd7\x63\x6b\x43\x26\x89\xe9\xda"
        );

        vector::push_back(
            &mut proof,
            b"\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        );

        let root =
            b"\x07\x54\xe1\xb2\xa1\xd6\x8e\x69\x64\x7c\x78\x67\xff\x44\x59\xf4\xff\xd0\xed\xc2\xcd\x52\xb5\x3d\x89\xdf\x0c\x2d\x06\xa1\xee\x6d";

        let k = test_verify_merkle_proof(leaf, proof, 8, root);
        assert!(k, 1);
    }

    #[test]
    fun test_is_valid_merkel_branch() {
        let leaf =
            b"\x94\x15\x9d\xa9\x73\xdf\xa9\xe4\x0e\xd0\x25\x35\xee\x57\x02\x3b\xa2\xd0\x6b\xad\x10\x17\xe4\x51\x05\x54\x70\x96\x7e\xb7\x1c\xd5";

        let branch = vector::empty<vector<u8>>();

        vector::push_back(
            &mut branch,
            b"\x8f\x59\x4d\xbb\x4f\x42\x19\xad\x49\x67\xf8\x6b\x9c\xcc\xdb\x26\xe3\x7e\x44\x99\x5a\x29\x15\x82\xa4\x31\xee\xf3\x6e\xcb\xa4\x5c"
        );

        vector::push_back(
            &mut branch,
            b"\xf8\xc2\xed\x25\xe9\xc3\x13\x99\xd4\x14\x9d\xca\xa4\x8c\x51\xf3\x94\x04\x3a\x6a\x12\x97\xe6\x57\x80\xa5\x97\x9e\x3d\x7b\xb7\x7c"
        );

        vector::push_back(
            &mut branch,
            b"\x38\x2b\xa9\x63\x8c\xe2\x63\xe8\x02\x59\x3b\x38\x75\x38\xfa\xef\xba\xed\x10\x6e\x9f\x51\xce\x79\x3d\x40\x5f\x16\x1b\x10\x5e\xe6"
        );

        vector::push_back(
            &mut branch,
            b"\xc7\x80\x09\xfd\xf0\x7f\xc5\x6a\x11\xf1\x22\x37\x06\x58\xa3\x53\xaa\xa5\x42\xed\x63\xe4\x4c\x4b\xc1\x5f\xf4\xcd\x10\x5a\xb3\x3c"
        );
        let root =
            b"\x27\x09\x7c\x72\x8a\xad\xe5\x4f\xf1\x37\x6d\x59\x54\x68\x1f\x6d\x45\xc2\x82\xa8\x15\x96\xef\x19\x18\x31\x48\x44\x1b\x75\x4a\xbb";

        assert!(
            test_is_valid_merkle_branch(root, leaf, branch, 3, 2),
            222222
        );
    }

    #[test]
    fun test_BeaconBlockHeader_hash_tree_root() {
        let slot = 6881051;
        let proposer_index = 870;
        let parent_root =
            x"ca0e045ad69ad56aaaf54800cb59e0a2ff2c20c1af3c46ea992441eb2582209d";
        let state_root =
            x"4b146fe8b23495dcdca86c020e027abe1f88db431789c3ed1033ea34d295206e";
        let body_root =
            x"6b2956b3182cfd22cc8b2bf1a9ef3909903b0c5f7451e3661f26a4fad89aa941";
        let parent_root_node = parent_root;

        let state_root_node = state_root;
        let body_root_node = body_root;

        let block = test_construct_beacon_block_header(
            slot,
            proposer_index,
            parent_root_node,
            state_root_node,
            body_root_node
        );

        assert!(
            &test_hash_tree_root_beacon_block_header(&block)
                == &x"a79dbd59e0705c062a605f01d50539ccc8d84ee87bad15847468a93f6b31f9fc",
            11111
        )
    }

    #[test]
    fun hash_tree_root_signing_data() {
        let domain = vector[
            7, 0, 0, 0, 211, 31, 97, 145, 202, 101, 200, 54, 225, 112, 49, 140, 85, 252,
            243, 75, 126, 48, 143, 143, 188, 168, 230, 99, 191, 86, 88, 8
        ];
        // let  body_root_node =Node { bytes:body_root};
        let object_root =
            x"c8b8aebc164df3895abaa3bf40008a740062d035da231b953ec44ca5fa5ab554";

        let signing_data = test_construct_signing_data(object_root, domain);

        assert!(*test_get_object_root(&signing_data) == object_root, 22);
        assert!(*test_get_domain(&signing_data) == domain, 22);
        assert!(
            &test_hash_tree_root_signing_data(&signing_data)
                == &x"91b2c98a7db1c7bebd4d3ef0a0fed7323e23bd0b6076ab01a1ff3667ca4d95fc",
            11111
        )
    }

    #[test]
    #[expected_failure]
    fun test_hash_tree_root_signing_data_EINVALID_OBJECT_ROOT_LENGTH() {
        let domain = vector[
            7, 0, 0, 0, 211, 31, 97, 145, 202, 101, 200, 54, 225, 112, 49, 140, 85, 252,
            243, 75, 126, 48, 143, 143, 188, 168, 230, 99, 191, 86, 88, 8
        ];
        // let  body_root_node =Node { bytes:body_root};
        let object_root =
            x"c8b8aebc164df3895abaa3bf40008a740062d035231b953ec44ca5fa5ab554";

        let signing_data = test_construct_signing_data(object_root, domain);

        assert!(*test_get_object_root(&signing_data) == object_root, 22);
        assert!(*test_get_domain(&signing_data) == domain, 22);
        assert!(
            &test_hash_tree_root_signing_data(&signing_data)
                == &x"91b2c98a7db1c7bebd4d3ef0a0fed7323e23bd0b6076ab01a1ff3667ca4d95fc",
            11111
        )
    }

    #[test]
    #[expected_failure]
    fun test_hash_tree_root_signing_data_EINVALID_DOMAIN_LENGTH() {
        let domain = vector[
            7, 0, 0, 0, 211, 31, 97, 145, 202, 200, 54, 225, 112, 49, 140, 85, 252,
            243, 75, 126, 48, 143, 143, 188, 168, 230, 99, 191, 86, 88, 8
        ];
        // let  body_root_node =Node { bytes:body_root};
        let object_root =
            x"c8b8aebc164df3895abaa3bf40008a740062d035da231b953ec44ca5fa5ab554";

        let signing_data = test_construct_signing_data(object_root, domain);

        assert!(*test_get_object_root(&signing_data) == object_root, 22);
        assert!(*test_get_domain(&signing_data) == domain, 22);
        assert!(
            &test_hash_tree_root_signing_data(&signing_data)
                == &x"91b2c98a7db1c7bebd4d3ef0a0fed7323e23bd0b6076ab01a1ff3667ca4d95fc",
            11111
        )
    }

    #[test]
    // fork_data ForkData { current_version: [144, 0, 0, 115], genesis_validators_root: Node(d8ea171f3c94aea21ebc42a1ed61052acf3f9209c00e4efbaaddac09ed9b8078) }
    // fork_data_root Node(d31f6191ca65c836e170318c55fcf34b7e308f8fbca8e663bf565808b255b10b)
    fun test_fork_data() {
        // let  body_root_node =Node { bytes:body_root};
        let genesis_validators_root =
            x"d8ea171f3c94aea21ebc42a1ed61052acf3f9209c00e4efbaaddac09ed9b8078";
        let fork_data = test_construct_fork(23, genesis_validators_root);
        assert!(test_get_epoch(&fork_data) == 23, 11111);
        assert!(
            *test_get_version(&fork_data) == genesis_validators_root,
            11111
        )
    }

    #[test]
    // fork_data ForkData { current_version: [144, 0, 0, 115], genesis_validators_root: Node(d8ea171f3c94aea21ebc42a1ed61052acf3f9209c00e4efbaaddac09ed9b8078) }
    // fork_data_root Node(d31f6191ca65c836e170318c55fcf34b7e308f8fbca8e663bf565808b255b10b)
    fun test_hash_tree_root_fork_data() {
        let current_version = vector[
            144, 0, 0, 115, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0
        ];
        // let  body_root_node =Node { bytes:body_root};
        let genesis_validators_root =
            x"d8ea171f3c94aea21ebc42a1ed61052acf3f9209c00e4efbaaddac09ed9b8078";

        assert!(
            &test_compute_fork_data_root(current_version, &genesis_validators_root)
                == &x"d31f6191ca65c836e170318c55fcf34b7e308f8fbca8e663bf565808b255b10b",
            11111
        )
    }

    #[test]
    fun test_hash_tree_root_pk() {
        let pk =
            x"932d72ae4952031f9070b1d7cc2e827e06eb606e0e10594d19f56d9460cb5d1675bb3e19ce5752512e3bec256a0d88bf";
        let _x = test_hash_tree_root_public_key(pk);
        assert!(
            test_hash_tree_root_public_key(pk)
                == x"a723937e67a254bd7f7434545a1b8268704c4b5fc746563bbb06e11f7ec10b3c",
            22
        );
    }

    #[test]
    fun test_sync_aggregate() {
        let sync_committee_bits = vector[
            true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true
        ];
        let sig =
            x"a691a92811636beb56e71e228532a1f8897b56d496f0e7aab6494ad92739a0afecf43ccae4fed143d84ec8207f449d93001c02ed97c9d8062602ef938cca866792f894521f7c4a8fe62170af5c1c87ef22f44142828d92cab0a32fa60bf315e5";

        let sync_aggr = test_construct_sync_aggregate(sync_committee_bits, sig);

        assert!(
            *test_get_sync_committee_signature(&sync_aggr) == signature_from_bytes(sig), 22
        );
        assert!(*test_get_sync_committee_bits(&sync_aggr) == sync_committee_bits, 22);
    }

    #[test]
    #[expected_failure]
    fun test_test_test_construct_beacon_block_header_EINVALID_ROOT_LENGTH_32() {
        let _attested_block_header =
            test_construct_beacon_block_header(
                7017910,
                732,
                x"710bc39296af5b3ea3b0dccf3651210e1e2ab66b78b3c3ff5c037643cf25e4",
                x"ccb69b188338b1d5893c18c8cd58761129b9c763f3dd381e7f445e02a7d6974e",
                x"9267f650bb9c795bb780ca4067e43474428ce870b0b76a525eb136a5c8d2d838"
            );
    }

    #[test]
    #[expected_failure]
    fun test_compute_fork_data_root_EINVALID_FORK_VERSION_LENGTH() {
        let current_version = vector[
            144, 0, 115, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0
        ];
        // let  body_root_node =Node { bytes:body_root};
        let genesis_validators_root =
            x"d8ea171f3c9ea21ebc42a1ed61052acf3f9209c00e4efbaaddac09ed9b8078";
        let _ = test_compute_fork_data_root(current_version, &genesis_validators_root);
    }


    ////helpers
    // === Tests ===
    use hypernova_core::helpers::{
        compute_committee_updater_reward,
        trim_start,
        count_leading_zeros,
        from_be_bytes,
        static_left_pad,
        bytes_to_u64,
        u64_to_le_bytes32,
        pad_right,
        pad_left,
        hash_pair,
        compute_verification_fee
    };
    use std::vector;
    use std::bcs;

    #[test]
    fun test_trim_start() {
        let _x = trim_start(x"c8b8aebc164df3895abaa3bf40008a740062d035da231b953ec44ca5fa5ab554", 10);
    }

    #[test]
    fun test_compute_committee_updater_reward() {
        let cg = 155500;
        let cm = 1000;

        let cr = compute_committee_updater_reward(cg, cm);
        assert!(cr != 0, 22);
        assert!((cr as u256) >= cg, 22);
    }

    #[test]
    fun test_compute_verification_fee() {
        let cg = 155500;
        let cm = 1000;
        let x = 10;
        let vm = 1000;
        let cr = (compute_committee_updater_reward(cg, cm) as u256);
        assert!(cr != 0, 2);
        assert!(cr >= cg, 22);
        let v = compute_verification_fee((cr as u64), x, vm);
        assert!(cr != 0, 2);
        assert!(cr >= cg, 3);
        assert!(v != 0, 4)
    }

    #[test]
    fun test_u64_to_le_bytes32() {
        // Test case 1: Minimum value of u64 (0)
        let value: u64 = 0;
        let expected_bytes: vector<u8> = vector[
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // u64 in little-endian
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Padding
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Padding
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 // Padding
        ];
        assert!(u64_to_le_bytes32(value) == expected_bytes, 1);

        // Test case 2: Maximum value of u64 (18446744073709551615)
        let value: u64 = 18446744073709551615;
        let expected_bytes: vector<u8> = vector[
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // u64 in little-endian
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Padding
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Padding
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 // Padding
        ];
        assert!(u64_to_le_bytes32(value) == expected_bytes, 2);

        // Test case 3: Intermediate value (123456789)
        let value: u64 = 123456789;
        let expected_bytes: vector<u8> = vector[
            0x15, 0xCD, 0x5B, 0x07, 0x00, 0x00, 0x00, 0x00, // u64 in little-endian
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Padding
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Padding
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 // Padding
        ];
        assert!(u64_to_le_bytes32(value) == expected_bytes, 3);

        // Test case 4: Another intermediate value (987654321)
        let value: u64 = 987654321;
        let expected_bytes: vector<u8> = vector[
            0xB1, 0x68, 0xDE, 0x3A, 0x00, 0x00, 0x00, 0x00, // u64 in little-endian
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Padding
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Padding
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 // Padding
        ];
        assert!(u64_to_le_bytes32(value) == expected_bytes, 4);
    }

    #[test]
    fun test_bytes_to_u64() {
        // BCS encoding of u256 value 0
        let zero_u256 = 0u256;
        let bytes = bcs::to_bytes(&zero_u256);
        vector::reverse(&mut bytes);
        let result = bytes_to_u64(bytes);
        assert!(result == 0, 0);

        let value_u256 = 42u256;
        let bytes = bcs::to_bytes(&value_u256);
        vector::reverse(&mut bytes);
        let result = bytes_to_u64(bytes);
        assert!(result == 42, 1);

        let value_u256 = 12345u256;
        let bytes = bcs::to_bytes(&value_u256);
        vector::reverse(&mut bytes);
        let result = bytes_to_u64(bytes);
        assert!(result == 12345, 2);

        let value_u256 = 256u256;
        let bytes = bcs::to_bytes(&value_u256);
        vector::reverse(&mut bytes);
        let result = bytes_to_u64(bytes);
        assert!(result == 256, 3);

        let max_u64_as_u256 = 18446744073709551615u256; // 2^64 - 1
        let bytes = bcs::to_bytes(&max_u64_as_u256);
        vector::reverse(&mut bytes);
        let result = bytes_to_u64(bytes);
        assert!(result == 18446744073709551615, 4);

        let value_u256 = 65536u256;
        let bytes = bcs::to_bytes(&value_u256);
        vector::reverse(&mut bytes);
        let result = bytes_to_u64(bytes);
        assert!(result == 65536, 5);

        let value_u256 = 1000000u256;
        let bytes = bcs::to_bytes(&value_u256);
        vector::reverse(&mut bytes);
        let result = bytes_to_u64(bytes);
        assert!(result == 1000000, 6);

        let value_u256 = 0x123456789ABCDEFu256; // This will show reversal effect
        let bytes = bcs::to_bytes(&value_u256);
        vector::reverse(&mut bytes);
        let result = bytes_to_u64(bytes);
        assert!(result == 0x123456789ABCDEFu64, 7);
    }

    #[test]
    fun test_hash_pair() {
        use std::hash;

        // Test case 1: Both vectors are empty
        let left: vector<u8> = vector[];
        let right: vector<u8> = vector[];
        let expected_hash: vector<u8> = hash::sha2_256(vector[]); // Hash of an empty vector
        assert!(hash_pair(left, right) == expected_hash, 1);

        // Test case 2: Left vector is empty, right vector is non-empty
        let left: vector<u8> = vector[];
        let right: vector<u8> = vector[0x01, 0x02, 0x03];
        let expected_hash: vector<u8> = hash::sha2_256(vector[0x01, 0x02, 0x03]); // Hash of the right vector
        assert!(hash_pair(left, right) == expected_hash, 2);

        // Test case 3: Left vector is non-empty, right vector is empty
        let left: vector<u8> = vector[0x01, 0x02, 0x03];
        let right: vector<u8> = vector[];
        let expected_hash: vector<u8> = hash::sha2_256(vector[0x01, 0x02, 0x03]); // Hash of the left vector
        assert!(hash_pair(left, right) == expected_hash, 3);

        // Test case 4: Both vectors are non-empty
        let left: vector<u8> = vector[0x01, 0x02, 0x03];
        let right: vector<u8> = vector[0x04, 0x05, 0x06];
        let expected_hash: vector<u8> =
            hash::sha2_256(vector[0x01, 0x02, 0x03, 0x04, 0x05, 0x06]); // Hash of the combined vector
        assert!(hash_pair(left, right) == expected_hash, 4);

        // Test case 5: Vectors of different lengths
        let left: vector<u8> = vector[0x01, 0x02];
        let right: vector<u8> = vector[0x03, 0x04, 0x05, 0x06];
        let expected_hash: vector<u8> =
            hash::sha2_256(vector[0x01, 0x02, 0x03, 0x04, 0x05, 0x06]); // Hash of the combined vector
        assert!(hash_pair(left, right) == expected_hash, 5);

        // Test case 6: Large vectors
        let left: vector<u8> = vector[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08];
        let right: vector<u8> = vector[0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10];
        let expected_hash: vector<u8> =
            hash::sha2_256(
                vector[
                    0x01,
                    0x02,
                    0x03,
                    0x04,
                    0x05,
                    0x06,
                    0x07,
                    0x08,
                    0x09,
                    0x0A,
                    0x0B,
                    0x0C,
                    0x0D,
                    0x0E,
                    0x0F,
                    0x10
                ]
            ); // Hash of the combined vector
        assert!(hash_pair(left, right) == expected_hash, 6);
    }

    #[test]
    fun test_pad_left_right() {
        let vec = x"12";

        assert!(pad_right(vec, 2) == x"1200", 22);
        assert!(pad_left(vec, 2) == x"0012", 22);
    }

    #[test]
    #[expected_failure]
    fun test_pad_left_EINVALID_PADDING_LENGTH() {
        let vec = x"12";
        let _ = pad_left(vec, 0);
    }

    #[test]
    #[expected_failure]
    fun test_pad_right_EINVALID_PADDING_LENGTH() {
        let vec = x"12";
        let _ = pad_right(vec, 0);
    }

    #[test]
    #[expected_failure]
    fun test_from_be_bytes_invalid_length() {
        let invalid_input = vector[0x12, 0x34, 0x56, 0x78];
        let _ = from_be_bytes(invalid_input);
    }




    #[test]

    fun test_from_be_bytes() {
        let input = vector[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x2C];
        let value = from_be_bytes(input);
        print(&value);
    }

    #[test]
    #[expected_failure]
    fun test_static_left_pad_invalid_length() {
        let data = vector[0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77];
        let _ = static_left_pad(data);
    }

    #[test]
    fun test_count_leading_zeros_zeroval() {
        let _x: u64 = 0;
        let _result = count_leading_zeros(255);
    }

    //proof verifer

    fun test_initialize_light_client_store(
        test_account: &signer, user: &signer
    ) {
        account::create_account_for_test(signer::address_of(test_account));
        let (burn_cap, mint_cap) = supra_coin::initialize_for_test(user);

        coin::register<SupraCoin>(test_account);
        let coins_minted = coin::mint<SupraCoin>(1000000, &mint_cap);
        // print(&111111111111111);
        coin::deposit(signer::address_of(test_account), coins_minted);

        let coins_minted_11 = coin::mint<SupraCoin>(100000000, &mint_cap);
        move_to(
            test_account,
            FakeMoneyCapabilities { burn_cap, mint_cap }
        );
        let hypernova_resource_addr = generate_resource_address();
        test_only_init_module(test_account);
        coin::deposit(hypernova_resource_addr, coins_minted_11);
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
        //this is the orginal change back to this once the necode is fixed
        let source_hypernova_core =
            x"000000000000000000000000c4ae54a3d371aab074c5584d91487d1e7bae1a87";

        let sync_committee_threshold = 400;
        test_only_initialize_light_client_store(
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
            source_hypernova_core,
            sync_committee_threshold,
            x"6253c4239a235930c4597a4076cc8351362a2a8107a4acdeb5e2f7aeafb87e49"
        );
    }

    public fun get_sync_commitee_finality():
    (vector<vector<u8>>, vector<u8>, vector<vector<u8>>) {
        let public_keys = vector[
            x"b91b4260e2884bae9778fe29a2c1e4525e4663ec004159def5d47320de304c96d2a33ad7a670e05acf90cbba3efdd4d9", x"a922d48a2a7da3540dd65bda3a8b5fb1f1741604e2335de285ac814c69c40b5373d92bc1babd3e4b2d32993f251c70b5", x"916e770af2939ae3d933db81d8fedff334591380b379ef4a6e0d873b67ba92f5ccf514805a38b961b8e1a346b054506e", x"901f724ee1891ca876e5551bd8f4ad4da422576c618465f63d65700c2dd7953496d83abe148c6a4875a46a5a36c218cf", x"b96e3ff8bdae47aa13067c29318b1e96a7fe3941869c17ce6662183b7b064bf261e1cea03e2a4643c993728a2606b5b5", x"a065363b9c4b731b08fd361081f93d987ad336475487dd28bbda2dca92b0b5da4edf326995a4ae923a4b2add7aa1df4d", x"9330a8d49b52cc673adc284c5297f961c45ec7997ced2a397b2755290981104c8d50b2fea9a3036ac2b1c329feaf4c7f", x"b0922acd6da2a95b36de6d0755316594a7e2e32ea774792dc314e8c3cd76d9f1d69df38231e166e24bd42c664f4fbac7", x"8d50e904d851a5d8e01d7902d8a67b978571705caa5e58db3037350906f96db7bb141354e29ed9a47ef5e59914dcbdc4", x"8d474636a638e7b398566a39b3f939a314f1cf88e64d81db0f556ca60951ec1dca1b93e3906a6654ed9ba06f2c31d4ea", x"838733220d1559c800cf1714db8a43a67a0c0d1d3a9fc1e2cdcf615d20406501e5146fe8b59bf64f4c5daa1a6d74f15c", x"a0b3dff15982a38a2f56d8c6cfc5c5543c045bf2db24571d23387ccab42abe2756f34d5f0bf6a426bbad3c358b8bdb00", x"95614544f65808f096c8297d7cf45b274fc9b2b1bd63f8c3a95d84393f1d0784d18cacb59a7ddd2caf2764b675fba272", x"946d585d7aa452d37a8c89d404757c3cce2adf2410e18613483c19199abd88f7a12e206f87a43f6009e42f4e31ed20c0", x"93e4c18896f3ebbbf3cdb5ca6b346e1a76bee6897f927f081d477993eefbc54bbdfaddc871a90d5e96bc445e1cfce24e", x"b81328c05a9569116a51d822a9e7bf43f6914214874622150f302fc812917375efc111e49b6b9075842d7d534182d290", x"ae50f93230983a82e732903d6ed50a506d678f35b6b4a4b3686a92b12aeb9d34cb095e8562b0900125bbced0359b37de", x"81dcb1672456b86ee663a329e81a548d45dc0374b17559bce2ca478c944f10989f49577022132b7876a64d04adb3ddac", x"a5817c74a394b0359a4376ef7e9e8f7dfa6a7829602da225074fb392b715e1fd52c50cae0f128a7006f28b22f233fbf5", x"88158d759eafd2205c770f166829fd61e8f17b2c13f440777eaf45f4d88a6e2028bc507680ff435882d5fb462f813735", x"89681684a4f5a2e56a4acd37836c06cfe8613b0694d2258f8ccee67796e76f49dd9da349b1c23a36f9438097c1e6415e", x"871656153e1f359ea1cf77914a76de34b77cb62e670c99f3584e7cb2c500c04f65f36bcb5321f4630df5c3de9245a7c0", x"80d492fbdbe9d5fcd08fe962b3ce2b9c245c068f686c4838f57db5b4e8b1bfc729c98e93dd4e5cc78b661845d7459809", x"b6aeb7a9b934a54e811921494f271d5d717924c561cd7a23ab3ef3dd3e86184d211c53c418f0746cdb3a12a26a334fc8", x"997a91da55801acb6134d067ad65a9a44ead0b53d3871bb97b46ec36149d25e712d7230d38605479796190abd3d134b7", x"b45c5652db4baab95300e81c0e280bfb9be75741d56545ff33b64d7f195e157ba9ecf909005a2fff59a8ee4dfab71be1", x"b2349265be33d90aaf51362d015ce47c5ffe33e9e6e018c8c6e39336d9327ccdd13d25e792eb33b43ed89a162f6ac2fd", x"8f7bbaaac458bada6d852fe665c87c646133bab16c0d5136c3dc922095b9d647d93a9de7671cb7bfd4cbd138ae0709d1", x"875133b542cd93b7ca5c236a14dec59d2e2fadcdf7673f09fcbb2282ec50b81410de244229701501d2a33802f751b458", x"921b2546b8ae2dfe9c29c8bed6f7485298898e9a7e5ba47a2c027f8f75420183f5abdcfe3ec3bb068c6848d0e2b8c699", x"b40504588a8ee3e0da1b60a304b865ce77196dd506e32d532e22eac9acfd2d03d3106be7d65b5c935191815a301b0f27", x"ad2aee9a61242235f0ef6adadd5d314b18e514083d6a589ca65cc89f505e44b480724d7659a87c95b03c62caba53f487", x"a2ee6c29efa982e9b9abd3c5e4f14b99d5d0369d7bfc3c8edae1ab927398dc8a147a89e127b3324d7f4e3a7494c5d811", x"896ae73bbdbaba487d7e425c0d48a90485c521fde519964b7c2c0eb874eae1a7a5c3339f370d2cfb75a788b4b303f652", x"a25e16820baca389c78a8a72e9b244a4db0399d146eba4f61c24b6280f7cf6a13ddd04de1df6331b2483e54fd2018de6", x"8f71f8edae59d6936846d8b50da29520f69b339f574ba9156d3d5f0cd4a279d36bad7ca7eb724dd48aefc4ca9ce26bdc", x"b3a5497365bd40a81202b8a94a5e28a8a039cc2e639d73de289294cbda2c0e987c1f9468daba09ea4390f8e4e806f3c8", x"8d0e6475acfa2b904e7d53bc7acd070a2ee4894ff5720a20e560e9ecb7872ea442a51cf2f2eee4bef66604a5c08ad9eb", x"a4b0732fcc79d82f3e5117a67571d498779afe6c20b8c56c90c76e3163c20726b584e02a0243de302b0a5c95f593cb66", x"8eb3b3e3135720036c1120c4e8b8d405b00d002f2bdbe601a06f2c2fffb940a9966d18636ee34fc003dfef547d8f3b76", x"b9e6c9f2562e90bd3008669a42151538b70faf028cc5bbc09fd6ab3febc626df911fcc65744a2ad793ecaf3f91a1f701", x"93cd53472c2818ab26f77bcc52ea2f37914d80c8abe318f9db59cc5a6943d1b252287d470174a4cbbff0f5ec295a2fc7", x"81c850f419cf426223fc976032883d87daed6d8a505f652e363a10c7387c8946abee55cf9f71a9181b066f1cde353993", x"b973f9c3d3faf641badf533ec36165a665759e0ae9ba45f9190fc44b1cdad78ca90ef6298dbe1dc0ee95ff58531cd0b3", x"ad8d94e46cc02a1c0ad27105e8f672ec15b8296051801f1918d0bd470625686e8e8a0abde8f6852b846ee8d9132b26bc", x"b0053550040ab3a3996cba5caf9ad5718867b5f5df273ed8c6520761571f03a94e50b5f8a6a8c42d725383cce97d3cae", x"897d7a19b70dcef1af006df3365981d73068c81f18017f32fb9966599481496efd5f6caceef943b31c52750c46d9590d", x"b45b285863f7303a234173b06e8eb63c8e2b70efe0dfb9872e3efddd31d52accf0f1292cfd1239b5a57492f3617a19e8", x"afa1d94996b77e9de7312e087a18e5b72574b9fe3a0c17fc5fc1ab1e6aa924d8494adfee338fa2e4b2d2bcfc9b1f64c3", x"90273bb88f2d4d23f9d7dd2fad356f7c0626b4ff52569f274ca62f8fba65fbded0121e7cc0981272da155f36e9be8bae", x"9439b663e4104d64433be7d49d0beaae263f20cfac0b5af402a59412056094bd71f0450bc52a294fc759ca8a3fddfee9", x"abf72ec0280d56971e599b3be7915f5f224c0ccde2c440237e67b95489f0c9154ace04b7763db228473715f68053f071", x"8c016e86b7aa752edd697c022116713d6a6b61538c7e46f4d76c99c29313615ec18cd21f48d99d495db3d9ed09fe946d", x"aaa18df4ad95f7443955accf8ec206f46d4d8ad9f1adb07b143b4225590917ed7ae050fc329d54310d3d0b198cedaf0b", x"a8b742cb7f497adfb99bdc6bcaf7f4bdadded2a6d5958680406b3b00545e1812d78e03e20be42b471b1daba84587d574", x"a0e68d24f784fcb2b71acc2d5871285623c829d0e939146b145e04908b904468a67c07a2f156e6b17bf531adc5777c4b", x"82daf8d4185bc828f1aa70ef0fbf235df8f44563d154b2d85af9a55977ed619fcba78bd0bf4cec4e565569a40e47b8f5", x"a3681ac11c5426767a2f1cdc89557746d5501d70add50bf4f2c9165fb5055af0644f3013603209cbaa0414d3dc794ee7", x"b26f5ed09f7d5bb640ec94ddd1df0b76466f69a943b4699f53d45296d5d6b8010bb61477539bc377d1a673d89074d22f", x"b284286dd815e2897bb321e0b1f52f9c917b9ef36c9e85671f63b909c0b2c40a8132910325b20a543640b01dc63b48da", x"8f9f85ae6377414fcf8297ed45a736210cd3803f54f33116b0f290b853dc61e99ea08f3c422ed9bc6bdc2f42ab4f56ba", x"838ff6630dc3908a04c51fb44a29eca5a0d88330f48c1d0dd68b8890411a394fd728f14215482b03477d33f39645dceb", x"b65e8b290bdec2fda05cd1c09f8508f662aa46d7d19556d0a4e3244b4ec20093aa37088105ea4c2b1e5b245410241445", x"8f6fde2ebbd7682c69026069cfe93aa5410071f05de9ccd7070c8c3299a6539b39b3798f01a0b4e9b1330510bdb51de7", x"aa6cfb3a25f4d06c3ce1e8fd87496a74a5b951ab72557472a181a2e278c5e982d290dd4facf40bd2f4f8be62263dadb0", x"80822499f96a1a8c0048f01f389dfcaaa5d8269c332dbb507fe46f270bcfd5f67c53f827fd867221592dbde77b6b37ab", x"94696bbf459f3a21b7d038923b621b5b599f60d24077452c23a8900d8ea40c016cf2f9b446ef008a3b6e2a0c6ff1cecf", x"93e4d7740847caeeaca68e0b8f9a81b9475435108861506e3d3ccd3d716e05ced294ac30743eb9f45496acd6438b255d", x"a9ee291de5997232c68c9f6c3b568b05f46bfedfa18eb3776699d98cc7c6320003b7d862564d07fd28fc3691d1d28b21", x"866ec39b9eda580d96bc2bff76af5cd4887b6788675149ab33bfefe38db82ad01b8d64c6b60704210918f3564cde1110", x"a40a83176a3890c867c34803e0f2571125c2cf1596767468a74107ba9b2d663c74e7c56a3de61bd7ed0c8db39534c7b4", x"a16938f556b8c11d110d95b8584cecef8b95ef349ea64b59df806cc62c52ee48074d0b3f18d84533e41583aefd6a9d43", x"a6938eb874460735402e4e8955b2d9f67032653154eacf78d61c2fcaa36af8639fa0aa22edf5015a93fe77080aadfbe3", x"936749ff47e5be307546564a5a4615bd8df52e2590034b2db19846939af3595a79ccabf0f6ff52ca46b9a1de3efd47a5", x"89d356593ec09d838cd89306ce83c060ee797bf9eec8523f581cf263925699ef0f7161a790bd00bb09681534ed05ac82", x"b468835c3070f1a00248e27d32e83d33cf599771992d65502b163cc1596c3c2056e6da868b0dbbd6c49671e4b2a2e954", x"8027e3716601f04f1bec13c787805cfdff2c85a63390cc3db377594580a3292c730b833a002ae5cfc0a826bacce666bb", x"815f9906177910288cf1d8db5f8b496f662e5da6db4d719c628f128256df976e5044f816986bd6646ecc95d79054885e", x"884c769ff3dabc132330e4a72ecf5331490ff08a59b7dd51cf2a9cf803a1a3dbff838f40451b243786661eb1630a60d0", x"8aadfcf3562f1c357068323352cb1745349a27a7362358d869e617c2410db747149b993ee9e881e252ecdd42fd75f351", x"86eac7e4bbd3a302fa5eab35697d26f17e0b646f097ed5e74fb45ad857615d06e829c7187bc20e136085af97d487744f", x"95cf2e038c790ce7a2960add7ab44804375f04ec6829f8cc63793dfe9fc48c7471079f81b932726509394fd3d46a52e9", x"a575be185551c40eb8edbdb21a0df381c801b6e99467fcf5882dd7cb34916960ce47ac732c1920ad3218f497b690cef4", x"91babaea18cf8f1e56feb0b89f0a3956c6469bb963d63312431057093b0ea0240a36abc3b7ac160e644e826cceb62530", x"b397ed7134f447d9bf1c511bf92f2d27d7b6d425b8b411365fbef696cff95c2175461cf5dd83d93bb700e50ebb99b949", x"8ceeec6c85df65d52e3d56efcf95f88b59aa085b61bb026fb228b855f088d9b676ffd5f0ee2ddbae00662b2f9ce770b1", x"a9ef845ab489f61dbfdcd71abcc29fc38f3494a00243b9c20b9cd0dd9e8a0f23304df84939b9652cdf5542d9b3ee085e", x"86edef59ab60ce98ae8d7a02e693970ca1cc6fa4372a59becc7ccca2a95e8f20a419899c8ccbb9c3e848f24178c15123", x"b835ffaf54c8b878d3c4262ca2bf5e6be2c691adced622b35d998ed72e1467ba907f4fde8d64ce43b43a8196f48e55db", x"8068da6d588f7633334da98340cb5316f61fcab31ddfca2ab0d085d02819b8e0131eb7cdef8507262ad891036280702c", x"88015bec478fd3ddff72efda0e8fc54b74faf804b0a3473cca38efbe5a7e6dc0be1cfe3dd62b8ac5a6a7a21971dcc58c", x"92127d55535bf59f2b00511c82f74afe90529d4abfbaca6e53515d63303fe52b4b22383fb026a2a3f88e96d2bd235f6a", x"a2538a9a793889d6bd6b4c5b0e874389494dfeba824eaf43b34ddbb311086e86912257e634fb5171f0164937c5632547", x"9437ce85146202d3815df7f341a182678665dfb74b96006dc9d6acc16110d00b4a02717b702a765566457710ff5a7280", x"842ba3c847c99532bf3a9339380e84839326d39d404f9c2994821eaf265185c1ac87d3dc04a7f851df4961e540330323", x"b7e74ab2b379ceb9e660087ee2160dafe1e36926dfab1d321a001a9c5adde6c60cd48c6da146d8adfa2bd33162eeaf1a", x"b0e8428b7feac527da3276d1eb67f978f0aa279bc16c09bd15b799059b5670e05a4e79f3278a8b9a96f46f964e8e831e", x"8c432e044af778fb5e5e5677dbd29cd52d6574a66b09b0cd6e2a5812e71c91559c3f257587bfc557b4b072a822973a60", x"ac6e7e9960207138d5b4b6a7f061756c01cc4a830e5988423d344f23544ed0eaa790aed63a22df375768f670cc9b9bd4", x"93cd53472c2818ab26f77bcc52ea2f37914d80c8abe318f9db59cc5a6943d1b252287d470174a4cbbff0f5ec295a2fc7", x"838ff6630dc3908a04c51fb44a29eca5a0d88330f48c1d0dd68b8890411a394fd728f14215482b03477d33f39645dceb", x"95c0a30943ef34ef0a644439d857446e1c1736e18360f3f41803b0ca118e79af3fb9c608ec440a8de0f79d2c245b583c", x"90f1d6745ed9a2fb2248d35de8cc48698f9e006dd540f690c04038ff3d22bd7f9c3979f6b3f955cb397542b3ef1c52dd", x"95fa868db7592c5fb651d5d9971fc4e354dff969d6b05085f5d01fb4da1abb420ecad5ecb0e886e0ced1c9de8f3d5cfe", x"92aacbfc412bcaa0fef865869a76f290b7d568ae177314b4a2d8ff26ff1dcdd384dd6b49bbc924dd078ccce9ccf43332", x"8261f7e644b929d18197b3a5dcbba5897e03dea3f6270a7218119bd6ec3955591f369b693daff58133b62a07f4031394", x"a69f0a66173645ebda4f0be19235c620c1a1024c66f90e76715068804b0d86a23dc68b60bca5a3e685cce2501d76de97", x"a03c1e287ccc4d457f5e71e9dc769294835945561e6f236ac7de210d2e614eee8a85e21dfb46e2143c68de22ccee8660", x"8bb51b380a8a52d61a94e7b382ff6ce601260fa9b8c5d616764a3df719b382ec43aec9266444a16951e102d8b1fb2f38", x"8368bb9b9bb2e17730c42ed1100eb870c88a8431601312aa8cb1e738cdb9ca2704dfd432cf1703c0db043259819631dc", x"946e508e1d399f22ae69a42102574c3d2827adfa47796c4c1b947f6ab84812f1474fd667c9491f13d4511cca3e8fffc7", x"b8d68610fdee190ec5a1f4be4c4f750b00ad78d3e9c96b576c6913eab9e7a81e1d6d6a675ee3c6efac5d02ed4b3c093a", x"8eafbb7002f5bc4cea23e7b1ba1ec10558de447c7b3e209b77f4df7b042804a07bb27c85d76aea591fa5693542c070de", x"841d9c04009af59c646e65cb79be10bff240fec75d756c8b8b9c4f54a2463561510f5b2f3d09eacce57cfa4a856d72f7", x"8163eea18eacc062e71bb9f7406c58ebe1ce42a8b93656077dd781c2772e37775fe20e8d5b980dd52fdad98b72f10b71", x"aff9a5903b2531bdf658c28fea5b8ebafdc4f0c562b97a7236442359fbb9c9184eaad619d40d49a6314062240c2757bf", x"873ef003ebb75508a3e50def6a37627161f40edf6835cb927814020623a6f92810d5e869f0884a0d2ab37a3a1edc8481", x"a4154b14b45f0683bd79a00cf07566e43b1eac7c80809cef233c7ed62a5abf8287f4ef3686f7130f10b6123cc3578601", x"b549cef11bf7c8bcf4bb11e5cdf5a289fc4bf145826e96a446fb4c729a2c839a4d8d38629cc599eda7efa05f3cf3425b", x"b505941fed274189346ac4822c06eead45c56b9c12e8caceebf79e3096ce6e081f423c205dbe7839df1d6c3fbe626193", x"8614a7599c8d97aa9ca63b876f677977cf0daa969ff2a9a153f297a4a46e08fa5d91492995de94dc32cf009ce6bb5b5f", x"b2c51c121acff7c0237d2e85e8e36a9e593eba4de2031ec58a2e6a375c447872756ef6e24c10601d1477249888113a8c", x"97578474be98726192cb0eac3cb9195a54c7315e9c619d5c44c56b3f98671636c383416f73605d4ea7ca9fbeff8dd699", x"81cfea085de08a39ecb888831381c4e60d2ece13caa69a1da2ade95841311f0e6e958863fe834f8ac70e358f730a9dcd", x"b3d41dcf67bc7467dafe414b1dd5e78edf158bfad5dcbe64e33ffb6bec5063b1575d0bb8ef768e5904f718cab7daa8ec", x"a8b742cb7f497adfb99bdc6bcaf7f4bdadded2a6d5958680406b3b00545e1812d78e03e20be42b471b1daba84587d574", x"8275eb1a7356f403d4e67a5a70d49e0e1ad13f368ab12527f8a84e71944f71dd0d725352157dbf09732160ec99f7b3b0", x"a4baa3dbcaa9bbdbbea7d3052d739b5dfb248eb910aa246cf494b07292faaf5537dab0971f2cfdaf8c60aea018a51575", x"aefb70e89dbf4456e077690509afcdcabf975416ff2fa16777fdf90b3abd3f5dcd865c43f1ebe6f8a669edc7f3bd6ad8", x"8cf3c29531a17489a5f8232d56c5251ffddc95be3ff7ff61472e19fb38c5eaec841ef3b1ee36756b3dd8ff71ae199982", x"8f9f85ae6377414fcf8297ed45a736210cd3803f54f33116b0f290b853dc61e99ea08f3c422ed9bc6bdc2f42ab4f56ba", x"ad83b3c5e9a08161950b1df9261d332dda2602cc68e0f5ee75bfa7e03bbef9edfb4945ca1f139df1bcb8affe8ae025da", x"8009dff405aada0798a6cb7f418f73017d7a569a7576aff51348b15913a5e639dd232657cd775cfa0dd811ae5e301241", x"a7c2174eea2b66b2a71cc8095fae39c423a353c7d5020ec2d0551317a66202fcf082c6119ba768755523fff49791bb4e", x"b2fc4478830f2ae4234569346d80b59899247c609b75bd2190a896498539e1f30dca5edbad69f0224918d09f0d7eb332", x"8c345a1ce2e44f371e7d84c904bc93d054c55abd51254dee67bd1292369703eaf49117a70e5ac09845c04c60634c743e", x"ab01a7b13c967620d98de736b8ff23d856daa26d5cd8576993ee02a5d694332c0464ed018ebffcd5c71bab5cada850ce", x"90c402a39cd1237c1c91ff04548d6af806663cbc57ff338ed309419c44121108d1fbe23f3166f61e4ab7502e728e31fd", x"90f4476224b64c2a5333198a4300ece8b3a59ae315469b23fd98dadcdceaaf38642d2076e9cd0bfacc515306f807819f", x"b15460725c0d6bc3a6a7006dcf3c3e3561d9acd674c52d4199daa8598ee29eef053ae521f1271aebc66943938c9f4b7e", x"b26b4d483bca73d3f3a976bb595a0e40f9a42094e0febbad3a1874934be1939a1b362ee4ea14a4f5cbfa9b1392796a12", x"942a12ba2f7b8708afb97e8ecba8f4ce66df1f862ceb86b3452f9b80eff581ee729f0f3122c6234075c6970270e2c367", x"82d2b1053f6610064f838b3aeec585878f86323cac357c4aed054d87595c7734729a737b29b57940884ee839e984d612", x"941bbb3565f0019619aefd551a471adcf28a089bf272bfb2c84e47312d09263f3a64da317e940d857ac72191730c294b", x"a278bea51af1de8bbd2319f3a37ab14abc3bc0289ed31aae44f38897a7b24263a4dde1cb037e1441217bec0ddcf47266", x"aa0b0ef6abddbb4931fea8c194e50b47ff27ea8a290b5ef11227a6b15ae5eda11c4ab8c4f816d8929b8e7b13b0b96030", x"8be72c12bfaa845ea0c736b7ebe6d4dcb04ee9535c0d016382754e35a898c574fd5de3fe8f0ab6f7e58ba07500536e9f", x"b2235bdf60dde5d0d78c72cb69e6e09153b0154efdbab97e1bc91f18d3cec4f660a80311fe6a1acd419a448ab65b18f1", x"ac56dbae1e290ad35dc14eee30c6cea441cb7d2cc64b8407b83df5e07ce4a8677983b45458c0127ec0d01f31bdd61a15", x"ab1abf9cf630d6cbcac0c503df44603142ac81acd647784ae0e8fc97800ef04378bc9d7f2087f959ad4bbbeec65b8dfe", x"88015bec478fd3ddff72efda0e8fc54b74faf804b0a3473cca38efbe5a7e6dc0be1cfe3dd62b8ac5a6a7a21971dcc58c", x"88554c83648ea97dac83d806cd81d92531980346b208d281fba489da15a0084fd4d9a00591d1ca67aad3c5793685d55f", x"8e0d08f5c2db6fa838784ceeca421c579f6b1f8819a17272bbf6d1cbb41c249cdaa52eb2bd2edb1bda1a55d6c2f2a445", x"b9893f7a47af457a9efd90ddc0c0ef383ab34e9c1284e617c126965cd9f0de5c54ee8b7b5208ff190366fe445e9c1325", x"a1c0c317e6e352e16e25c140820b927161ce5d2c4c2e10bca3057ba4d46b4f42ad7aba20de86dad9fc6368ea92695268", x"838d5eee51f5d65c9ed1632d042bb7f88161f3789e6bb461318c5400eaf6728e7ba0f92c18e1a994aa4743145c96164b", x"b0ad3c61be779023290256142d6b30200b68ff41f5405757b1a1c634b4d6bafbdcbd31a1f9d2866f111d8601d6dcae35", x"8b300dea07e73dd2f07b05d477e51f8424589f6b2fa6f461240e1322a3a7ab5bf227b74544bb5d66a297702cdbf6c6bf", x"93e4c18896f3ebbbf3cdb5ca6b346e1a76bee6897f927f081d477993eefbc54bbdfaddc871a90d5e96bc445e1cfce24e", x"91c3e8d2a65af7a31e24445afe9393e53f47b91167818210f2d8b9847ff76687ebc1107f52183ebadbafdaaaf72bd951", x"855474478de6f0f17168294a676f5a92db8d7f87b3e7e66f5ceee66dadeb5c94d740f0e0997e532409c2934175b6131c", x"979482fc84ee250501a60039ed32cfa2970ab79e951a9ed035a7060e0966da867a98ef4308e07fa99aced6ee633ae70c", x"af6911edd6c7ad30f905a0a3f78634808832fdeb4206b006934822d673bcced8e378779261b3c4b772b34b8871987f57", x"936f7e20c96b97548fef667aa9fa9e6cfdc578f392774586abe124e7afc36be3a484735e88cc0d6de6d69cf4548b1227", x"8d4263e8a208ea0a6798e0cf956ca01d650a6e23a1beca11ed82f04db598546713dc716ec8ed81eaa8ffa48924b5dea8", x"84faf4d90edaa6cc837e5e04dc67761084ae24e410345f21923327c9cb5494ffa51b504c89bee168c11250edbdcbe194", x"8e6bbfe492ecbbb8dc8889d3dcd7037a58db605bc6bb79131a72a9b9c1bad630e75f5e5e0c1bc407e73f3d13b116739f", x"a650864b7eb6769aaf0625c254891447351e702e40d2be34dfd25f3b5367370de354318d8935ba18db7929270455ae6a", x"a684a09add047c0fe648d9c5618500d1816047168e055e8ac8c952c3544a462cc095b32fab07d939947a58fcb4ec7ba7", x"aff9a5903b2531bdf658c28fea5b8ebafdc4f0c562b97a7236442359fbb9c9184eaad619d40d49a6314062240c2757bf", x"9545f94c4e9056e360dd999985f8ad06210556fa6f07cff77136a2460605afb0ff1fb1d1a2abe4a4e319fd6c29fff80f", x"aac995a41c14d379853ef18ffc854ad62ad77061ca9bdf5029cab3d6c2630de114e777a7fc3322455939d5205ed59c55", x"a131f61a215d689938b1997ec40357b939bd2a2565df04cea7800674e23ba068d0ce28bad32f49f3099434f34445eb4a", x"acdaa6263cb7ffa0fa159983888348fef7f0514abd4d897884bb6eaeb57c68e61044047215ccb0f32face09b0a72ea3b", x"b2574396e4360c971ebd71aa7e50d1683bd899fb1f404497c2a97129ea9d7e0a2642dfa8e0bd232ffb6ca443dd7a9683", x"b2235bdf60dde5d0d78c72cb69e6e09153b0154efdbab97e1bc91f18d3cec4f660a80311fe6a1acd419a448ab65b18f1", x"89ca7b7aecbb224d04839d36e4b323ae613c548a942830317aa0d51a111cb40d7e6d98600dc1a51e5a32f437951d6c7c", x"9722c1079db7e2e1c49756288a02302b43b8fd92d5671585ac1ea7491123742a2744a526c12c9a0b4c4a80f26342a3a6", x"93042dd42e56671155bb40d85d9d56f42caf27bd965c6a7a7948b39089dba8487d4d5fd30522dba6ba392964e3ffd590", x"a57d5de556853484b1d88808d2529450238bc467376ded84cfd7b4a1ba258f6d43b5958220f962c57b033abcef1d5158", x"a734a3c947be4c7e6704639d4400aec2ccf5f1af0901b41a29e336afb37c53bf168774939ce51f32d4496bce1a32e612", x"824d0dc002e158adef06fc38d79b01553be5a3903566029cf0beddb2248b11da40e66feb168e8e3e2a63ea033a75f382", x"a3b109249ac2900806f0f39338da72d4f2cc6d1ac403b59834b46da5705cf436af8499fa83717f954edb32312397c8d9", x"8eb3b3e3135720036c1120c4e8b8d405b00d002f2bdbe601a06f2c2fffb940a9966d18636ee34fc003dfef547d8f3b76", x"855474478de6f0f17168294a676f5a92db8d7f87b3e7e66f5ceee66dadeb5c94d740f0e0997e532409c2934175b6131c", x"8fbc274c5882666da39e7ef636a89cf36725820c8ada6eec0ab9b5af3760524b73a2173c286e155c597b4ed717d879e4", x"94df5fe87661101a89b49091a3d4de89331cdbd88531ebb08a95f2629886ee53b3dcbcc26bb6bc68b443303d8d397141", x"b9eed89e003894ad2cc9d9b93a45247e1367ac69a00b0ed5e3280c1188b4cb90eb870d449b83a852a798bd02f9d0c813", x"b2df29442b469c8e9e85a03cb8ea6544598efe3e35109b14c8101a0d2da5837a0427d5559f4e48ae302dec73464fec04", x"8633ba9d7e98d07bb1ab1a35927d25172236bebce1504e7f9e9e25e49761e72589e531b8d5a361edb733d69d7d5cc524", x"a3a7196fecd25e9cc7cac79c35365676e48c7be1493df255676adff2209c0719f2190ceff3ce008d08efa07c244c11a6", x"b4b80d7fbdb1dbf1567dfb30d8e814e63de670839a8f6ff434fe171416599fef831b8e978d6498851b8a81e0bc8dfb85", x"8c22f1f2a530879a93e744397fa6acca57b01fb62b62188ffa7487464815c605e1520ff4bb18e832753893649ab80d62", x"84fe145491d145fbe0c7f9104c9cca07c4f77746dbb93cfefd066b8a1ee61be8fe5d592c18b153f40f41ffdd8020f11c", x"b1ea1e8ab5dba06c7cf3f30512d2db1b9ac360cf9a639ad7bcde9221012b4f65adb8322bc2ae291b6b19c58eafc73232", x"b7d1d1edc5e72c11b55aa0aa85d3aacc38db925c0d30b082c7c47d39459b8ff2e7f969a754c814ac2a3e7c42a8885792", x"8b50e4e28539270576a0e8a83f5dedcd1e5369e4cd0be54a8e84069e7c3fdcc85483678429fd63fe2aa12db281012af2", x"94bbc6b2742d21eff4fae77c720313015dd4bbcc5add8146bf1c4b89e32f6f5df46ca770e1f385fdd29dc5c7b9653361", x"b4745c71c45bcc30163ed4fad7ad706b188fc1e19cf962f547d5500ff1972493539d2787c0e5ace5a85f7c39d1be4bbb", x"a12fc78b8d3334a3eb7b535cd5e648bb030df645cda4e90272a1fc3b368ee43975051bbecc3275d6b1e4600cc07239b0", x"b792b08f3b1048c8883d0ca34e1d693d411819dc990c117923d42bf1cde7b0e7193e92941f7d9c520cc6f9eab0f7bf6d", x"a80ac2a197002879ef4db6e2b1e1b9c239e4f6c0f0abf1cc9b9b7bf3da7e078a21893c01eaaab236a7e8618ac146b4a6", x"9131874b09aa95ba186bcaa9e040fabc811b9c7b905b7dc79e902cf2bb5816d7ee39b0b55be609f22bc8c538760b2037", x"b3c36fa39f668bbc3fec028875a820057dbf96f727bb423280da96d5d50e885d23bc23fb73457bf79089691ce7663a7b", x"b4ef65b4c71fa20cd0ed863f43f6c652d4c35f2677bc2083f5a9808284e8bd8988703faaf0fb4cac8ecbda19541ecc65", x"b6717b1b9cf1fdfa9a955f443aeedf600dd342aed16c0f0763a59fea7625e8497f519b7f24dfbf990af76df284ab21b9", x"8e58219fde5e9525e525b16b5332ef27fb6269e08e8c0bd3c20abb89397864b2c5bb55f5b6e03e8f0a0e0b04e5f72b14", x"8903f7e0c9764ce844b15d84feea04406dc66b195a5f82ff4027f27361e11cf368538137d139368f5a6f42876b04f056", x"8302ad0f2234535b55b975c5dd752c8a555d278b85b9e04e83b1db3bb2ae06f082f134d55216b5cacbf80444e1d0af84", x"ad5be06308651ab69fc74a2500c2fdab5a35977dd673949a5bb7d83309b6bf3fcc3c82d8770802db1556fd7abe37f052", x"91659e4ff45b9f2941cb41cd33553f29c4b65be9dc68d747467f2b5e39b9bec12dada05ec514255b4e9da31ac819d8d7", x"b6c7360054cf250ac48c41fce8da7a15b4c6f226688a60da737ea2e19b00c94ba728aa588ee72a7ac65f2d63f216285a", x"a42c46a7e617d78b12053d7783f0d175fd9103db06d0c6982b38893a20b72fd8ad8501eacb3d47be06fd7c3ad89a8159", x"af9285a3a9b968a90ae384344aa9f981683d548d957c6105fa165da78f17cdf86099f18776a5c9251caa62953841fdd5", x"93f941b4fe6c05621e7a651b87669eefd60b6e8a4a8e630a51fa3fee27417b9eebce39f80a5bade9ca779133ad8388f6", x"95c810431c8d4af4aa2b889f9ab3d87892c65a3df793f2bfd35df5cfdb604ca0129010fa9f8acae594700bece707d67f", x"80d492fbdbe9d5fcd08fe962b3ce2b9c245c068f686c4838f57db5b4e8b1bfc729c98e93dd4e5cc78b661845d7459809", x"b8d68610fdee190ec5a1f4be4c4f750b00ad78d3e9c96b576c6913eab9e7a81e1d6d6a675ee3c6efac5d02ed4b3c093a", x"8acd9b1213e397b2bd494714aec2d7b964558d0d16b0d4bf9334fe7804fb1d96f484b48b859a0589a61f31eed35c80d0", x"993726e0b1c2277b97b83c80192e14b67977bf21b6ebcde2bda30261aa1897251cd2e277cfcb6193517f1eb156d2fe86", x"87c288b63db2cc89a31b57593dd3632fc0970e305175ae4917f2ad9f7916fd77163f08c491feab0de2dacde7d615111a", x"a3fd9e1b5b61d2e0b9d66c46eecfc18f3745f35cda59994bf97144bdab6832c1f79b1068d2e8799bb7baf9f282c9380b", x"805c06e565ee67cab0cbccb92b6656fdb240b430766eade3c6b0a0b1b93c840e2b4f028601451dca135c783239463880", x"907c827a4fb5f698bf0e6f10ca07741c5b8e3ecb26aa53f938ba34ceb50c01be80c4afc5ac4358a5fda88eadea0cbe73", x"99dad12f78e1a554f2163afc50aa26ee2a3067fc30f9c2382975d7da40c738313eaae7adbc2521f34c1c708f3a7475b7", x"898deb30ede570d391266c81132a78239083aa9e27a9068e26a3bc14ff6468c3f2423484efb2f808b4996c16bfee0932", x"8d286e63f64a3e24c2e4c2b91bafb7c6a71d9438a2ffd7288c58ec6de9db6194eaf671b39c5a462c8658ad3cfce46f85", x"b7e18647b9d147a620b4905caf4a535a5b98e6ff0de5cc95a7dbe9c32bf1ac195a788baf9f51a6d7d0d2233d75af6e85", x"94f327bc57ed1ce88ce4504b4810cc8af5bd21a7e07b280a7866ce08e39b6cf7a6560bf73a5f10671271624cd7893970", x"8c03fb67dd8c11034bd03c74a53a3d55a75a5752ea390bd2e7f74090bf30c271541b83c984d495871d32c98018088939", x"a343d9fed516cd9dfa04d2542d93ded6f0bf1ff5c31cfd4f87b061461dc4e46ce6583272d3032767dc26701a4dd4277a", x"ab4a1ffef7e001723c71f5d28f3dd030a06c42d91773733d117247bbf9c01cd66fca2cff8c6ce04c4bfb68dfcdd851f2", x"91412f6f2d5662c541f77a4fb884daaadb305765e148dc2f5495cbf9ca29fdb3f53af6fce4493f3f5fd7c867901e98f3", x"8370c38104527d5b510faea45b92b1d077f9a43558178fc11204e4d0486fa94dee0c1d072b42c9f49770e63673c33fdc", x"a1cf175541368768b65e523ec5059c21b6d21a18d01b2c076d36107767c8a389be0bbe51c5535c6dceb576adbdea7107", x"8e2a281e944a28673fb8b47aaa288375cefd3a6be20e453131d85363ecc4fd5b250e7f9d7ca1e53408c54943041945a2", x"a8bbea7eb6c75bf058c421a3735d8c651e9ae6b1931593b13a588e00aa7dfa62d0982c7cdcbde1d9800fb75a208ed0ab", x"903b9bf66c147ddfddacce63c8f12f62e45638383bf91b50e2fef29013ce54a3fd8c3eccc9b8961d91ca2920ba5b0c1e", x"a0ea0827b17130cae727928ad22dca3a844beebee3f11b2e511782f8bbc8773ca9eb351348f7711fa1f5aba0b29190d4", x"a5fe3dfb5031517bb8db0d5ade1e9f438e84bcf23221de003b03d2a2f4ea97629e81c79abc3769bdb8c69a512c189b91", x"813bafdf6a64a9c40ef774e6c8cad52b19008f1207fc41bd10ad59c870fda8089299dd057fc6da34818e7a35b5a363e9", x"a07826925f401a7b4222d869bb8794b5714ef2fc66fba2b1170fcac98bed4ba85d976cf9ee268be8a349ae99e17ac075", x"a2b27f2a3f133d4f8669ddf4fccb3bca9f1851c4ba9bb44fbda1d259c4d249801ce7bd26ba0ee2ad671e447c54651f39", x"b284286dd815e2897bb321e0b1f52f9c917b9ef36c9e85671f63b909c0b2c40a8132910325b20a543640b01dc63b48da", x"970df2314849c27daa16c6845f95b7be178c034d795b00a5b6757cc2f43c4c8d8c2e4d082bec28d58dd4de0cb5718d61", x"96d7a69eaf2761bf0e5ebcd607b134d5dedba8e262ca1d6d3e8fbf23e6419a8ce1bbe4cd23b9e4b5f80db54a802a9795", x"a211120e1bb3b10138df1fa58efb009a298b8771f884b82bb3de15822b1252124a68f3980f96122a775fb96f05ddc3d5", x"90fc170529bcc0b80c46a53fffd8323fd2cc5cfa9b75ea4d36db21bd1f198335ad2bfa87f8990cf9cd9fd7989ecca718", x"90e5db75f3787b819df471712f87b6f3281437090f5db7a2c21b07164446292a414c687e41de2d1ca00786b093239c64", x"998a653dba837c4484ad5090ea32919dfb2ed647d4bfb7578c1901e3b77ba7fe275c00c8ea560d6505dc2f1cd689733b", x"ae5ea228c1b91ef23c245928186fbafa1275ff1817535018d7d2d913abff0fd76bf41fd04a96d816f2f1891bd16e9264", x"a0af9e02a7620e7ff119c3650d59d80169edd0ad452062b0e3e429c038cdaa4f55a18495e459367aaeb6a92c98003191", x"b74f6e53b56856f88f8607b1c4e6c9e54aec15c5bb891e7bab00e2a13caab3b1d6529bf0d72d4ce99714b8cb8b973f1a", x"925f3bb79c89a759cbf1fabdaa4d332dfe1b2d146c9b782fe4a9f85fee522834e05c4c0df8915f8f7b5389604ba66c19", x"84991ca8ef255610ebc6aff6d66ea413a768e4d3a7764750fd02b5cd4735d41df399b36e87647fc83cf73421a39d09e9", x"96e7d1bbd42195360267c2a324b4d9bccad3231ed8a7f070278472a90371867e2ef2c29c9979a1ec6e194893afd992df", x"85626305abd33d464b345f59df3f2f912d159f742b13ad238e318adb58cc4afb66e2376af5ddc96b0fe03bb7b0f5f0f0", x"809c7a08fbef7caf4c137cd639f2e47a8ca60d13bca3990eac51ac2a9e4442cd1a1473bebb63c61d595b586525d7b027", x"af51da717d2a45ab96fad5d9317ea867ec4c6a411af6fabd72e568230099a04c036a0f114158815b1a75da6474dc892a", x"889a5cf9315383bf64dfe88e562d772213c256b0eed15ce27c41c3767c048afe06410d7675e5d59a2302993e7dc45d83", x"a5a07bf219432e9c80c38596c93560b49c7de287f31e30b7a06fcb4d15982add4a24085adbc5b753c462be989c64c96d", x"94bbc6b2742d21eff4fae77c720313015dd4bbcc5add8146bf1c4b89e32f6f5df46ca770e1f385fdd29dc5c7b9653361", x"a75bcd04fcb44ce5cbab7eef6649155ec0bef46202e4eb86c88b4ced65e111f764ee7fb37e9f68e38067040fedf715ee", x"8cf3c29531a17489a5f8232d56c5251ffddc95be3ff7ff61472e19fb38c5eaec841ef3b1ee36756b3dd8ff71ae199982", x"add7c99ab5d627951f435bf2bb8025e835503f643b3de8ea702094027923513edd7307590cc073f56586b06b7b5fca41", x"985af1d441b93fa2a86c86b6d7b70b16973d3971e4e89e093b65f0ae626d702202336869af8e3af3923e287547d5384b", x"ab8a8769c754008a7976b6799e81d7bfe97413d0a79b90715703c1f8f567675463ec93aabee59277121fc4df88b5c7a9", x"b1809f9fa306d63c6cef586a74de6373fb2fac0cd10c5cffa6559cf1a16a99502c16c204f803139d4f2fba5161f90a6d", x"a9f261d19934fd26458421551e91f484d7a1522a7e7adbfb28f6371102a7650a5ae6efd49d9e33b03aefde647d134ce6", x"b429841b1eb28c9083ddaf05385c2bb55f2b6becb3ab97163b0d0af7c9e878e402110177527f8c6e592a52e9bcb379d6", x"8a978ee4be90254fd7003ee1e76e5257462cbb14a64dbca0b32cea078908d7da47588a40ffeb42af11a83a304608c0f7", x"b009efcac1a52e4d752a4810af784df2c0fe4c339ffa8b6a37632eccf04453fb9cc1c04ea27881efb4f141c580f7c568", x"94cbfc4d6cf52cf4b05ab56e5ac07f01fc4f0b85bccff95031778607b895d188ceef194b7ae92a69e5f68e7a5d2278b7", x"b8fca0f7bc276f03c526d42df9f88c19b8dc630ad1299689e2d52cd4717bbe5425479b13bdf6e6337c48832e4cd34bb5", x"af3d8623e44947a1caba6fed648a943e22ebc2d8c6bd18739b05bbc59c088a9f1bec7aa454e21bbb2c279f84561cbb2f", x"8d6bed5f6b3f47b1428f00c306df550784cd24212ebac7e6384a0b1226ab50129c0341d0a10d990bd59b229869e7665a", x"adbc658d54f46fc805767257f5e87d013112f0c6335605e9e763cd4745a1271b0e0b83902d5aaea6f8b46485d2e82042", x"a42c46a7e617d78b12053d7783f0d175fd9103db06d0c6982b38893a20b72fd8ad8501eacb3d47be06fd7c3ad89a8159", x"8fed283861ce42b3151d60887d0d3d2ff69869c051aed304af0f1db3f57dabf32f2b6994d9f0f11478eefbbb1daf9a8a", x"ab4119eef94133198adb684b81f5e90070d3ca8f578c4c6c3d07de592a9af4e9fa18314db825f4c31cea1e2c7c62ed87", x"93be3d4363659fb6fbf3e4c91ac25524f486450a3937bc210c2043773131f81018dbc042f40be623192fbdd174369be2", x"8f6da3598f875ac6eab33616ac0780286a1082e15ce3d87efa621be9bbe5ebc0da47fef2ed9edcfd435181d84b1662e3", x"8c016e86b7aa752edd697c022116713d6a6b61538c7e46f4d76c99c29313615ec18cd21f48d99d495db3d9ed09fe946d", x"9467b7d5d90b8653b8a2f248f30475856e28407dd3fbc4e1a84445a8f2da5e181796e1cc5c293aab60a6f8a8aba1f4e3", x"8db19f6dd3789df179ab606508ca7e3da7967ad4340f630bda83df54c197d6bd3a14980c87fe10cbced7678c0c300ef1", x"a72f459c87fa76a55b6dbe1e0e89a441e732e151e75bc5ce2f4459ca60b80e6dbbac5d05d599677c0f2948f345705dfe", x"ae2d3f75cecd24685994d5f04a268b22ea568cc143b81107282325b5257b023428d4ce45784c50b6a0006f5e70bbf257", x"b9445bafb56298082c43ccbdabac4b0bf5c2f0a60a3f9e65916af4108d773d62ffc898a35b0b8efb72ea846e214faa02", x"80e30cabe1b6b4c3454bc8632b9ba068a0bcfd20ce5b6d44c8b1e2e39cbe84792fd96c51cf45cf9855c847dc92ce9437", x"8c6fc89428c74f0c025e980c5a1e576deadf8685f57136e50600175fa2d19389c853d532bb45a3e22b4a879fab1fcb0d", x"84d3e2a06e16ced26094b356a16a4fb6aad50ad9ab23ef804a5852a33ef0bff76f3c5fbf7beb062376c2e669cb598679", x"81534e2a182da0c6831479c7e722953d267ba9c63a204ac96a178b1dc90d0a6ba8737002688ba5f102eda5669249f114", x"b5988ce430afce35829804e0afeeb91fc578534bd9ebe64717b51dd0d2bfe32ff028b210850ab272dfce03fe22be85c0", x"ad40217a1856d77fe520ce6b97a089b2a399ae6b314139cd65d1990e363ef4ceb8d7be2d8152646ed3a9f0b0762dd4f1", x"b007aa051cbb3c96be3230c80afe7938a5d66d19c52ee4712bf30687807b331d8cb267354ef4a0e339e50df1fc9556a6", x"8b8813bd2c07001a4d745cd6d9491bc2c4a9177512459a75dc2a0fa989680d173de638f76f887de3303a266b1ede9480", x"aa25208385573caee2a4830f09e1cc9bd041cdb78d3ee27a4b011815a62d0d2e0295c222480947ae427b1578fb5509f5", x"acd4d1e11f81f4833353b09d4473ec8b15b8ff31dbf39e97654f5338a26c4020306d51018f1f4b9c4efdb92992408a6e", x"91659e4ff45b9f2941cb41cd33553f29c4b65be9dc68d747467f2b5e39b9bec12dada05ec514255b4e9da31ac819d8d7", x"95791fb6b08443445b8757906f3a2b1a8414a9016b5f8059c577752b701d6dc1fe9b784bac1fa57a1446b7adfd11c868", x"8cfcdfa192b17321be4e447204e1a49ecaadca70a3b5dd96b0c70ab64d1a927d1f8c11a7e596367e5fa34e2307af86fc", x"b2a652f56fd69fe1c358c360b6c9d9bb78900b5b1de0b2fca5d1fefc6e05290bda2efec64a118f367ef1fa942bd05ad3", x"86b3ec14a8ffb811a0ecc3771f600d8b08c098537d100fba66def19e7ee4d1c397a311977bf37e6cd2d47a8a2ee8c223", x"b312aad0a82565f02b8db1a8cb99bfa80e774b13575ffde9dcb7e6720fe96496bcc4ec1b4d42a5f06d137630b738e987", x"8027bc62b59f9f15613e38da74ccc71fc3eaee26f096d187c613068195ce6eb64176013f2d86b00c4b0b6a7c11b9a9e5", x"a10788831a0cb2c3d14d8bc214d92bee6e2a9e92c423d2974760d84a6872a9465d12b628f9bd8a6e777a7db6f509b3a0", x"a57bacada151d6521c6f40371e80cc8e44bb76389dfa7da5deba7675bb9a253c59a901df26c6f1069205b37f18048b1c", x"ab73a043ccdfe63437a339e6ee96ef1241264e04dd4d917f6d6bc99396006de54e1e156d38596ba3d15cb1aaa329f8f5", x"91cb79d52951d1b901e4a686bf4ad587e31db57ea5af6ffeb93eeafae3929879c386ddec860f803c2dc61055437e6bee", x"8180ffffb5abe78c38f2a42a3b7f1a408a6d70d3f698d047d5f1eef3018068256110fcb9fb028c8bdccbc22c0a4c3a20", x"914f0f1bdc62c3e67c607e6a3df69ff47e396fb46a3f2aebf74d39fc4f2f8735bcdbd1814de99d6ad20cbe44c3f82dad", x"a333abf3cfa6b46599e210f7ae33cb6bd378ffa4e11fb5bf9d2cdc2787cc34e6e088e010321c193ce46495009e88b780", x"b549cef11bf7c8bcf4bb11e5cdf5a289fc4bf145826e96a446fb4c729a2c839a4d8d38629cc599eda7efa05f3cf3425b", x"b7eb6a49bf8f942dd8c37c41c1b35df43e4536e07ca9f4c1cfbbf8a8c03f84c54c1a0d8e901c49de526900aeac0f922f", x"a3e909196f447e492200cc67000c5d7f0f585fb98e966cf9bf08257597fea8d92a90ceb054d4b5553d561330b5d0c89a", x"a5b3da08aad945effdb645c797a0a8bfa828c9d658df2783a214597acebda3ffc07ee48d0ce1147d77540b557d9ada91", x"aeddb53c6daac757916039e0992ec5305814e9deb113773f5ecf10355cc3723848fd9c55e0a6ffb6bcff4ad65ed5eb3c", x"a48b1031ca2f5a5acb4dbdd0e9a2b4e9add5ccfc0b17d94818273c8df11e825193fade364e0aec10f1ff91d57d03a52f", x"95757096c132e7f6c096d7b93a5a0d2594d5e609b9f13c4a9f878e95a389fa1a111b185dc1fd8f7d98b737dcf8d2af60", x"a11faaeb9e2c6ebaa2fb66ada1020d7129b75ea8518928c4cee46d6231c27f51ac2273be99ccdf74e859d3a3219c4775", x"98eccc5eeacef24188409d380b772cd5c72f376c461032cf2852fb8ce2afb37567c059e5b004395ebb5d97fd31028407", x"ab45f5b756ec6e0b98d0d4301c87675a0a1f0b1178b8a9780c1ab23e482cd821834835afa1de890962212159e464b10a", x"a3d31b20198f326eac488e88fc5b9171276d4934b0bc573c8b55b2abd26380d5296d5bbea281de91c0945f34b37f42bb", x"af03bc1e94067741bca4978b9cf065cc6852090fde3aaf822bbe0744705ebda5baac6ed20b31144db0391309e474ba48", x"880b99e77a6efb26c0a69583abb8e1e09a5307ac037962ddf752407cacaf8f46b5a67faf9126bdbcb9b75abf854f1c89", x"a32a5bd9b7bec31dd138c44d8365186b9323afbba359550414a01e1cdb529426bfa0b6f7daaf3536e9402821faa80003", x"8e0d08f5c2db6fa838784ceeca421c579f6b1f8819a17272bbf6d1cbb41c249cdaa52eb2bd2edb1bda1a55d6c2f2a445", x"86561f796ff1dc82581dcc22baddbc6c630c27ecc4402c75deb4559318c093656951b5fe91aad6efeafcc6266f9b7963", x"a5bf4aae622b58a37e722c3d1322b402907f10eec372a42c38c027b95f8ceba0b7b6f9b08956b9c3fdfedaa83d57a217", x"94402d05dbe02a7505da715c5b26438880d086e3130dce7d6c59a9cca1943fe88c44771619303ec71736774b3cc5b1f6", x"acfbac397ae2ff23b31bb27b90788fd0fd51a50f8e8c9f4b31be8499194252014f0b1972b204aeb9c2836a20beb3c868", x"850f932ef35fd8693816d950e6209bc04ce26762cf6747d0aee03770e386fa0189790a8295414c0b27695b70988a3c5a", x"8c26d4ec9fc8728b3f0340a457c5c05b14cc4345e6c0b9b9402f73e882812999e2b29b4bffdcb7fe645171071e2add88", x"90f1d6745ed9a2fb2248d35de8cc48698f9e006dd540f690c04038ff3d22bd7f9c3979f6b3f955cb397542b3ef1c52dd", x"9332251b4b56579b201a2fd9e777e4be80aa213bc986ed5d1187cada9b225a7ed18f1f5bf68c2839bf330e00b2d63f22", x"8903f7e0c9764ce844b15d84feea04406dc66b195a5f82ff4027f27361e11cf368538137d139368f5a6f42876b04f056", x"b2a01dc47dd98f089f28eee67ba2f789153516b7d3b47127f430f542869ec42dd8fd4dc83cfbe625c5c40a2d2d0633ea", x"a40a83176a3890c867c34803e0f2571125c2cf1596767468a74107ba9b2d663c74e7c56a3de61bd7ed0c8db39534c7b4", x"a42bcc5012a8b87caac4ec279f8cf7e43f88e36b65c321a835fd8a5ba427a635de79b93d2460f5e15258f09d8d51c7ce", x"973fc857d37e42d8dff4357326c7ee1fbe6f1ceac636e109bc09689976ad5fcfe8111afafb63b98737839786bbd455c4", x"978299430079ea9a0868eb1289ea175e133e9f604129d56b1b1d0f768930bc4c64db921e08f352bfe6ad2296123e6ba7", x"93ba2e000bdb7269818d390bc4232992d280e69abebe2db2ecb6fcb1390d323238c9793574509bc1fa34051ac1928f07", x"8757e9a6a2dac742ab66011c53fa76edb5ebc3c2fbd9a7265529a3e5608b5c24b4482fed095725e9b8fed5a8319c17a4", x"a6266fca079b955d49cccb8532fad7e44d5e7656c54613d415d2fe28702b4dcbc2e43e280a919320a4fcf789fbf3e2f6", x"a7555d66719916a2be7a7f0c8b7001aa2925bcb79723f78288f10831f9cec64923228b0e4b89dfd4342de8f70ce03cb4", x"b552707ec0d9124dc71f0076e56ca63878473c953663b1b8952e828ea0bd0945f2f410a72d413e9efdf536b4c9e280dd", x"b42578df29a9eb23bed91db6a1698df49654d2bc1b0d7973b2a7e300e9cf32e0e6ac464d463d4d26e394e7598239c4bf", x"b0eecd04c8d09fd364f9ca724036995c16ba6830d6c13a480b30eb2118c66c019cfdc9dacce6bfd8215abe025733e43d", x"ac568059f6526440655078ae8d5c13860cb7ec82c36db744a447f98721ba5ca88aaacf377ee9dfa6dfb8313eaac49d9c", x"ac2955c1d48354e1f95f1b36e085b9ea9829e8de4f2a3e2418a403cb1286e2599ba00a6b82609dd489eda370218dcf4c", x"82ffe4de0e474109c9d99ad861f90afd33c99eae86ea7930551be40f08f0a6b44cad094cdfc9ed7dd165065b390579d0", x"a8151dc5a9995a660759e36a9f82ed3be6956395866edcd1413ba15ce96e3210da40d364516a50f87ff78e9de9d59657", x"901f724ee1891ca876e5551bd8f4ad4da422576c618465f63d65700c2dd7953496d83abe148c6a4875a46a5a36c218cf", x"a07b35ec8d6849e95cbd89645283050882209617a3bb53eae0149d78a60dbf8c1626d7af498e363025896febdba86ee7", x"8dca376df4847cb8fc2e54a31894c820860c30b5e123b76670a37435e950f53312f089a8e9bd713f68f59fd1bf09202f", x"900a87a9cfa9aee38382a4bc45abbc9c6f566db3bc70e6a7a21743768b51b99656a667df3c29849993e9ff89dd5db35d", x"97825edba8410e8bcb85c5943628c02ea95ee7595f559c030b94395c0d1d0d84c38eca199fce9c1992e572b5029b124c", x"a910ab63aef54d8da04a839995ef38893d2cf884539ec81f97b8a4dde1061a27f6d3fe41186d1b7af872c12d44f36397", x"b4de7f20e5d141f5682b7e0f0326a3429e00e0236fb8ae58e84c20ed7a986b951cda30d5e2e7e7196119dbd9b0ef5ea1", x"8e0d08f5c2db6fa838784ceeca421c579f6b1f8819a17272bbf6d1cbb41c249cdaa52eb2bd2edb1bda1a55d6c2f2a445", x"95aafa379cc6a2b4bdd0cad30b7f0a47839952af41f584219ec201c6c4d54610eb2c04b67b29080acb8cecc5e7543fbc", x"82d09556978fa09b3d110e6066c20db31da2e18de90f973930f752970046f2df96b2a0248fdd833cbc50abad5c756026", x"a0ea0827b17130cae727928ad22dca3a844beebee3f11b2e511782f8bbc8773ca9eb351348f7711fa1f5aba0b29190d4", x"a75bcd04fcb44ce5cbab7eef6649155ec0bef46202e4eb86c88b4ced65e111f764ee7fb37e9f68e38067040fedf715ee", x"b0a32f5ee1e22853d6557c59517234abf7af5bd5984274fc084f25dbd8a07d026715b23b776fe47f8a3686c69a77cb8c", x"8c722aaf5d5dad1845056bf5e56dbff0f8b501f4846610f99da01130a49c96db9962bfd9be20670658cf276cc308be08", x"8bc161f543ec5a4ef2d09ecbc9d6a26bd624a06fca6528ba0dfe09c7814145cee71ea2a0e120d0c81e30c8771d7a3abb", x"86bba46d0031989d0f1baccea4174fc3fa0d595e60d35a464e86c33c233e2d6def84fced7a00f59afe397cf4fb5b67c5", x"ac6e7e9960207138d5b4b6a7f061756c01cc4a830e5988423d344f23544ed0eaa790aed63a22df375768f670cc9b9bd4", x"a80deb10bba4bc7e729145e4caf009a39f5c69388a2a86eaba3de275b441d5217d615554a610466a33cfe0bbe09ef355", x"952cbd8e9d5e9d23139e8f3e979a89b54206188e627f8e06cdfb3e38aa5159e610629bf79713954110bfa6f450c6e55a", x"b1afaefc9fb0e436c8fb93ba69feb5282e9f672c62cbb3a9fc56e5377985e9d8d1b8a068936a1007efa52ef8be55ce9c", x"91b0ac6cd2c9dcd2ffe3022b477c3490be344e9fadd15716157237b95625b77c67e59021687c54a0ec87625be0d1631e", x"94d3c9406dc6dd7241a726355643d706e46b35f1ffe4509ac43e97c64c07592821156ba02ec9a78978e66709995a0ac8", x"8a501497cdebd72f9b192c8601caa425072e8e6ef438c2e9493675482808522e488779dcb670367cf6d68edea02a12af", x"8d74f4c192561ce3acf87ffadc523294197831f2c9ff764734baa61cbad179f8c59ef81c437faaf0480f2b1f0ba1d4c8", x"908d762396519ce3c409551b3b5915033cdfe521a586d5c17f49c1d2faa6cb59fa51e1fb74f200487bea87a1d6f37477", x"86a06be6d04ec3106869ea5866b07bafcfb0d5b15fb9fa6e01b634c02f9f5f15e2279a7227ac7881344abacc983ea12e", x"b6aeb7a9b934a54e811921494f271d5d717924c561cd7a23ab3ef3dd3e86184d211c53c418f0746cdb3a12a26a334fc8", x"b89bc3cd7d9079e675dbd7a7c9748d4ba4f35ff4af9c190cd94783e945e52887b80cd972a95944acb7db580f4bc3a4d4", x"896ae73bbdbaba487d7e425c0d48a90485c521fde519964b7c2c0eb874eae1a7a5c3339f370d2cfb75a788b4b303f652", x"a5c225b7bd946deb3e6df3197ce80d7448785a939e586413208227d5b8b4711dfd6518f091152d2da53bd4b905896f48", x"a4154b14b45f0683bd79a00cf07566e43b1eac7c80809cef233c7ed62a5abf8287f4ef3686f7130f10b6123cc3578601", x"aec5e915f23d327ceb37612ced6a3fbdcb3153ae075fa37c32146a7aac038fb65e03a87612b9a8c2a89188fa98c0a630", x"b54fef3e679059cf38a721b61cbd1d2492b06672da0e8ec1132f845f2acab375bf2cba5e9e4fd6833f615586ecc21c7c", x"a70a79cdb02f144dd395f93d35f232569d3d0988a447099e40597d76ee3bce0241fb27bcb03a80ed3eb7e6c4003a40fa", x"8afa23226c47083bba80ab1be55b48c90c6629135533e3e4c14057d19febeba7f8e2cabe617b28ce1f0bd97a06972f66", x"b97fb8ebf2ee1bae5914cf96e5a07887ba41e712530eb2096ace318e989c0ad93060cfcf40507d927af6c7e945bcc289", x"99c629c9cd603a9344b04d22d2bcc06cf45ebf62d97f968df19c73c7a50f4f6a2a2cc7fb633f509f961edfb94fbab94e", x"b4a1d185c770ed41021ab0497a2ecf724fbd046784418b8a4af8d654dd9b10c2f3333e6f4f9e6ce385916546a2cb6a8e", x"91013e0d537fb085a49bf1aa3b727239b3e2c1d74c0f52050ff066982d23d5ee6104e70b533047b685e8b1529a0f14dc", x"abf7da952c9d8f75fcc67fa7969fac0b26d4dc3e022961ed674ce85d734f11620a950fb1fb0ef830fba1d8b5bc3eced4", x"b3180ded54610b1b3a2db7db539197ced6a75e9bb381d1f4b802ca7cd450f5418522ad2bee3df1956ed63ff1ffe95dc1", x"93706f8d7daca7c3b339538fb7087ddbf09c733662b55c35f2a71073f4a17c91741955d4d549c2ee6c22eaa84193c1ad", x"93cd53472c2818ab26f77bcc52ea2f37914d80c8abe318f9db59cc5a6943d1b252287d470174a4cbbff0f5ec295a2fc7", x"850515e1671f869ad1e207d44867f29b1fe3ec2bd736dbe053b5b72d53ff97d79c28218a7ace24c72d7972ed264f7356", x"8b300dea07e73dd2f07b05d477e51f8424589f6b2fa6f461240e1322a3a7ab5bf227b74544bb5d66a297702cdbf6c6bf", x"93c1b107eed20ea64c303f53819aede3fc3df85ecf1009174398a8be1441e374657697936af1b9f6e655797478557cea", x"a267ed144cdd3099c7c418ae92e8f4696704c2c9dcde5ffccc3118c21abe09e3a05e78b067430d4fcfca0f8b1ad0714e", x"b429841b1eb28c9083ddaf05385c2bb55f2b6becb3ab97163b0d0af7c9e878e402110177527f8c6e592a52e9bcb379d6", x"937ccbf8cd19b82af2755b4856cfcca3d791e33ae37e4881982ea89d3b21d205a9402d754fac63037243e699484d21f6", x"aa25208385573caee2a4830f09e1cc9bd041cdb78d3ee27a4b011815a62d0d2e0295c222480947ae427b1578fb5509f5", x"a020404547407be6d42856780a1b9cf46b5bc48122902880909bdcf45b204c083f3b03447c6e90d97fd241975566e9bf", x"8c0a3c445d437ca15be0e3a083f792c893e18b9c3caa67410b0c10947a0c8b5a4fda7dbf3549482b03d971021d4a353f", x"8bb51b380a8a52d61a94e7b382ff6ce601260fa9b8c5d616764a3df719b382ec43aec9266444a16951e102d8b1fb2f38", x"a02f7fec0661394399a82b2e3151009160b3f5392017ba579b301ed42c85100c295acbfed46b6c58a9d71796ed0930e6", x"93ba2e000bdb7269818d390bc4232992d280e69abebe2db2ecb6fcb1390d323238c9793574509bc1fa34051ac1928f07", x"8180ffffb5abe78c38f2a42a3b7f1a408a6d70d3f698d047d5f1eef3018068256110fcb9fb028c8bdccbc22c0a4c3a20", x"b01a30d439def99e676c097e5f4b2aa249aa4d184eaace81819a698cb37d33f5a24089339916ee0acb539f0e62936d83", x"8117fbcf61d946bee1ce3dff9e568b83716907acfde9b352c3521cfed44158874af8dd5b3906b4a6b49da2fb212ef802", x"a507e96d7cf15c3a67687dbbcf62b1acb41834568754d51d647d94fece39c14aa264d9e6aef04c9ee4c3bd87119f9b56", x"97f1a7370b4f5acf83b466f519da361c366915f560385dd7eff9d53700ad81b25c9862bc71d35428e82372a5ae555ea0", x"973091c0e72354e0df4488c9078d11eec554c8cc84771955595aa1dd7a7a9dc9e29597924678aa20ecefe5be394fd2ae", x"b102107527690d9324e9f121aad6b01f15d70140ff3b54e88a6743af913e95df9756f46c88c2525b6468f79497e1903e", x"a131f61a215d689938b1997ec40357b939bd2a2565df04cea7800674e23ba068d0ce28bad32f49f3099434f34445eb4a", x"96dc061ef504f721c17043fb88f4b338d3c4d9fd135c909fd6456a3f05331b4bdf9f9adc3083270e27bbfb0511788394", x"99efc1b9c40aafca602efa4ea00d8d9dfadcd77a962c833e347a928d8d52da51fb000f673cd17dadc80e9115ba04f91e", x"96d4b9b411319e531bab6af55c13f0adb1dd6b4286784ff807f283e7990dc368c16d536fc5db3d992deb4b0278914e6f", x"b7519d6a1d93cfd11fb19ea534b107b0dd612986d6d56a0d81e8b5faf112919a55e4135a5c5052ef8142535a22ab8bdf", x"93655457967d1f62c3574c4bd85688c92dbdf256f3629818f8c2d75fe12acacc57b6fe78632bb22d4ac7bc1861e59fcf", x"949b8b056e465813496fbdd71929cfb506b75a7aca779002c437745f651527387afb84bfaacdd0c2501893a7209b4a5f", x"a802b9ffbd4f01b877791aba27da972be4bacacc64a1f45687be4af01b84bd4b83fe2ba1ea78e29d7683f6c777ab2543", x"a85a31dbc17a20a7b814cf9a8ce96dad2349397bd5b08fdbdfcc3e71e29bfd56ad746e88f752215e2822a193cbd2749a", x"a80ac2a197002879ef4db6e2b1e1b9c239e4f6c0f0abf1cc9b9b7bf3da7e078a21893c01eaaab236a7e8618ac146b4a6", x"b9cd71ebd50b024e32558ab1ddbb50c222503492e5c9e1d282731948c0b59458fbd85cac56bab0ba47a4c6dec8549c5f", x"990ea2b09cddb2d2859a1c54e403b8dcec16505f6117afc8957aaf73d08b7c86f822f0db037b634d9614cf90a69bfc4b", x"8c0a3c445d437ca15be0e3a083f792c893e18b9c3caa67410b0c10947a0c8b5a4fda7dbf3549482b03d971021d4a353f", x"820f164a16c02e136911dadbc61b9f6859a7c53d0ea17b8f64b783f7f2f4f549775d3f16e21634dc6d54aef8d56517b2", x"b7c66da483b18f08344fc3c27bdf4914dabbcefd7ee7672fab651d05127d85d25ce363b0c338d6eed55c4e31f57bcb35", x"ab6b47627cf76d9552c723818db5ebee7734542436b50ffe15b3a96e8e7a6b54f9a0965de78405e16e309193f147108d", x"89ab1e5c2565f154f92c9b3554160832d176613f1a2f872b6ed62ed925a33fb0b40b71b7443eaaa15099ab24693c8d13", x"af17532b35bcb373ce1deebce1c84abe34f88a412082b97795b0c73570cb6b88ea4ba52e7f5eb5ca181277cdba7a2d6d", x"80d492fbdbe9d5fcd08fe962b3ce2b9c245c068f686c4838f57db5b4e8b1bfc729c98e93dd4e5cc78b661845d7459809", x"b8d68610fdee190ec5a1f4be4c4f750b00ad78d3e9c96b576c6913eab9e7a81e1d6d6a675ee3c6efac5d02ed4b3c093a", x"b96a11048c7c327709d52e72e6f6ed0b7653329a374ea341ad909311b5b303e5629d6dcf11dcdb195e8c7592ceefac21", x"917721639b1bd13c33ad5b332e4486c4202ed28ddd9fe97b4d2367a87829c742c9e4bfb508827f4b8cadd0bdab99708f", x"97a16c696787a99fd243193ef8edc43285d9d9b5911a27d057186a0b80b2593236d1dd48baaba1e9a0467114aeb776e8", x"83eb2f58e5d1775a8d92ea9eec121a1917dac431ced3b2e9ef7dd670cf719f82c1d0694b312150ced991114925a4912e", x"952a95612aecce4321d2c17aabd2fb260b1cb41df5f76f5b82b46cf818d7a4f18e5e2944cddcd2280a993c0af4f834fe", x"aac995a41c14d379853ef18ffc854ad62ad77061ca9bdf5029cab3d6c2630de114e777a7fc3322455939d5205ed59c55", x"a156e24fba7e966105307e89b102106710e2021e694c090decf32012e8794c6a090b27063ee605db40e435bf8b6ebf9f", x"8934e9a3feababa12ed142daa30e91bd6d28b432d182ac625501fe1dc82f973c67f0fe82d39c9b1da3613bb8bfe2f77b", x"b0a771b9a0dd7e352d46c8efcc1834e610dd097711bf7117678a99d386890c93b9b901872d4dcacb6dcbcf3aea0883ea", x"8910f41db6952c25dfbf6b6b5ba252a2d999c51537d35a0d86b7688bb54dcb6f11eb755a5dce366113dfb2f6b56802b7", x"98dcde79eb47b1e453ca6f61d4d5e53793d46300eda8d1f373500ab57ee766603d30480eab88164714e598ecdcb86cc6", x"94179fcc1fa644ff8a9776a4c03ac8bff759f1a810ca746a9be2b345546e01ddb58d871ddac4e6110b948173522eef06", x"b9445bafb56298082c43ccbdabac4b0bf5c2f0a60a3f9e65916af4108d773d62ffc898a35b0b8efb72ea846e214faa02", x"862d53d9e4313374d202f2b28e6ffe64efb0312f9c2663f2eef67b72345faa8932b27f9b9bb7b476d9b5e418fea99124", x"93418c312300d4431dd7c304fab1639d8ef927d4a36518642c574769953321cd0516e0dad739d6e2ccd315ff1257275a", x"9366d86243f9d53bdd15d4cd6bf5dd348c2b89012c633b73a35d42fa08950073158ca0a1cfc32d64f56692c2374a020f", x"ad77fcac9753efba7a9d9ef8ff4ec9889aa4b9e43ba185e5df6bf6574a5cf9b9ad3f0f3ef2bcbea660c7eef869ce76c8", x"9330a8d49b52cc673adc284c5297f961c45ec7997ced2a397b2755290981104c8d50b2fea9a3036ac2b1c329feaf4c7f", x"824fde65f1ff4f1f83207d0045137070e0facc8e70070422369a3b72bbf486a9387375c5ef33f4cb6c658a04c3f2bd7e", x"813bafdf6a64a9c40ef774e6c8cad52b19008f1207fc41bd10ad59c870fda8089299dd057fc6da34818e7a35b5a363e9", x"93a1ff358d565658d3382f37c6e057e3c55af8aa12b46ff2cb06f3dd7f4bb83b04ea445c8f3af594f9ea3b0cca04c680", x"a1f8583c2e00ca686040451b4f99efc06cad42d1cf97542d951eb755d95010ee4b9f6e105a82bb8ac1ae5c7d58d9ef35", x"921109a390e4d7fbc94dff3228db755f71cb00df70a1d48f92d1a6352f5169025bb68bcd04d96ac72f40000cc140f863", x"887ac0eaa1020681dd405305299e994a02bc71bbc696484e2138a71ea09fbf0d2675333bdaf428a5a14fd1d275859ab4", x"893a2d97ae067202c8401f626ab3938b135110105b719b94b8d54b56e9158665e96d8096effe9b15c5a40c6701b83c41", x"a485a082dee2987e528d1897dfc5ee99c8de9cdc0c955fc38c404c16c35b71bccd08770c93102110547381a2eb9d3782", x"aa318e541c171104c94abd4110f9269efc88ce98ed472aa52ed877634291f6355314b915230723da00069eebefda97aa", x"a53658aaddc51e20752454dcbc69dac133577a0163aaf8c7ff54018b39ba6c2e08259b0f31971eaff9cd463867f9fd2f", x"989dd204868cc2d003cea91384ca706b022a837a8e5e10657a47795a5964452bbd4ad456f9b1053a51a257e241be51f4", x"b4d5ad2fa79ce408d9b13523764ad5c7c6c7ffe96fdf1988658ef7baf28118b33d48eb9c3e21d1951fd4499f196d2f0a", x"97070a33393a7c9ce99c51a7811b41d477d57086e7255f7647fd369de9d40baed63ce1ea23ad82b6412e79f364c2d9a3", x"a25e16820baca389c78a8a72e9b244a4db0399d146eba4f61c24b6280f7cf6a13ddd04de1df6331b2483e54fd2018de6", x"9702ebb1f2eeb3a401b0a65166fa129d829041984fe22b3f51eedfaf384578d33dab73d85164a101ecbb86db9d916419", x"941fe0dabcdb3225a625af70a132bc1e24ccab1f8331dde87db3e26cbee710b12b85535e46b55de7f5d1c67a52ddd5c8", x"9517cd84390fbbfb7862ca3e0171750b4c75a15ceb6030673e76b6fc1ce61ac264f6dd1758d817662abfc50095550bd3", x"84888f2efd897a2aca04e34505774f6f4d62a02a5ae93f71405f2d3b326366b4038854458fd6553d12da6d4891788e59", x"85ee86a9de26a913148a5ced096ba46ee131d2975f991d6efcb3fec62975b01a1d429fc85d182f0d2af72d1adf5bfd2b", x"98181e9291622f3f3f72937c3828cee9a1661ca522250dfbbe1c39cda23b23be5b6e970faf400c6c7f15c9ca1d563868", x"952ae6ce5beb7900cc492b255c44faa7810d70d9490af794f52d0f03f3dbd54fb9a7b940f07f5e6d4dc61dba708c7fc9", x"acb7069fe0428d350b8b710a702f56790bdaa4d93a77864620f5190d1ac7f2eed808019ca6910a61ec48239d2eca7f2a", x"8d47a7c2c62b459b91e8f67e9841b34a282ceb11e2c4b0549883b627c8526d9e0ebd7333ba70630bc0ec2478114b6ae8", x"a1359866783af9031d20ac64380daee86c8054a9af62e4d2100f87c5aeffd0ca48769560fb9a550675e6cd1e6382f32f", x"95fa868db7592c5fb651d5d9971fc4e354dff969d6b05085f5d01fb4da1abb420ecad5ecb0e886e0ced1c9de8f3d5cfe", x"98b41b67eeaaec5696bfb492efa84248c386c9267a259270f214bf71874f160718b9c6dd1a1770da60d53c774490de68", x"942bee9ee880ac5e2f8ba35518b60890a211974d273b2ae415d34ce842803de7d29a4d26f6ee79c09e910559bdcac6d3", x"b2df29442b469c8e9e85a03cb8ea6544598efe3e35109b14c8101a0d2da5837a0427d5559f4e48ae302dec73464fec04", x"8d264fbfeeebb6c4df37ff02224e75e245e508f53fb3446192cd786ecf10d0f704c4fc2e53e7f7318ae1407e46fc0fb8", x"88d417467d9286577913b2ba793d43c3a0202388f793187e9e38cee9e83eae1f6ac7f9138fd9c9b105e1c7560ad298d7", x"99049e9a23c59bb5e8df27976b9e09067d66e4a248926d28171d6c3fdd1ab338944a8b428b2eaae5e491932c68711c7c", x"8ba7b12d2aa2786e50a6e6fb96f8205ed32b245e363f883ec51047e30c5eccaedba701d84c2ccfb1e2988ea76d2f43c8", x"a507e96d7cf15c3a67687dbbcf62b1acb41834568754d51d647d94fece39c14aa264d9e6aef04c9ee4c3bd87119f9b56", x"87fd7e26a0749350ebdcd7c5d30e4b969a76bda530c831262fc98b36be932a4d025310f695d5b210ead89ee70eb7e53b", x"890def696fc04bbb9e9ed87a2a4965b896a9ae127bc0e1cc515549b88ddbcbc02647e983561cab691f7d25cf7c7eb254", x"b380ee52038a0b622cd7eccf4bd52966573fadde4fe8f70f43fa9c43a5a99b3eaf58335a1948b561f5b368ab4e0710f6", x"b3d41dcf67bc7467dafe414b1dd5e78edf158bfad5dcbe64e33ffb6bec5063b1575d0bb8ef768e5904f718cab7daa8ec", x"8275eb1a7356f403d4e67a5a70d49e0e1ad13f368ab12527f8a84e71944f71dd0d725352157dbf09732160ec99f7b3b0", x"98c8f45e348091164a71a06b8166a992dc692177e7e06063f2a62adbee2028c882dc8225891c59386e69dee53cefe2ec", x"8a98cc2fd044f6749775001dc8209349547d19dc56e1da2e4de1c953e7e36f15740cdbb5e8c6e4238bf216c1f7f9f02b", x"824fde65f1ff4f1f83207d0045137070e0facc8e70070422369a3b72bbf486a9387375c5ef33f4cb6c658a04c3f2bd7e", x"80e58680edb62d6ef04727a36e41e5ba63fe787aa173171486caee061dcb6323f8b2de07fc0f1f229c0a838ed00e3e31", x"a413befdecf9441fa6e6dd318af49173f19e8b95b8d928ebe1cc46cacc78b1377afa8867083be473457cd31dfff88221", x"89a3da03c0d87cf8a3a166dc845824215cc6057f9d2e582866c6d4ba35ecd51e31a8c8203a6f222bc6701beb249052f4", x"860f5649c5299211728a36722a142bf1aa7cbbfbd225b671d427c67546375de96832c06709c73b7a51439b091249d34f", x"998c9ee20d33f96a2388b1df642aa602bc8900ba335e8810baab17060c1eace4bc5203672c257b9ae750008b707b0aa1", x"9831b8c836114f6d8213170dde1e7f48d5113974878ae831fc9b4da03f5ed3636342008228b380fd50d4affe909eb54a", x"a17b0040b4e8549acbcfcb5cc3100230e50a0289f54f5b6df39dbae22cde97eab0b13ad4aedcd21bc685bdd0afdc1ca7", x"900b9972180a2c8753f5ff49fdd2cfe18c700d9927b3c3e16deb6376ad6ee665c698be72d4837b94911a0b4c183cb140", x"9340bfc34ffab8c28b1870a4125c559978ac2b278f76f462b5c859a00c3ba3426b176dc2c689096ad575b4cd4dbb76ae", x"ad5be06308651ab69fc74a2500c2fdab5a35977dd673949a5bb7d83309b6bf3fcc3c82d8770802db1556fd7abe37f052", x"8c0a3c445d437ca15be0e3a083f792c893e18b9c3caa67410b0c10947a0c8b5a4fda7dbf3549482b03d971021d4a353f", x"ae5ea228c1b91ef23c245928186fbafa1275ff1817535018d7d2d913abff0fd76bf41fd04a96d816f2f1891bd16e9264", x"ac4075da4614cd05cd4e23dc11d8aa630a9a2e908ba72f55b9c92d6a14a656794e74282864829954468f02b5b8a1648e", x"90273bb88f2d4d23f9d7dd2fad356f7c0626b4ff52569f274ca62f8fba65fbded0121e7cc0981272da155f36e9be8bae", x"a3680e085b257d11e89f682db42c5693669c3e895d300be471917cbc051e9da36901263dac4b0c7e9047b35dbc8eae4c", x"a86eb98aa505fc1cab0be79c9c51d3823930ac212578a8e2b5a168573ceb8d6577387200ca810b84702741f5dc78a8f7", x"aa0b0ef6abddbb4931fea8c194e50b47ff27ea8a290b5ef11227a6b15ae5eda11c4ab8c4f816d8929b8e7b13b0b96030", x"a2053719da2b7501dab42011ae144b3c8d72bd17493181bf3ae79a678068dc3ee2f19d29a60b5a323692c3f684f96392", x"847b58626f306ef2d785e3fe1b6515f98d9f72037eea0604d92e891a0219142fec485323bec4e93a4ee132af61026b80"
        ];
        let aggregate_public_key =
            x"91907a23f2339405377a7621fdabf651b4a63d9352d82c84beb711a422aca6dfe2e69f02fda7ba761823f5e8a48b37f7";
        let current_sync_committee_branch = vector[
            x"5e12c619db473930109cc1f0cacb511ad9406992f8428d1f0b1282e29ae74072",
            x"e081f9182176913e8721bd0222e33cd64d682805a3157b638da9043a77722cf2",
            x"3e8fadfe1e928c02ee6d41c17242fd6b05e450d96b5f981ba1c1533d147d359a",
            x"059969636583cb84a19b49cb0956529139f4d7c3475287d2109f4509acc3ab28",
            x"d4106dceafd0ba3bcc884345bee73d86f30ff7c1c808e8700915646e929d982c",
            x"b6fe319df634d358075169e51cb0a7fc6ed33b321aa5f9563df8218a243d46e9"
        ];
        (public_keys, aggregate_public_key, current_sync_committee_branch)
    }

    fun test_initialize_light_client_store_finality(
        test_account: &signer, user: &signer
    ) {
        account::create_account_for_test(signer::address_of(test_account));
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
        test_only_init_module(test_account);
        coin::deposit(hypernova_resource_addr, coins_minted_11);
        let slot = 7672512;
        let proposer_index = 1666;
        let parent_root =
            x"435205e70d0eb705cde7c68332bb45e4716c41e2c0d981f06f8f0800b876aa2f";
        let state_root =
            x"d310cfc1282fbe66ebc928fb9b24ffb17df77a02a5ebc7607bd3603c444a713e";
        let body_root =
            x"dce97ddcf50065bdfe832666d0c68af4d251bdf110294fcdb59dfdb704e02633";
        let (cureent_sync_public_keys, aggregate_public_key, current_sync_committee_branch) =

            get_sync_commitee_finality();
        let source_chain_id = 11155111;
        let epochs = vector[50, 100, 56832, 132608, 222464];
        let versions = vector[
            x"9000007000000000000000000000000000000000000000000000000000000000",
            x"9000007100000000000000000000000000000000000000000000000000000000",
            x"9000007200000000000000000000000000000000000000000000000000000000",
            x"9000007300000000000000000000000000000000000000000000000000000000",
            x"9000007400000000000000000000000000000000000000000000000000000000"
        ];
        //this is the orginal change back to this once the necode is fixed
        let source_hypernova_core =
            x"0000000000000000000000002bdf8988f6c030fa592a09f94559ee65e0eb3825";

        let sync_committee_threshold = 400;
        test_only_initialize_light_client_store(
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
            source_hypernova_core,
            sync_committee_threshold,
            x"6253c4239a235930c4597a4076cc8351362a2a8107a4acdeb5e2f7aeafb87e49"
        );
    }

    #[test(test_account = @0xdead, user = @0x1, deposit_acc = @0x123456)]
    fun test_process_data_optimistic(
        test_account: &signer, user: &signer, deposit_acc: &signer
    ) {
        change_feature_flags_for_testing(user, vector[89], vector[0]);
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741802303);
        test_initialize_light_client_store(test_account, user);
        let recent_block_slot = 7164745;
        let recent_block_proposer_index = 352;
        let recent_block_parent_root =
            x"bb6bc8c5a790995e4cf7a9d6a2de2eaf3352ebce2ecf4ec0be7f4659094338ca";
        let recent_block_state_root =
            x"0301f12622a0eaaf74285df33e5abee266eee229c3d8cae2acd491929767f727";
        let recent_block_body_root =
            x"6e9b3403aa8101e68d95967702a68740677f70e798a01598502611f16ba0cb16";
        // // sync_aggregate: SyncAggregate,
        let recent_block_sync_committee_bits = vector[
            true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, false, true, false, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, true, false, false, true, true, false, true, true, false, false, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, false, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, true, false, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true
        ];
        let recent_block_sync_committee_signature =
            x"8834db2281a84c40e3262e5d5ec84bd7879756c47febffdaec1e96710545d32a6194aef76251f78c7f15e7a96ae2bcc406950fc0be85ff5988f7139934231eafc8f7fb441284af82cebd1d5ded782e91ad03a031ba072ca413f6af39530e51a4";
        let recent_block_signature_slot = 7164746;

        let is_historical = false;
        let block_roots_index = 570176;
        // let block_root_proof = vector [x"98020ad5c6f88200a9922ce0ca75166d25181f8ddcf1d8aa9a880d6a4b6f9332", x"c4134576b762f4050a1aa9a949f3bbbf4cc303c1262b7f3c2ad42029f18a07c0", x"f9284c867e5620b92ae2e47e93cc81bd38344c78fc208d328b86b23820fe9c3b", x"f5829864579e190f02d4484bf418d2dd6cbb8c13b930879fdc1fc9a4eb515bf7", x"246f410f4a24f0da9c070aa7537b4c62c18dbf2a32f59a05cb2c14f44948281b", x"62caf5ecac31cfbbea77b8973dec46a3e2b399e5f960beb104f35b4e30605ee5", x"dbf1046f6da443ecd298b45743034c5eaf59568ee2dc548a02178ce8d8f001bd", x"9daea5911b9bcff147782f63f3e1cda223a4b24ae577b50cd84f8af6702cb20f", x"dc910e6702975ef13bde3f2ef9471f7a7cf709775f13593f7f72bff45e8e7e70", x"58bd2701360623f812ec81c8e4a4e1980620cffb341070265d128ee8777152ec", x"f7abe67ca7c1cb4783abe8eead20ab25306ba513a3e68661b56fcee778df90a3", x"5cd3b2bc8f7787700e448d23ebc73ea0323c1629e25ef80548c0ccf86c741d0e", x"3575292afd365204526ce54ef21dd540d04bcfc0f2e360fda2df241e9f9d3143", x"ad3cc943690e8ee0b0b0acc6be18fd98e2d829cd820736eea077697e05458d5a", x"e627e86458023b264e0c9305d1394a0b4e5511ba85a7a16c67205983e2d62ca3", x"8460e613a3db209eb2d8abc8888586f04b025ca4a1f3c09e42d375ed96f18606", x"f74bddbee1332b65daa22696df0b27606ab68505006feb8c4208096973639cbc", x"fafdf7baf68736755f81f76c369d17787d0f83f455255d3a031b9d1ed12c8e1b", x"b83fd15f77764c922f7289fc7f438eb58651ef588f2dac66333f3d6632edc154"];
        let block_root_proof = vector[
            x"fc69a50155db01a864c24aa5d02d2309516743a0b4d5cd9e0940829fe2fb8be8", x"718f315585f5ae27864847d830d902a9932e748ff397266de4c5d5e8bed77566", x"705cf554f57c2061e6a099059414d1c877ade7e38222c9cbba1c39b9eb50790c", x"d4c2ed65b44597a2eb9588abce091ec9ec248819702668b741e9de840f928cd1", x"5630f835bffba993832554159f2e251f9b2a9e296c19991e53f4c1a1c9c2ae3b", x"78031f04a16c707e4ed78603a4cd2e186279016ece68f05a612a0760d64c9c6b", x"17d8c83512f209252f78c2e0cb29974d1d96328a19de4cc87f97b1072a33f1c7", x"6438e60ddccdffa1c28f60013807807c76a5532097971e361c56e1c20d6d6224", x"cf5732ca1687dc30070ae61928cee9de84099c6eb3b20f67bc084b464fad0871", x"58db38f4e4cae211b556bbc245aba54dd0f4b004637964b4469f3d2f2f42ddcb", x"a97a9fcd891fa712bf94382f9d9f0b82668dfcdaa7dcd403602166a705f587f1", x"0dab1b9afa9dceb7f17e3aa10b58b0d7fe771e89962ef83dac5c0b9c3cc2790b", x"e972d01afa37f5125acb04a97d49174a9edfbaa62a44db351a4081e848b65031", x"48b67f243f3dd4a67cdd3942474c5d757b029787a45bc522bca44d612e9639ca", x"a2372b9f49556b17e29377dccef2e4ce47895f895eb68bbf45c51b0492be2b2c", x"643e717d6e284488d717313f1a82b07310243638383fbd5e7fa0f2e5841cdce2", x"6ad55d8912fb3c6ac2521909cc03cb92aac1921da2ae2a3ef7af6b7e151bd435", x"de03995d4b3ae68f2ecd479e7a3924cb84f49b0bdfe0350a9806f16b0aa26212", x"b83fd15f77764c922f7289fc7f438eb58651ef588f2dac66333f3d6632edc154"
        ];
        // // Historical_Roots
        let historical_block_root_proof = vector::empty<vector<u8>>();
        let historical_block_summary_root = vector::empty<u8>();
        let historical_block_summary_root_proof = vector::empty<vector<u8>>();
        let historical_block_summary_root_gindex = 0;
        let slot = 7164736;
        let proposer_index = 691;
        let parent_root =
            x"bff6c5746e7e344b95145dbe4284be6d859de9e8d5c0c23808cc9b78c25f676a";
        let state_root =
            x"0b7fd9ff4eeff218d0d1601895b912707357c2cffba872e39e4c040dc6d3f6bb";
        let body_root =
            x"63fe367a5f8a544dbc22abe0f57a4000a4fa3a4a33b3316cfa3149c862e46244";
        let tx_index = 156;
        // // Receipt Proof

        let receipts_root_proof = vector[
            x"e94cd77a1f7bf45180a10ef7676a841bbb93862b82d4009c54a0b1517aeac81b",
            x"d77bf349e04e50e42cba9cdafab9994d91a68686f38286689075e03fe838e836",
            x"f642678c261374938898afad5363ed42ab31201cbc8a097e0b67d48096241fb6",
            x"edf64f154d4c05df768a48ed5b88970e6b6bd16aa592a47b714245316a8617c3",
            x"536d98837f2dd165a55d5eeae91485954472d56f246df256bf3cae19352a123c",
            x"a791039e050c084d8ae3b4031ff498fda911cd17d12e722f7b996156ad2cfc18",
            x"a09c812529fdd11d19edd02b480b8a265c15e70d7b63a2f742c2296dfc010418",
            x"6dd3b9955d892d92338b19976fd07084bfe88a76c3063482b7f30ee60feb2a58",
            x"a80abcd1a05d9d537d6206e92bf923776a46c772e333a4b749207f26a3b5b594",
            x"0000000000000000000000000000000000000000000000000000000000000000",
            x"f5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b",
            x"96f3e0a02964899855f4c726f50fd28fba48bb2cdd800463790de4ae751de557"
        ];
        let receipts_root_gindex = 6435;
        let receipt_proof = vector[
            vector[
                249, 1, 49, 160, 22, 171, 160, 72, 133, 186, 53, 232, 252, 87, 126, 128,
                182, 239, 162, 182, 33, 12, 19, 38, 88, 88, 70, 197, 215, 203, 134, 212,
                155, 241, 233, 225, 160, 40, 145, 45, 147, 213, 12, 141, 42, 129, 75, 159,
                21, 131, 113, 133, 222, 185, 99, 151, 175, 95, 50, 13, 158, 118, 44, 3, 8,
                161, 212, 232, 172, 160, 227, 242, 172, 202, 110, 83, 226, 128, 200, 239,
                127, 246, 2, 101, 143, 74, 2, 186, 178, 225, 230, 237, 68, 232, 164, 2, 60,
                50, 45, 187, 179, 36, 160, 87, 150, 219, 170, 201, 196, 100, 196, 43, 125,
                152, 174, 186, 93, 143, 122, 198, 123, 116, 42, 124, 156, 202, 114, 144,
                219, 33, 130, 10, 209, 130, 168, 160, 172, 7, 1, 115, 155, 96, 77, 231, 37,
                1, 148, 193, 166, 108, 215, 68, 201, 244, 97, 71, 94, 0, 14, 223, 16, 126,
                26, 170, 151, 96, 127, 12, 160, 47, 70, 86, 128, 245, 53, 191, 40, 4, 194,
                172, 19, 120, 25, 98, 134, 29, 17, 216, 114, 219, 195, 64, 249, 134, 217,
                21, 62, 48, 107, 12, 230, 160, 215, 132, 186, 102, 102, 40, 185, 175, 91,
                16, 12, 178, 63, 188, 10, 200, 247, 240, 120, 137, 80, 204, 28, 185, 132,
                172, 24, 255, 97, 77, 157, 154, 160, 88, 53, 62, 138, 231, 152, 139, 35,
                53, 41, 227, 110, 35, 41, 181, 225, 131, 165, 40, 127, 138, 187, 171, 214,
                231, 133, 251, 214, 245, 234, 68, 21, 160, 211, 198, 88, 241, 77, 243, 37,
                105, 16, 49, 154, 94, 242, 67, 144, 60, 138, 38, 197, 12, 201, 15, 246,
                123, 76, 207, 106, 78, 51, 175, 35, 185, 128, 128, 128, 128, 128, 128, 128,
                128
            ],
            vector[
                248, 81, 160, 172, 26, 35, 217, 176, 234, 101, 190, 221, 255, 67, 114, 107,
                168, 102, 118, 121, 63, 111, 118, 29, 31, 48, 225, 16, 111, 77, 187, 58,
                25, 197, 215, 160, 17, 244, 165, 84, 119, 231, 46, 243, 119, 20, 35, 212,
                1, 105, 160, 75, 184, 202, 167, 107, 174, 72, 164, 213, 132, 37, 49, 25,
                16, 188, 151, 82, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
                128, 128, 128, 128
            ],
            vector[
                248, 81, 128, 128, 128, 128, 128, 128, 128, 128, 160, 123, 18, 41, 246, 47,
                194, 155, 129, 196, 106, 49, 1, 182, 40, 74, 255, 19, 152, 25, 234, 161,
                148, 212, 188, 49, 107, 241, 205, 171, 190, 77, 15, 160, 169, 101, 171,
                123, 24, 39, 165, 91, 87, 208, 181, 64, 58, 76, 52, 30, 34, 171, 21, 183,
                12, 65, 35, 243, 142, 39, 199, 104, 14, 62, 21, 171, 128, 128, 128, 128,
                128, 128, 128
            ],
            vector[
                249, 1, 209, 160, 208, 34, 141, 104, 230, 210, 186, 149, 58, 141, 67, 148,
                70, 245, 148, 132, 209, 144, 208, 104, 148, 104, 72, 144, 45, 122, 218,
                234, 10, 21, 83, 136, 160, 35, 187, 37, 133, 28, 55, 198, 143, 69, 39, 88,
                146, 31, 177, 172, 13, 48, 61, 89, 189, 143, 64, 49, 103, 140, 90, 135,
                252, 69, 204, 128, 14, 160, 145, 188, 254, 168, 201, 146, 201, 175, 148,
                52, 219, 231, 61, 148, 78, 183, 26, 144, 59, 206, 62, 159, 107, 116, 119,
                228, 115, 132, 17, 200, 178, 58, 160, 210, 233, 135, 118, 233, 32, 21, 154,
                45, 7, 24, 209, 55, 109, 227, 187, 241, 55, 243, 67, 240, 87, 145, 32, 92,
                223, 103, 108, 68, 101, 155, 243, 160, 61, 82, 6, 174, 70, 129, 180, 201,
                99, 142, 185, 73, 12, 22, 93, 81, 150, 146, 216, 55, 212, 173, 188, 111,
                53, 145, 230, 227, 47, 216, 91, 200, 160, 108, 21, 92, 184, 199, 193, 148,
                121, 245, 43, 209, 250, 176, 132, 232, 79, 139, 190, 0, 115, 90, 233, 2,
                142, 30, 40, 6, 8, 169, 149, 17, 234, 160, 9, 59, 72, 191, 120, 219, 216,
                183, 243, 136, 144, 166, 90, 49, 189, 109, 169, 218, 64, 39, 15, 0, 179,
                150, 253, 226, 89, 30, 125, 226, 202, 160, 160, 167, 133, 61, 31, 93, 11,
                238, 74, 187, 177, 4, 216, 73, 113, 68, 126, 12, 211, 39, 83, 145, 166,
                119, 105, 233, 107, 126, 177, 239, 164, 126, 224, 160, 96, 208, 48, 12, 9,
                51, 80, 27, 204, 85, 80, 69, 124, 162, 136, 88, 115, 19, 48, 40, 76, 190,
                72, 107, 207, 89, 196, 111, 165, 159, 64, 227, 160, 241, 200, 217, 16, 11,
                171, 139, 213, 6, 1, 66, 105, 130, 243, 184, 194, 33, 183, 205, 236, 150,
                177, 111, 118, 234, 155, 113, 133, 241, 80, 128, 1, 160, 90, 103, 199, 67,
                161, 69, 129, 135, 255, 94, 26, 202, 70, 93, 10, 57, 249, 100, 29, 254, 35,
                214, 49, 246, 188, 16, 195, 70, 41, 45, 130, 128, 160, 24, 203, 187, 198,
                222, 237, 154, 62, 80, 208, 121, 120, 81, 160, 73, 176, 174, 87, 89, 107,
                133, 224, 86, 50, 235, 138, 204, 12, 34, 167, 95, 183, 160, 51, 178, 164,
                139, 126, 5, 65, 186, 172, 141, 2, 153, 11, 225, 222, 109, 233, 52, 242,
                189, 214, 204, 240, 17, 199, 50, 176, 65, 155, 250, 7, 108, 160, 207, 30,
                34, 104, 105, 140, 20, 12, 117, 109, 172, 44, 153, 176, 35, 168, 201, 173,
                159, 253, 34, 162, 76, 155, 65, 144, 14, 18, 68, 70, 153, 176, 128, 128,
                128
            ],
            vector[
                249, 2, 244, 32, 185, 2, 240, 2, 249, 2, 236, 1, 131, 253, 158, 179, 185,
                1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 1, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 32, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 4, 0, 0, 0, 0, 0, 16, 249, 1, 225, 249, 1, 222, 148, 196, 174, 84, 163,
                211, 113, 170, 176, 116, 197, 88, 77, 145, 72, 125, 30, 123, 174, 26, 135,
                248, 132, 160, 98, 83, 196, 35, 154, 35, 89, 48, 196, 89, 122, 64, 118,
                204, 131, 81, 54, 42, 42, 129, 7, 164, 172, 222, 181, 226, 247, 174, 175,
                184, 126, 73, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226, 121, 78, 30,
                247, 212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193, 57, 241, 12,
                160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 38, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 185, 1, 64, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226,
                121, 78, 30, 247, 212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193,
                57, 241, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226, 121, 78, 30, 247,
                212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193, 57, 241, 12, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 1, 110, 111, 116, 104, 105, 110, 103, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 224, 182, 179, 167,
                100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 25, 158, 227, 137, 157, 182, 50, 216, 20,
                107, 43, 232, 197, 51, 91, 237, 219, 122, 106, 238, 7, 140, 186, 109, 186,
                156, 81, 40, 83, 68, 150, 240, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 103, 208, 100, 84
            ]
        ];
        let receipts_root =
            x"76a699bc8a8e73a1ed65dac8d7f59f69ce9f9eca45b37857dfdbdfd47cb03bbc";
        // // Message
        let msg_id = x"0000000000000000000000000000000000000000000000000000000000000026";
        let source_chain_id = 1;
        let source_hn_address =
            to_address(
                x"000000000000000000000000c4ae54a3d371aab074c5584d91487d1e7bae1a87"
            );
        let destination_chain_id = 6;
        let destination_hn_address =
            to_address(
                x"e15636c4d459d01c7a7c081276448b7d9fd294e01528b38c7194bf537b648f2a"
            );

        let log_hash =
            x"e3e3fdfa3b4b43c3d688b29a6e4175b99eee00fed44b381e6d7772a8145ef907";

        let log_index = 0;

        let (extracted_log, _loh_hash) =
            process_data_optimistic_or_safe(
                test_account,
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
                msg_id,
                source_chain_id,
                source_hn_address,
                destination_chain_id,
                destination_hn_address,
                log_hash,
                log_index,
                3,
                23
            );

        let topics = get_topics(&extracted_log);
        let _source_token_bridge_address_extracted = *vector::borrow(topics, 1);

        let message_data_extracted = get_data(&extracted_log);

        let _payload_extracted = vector::slice(message_data_extracted, 160, 192);
        let _amount_extracted =
            bytes_to_u64(vector::slice(message_data_extracted, 192, 224));
        let _fee_extracted = bytes_to_u64(
            vector::slice(message_data_extracted, 224, 256)
        );
        let _receiverAddr_extracted = vector::slice(message_data_extracted, 256, 288);
        account::create_account_for_test(signer::address_of(deposit_acc));
        coin::register<SupraCoin>(deposit_acc);
        // print(&coin::value(&coins_minted));
        assert!(
            coin::balance<SupraCoin>(signer::address_of(test_account)) == 980804,
            33
        );
    }

    #[test(test_account = @0xdead, user = @0x1, deposit_acc = @0x123456)]
    fun test_process_data_safe(
        test_account: &signer, user: &signer, deposit_acc: &signer
    ) {
        change_feature_flags_for_testing(user, vector[89], vector[0]);
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1749756866);
        test_initialize_light_client_store(test_account, user);
        let recent_block_slot = 7164745;
        let recent_block_proposer_index = 352;
        let recent_block_parent_root =
            x"bb6bc8c5a790995e4cf7a9d6a2de2eaf3352ebce2ecf4ec0be7f4659094338ca";
        let recent_block_state_root =
            x"0301f12622a0eaaf74285df33e5abee266eee229c3d8cae2acd491929767f727";
        let recent_block_body_root =
            x"6e9b3403aa8101e68d95967702a68740677f70e798a01598502611f16ba0cb16";
        // // sync_aggregate: SyncAggregate,
        let recent_block_sync_committee_bits = vector[
            true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, false, true, false, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, true, false, false, true, true, false, true, true, false, false, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, false, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, true, false, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true
        ];
        let recent_block_sync_committee_signature =
            x"8834db2281a84c40e3262e5d5ec84bd7879756c47febffdaec1e96710545d32a6194aef76251f78c7f15e7a96ae2bcc406950fc0be85ff5988f7139934231eafc8f7fb441284af82cebd1d5ded782e91ad03a031ba072ca413f6af39530e51a4";
        let recent_block_signature_slot = 7164746;

        let is_historical = false;
        let block_roots_index = 570176;
        // let block_root_proof = vector [x"98020ad5c6f88200a9922ce0ca75166d25181f8ddcf1d8aa9a880d6a4b6f9332", x"c4134576b762f4050a1aa9a949f3bbbf4cc303c1262b7f3c2ad42029f18a07c0", x"f9284c867e5620b92ae2e47e93cc81bd38344c78fc208d328b86b23820fe9c3b", x"f5829864579e190f02d4484bf418d2dd6cbb8c13b930879fdc1fc9a4eb515bf7", x"246f410f4a24f0da9c070aa7537b4c62c18dbf2a32f59a05cb2c14f44948281b", x"62caf5ecac31cfbbea77b8973dec46a3e2b399e5f960beb104f35b4e30605ee5", x"dbf1046f6da443ecd298b45743034c5eaf59568ee2dc548a02178ce8d8f001bd", x"9daea5911b9bcff147782f63f3e1cda223a4b24ae577b50cd84f8af6702cb20f", x"dc910e6702975ef13bde3f2ef9471f7a7cf709775f13593f7f72bff45e8e7e70", x"58bd2701360623f812ec81c8e4a4e1980620cffb341070265d128ee8777152ec", x"f7abe67ca7c1cb4783abe8eead20ab25306ba513a3e68661b56fcee778df90a3", x"5cd3b2bc8f7787700e448d23ebc73ea0323c1629e25ef80548c0ccf86c741d0e", x"3575292afd365204526ce54ef21dd540d04bcfc0f2e360fda2df241e9f9d3143", x"ad3cc943690e8ee0b0b0acc6be18fd98e2d829cd820736eea077697e05458d5a", x"e627e86458023b264e0c9305d1394a0b4e5511ba85a7a16c67205983e2d62ca3", x"8460e613a3db209eb2d8abc8888586f04b025ca4a1f3c09e42d375ed96f18606", x"f74bddbee1332b65daa22696df0b27606ab68505006feb8c4208096973639cbc", x"fafdf7baf68736755f81f76c369d17787d0f83f455255d3a031b9d1ed12c8e1b", x"b83fd15f77764c922f7289fc7f438eb58651ef588f2dac66333f3d6632edc154"];
        let block_root_proof = vector[
            x"fc69a50155db01a864c24aa5d02d2309516743a0b4d5cd9e0940829fe2fb8be8", x"718f315585f5ae27864847d830d902a9932e748ff397266de4c5d5e8bed77566", x"705cf554f57c2061e6a099059414d1c877ade7e38222c9cbba1c39b9eb50790c", x"d4c2ed65b44597a2eb9588abce091ec9ec248819702668b741e9de840f928cd1", x"5630f835bffba993832554159f2e251f9b2a9e296c19991e53f4c1a1c9c2ae3b", x"78031f04a16c707e4ed78603a4cd2e186279016ece68f05a612a0760d64c9c6b", x"17d8c83512f209252f78c2e0cb29974d1d96328a19de4cc87f97b1072a33f1c7", x"6438e60ddccdffa1c28f60013807807c76a5532097971e361c56e1c20d6d6224", x"cf5732ca1687dc30070ae61928cee9de84099c6eb3b20f67bc084b464fad0871", x"58db38f4e4cae211b556bbc245aba54dd0f4b004637964b4469f3d2f2f42ddcb", x"a97a9fcd891fa712bf94382f9d9f0b82668dfcdaa7dcd403602166a705f587f1", x"0dab1b9afa9dceb7f17e3aa10b58b0d7fe771e89962ef83dac5c0b9c3cc2790b", x"e972d01afa37f5125acb04a97d49174a9edfbaa62a44db351a4081e848b65031", x"48b67f243f3dd4a67cdd3942474c5d757b029787a45bc522bca44d612e9639ca", x"a2372b9f49556b17e29377dccef2e4ce47895f895eb68bbf45c51b0492be2b2c", x"643e717d6e284488d717313f1a82b07310243638383fbd5e7fa0f2e5841cdce2", x"6ad55d8912fb3c6ac2521909cc03cb92aac1921da2ae2a3ef7af6b7e151bd435", x"de03995d4b3ae68f2ecd479e7a3924cb84f49b0bdfe0350a9806f16b0aa26212", x"b83fd15f77764c922f7289fc7f438eb58651ef588f2dac66333f3d6632edc154"
        ];
        // // Historical_Roots
        let historical_block_root_proof = vector::empty<vector<u8>>();
        let historical_block_summary_root = vector::empty<u8>();
        let historical_block_summary_root_proof = vector::empty<vector<u8>>();
        let historical_block_summary_root_gindex = 0;
        let slot = 7164736;
        let proposer_index = 691;
        let parent_root =
            x"bff6c5746e7e344b95145dbe4284be6d859de9e8d5c0c23808cc9b78c25f676a";
        let state_root =
            x"0b7fd9ff4eeff218d0d1601895b912707357c2cffba872e39e4c040dc6d3f6bb";
        let body_root =
            x"63fe367a5f8a544dbc22abe0f57a4000a4fa3a4a33b3316cfa3149c862e46244";
        let tx_index = 156;
        // // Receipt Proof

        let receipts_root_proof = vector[
            x"e94cd77a1f7bf45180a10ef7676a841bbb93862b82d4009c54a0b1517aeac81b",
            x"d77bf349e04e50e42cba9cdafab9994d91a68686f38286689075e03fe838e836",
            x"f642678c261374938898afad5363ed42ab31201cbc8a097e0b67d48096241fb6",
            x"edf64f154d4c05df768a48ed5b88970e6b6bd16aa592a47b714245316a8617c3",
            x"536d98837f2dd165a55d5eeae91485954472d56f246df256bf3cae19352a123c",
            x"a791039e050c084d8ae3b4031ff498fda911cd17d12e722f7b996156ad2cfc18",
            x"a09c812529fdd11d19edd02b480b8a265c15e70d7b63a2f742c2296dfc010418",
            x"6dd3b9955d892d92338b19976fd07084bfe88a76c3063482b7f30ee60feb2a58",
            x"a80abcd1a05d9d537d6206e92bf923776a46c772e333a4b749207f26a3b5b594",
            x"0000000000000000000000000000000000000000000000000000000000000000",
            x"f5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b",
            x"96f3e0a02964899855f4c726f50fd28fba48bb2cdd800463790de4ae751de557"
        ];
        let receipts_root_gindex = 6435;
        let receipt_proof = vector[
            vector[
                249, 1, 49, 160, 22, 171, 160, 72, 133, 186, 53, 232, 252, 87, 126, 128,
                182, 239, 162, 182, 33, 12, 19, 38, 88, 88, 70, 197, 215, 203, 134, 212,
                155, 241, 233, 225, 160, 40, 145, 45, 147, 213, 12, 141, 42, 129, 75, 159,
                21, 131, 113, 133, 222, 185, 99, 151, 175, 95, 50, 13, 158, 118, 44, 3, 8,
                161, 212, 232, 172, 160, 227, 242, 172, 202, 110, 83, 226, 128, 200, 239,
                127, 246, 2, 101, 143, 74, 2, 186, 178, 225, 230, 237, 68, 232, 164, 2, 60,
                50, 45, 187, 179, 36, 160, 87, 150, 219, 170, 201, 196, 100, 196, 43, 125,
                152, 174, 186, 93, 143, 122, 198, 123, 116, 42, 124, 156, 202, 114, 144,
                219, 33, 130, 10, 209, 130, 168, 160, 172, 7, 1, 115, 155, 96, 77, 231, 37,
                1, 148, 193, 166, 108, 215, 68, 201, 244, 97, 71, 94, 0, 14, 223, 16, 126,
                26, 170, 151, 96, 127, 12, 160, 47, 70, 86, 128, 245, 53, 191, 40, 4, 194,
                172, 19, 120, 25, 98, 134, 29, 17, 216, 114, 219, 195, 64, 249, 134, 217,
                21, 62, 48, 107, 12, 230, 160, 215, 132, 186, 102, 102, 40, 185, 175, 91,
                16, 12, 178, 63, 188, 10, 200, 247, 240, 120, 137, 80, 204, 28, 185, 132,
                172, 24, 255, 97, 77, 157, 154, 160, 88, 53, 62, 138, 231, 152, 139, 35,
                53, 41, 227, 110, 35, 41, 181, 225, 131, 165, 40, 127, 138, 187, 171, 214,
                231, 133, 251, 214, 245, 234, 68, 21, 160, 211, 198, 88, 241, 77, 243, 37,
                105, 16, 49, 154, 94, 242, 67, 144, 60, 138, 38, 197, 12, 201, 15, 246,
                123, 76, 207, 106, 78, 51, 175, 35, 185, 128, 128, 128, 128, 128, 128, 128,
                128
            ],
            vector[
                248, 81, 160, 172, 26, 35, 217, 176, 234, 101, 190, 221, 255, 67, 114, 107,
                168, 102, 118, 121, 63, 111, 118, 29, 31, 48, 225, 16, 111, 77, 187, 58,
                25, 197, 215, 160, 17, 244, 165, 84, 119, 231, 46, 243, 119, 20, 35, 212,
                1, 105, 160, 75, 184, 202, 167, 107, 174, 72, 164, 213, 132, 37, 49, 25,
                16, 188, 151, 82, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
                128, 128, 128, 128
            ],
            vector[
                248, 81, 128, 128, 128, 128, 128, 128, 128, 128, 160, 123, 18, 41, 246, 47,
                194, 155, 129, 196, 106, 49, 1, 182, 40, 74, 255, 19, 152, 25, 234, 161,
                148, 212, 188, 49, 107, 241, 205, 171, 190, 77, 15, 160, 169, 101, 171,
                123, 24, 39, 165, 91, 87, 208, 181, 64, 58, 76, 52, 30, 34, 171, 21, 183,
                12, 65, 35, 243, 142, 39, 199, 104, 14, 62, 21, 171, 128, 128, 128, 128,
                128, 128, 128
            ],
            vector[
                249, 1, 209, 160, 208, 34, 141, 104, 230, 210, 186, 149, 58, 141, 67, 148,
                70, 245, 148, 132, 209, 144, 208, 104, 148, 104, 72, 144, 45, 122, 218,
                234, 10, 21, 83, 136, 160, 35, 187, 37, 133, 28, 55, 198, 143, 69, 39, 88,
                146, 31, 177, 172, 13, 48, 61, 89, 189, 143, 64, 49, 103, 140, 90, 135,
                252, 69, 204, 128, 14, 160, 145, 188, 254, 168, 201, 146, 201, 175, 148,
                52, 219, 231, 61, 148, 78, 183, 26, 144, 59, 206, 62, 159, 107, 116, 119,
                228, 115, 132, 17, 200, 178, 58, 160, 210, 233, 135, 118, 233, 32, 21, 154,
                45, 7, 24, 209, 55, 109, 227, 187, 241, 55, 243, 67, 240, 87, 145, 32, 92,
                223, 103, 108, 68, 101, 155, 243, 160, 61, 82, 6, 174, 70, 129, 180, 201,
                99, 142, 185, 73, 12, 22, 93, 81, 150, 146, 216, 55, 212, 173, 188, 111,
                53, 145, 230, 227, 47, 216, 91, 200, 160, 108, 21, 92, 184, 199, 193, 148,
                121, 245, 43, 209, 250, 176, 132, 232, 79, 139, 190, 0, 115, 90, 233, 2,
                142, 30, 40, 6, 8, 169, 149, 17, 234, 160, 9, 59, 72, 191, 120, 219, 216,
                183, 243, 136, 144, 166, 90, 49, 189, 109, 169, 218, 64, 39, 15, 0, 179,
                150, 253, 226, 89, 30, 125, 226, 202, 160, 160, 167, 133, 61, 31, 93, 11,
                238, 74, 187, 177, 4, 216, 73, 113, 68, 126, 12, 211, 39, 83, 145, 166,
                119, 105, 233, 107, 126, 177, 239, 164, 126, 224, 160, 96, 208, 48, 12, 9,
                51, 80, 27, 204, 85, 80, 69, 124, 162, 136, 88, 115, 19, 48, 40, 76, 190,
                72, 107, 207, 89, 196, 111, 165, 159, 64, 227, 160, 241, 200, 217, 16, 11,
                171, 139, 213, 6, 1, 66, 105, 130, 243, 184, 194, 33, 183, 205, 236, 150,
                177, 111, 118, 234, 155, 113, 133, 241, 80, 128, 1, 160, 90, 103, 199, 67,
                161, 69, 129, 135, 255, 94, 26, 202, 70, 93, 10, 57, 249, 100, 29, 254, 35,
                214, 49, 246, 188, 16, 195, 70, 41, 45, 130, 128, 160, 24, 203, 187, 198,
                222, 237, 154, 62, 80, 208, 121, 120, 81, 160, 73, 176, 174, 87, 89, 107,
                133, 224, 86, 50, 235, 138, 204, 12, 34, 167, 95, 183, 160, 51, 178, 164,
                139, 126, 5, 65, 186, 172, 141, 2, 153, 11, 225, 222, 109, 233, 52, 242,
                189, 214, 204, 240, 17, 199, 50, 176, 65, 155, 250, 7, 108, 160, 207, 30,
                34, 104, 105, 140, 20, 12, 117, 109, 172, 44, 153, 176, 35, 168, 201, 173,
                159, 253, 34, 162, 76, 155, 65, 144, 14, 18, 68, 70, 153, 176, 128, 128,
                128
            ],
            vector[
                249, 2, 244, 32, 185, 2, 240, 2, 249, 2, 236, 1, 131, 253, 158, 179, 185,
                1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 1, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 32, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 4, 0, 0, 0, 0, 0, 16, 249, 1, 225, 249, 1, 222, 148, 196, 174, 84, 163,
                211, 113, 170, 176, 116, 197, 88, 77, 145, 72, 125, 30, 123, 174, 26, 135,
                248, 132, 160, 98, 83, 196, 35, 154, 35, 89, 48, 196, 89, 122, 64, 118,
                204, 131, 81, 54, 42, 42, 129, 7, 164, 172, 222, 181, 226, 247, 174, 175,
                184, 126, 73, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226, 121, 78, 30,
                247, 212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193, 57, 241, 12,
                160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 38, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 185, 1, 64, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226,
                121, 78, 30, 247, 212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193,
                57, 241, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226, 121, 78, 30, 247,
                212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193, 57, 241, 12, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 1, 110, 111, 116, 104, 105, 110, 103, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 224, 182, 179, 167,
                100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 25, 158, 227, 137, 157, 182, 50, 216, 20,
                107, 43, 232, 197, 51, 91, 237, 219, 122, 106, 238, 7, 140, 186, 109, 186,
                156, 81, 40, 83, 68, 150, 240, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 103, 208, 100, 84
            ]
        ];
        let receipts_root =
            x"76a699bc8a8e73a1ed65dac8d7f59f69ce9f9eca45b37857dfdbdfd47cb03bbc";
        // // Message
        let msg_id = x"0000000000000000000000000000000000000000000000000000000000000026";
        let source_chain_id = 1;
        let source_hn_address =
            to_address(
                x"000000000000000000000000c4ae54a3d371aab074c5584d91487d1e7bae1a87"
            );
        let destination_chain_id = 6;
        let destination_hn_address =
            to_address(
                x"e15636c4d459d01c7a7c081276448b7d9fd294e01528b38c7194bf537b648f2a"
            );

        let log_hash =
            x"e3e3fdfa3b4b43c3d688b29a6e4175b99eee00fed44b381e6d7772a8145ef907";

        let log_index = 0;

        let (extracted_log, _loh_hash) =
            process_data_optimistic_or_safe(
                test_account,
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
                msg_id,
                source_chain_id,
                source_hn_address,
                destination_chain_id,
                destination_hn_address,
                log_hash,
                log_index,
                2,
                2
            );

        let topics = get_topics(&extracted_log);
        let _source_token_bridge_address_extracted = *vector::borrow(topics, 1);

        let message_data_extracted = get_data(&extracted_log);

        let _payload_extracted = vector::slice(message_data_extracted, 160, 192);
        let _amount_extracted =
            bytes_to_u64(vector::slice(message_data_extracted, 192, 224));
        let _fee_extracted = bytes_to_u64(
            vector::slice(message_data_extracted, 224, 256)
        );
        let _receiverAddr_extracted = vector::slice(message_data_extracted, 256, 288);
        account::create_account_for_test(signer::address_of(deposit_acc));
        coin::register<SupraCoin>(deposit_acc);
        // print(&coin::value(&coins_minted));
        assert!(
            coin::balance<SupraCoin>(signer::address_of(test_account)) == 980804,
            33
        );
    }

    #[test(test_account = @0xdead, user = @0x1)]
    #[expected_failure]
    fun test_process_safe_EInvalidSafetyLevel(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741802303);
        test_initialize_light_client_store(test_account, user);
        let recent_block_slot = 7164745;
        let recent_block_proposer_index = 352;
        let recent_block_parent_root =
            x"bb6bc8c5a790995e4cf7a9d6a2de2eaf3352ebce2ecf4ec0be7f4659094338ca";
        let recent_block_state_root =
            x"0301f12622a0eaaf74285df33e5abee266eee229c3d8cae2acd491929767f727";
        let recent_block_body_root =
            x"6e9b3403aa8101e68d95967702a68740677f70e798a01598502611f16ba0cb16";
        // // sync_aggregate: SyncAggregate,
        let recent_block_sync_committee_bits = vector[
            true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, false, true, false, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, true, false, false, true, true, false, true, true, false, false, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, false, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, true, false, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true
        ];
        let recent_block_sync_committee_signature =
            x"8834db2281a84c40e3262e5d5ec84bd7879756c47febffdaec1e96710545d32a6194aef76251f78c7f15e7a96ae2bcc406950fc0be85ff5988f7139934231eafc8f7fb441284af82cebd1d5ded782e91ad03a031ba072ca413f6af39530e51a4";
        let recent_block_signature_slot = 7164746;

        let is_historical = false;
        let block_roots_index = 570176;
        let block_root_proof = vector[
            x"fc69a50155db01a864c24aa5d02d2309516743a0b4d5cd9e0940829fe2fb8be8", x"718f315585f5ae27864847d830d902a9932e748ff397266de4c5d5e8bed77566", x"705cf554f57c2061e6a099059414d1c877ade7e38222c9cbba1c39b9eb50790c", x"d4c2ed65b44597a2eb9588abce091ec9ec248819702668b741e9de840f928cd1", x"5630f835bffba993832554159f2e251f9b2a9e296c19991e53f4c1a1c9c2ae3b", x"78031f04a16c707e4ed78603a4cd2e186279016ece68f05a612a0760d64c9c6b", x"17d8c83512f209252f78c2e0cb29974d1d96328a19de4cc87f97b1072a33f1c7", x"6438e60ddccdffa1c28f60013807807c76a5532097971e361c56e1c20d6d6224", x"cf5732ca1687dc30070ae61928cee9de84099c6eb3b20f67bc084b464fad0871", x"58db38f4e4cae211b556bbc245aba54dd0f4b004637964b4469f3d2f2f42ddcb", x"a97a9fcd891fa712bf94382f9d9f0b82668dfcdaa7dcd403602166a705f587f1", x"0dab1b9afa9dceb7f17e3aa10b58b0d7fe771e89962ef83dac5c0b9c3cc2790b", x"e972d01afa37f5125acb04a97d49174a9edfbaa62a44db351a4081e848b65031", x"48b67f243f3dd4a67cdd3942474c5d757b029787a45bc522bca44d612e9639ca", x"a2372b9f49556b17e29377dccef2e4ce47895f895eb68bbf45c51b0492be2b2c", x"643e717d6e284488d717313f1a82b07310243638383fbd5e7fa0f2e5841cdce2", x"6ad55d8912fb3c6ac2521909cc03cb92aac1921da2ae2a3ef7af6b7e151bd435", x"de03995d4b3ae68f2ecd479e7a3924cb84f49b0bdfe0350a9806f16b0aa26212", x"b83fd15f77764c922f7289fc7f438eb58651ef588f2dac66333f3d6632edc154"
        ];
        // // Historical_Roots
        let historical_block_root_proof = vector::empty<vector<u8>>();
        let historical_block_summary_root = vector::empty<u8>();
        let historical_block_summary_root_proof = vector::empty<vector<u8>>();
        let historical_block_summary_root_gindex = 0;
        let slot = 7164736;
        let proposer_index = 691;
        let parent_root =
            x"bff6c5746e7e344b95145dbe4284be6d859de9e8d5c0c23808cc9b78c25f676a";
        let state_root =
            x"0b7fd9ff4eeff218d0d1601895b912707357c2cffba872e39e4c040dc6d3f6bb";
        let body_root =
            x"63fe367a5f8a544dbc22abe0f57a4000a4fa3a4a33b3316cfa3149c862e46244";
        let tx_index = 156;
        // // Receipt Proof

        let receipts_root_proof = vector[
            x"e94cd77a1f7bf45180a10ef7676a841bbb93862b82d4009c54a0b1517aeac81b",
            x"d77bf349e04e50e42cba9cdafab9994d91a68686f38286689075e03fe838e836",
            x"f642678c261374938898afad5363ed42ab31201cbc8a097e0b67d48096241fb6",
            x"edf64f154d4c05df768a48ed5b88970e6b6bd16aa592a47b714245316a8617c3",
            x"536d98837f2dd165a55d5eeae91485954472d56f246df256bf3cae19352a123c",
            x"a791039e050c084d8ae3b4031ff498fda911cd17d12e722f7b996156ad2cfc18",
            x"a09c812529fdd11d19edd02b480b8a265c15e70d7b63a2f742c2296dfc010418",
            x"6dd3b9955d892d92338b19976fd07084bfe88a76c3063482b7f30ee60feb2a58",
            x"a80abcd1a05d9d537d6206e92bf923776a46c772e333a4b749207f26a3b5b594",
            x"0000000000000000000000000000000000000000000000000000000000000000",
            x"f5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b",
            x"96f3e0a02964899855f4c726f50fd28fba48bb2cdd800463790de4ae751de557"
        ];
        let receipts_root_gindex = 6435;
        let receipt_proof = vector[
            vector[
                249, 1, 49, 160, 22, 171, 160, 72, 133, 186, 53, 232, 252, 87, 126, 128,
                182, 239, 162, 182, 33, 12, 19, 38, 88, 88, 70, 197, 215, 203, 134, 212,
                155, 241, 233, 225, 160, 40, 145, 45, 147, 213, 12, 141, 42, 129, 75, 159,
                21, 131, 113, 133, 222, 185, 99, 151, 175, 95, 50, 13, 158, 118, 44, 3, 8,
                161, 212, 232, 172, 160, 227, 242, 172, 202, 110, 83, 226, 128, 200, 239,
                127, 246, 2, 101, 143, 74, 2, 186, 178, 225, 230, 237, 68, 232, 164, 2, 60,
                50, 45, 187, 179, 36, 160, 87, 150, 219, 170, 201, 196, 100, 196, 43, 125,
                152, 174, 186, 93, 143, 122, 198, 123, 116, 42, 124, 156, 202, 114, 144,
                219, 33, 130, 10, 209, 130, 168, 160, 172, 7, 1, 115, 155, 96, 77, 231, 37,
                1, 148, 193, 166, 108, 215, 68, 201, 244, 97, 71, 94, 0, 14, 223, 16, 126,
                26, 170, 151, 96, 127, 12, 160, 47, 70, 86, 128, 245, 53, 191, 40, 4, 194,
                172, 19, 120, 25, 98, 134, 29, 17, 216, 114, 219, 195, 64, 249, 134, 217,
                21, 62, 48, 107, 12, 230, 160, 215, 132, 186, 102, 102, 40, 185, 175, 91,
                16, 12, 178, 63, 188, 10, 200, 247, 240, 120, 137, 80, 204, 28, 185, 132,
                172, 24, 255, 97, 77, 157, 154, 160, 88, 53, 62, 138, 231, 152, 139, 35,
                53, 41, 227, 110, 35, 41, 181, 225, 131, 165, 40, 127, 138, 187, 171, 214,
                231, 133, 251, 214, 245, 234, 68, 21, 160, 211, 198, 88, 241, 77, 243, 37,
                105, 16, 49, 154, 94, 242, 67, 144, 60, 138, 38, 197, 12, 201, 15, 246,
                123, 76, 207, 106, 78, 51, 175, 35, 185, 128, 128, 128, 128, 128, 128, 128,
                128
            ],
            vector[
                248, 81, 160, 172, 26, 35, 217, 176, 234, 101, 190, 221, 255, 67, 114, 107,
                168, 102, 118, 121, 63, 111, 118, 29, 31, 48, 225, 16, 111, 77, 187, 58,
                25, 197, 215, 160, 17, 244, 165, 84, 119, 231, 46, 243, 119, 20, 35, 212,
                1, 105, 160, 75, 184, 202, 167, 107, 174, 72, 164, 213, 132, 37, 49, 25,
                16, 188, 151, 82, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
                128, 128, 128, 128
            ],
            vector[
                248, 81, 128, 128, 128, 128, 128, 128, 128, 128, 160, 123, 18, 41, 246, 47,
                194, 155, 129, 196, 106, 49, 1, 182, 40, 74, 255, 19, 152, 25, 234, 161,
                148, 212, 188, 49, 107, 241, 205, 171, 190, 77, 15, 160, 169, 101, 171,
                123, 24, 39, 165, 91, 87, 208, 181, 64, 58, 76, 52, 30, 34, 171, 21, 183,
                12, 65, 35, 243, 142, 39, 199, 104, 14, 62, 21, 171, 128, 128, 128, 128,
                128, 128, 128
            ],
            vector[
                249, 1, 209, 160, 208, 34, 141, 104, 230, 210, 186, 149, 58, 141, 67, 148,
                70, 245, 148, 132, 209, 144, 208, 104, 148, 104, 72, 144, 45, 122, 218,
                234, 10, 21, 83, 136, 160, 35, 187, 37, 133, 28, 55, 198, 143, 69, 39, 88,
                146, 31, 177, 172, 13, 48, 61, 89, 189, 143, 64, 49, 103, 140, 90, 135,
                252, 69, 204, 128, 14, 160, 145, 188, 254, 168, 201, 146, 201, 175, 148,
                52, 219, 231, 61, 148, 78, 183, 26, 144, 59, 206, 62, 159, 107, 116, 119,
                228, 115, 132, 17, 200, 178, 58, 160, 210, 233, 135, 118, 233, 32, 21, 154,
                45, 7, 24, 209, 55, 109, 227, 187, 241, 55, 243, 67, 240, 87, 145, 32, 92,
                223, 103, 108, 68, 101, 155, 243, 160, 61, 82, 6, 174, 70, 129, 180, 201,
                99, 142, 185, 73, 12, 22, 93, 81, 150, 146, 216, 55, 212, 173, 188, 111,
                53, 145, 230, 227, 47, 216, 91, 200, 160, 108, 21, 92, 184, 199, 193, 148,
                121, 245, 43, 209, 250, 176, 132, 232, 79, 139, 190, 0, 115, 90, 233, 2,
                142, 30, 40, 6, 8, 169, 149, 17, 234, 160, 9, 59, 72, 191, 120, 219, 216,
                183, 243, 136, 144, 166, 90, 49, 189, 109, 169, 218, 64, 39, 15, 0, 179,
                150, 253, 226, 89, 30, 125, 226, 202, 160, 160, 167, 133, 61, 31, 93, 11,
                238, 74, 187, 177, 4, 216, 73, 113, 68, 126, 12, 211, 39, 83, 145, 166,
                119, 105, 233, 107, 126, 177, 239, 164, 126, 224, 160, 96, 208, 48, 12, 9,
                51, 80, 27, 204, 85, 80, 69, 124, 162, 136, 88, 115, 19, 48, 40, 76, 190,
                72, 107, 207, 89, 196, 111, 165, 159, 64, 227, 160, 241, 200, 217, 16, 11,
                171, 139, 213, 6, 1, 66, 105, 130, 243, 184, 194, 33, 183, 205, 236, 150,
                177, 111, 118, 234, 155, 113, 133, 241, 80, 128, 1, 160, 90, 103, 199, 67,
                161, 69, 129, 135, 255, 94, 26, 202, 70, 93, 10, 57, 249, 100, 29, 254, 35,
                214, 49, 246, 188, 16, 195, 70, 41, 45, 130, 128, 160, 24, 203, 187, 198,
                222, 237, 154, 62, 80, 208, 121, 120, 81, 160, 73, 176, 174, 87, 89, 107,
                133, 224, 86, 50, 235, 138, 204, 12, 34, 167, 95, 183, 160, 51, 178, 164,
                139, 126, 5, 65, 186, 172, 141, 2, 153, 11, 225, 222, 109, 233, 52, 242,
                189, 214, 204, 240, 17, 199, 50, 176, 65, 155, 250, 7, 108, 160, 207, 30,
                34, 104, 105, 140, 20, 12, 117, 109, 172, 44, 153, 176, 35, 168, 201, 173,
                159, 253, 34, 162, 76, 155, 65, 144, 14, 18, 68, 70, 153, 176, 128, 128,
                128
            ],
            vector[
                249, 2, 244, 32, 185, 2, 240, 2, 249, 2, 236, 1, 131, 253, 158, 179, 185,
                1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 1, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 32, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 4, 0, 0, 0, 0, 0, 16, 249, 1, 225, 249, 1, 222, 148, 196, 174, 84, 163,
                211, 113, 170, 176, 116, 197, 88, 77, 145, 72, 125, 30, 123, 174, 26, 135,
                248, 132, 160, 98, 83, 196, 35, 154, 35, 89, 48, 196, 89, 122, 64, 118,
                204, 131, 81, 54, 42, 42, 129, 7, 164, 172, 222, 181, 226, 247, 174, 175,
                184, 126, 73, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226, 121, 78, 30,
                247, 212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193, 57, 241, 12,
                160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 38, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 185, 1, 64, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226,
                121, 78, 30, 247, 212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193,
                57, 241, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226, 121, 78, 30, 247,
                212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193, 57, 241, 12, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 1, 110, 111, 116, 104, 105, 110, 103, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 224, 182, 179, 167,
                100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 25, 158, 227, 137, 157, 182, 50, 216, 20,
                107, 43, 232, 197, 51, 91, 237, 219, 122, 106, 238, 7, 140, 186, 109, 186,
                156, 81, 40, 83, 68, 150, 240, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 103, 208, 100, 84
            ]
        ];
        let receipts_root =
            x"76a699bc8a8e73a1ed65dac8d7f59f69ce9f9eca45b37857dfdbdfd47cb03bbc";
        // // Message
        let msg_id = x"0000000000000000000000000000000000000000000000000000000000000026";
        let source_chain_id = 1;
        let source_hn_address =
            to_address(
                x"000000000000000000000000c4ae54a3d371aab074c5584d91487d1e7bae1a87"
            );
        let destination_chain_id = 6;
        let destination_hn_address =
            to_address(
                x"e15636c4d459d01c7a7c081276448b7d9fd294e01528b38c7194bf537b648f2a"
            );

        // this is the orgibal hash --------------------------------------
        let log_hash =
            x"e3e3fdfa3b4b43c3d688b29a6e4175b99eee00fed44b381e6d7772a8145ef907";

        let log_index = 0;

        let (extracted_log, _loh_hash) =
            process_data_optimistic_or_safe(
                test_account,
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
                msg_id,
                source_chain_id,
                source_hn_address,
                destination_chain_id,
                destination_hn_address,
                log_hash,
                log_index,
                2,
                23
            );
        // let extracted_log = option::extract(&mut extracted_log);

        let topics = get_topics(&extracted_log);
        let _source_token_bridge_address_extracted = *vector::borrow(topics, 1);

        let message_data_extracted = get_data(&extracted_log);

        let _payload_extracted = vector::slice(message_data_extracted, 160, 192);
        let _amount_extracted =
            bytes_to_u64(vector::slice(message_data_extracted, 192, 224));
        let _fee_extracted = bytes_to_u64(
            vector::slice(message_data_extracted, 224, 256)
        );
        let _receiverAddr_extracted = vector::slice(message_data_extracted, 256, 288);
        // coin::deposit(signer::address_of(test_account), coins_minted)
    }

    #[test(test_account = @0xdead, user = @0x1)]
    #[expected_failure]
    fun test_process_safe_EINVALID_VERIFICATION_METHOD(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741802303);
        test_initialize_light_client_store(test_account, user);
        let recent_block_slot = 7164745;
        let recent_block_proposer_index = 352;
        let recent_block_parent_root =
            x"bb6bc8c5a790995e4cf7a9d6a2de2eaf3352ebce2ecf4ec0be7f4659094338ca";
        let recent_block_state_root =
            x"0301f12622a0eaaf74285df33e5abee266eee229c3d8cae2acd491929767f727";
        let recent_block_body_root =
            x"6e9b3403aa8101e68d95967702a68740677f70e798a01598502611f16ba0cb16";
        // // sync_aggregate: SyncAggregate,
        let recent_block_sync_committee_bits = vector[
            true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, false, true, false, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, true, false, false, true, true, false, true, true, false, false, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, false, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, true, false, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true
        ];
        let recent_block_sync_committee_signature =
            x"8834db2281a84c40e3262e5d5ec84bd7879756c47febffdaec1e96710545d32a6194aef76251f78c7f15e7a96ae2bcc406950fc0be85ff5988f7139934231eafc8f7fb441284af82cebd1d5ded782e91ad03a031ba072ca413f6af39530e51a4";
        let recent_block_signature_slot = 7164746;

        let is_historical = false;
        let block_roots_index = 570176;
        let block_root_proof = vector[
            x"fc69a50155db01a864c24aa5d02d2309516743a0b4d5cd9e0940829fe2fb8be8", x"718f315585f5ae27864847d830d902a9932e748ff397266de4c5d5e8bed77566", x"705cf554f57c2061e6a099059414d1c877ade7e38222c9cbba1c39b9eb50790c", x"d4c2ed65b44597a2eb9588abce091ec9ec248819702668b741e9de840f928cd1", x"5630f835bffba993832554159f2e251f9b2a9e296c19991e53f4c1a1c9c2ae3b", x"78031f04a16c707e4ed78603a4cd2e186279016ece68f05a612a0760d64c9c6b", x"17d8c83512f209252f78c2e0cb29974d1d96328a19de4cc87f97b1072a33f1c7", x"6438e60ddccdffa1c28f60013807807c76a5532097971e361c56e1c20d6d6224", x"cf5732ca1687dc30070ae61928cee9de84099c6eb3b20f67bc084b464fad0871", x"58db38f4e4cae211b556bbc245aba54dd0f4b004637964b4469f3d2f2f42ddcb", x"a97a9fcd891fa712bf94382f9d9f0b82668dfcdaa7dcd403602166a705f587f1", x"0dab1b9afa9dceb7f17e3aa10b58b0d7fe771e89962ef83dac5c0b9c3cc2790b", x"e972d01afa37f5125acb04a97d49174a9edfbaa62a44db351a4081e848b65031", x"48b67f243f3dd4a67cdd3942474c5d757b029787a45bc522bca44d612e9639ca", x"a2372b9f49556b17e29377dccef2e4ce47895f895eb68bbf45c51b0492be2b2c", x"643e717d6e284488d717313f1a82b07310243638383fbd5e7fa0f2e5841cdce2", x"6ad55d8912fb3c6ac2521909cc03cb92aac1921da2ae2a3ef7af6b7e151bd435", x"de03995d4b3ae68f2ecd479e7a3924cb84f49b0bdfe0350a9806f16b0aa26212", x"b83fd15f77764c922f7289fc7f438eb58651ef588f2dac66333f3d6632edc154"
        ];
        // // Historical_Roots
        let historical_block_root_proof = vector::empty<vector<u8>>();
        let historical_block_summary_root = vector::empty<u8>();
        let historical_block_summary_root_proof = vector::empty<vector<u8>>();
        let historical_block_summary_root_gindex = 0;
        let slot = 7164736;
        let proposer_index = 691;
        let parent_root =
            x"bff6c5746e7e344b95145dbe4284be6d859de9e8d5c0c23808cc9b78c25f676a";
        let state_root =
            x"0b7fd9ff4eeff218d0d1601895b912707357c2cffba872e39e4c040dc6d3f6bb";
        let body_root =
            x"63fe367a5f8a544dbc22abe0f57a4000a4fa3a4a33b3316cfa3149c862e46244";
        let tx_index = 156;
        // // Receipt Proof

        let receipts_root_proof = vector[
            x"e94cd77a1f7bf45180a10ef7676a841bbb93862b82d4009c54a0b1517aeac81b",
            x"d77bf349e04e50e42cba9cdafab9994d91a68686f38286689075e03fe838e836",
            x"f642678c261374938898afad5363ed42ab31201cbc8a097e0b67d48096241fb6",
            x"edf64f154d4c05df768a48ed5b88970e6b6bd16aa592a47b714245316a8617c3",
            x"536d98837f2dd165a55d5eeae91485954472d56f246df256bf3cae19352a123c",
            x"a791039e050c084d8ae3b4031ff498fda911cd17d12e722f7b996156ad2cfc18",
            x"a09c812529fdd11d19edd02b480b8a265c15e70d7b63a2f742c2296dfc010418",
            x"6dd3b9955d892d92338b19976fd07084bfe88a76c3063482b7f30ee60feb2a58",
            x"a80abcd1a05d9d537d6206e92bf923776a46c772e333a4b749207f26a3b5b594",
            x"0000000000000000000000000000000000000000000000000000000000000000",
            x"f5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b",
            x"96f3e0a02964899855f4c726f50fd28fba48bb2cdd800463790de4ae751de557"
        ];
        let receipts_root_gindex = 6435;
        let receipt_proof = vector[
            vector[
                249, 1, 49, 160, 22, 171, 160, 72, 133, 186, 53, 232, 252, 87, 126, 128,
                182, 239, 162, 182, 33, 12, 19, 38, 88, 88, 70, 197, 215, 203, 134, 212,
                155, 241, 233, 225, 160, 40, 145, 45, 147, 213, 12, 141, 42, 129, 75, 159,
                21, 131, 113, 133, 222, 185, 99, 151, 175, 95, 50, 13, 158, 118, 44, 3, 8,
                161, 212, 232, 172, 160, 227, 242, 172, 202, 110, 83, 226, 128, 200, 239,
                127, 246, 2, 101, 143, 74, 2, 186, 178, 225, 230, 237, 68, 232, 164, 2, 60,
                50, 45, 187, 179, 36, 160, 87, 150, 219, 170, 201, 196, 100, 196, 43, 125,
                152, 174, 186, 93, 143, 122, 198, 123, 116, 42, 124, 156, 202, 114, 144,
                219, 33, 130, 10, 209, 130, 168, 160, 172, 7, 1, 115, 155, 96, 77, 231, 37,
                1, 148, 193, 166, 108, 215, 68, 201, 244, 97, 71, 94, 0, 14, 223, 16, 126,
                26, 170, 151, 96, 127, 12, 160, 47, 70, 86, 128, 245, 53, 191, 40, 4, 194,
                172, 19, 120, 25, 98, 134, 29, 17, 216, 114, 219, 195, 64, 249, 134, 217,
                21, 62, 48, 107, 12, 230, 160, 215, 132, 186, 102, 102, 40, 185, 175, 91,
                16, 12, 178, 63, 188, 10, 200, 247, 240, 120, 137, 80, 204, 28, 185, 132,
                172, 24, 255, 97, 77, 157, 154, 160, 88, 53, 62, 138, 231, 152, 139, 35,
                53, 41, 227, 110, 35, 41, 181, 225, 131, 165, 40, 127, 138, 187, 171, 214,
                231, 133, 251, 214, 245, 234, 68, 21, 160, 211, 198, 88, 241, 77, 243, 37,
                105, 16, 49, 154, 94, 242, 67, 144, 60, 138, 38, 197, 12, 201, 15, 246,
                123, 76, 207, 106, 78, 51, 175, 35, 185, 128, 128, 128, 128, 128, 128, 128,
                128
            ],
            vector[
                248, 81, 160, 172, 26, 35, 217, 176, 234, 101, 190, 221, 255, 67, 114, 107,
                168, 102, 118, 121, 63, 111, 118, 29, 31, 48, 225, 16, 111, 77, 187, 58,
                25, 197, 215, 160, 17, 244, 165, 84, 119, 231, 46, 243, 119, 20, 35, 212,
                1, 105, 160, 75, 184, 202, 167, 107, 174, 72, 164, 213, 132, 37, 49, 25,
                16, 188, 151, 82, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
                128, 128, 128, 128
            ],
            vector[
                248, 81, 128, 128, 128, 128, 128, 128, 128, 128, 160, 123, 18, 41, 246, 47,
                194, 155, 129, 196, 106, 49, 1, 182, 40, 74, 255, 19, 152, 25, 234, 161,
                148, 212, 188, 49, 107, 241, 205, 171, 190, 77, 15, 160, 169, 101, 171,
                123, 24, 39, 165, 91, 87, 208, 181, 64, 58, 76, 52, 30, 34, 171, 21, 183,
                12, 65, 35, 243, 142, 39, 199, 104, 14, 62, 21, 171, 128, 128, 128, 128,
                128, 128, 128
            ],
            vector[
                249, 1, 209, 160, 208, 34, 141, 104, 230, 210, 186, 149, 58, 141, 67, 148,
                70, 245, 148, 132, 209, 144, 208, 104, 148, 104, 72, 144, 45, 122, 218,
                234, 10, 21, 83, 136, 160, 35, 187, 37, 133, 28, 55, 198, 143, 69, 39, 88,
                146, 31, 177, 172, 13, 48, 61, 89, 189, 143, 64, 49, 103, 140, 90, 135,
                252, 69, 204, 128, 14, 160, 145, 188, 254, 168, 201, 146, 201, 175, 148,
                52, 219, 231, 61, 148, 78, 183, 26, 144, 59, 206, 62, 159, 107, 116, 119,
                228, 115, 132, 17, 200, 178, 58, 160, 210, 233, 135, 118, 233, 32, 21, 154,
                45, 7, 24, 209, 55, 109, 227, 187, 241, 55, 243, 67, 240, 87, 145, 32, 92,
                223, 103, 108, 68, 101, 155, 243, 160, 61, 82, 6, 174, 70, 129, 180, 201,
                99, 142, 185, 73, 12, 22, 93, 81, 150, 146, 216, 55, 212, 173, 188, 111,
                53, 145, 230, 227, 47, 216, 91, 200, 160, 108, 21, 92, 184, 199, 193, 148,
                121, 245, 43, 209, 250, 176, 132, 232, 79, 139, 190, 0, 115, 90, 233, 2,
                142, 30, 40, 6, 8, 169, 149, 17, 234, 160, 9, 59, 72, 191, 120, 219, 216,
                183, 243, 136, 144, 166, 90, 49, 189, 109, 169, 218, 64, 39, 15, 0, 179,
                150, 253, 226, 89, 30, 125, 226, 202, 160, 160, 167, 133, 61, 31, 93, 11,
                238, 74, 187, 177, 4, 216, 73, 113, 68, 126, 12, 211, 39, 83, 145, 166,
                119, 105, 233, 107, 126, 177, 239, 164, 126, 224, 160, 96, 208, 48, 12, 9,
                51, 80, 27, 204, 85, 80, 69, 124, 162, 136, 88, 115, 19, 48, 40, 76, 190,
                72, 107, 207, 89, 196, 111, 165, 159, 64, 227, 160, 241, 200, 217, 16, 11,
                171, 139, 213, 6, 1, 66, 105, 130, 243, 184, 194, 33, 183, 205, 236, 150,
                177, 111, 118, 234, 155, 113, 133, 241, 80, 128, 1, 160, 90, 103, 199, 67,
                161, 69, 129, 135, 255, 94, 26, 202, 70, 93, 10, 57, 249, 100, 29, 254, 35,
                214, 49, 246, 188, 16, 195, 70, 41, 45, 130, 128, 160, 24, 203, 187, 198,
                222, 237, 154, 62, 80, 208, 121, 120, 81, 160, 73, 176, 174, 87, 89, 107,
                133, 224, 86, 50, 235, 138, 204, 12, 34, 167, 95, 183, 160, 51, 178, 164,
                139, 126, 5, 65, 186, 172, 141, 2, 153, 11, 225, 222, 109, 233, 52, 242,
                189, 214, 204, 240, 17, 199, 50, 176, 65, 155, 250, 7, 108, 160, 207, 30,
                34, 104, 105, 140, 20, 12, 117, 109, 172, 44, 153, 176, 35, 168, 201, 173,
                159, 253, 34, 162, 76, 155, 65, 144, 14, 18, 68, 70, 153, 176, 128, 128,
                128
            ],
            vector[
                249, 2, 244, 32, 185, 2, 240, 2, 249, 2, 236, 1, 131, 253, 158, 179, 185,
                1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 1, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 32, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 4, 0, 0, 0, 0, 0, 16, 249, 1, 225, 249, 1, 222, 148, 196, 174, 84, 163,
                211, 113, 170, 176, 116, 197, 88, 77, 145, 72, 125, 30, 123, 174, 26, 135,
                248, 132, 160, 98, 83, 196, 35, 154, 35, 89, 48, 196, 89, 122, 64, 118,
                204, 131, 81, 54, 42, 42, 129, 7, 164, 172, 222, 181, 226, 247, 174, 175,
                184, 126, 73, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226, 121, 78, 30,
                247, 212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193, 57, 241, 12,
                160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 38, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 185, 1, 64, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226,
                121, 78, 30, 247, 212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193,
                57, 241, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226, 121, 78, 30, 247,
                212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193, 57, 241, 12, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 1, 110, 111, 116, 104, 105, 110, 103, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 224, 182, 179, 167,
                100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 25, 158, 227, 137, 157, 182, 50, 216, 20,
                107, 43, 232, 197, 51, 91, 237, 219, 122, 106, 238, 7, 140, 186, 109, 186,
                156, 81, 40, 83, 68, 150, 240, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 103, 208, 100, 84
            ]
        ];
        let receipts_root =
            x"76a699bc8a8e73a1ed65dac8d7f59f69ce9f9eca45b37857dfdbdfd47cb03bbc";
        // // Message
        let msg_id = x"0000000000000000000000000000000000000000000000000000000000000026";
        let source_chain_id = 1;
        let source_hn_address =
            to_address(
                x"000000000000000000000000c4ae54a3d371aab074c5584d91487d1e7bae1a87"
            );
        let destination_chain_id = 6;
        let destination_hn_address =
            to_address(
                x"e15636c4d459d01c7a7c081276448b7d9fd294e01528b38c7194bf537b648f2a"
            );

        // this is the orgibal hash --------------------------------------
        let log_hash =
            x"e3e3fdfa3b4b43c3d688b29a6e4175b99eee00fed44b381e6d7772a8145ef907";

        let log_index = 0;

        let (extracted_log, _loh_hash) =
            process_data_optimistic_or_safe(
                test_account,
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
                msg_id,
                source_chain_id,
                source_hn_address,
                destination_chain_id,
                destination_hn_address,
                log_hash,
                log_index,
                1,
                23
            );
        // let extracted_log = option::extract(&mut extracted_log);

        let topics = get_topics(&extracted_log);
        let _source_token_bridge_address_extracted = *vector::borrow(topics, 1);
    }

    #[test]
    fun test_process_verify_ancestry_proof_historic_proof() {
        let is_historical = true;
        let block_roots_index = 0;
        let block_root_proof = vector[
            x"0000000000000000000000000000000000000000000000000000000000000000"
        ];
        let historical_block_root_proof = vector[
            x"1938557dbd9c06b4581d6e272c7ab9849963106cbc66996bf40589220a5ff0e4",
            x"fe1d878bc51f0ea39fdb42b9125d5677b2555bc286c664397cc2a02adee19642",
            x"624e2456d72021bfd07607d6fbe92408e450d31f21bed3cc67b42d2296d866bd",
            x"252e4609220f76818eebb5d2ca07d0c486394fdeab51e67a3f1a10bf61269da0",
            x"dd18da8240488fd266bad1708e5deee55746a43228eb74b0fba2d7ed56d2109c",
            x"38ff779f91208389aec07178740a1fcf5dd9718a6154e724a300c761b365571a",
            x"275531aa48654be14476cdc2b3c6651c80dc7856fb7d75c528008f9e70cd6909",
            x"906ff582fa4a1cb31772f868ddb1609f0c76def2e016900bfc48989ff63cb2b0",
            x"d3048a704000ee0217954d135512210388e36c7506ee72d5e9e90811a27dca59",
            x"63caac8e7f6cf19370f361f51f7905402fbdd144a10a1fb4db2aa1104bef7f4c",
            x"9d37094940d92f56b0f99de24655121fbd653b9580a77e5e1f44028821719255",
            x"50477a5f9f06856fc8d4f3c5060100b636afd6f4fdefbbc30fd77b74b0f924dd",
            x"9a4273455456f87588e4fb72a67090532508094eb34fff2946eff28efe202901"
        ];

        let historical_block_summary_root =
            x"e0d5d74ebfd37e490a588fbd62acd2f8704821ed2e290f48ee1257f2b8a4022f";
        let historical_block_summary_root_proof = vector[
            x"1638c21f1f4e295befa4cbf40010ace0e879ccc7ac116a7f56fd8179aab43c42", x"9fd141c7339ea9f9963f4b77223bb2803727d3e78820da9870c0aae8319755ae", x"c4a6926df7679e94efdac22d4eddbc7745280fa68458d9e16494529501dcfba0", x"69bbf07eadfd7763a7d66ba0d61ce9c142a4bf61a3c5a74c7cc0366780780249", x"d2c5c5010a2a6daeee009d3a3fcd400b754726a1ae7457a0ff8c71dd177ddbb2", x"536d98837f2dd165a55d5eeae91485954472d56f246df256bf3cae19352a123c", x"9efde052aa15429fae05bad4d0b1d7c64da64d03d7a1854a588c2cb8430c0d30", x"2d5250ee9169df627582e64b0d47cd57cd3792377bc717f64725df975bd37a99", x"033afcdc60251d3bdbc48a0c46f668838859195f48c56a28383aed4603bfd56b", x"26846476fd5fc54a5d43385167c95144f2643f533cc85bb9d16b782f8d7db193", x"30d53f9bc8af1f2a5872c0b3bf6b5b56b4b757f8bea88792f3cf155c9d8f50c3", x"ffff0ad7e659772f9534c195c815efc4014ef1e1daed4404c06385d11192e92b", x"6cf04127db05441cd833107a52be852868890e4317e6a02ab47683aa75964220", x"b7d05f875f140027ef5118a2247bbb84ce8f2f0f1123623085daf7960c329f5f", x"df6af5f5bbdb6be9ef8aa618e4bf8073960867171e29676f8b284dea6a08a85e", x"b58d900f5e182e3c50ef74969ea16c7726c549757cc23523c369587da7293784", x"d49a7502ffcfb0340b1d7885688500ca308161a7f96b62df9d083b71fcc8f2bb", x"8fe6b1689256c0d385f42f5bbe2027a22c1996e110ba97c171d3e5948de92beb", x"8d0d63c39ebade8509e0ae3c9c3876fb5fa112be18f905ecacfecb92057603ab", x"95eec8b2e541cad4e91de38385f2e046619f54496c2382cb6cacd5b98c26f5a4", x"f893e908917775b62bff23294dbbe3a1cd8e6cc1c35b4801887b646a6f81f17f", x"cddba7b592e3133393c16194fac7431abf2f5485ed711db282183c819e08ebaa", x"8a8d7fe3af8caa085a7639a832001457dfb9128a8061142ad0335629ff23ff9c", x"feb3c337d7a51a6fbf00b9e34c52e1c9195c969bd4e7a0bfd51d5c5bed9c1167", x"e71f0aa83cc32edfbefa9f4d3e0174ca85182eec9f3a09f6a6c0df6377a510d7", x"c902000000000000000000000000000000000000000000000000000000000000", x"b201000000000000000000000000000000000000000000000000000000000000", x"c974d094661be98396d45a319893ac65f85da93ada23a699e5987111ac3baaf5", x"93fd38e30a2cffb7f217c9ae6f138fcc5cf7edd47624020331f0389ab27c006a", x"a9963f4d86f184662015148e638c0fffad105cdf0aac80fddb1fce6073c33fc1", x"e734e5bb076340bcaf47bf23e4e8dc2333201f51de93b4b36de1a9e00f021375", x"b6fe319df634d358075169e51cb0a7fc6ed33b321aa5f9563df8218a243d46e9"
        ];

        let historical_block_summary_root_gindex = 6106908044;

        // Recent Block Header

        let recent_block_slot = 7667106;
        let recent_block_proposer_index = 587;
        let recent_block_parent_root =
            x"5673b4f1920d49d81b63dafa9a9f334843ba7d5a68249ff4be54c9d4b7b0c327";
        let recent_block_state_root =
            x"a91cd0673779759a75da32ede5fb3142745e5c0990f6c61e39b882af19bb4e01";
        let recent_block_body_root =
            x"588dbee284746c2ad2a4e22d8dc5795967b5aaa4082ad8c0dc525b046648d65b";
        // Target Block Data
        let slot = 7641781;
        let proposer_index = 1413;
        let parent_root =
            x"1938557dbd9c06b4581d6e272c7ab9849963106cbc66996bf40589220a5ff0e4";
        let state_root =
            x"34190f061b9a938da29eeea14a4e94060eeb7d42866bc2339c4c12206b72ac54";
        let body_root =
            x"b7ed7f13e52ccf78470252425e538318d3830cf142fec253abebe6c0ad9ac385";

        let recent_block_header_build =
            &test_construct_beacon_block_header(
                recent_block_slot,
                recent_block_proposer_index,
                recent_block_parent_root,
                recent_block_state_root,
                recent_block_body_root
            );

        let target_block_header_build =
            &test_construct_beacon_block_header(
                slot,
                proposer_index,
                parent_root,
                state_root,
                body_root
            );
        let hash_tree_root_target_block_header =
            test_hash_tree_root_beacon_block_header(target_block_header_build);
        test_verify_ancestry_proof(
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
    }

    #[test(test_account = @0xdead, user = @0x1, deposit_acc = @0x123456)]
    fun test_process_data_finality(
        test_account: &signer, user: &signer, deposit_acc: &signer
    ) {
        change_feature_flags_for_testing(user, vector[89], vector[0]);
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1747809527);
        test_initialize_light_client_store_finality(test_account, user);
        let recent_block_slot = 7672672;
        let recent_block_proposer_index = 1651;
        let recent_block_parent_root =
            x"bd6033d2d04bd5421840b3f18dab21eedc9dba5b6b9d32cc4c0019e6d4b1608c";
        let recent_block_state_root =
            x"44773f13a9a3d869770a40b0fdc8aa2786488dbf4451d7510c4712c5dd58819b";
        let recent_block_body_root =
            x"ef11cf718a114fdc85170d9e424aac2651f8e68f8295968892fcd0370d401149";
        // // sync_aggregate: SyncAggregate,
        let recent_block_slot_finalized = 7672608;
        let recent_block_proposer_index_finalized = 939;
        let recent_block_parent_root_finalized =
            x"e37c213ca6c18190209553697991ad086071564f688ef2fd33cf3024cd3fd16d";
        let recent_block_state_root_finalized =
            x"071f97e24121d59109993a56573d64215653a7bf21e8992f7bdcf2c78900b11b";
        let recent_block_body_root_finalized =
            x"885cf76203fe5862d4bc2035b51a91e236c624e137d81333fd1ef64cbfc086ee";
        let recent_block_finality_branch = vector[
            x"99a8030000000000000000000000000000000000000000000000000000000000",
            x"5491da9fcb3bea34b96388cdfd7795c131f096e357b20296cbef9ab23097e006",
            x"f8654b4beb097570119ccb05060453ad9d8c162f23101d7e29bfe6f4430d6c40",
            x"e7b4c92d0240c7d844df7872fbb785834cfa6193438fe5505a7dad970316a38d",
            x"44016922c08843bb012f3f233197f5ff401e76dc1060051463ea04c383e7806c",
            x"78940a9077804aef0ca18644fd076761353401a3e7606d38fe6d1a7ce2a900bb",
            x"b6fe319df634d358075169e51cb0a7fc6ed33b321aa5f9563df8218a243d46e9"
        ];
        let recent_block_sync_committee_bits = vector[
            true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, false, true, false, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, true, false, true, true, true, true, true, true, true, true, true, true
        ];
        let recent_block_sync_committee_signature =
            x"8f080440deb276f6ae43ca0b51093415a12e8f5c17a15483f7ac8d3b253586fc0e4488f2a73a2a50f6dc83f18faf33330a08caa64b1453aa733cc66ab40e37b0205edb75c7e0d203df255851cb77272d65e27383c0c4537fbfc71f546053e301";
        let recent_block_signature_slot = 7672673;

        let is_historical = false;
        let block_roots_index = 570141;
        let block_root_proof = vector[
            x"f9079cfefb25820302fdfd76ab324ed92f251f0638c61a9bb88b9794fae5f8b6", x"7bda62ae8970225d6747c2ada591dbb9a46601f4066a121f897c1de62b0854bd", x"c083f10ab9d158a40748926a7081bff2b574683aeacaf0f0333d7336cf53b378", x"606694f926065bca03659c8fab347e4afb8f4ce1d5a837e69c69236fa9852b50", x"0a4d1ca53bada70e1c5c74e18a00a4a439e3c1cf01dfb60775feb389ffdb66fc", x"e1931e68e0a5c67f8df883ae89668c8d6e1677bade6d429342effba027e95671", x"4e0e805e033d6daa94e279cb987d9f36b1376efe699239d1bd11c8006cef5bda", x"6b2606ce08bb2e6af622d664ce6fba6a2ea52e1fd6f9ac02b88dbe1f410e25e2", x"e0ea99822a8f8069b841ae60d03ee390c4d492681a4a1e46b66b880b0d37d4fa", x"5b6b7f1d7c3618901c5de35e06a5ef926d9fb76d4966aea1b95f89256742d220", x"3e54e57ee291f5a668f547583adc3dda822815e1786ed6606d6ec60b40af8f55", x"b278ecb5628ce522cc5ba656862d0e066e68cbc7c73dabc15f24eb16edf30762", x"363f55c1ebf944ac8c2018b1c5972ac5eb6c6ae25072313464106f8f83996e83", x"b7f154f7f2d8ee811af965204359df42f2ee73ba997a0c39223fa83967a73a99", x"2d2e65fb4851f9f6af177208cf44c6c4ffce0932c6c1b1a32f0fe7177e9e153e", x"3e36c0a4d0e67a37a95c0e88b9894a2b4826faeecabfa1673257528db4983a6f", x"000a6f29b57e0c43f3d02598dc77707633349dcb2cb3cf6ad05127ca603097af", x"9705726aff2de6ca0931ec5045dea323044436e3e7f53d558c47bbb63ca16e56", x"b6fe319df634d358075169e51cb0a7fc6ed33b321aa5f9563df8218a243d46e9"
        ];
        // // Historical_Roots
        let historical_block_root_proof = vector::empty<vector<u8>>();
        let historical_block_summary_root = vector::empty<u8>();
        let historical_block_summary_root_proof = vector::empty<vector<u8>>();
        let historical_block_summary_root_gindex = 0;
        let slot = 7672605;
        let proposer_index = 114;
        let parent_root =
            x"f9079cfefb25820302fdfd76ab324ed92f251f0638c61a9bb88b9794fae5f8b6";
        let state_root =
            x"2781fc0cc2e49ad06dddc66e59ea5d2e5928bf0892ef2397be0764679beb0476";
        let body_root =
            x"b8693ca9205e2d7d75d17212d81d3449ec3e151b2f467535fcabef03041e033c";
        let tx_index = 79;
        // // Receipt Proof

        let receipts_root_proof = vector[
            x"02a74fec965ffed4fc064f4b7ad187875e54bb856ce8d4125648d624061f3637",
            x"bc44f0c46a085e8f66780be4032ccd9add8e039c86adc491cac8d47276584a71",
            x"bd5d73b39d15696ba26fb91c6d9ec6dcb0b2a0e432ea6088e2b43f62e987b956",
            x"4305516291991da217b28050c1f06c0d4f92e49b5fd768e32b0b0c27861c249a",
            x"536d98837f2dd165a55d5eeae91485954472d56f246df256bf3cae19352a123c",
            x"739539ca0690aa661133815820b1d702075d251f1563ef5ede0d5e09bf3355c4",
            x"b46f0c01805fe212e15907981b757e6c496b0cb06664224655613dcec82505bb",
            x"6dd3b9955d892d92338b19976fd07084bfe88a76c3063482b7f30ee60feb2a58",
            x"bb9dd2cf04c46691ff67cf626c56a75437ec36c2b16e27709b93c6ed0bfa6bd5",
            x"0000000000000000000000000000000000000000000000000000000000000000",
            x"f5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b",
            x"20fdeff11f93cf50d353cba40f66b9f81c8a4beb634a366c18c9b7ebe618886b"
        ];
        let receipts_root_gindex = 6435;
        let receipt_proof = vector[
            x"f90131a000b2aa0c52d651d06c63c5dd48bfd6a80a62108b42144e8bbc60fcb6d1052de6a0809991786f00a2a9394d70f552b85f31fa431b149c33d644f0d42a2e16399395a0db8c0bfb1bc7979f04a6fe69a141f370581c0a4c7f59dbe91945c24492ca7461a0f58394412825d73d8653d856a34e6ae9d59c285d18a85c98f63300a38684ad26a0492224985170120911392f52be2c227168620a12c7735355438b72e7e236fc0ea0be222cdc78feadd039325703ba4ed26472eed20fbf5340605c63fe8c041b8542a0b4382816a7ae1eb3e3c1cc8dc2bba29787679205b2a5f049727b5eff4c4bb52aa0fc12605f5c5ce69bc4c02bbf4c4471c0c99919eac448bdd9d1e015c82eeeeec0a0f95c3d39f9b0d73ed5c0c7838c067bb3aa5ad3489bec3a42c2cadb03d0e2e7808080808080808080",
            x"f90211a04dbaeaebaa2cc1424c35665a29a2a72d65467d169e0f14003684b38f15245826a03eded2f239b263334bc84311a2614d677678c048aa634158ea5622cee2a1b13aa078b6cdeacebbda348dcc606e8e89cdfc972e12b10535e679ad3985a7b3e72381a0faa1a4b90150a1b20f91be70bd439fd636edf3ba4e696eda8e1623324fe0dde7a00905d69c0b2a3be481d84a63e71a82abae2ecfc105e0badf1dc55f36cee9201ea00be4182d686e16e967b84b7a6ca8686e9b17c0054d386f507c7b8133befc594ea082075c08cb5080d5860dc0cefbf1cbc9395c8459d8b753feaebc50a67a52b526a01b502dd32eb30533e436cc6d48cb8d25f83237d123a83058d867c560d9b929e8a0e8841c6632f88e88460291e130b00ddea2201c7924b7411687ef91acb2e15591a0d1f6022dcb74c5f10a2db7b6036a89ac762000a43b5615949ebbbfe567aaf06aa0c34f229fc9db0d34241624e90be8a66c049127feb9bdbe973fa10af87c5a29bda011e5eeed322b6ccd99fbfbac3f41b96c86f5fb55a278bb703633a7c1065b6287a0a0ef34da5cc90f10d969b18adc240b2e7d70e5582ebba429f412855c93b2d747a0ee612cbd04c36b2af4d710ec7718d116b6202f2f4a0e0c3ab9238abdcd1735f8a06bb44da855d9aedfc7e947009a4afbd55f6992398a919e6bcb08000c241a3977a0f452cbf4b15c617e061ea352eba40540c0a401e7d0f6caf4633af715aec7d56680",
            x"f9038a20b9038602f9038201838e1e72b9010000000000000000000000000800000000000000000000000000000000000000000000000000000008000000000000000000000000000600000000000000000004000000000000000000002000000000010000000400000000000000008000000000000000020010000000000000000000000000000000000000000000000001000040000400000000000000040000000000001401000001000000000000000000000020000000000000000004000000000000000000000000000000080000000000000000000000000002000000000000000000000000000000001000000000040000080008010000000000000000000000000000000000400004000000000000f90277f87a94fff9976782d46cc05630d1f6ebab18b2324d6b14f842a0e1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109ca00000000000000000000000004a2a41a494b0a5b8e17e1584ebcac1700dbee7eca00000000000000000000000000000000000000000000000000000000001607a60f838944a2a41a494b0a5b8e17e1584ebcac1700dbee7ece1a05d423e9915df61bfb81a1b2d43e9d5ef39d97561cea6bc88b105528209dce26680f901be942bdf8988f6c030fa592a09f94559ee65e0eb3825f884a06253c4239a235930c4597a4076cc8351362a2a8107a4acdeb5e2f7aeafb87e49a000000000000000000000000057a06e167b8222add7e4804f425c42a2182d0613a00000000000000000000000000000000000000000000000000000000000005271a00000000000000000000000000000000000000000000000000000000000000006b90120000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000612dce22cba37fd7fabf11216e8a79e1e4a00e9000000000000000000000000fff9976782d46cc05630d1f6ebab18b2324d6b140000000000000000000000000000000000000000000000000000000000aa36a700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001607a60000000000000000000000000000000000000000000000000000000000002a6e848466f4b064ca1231504cec481aff9b20704cb521a0ad706a4c42f8fd98d40ed"
        ];
        let receipts_root =
            x"0383b98de9ed3757cd32de9f3da29c148ea7d969d4494c62b9ab19860ca74f5b";
        // // Message
        let msg_id = x"0000000000000000000000000000000000000000000000000000000000005271";
        let source_chain_id = 11155111;
        let source_hn_address =
            to_address(
                x"0000000000000000000000002bdf8988f6c030fa592a09f94559ee65e0eb3825"
            );
        let destination_chain_id = 6;
        let destination_hn_address =
            to_address(
                x"cc5c63acf23ce5dd582e52ca58cd1694a8e1d7e10ced8e9dfd23d4ef4f611606"
            );

        let log_hash =
            x"d1e1619abaf9e5190464694dded02aaf6c1aba2f76793a26e29e00e6c2bf5eec";

        let log_index = 2;
        let (extracted_log, _loh_hash) =
            process_data_finality(
                test_account,
                recent_block_slot,
                recent_block_proposer_index,
                recent_block_parent_root,
                recent_block_state_root,
                recent_block_body_root,
                recent_block_slot_finalized,
                recent_block_proposer_index_finalized,
                recent_block_parent_root_finalized,
                recent_block_state_root_finalized,
                recent_block_body_root_finalized,
                recent_block_finality_branch,
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
                msg_id,
                source_chain_id,
                source_hn_address,
                destination_chain_id,
                destination_hn_address,
                log_hash,
                log_index,
                1
            );

        let topics = get_topics(&extracted_log);
        let _source_token_bridge_address_extracted = *vector::borrow(topics, 1);

        let message_data_extracted = get_data(&extracted_log);

        let _payload_extracted = vector::slice(message_data_extracted, 160, 192);
        let _amount_extracted =
            bytes_to_u64(vector::slice(message_data_extracted, 192, 224));
        let _fee_extracted = bytes_to_u64(
            vector::slice(message_data_extracted, 224, 256)
        );
        let _receiverAddr_extracted = vector::slice(message_data_extracted, 256, 288);
        account::create_account_for_test(signer::address_of(deposit_acc));
        coin::register<SupraCoin>(deposit_acc);

        assert!(
            coin::balance<SupraCoin>(signer::address_of(test_account)) == 980804,
            33
        );
    }


    ////hypernova core



    #[test(test_account = @0xdead, user = @0x1)]
    fun init_module_init(test_account: &signer, user: &signer) {
        account::create_account_for_test(signer::address_of(test_account));
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
        test_only_init_module(test_account);
        coin::deposit(hypernova_resource_addr, coins_minted_11);
        assert!(
            is_initializer_scratch_space(signer::address_of(test_account)),
            22
        );
    }


    #[test(test_account = @0xdead, user = @0x1)]
    fun test_update_verifier_config(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741702303);
        test_init_module_init(test_account, user);
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

        test_initialize_light_client_store_v2(
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
        test_initialize_step();
        test_initialize_step();

        add_or_update_hypernova_config(test_account, 155500, 1000, 1000, 10);


        let sync_committee_threshold = 512;
        let source_chain_id = 42;

        let source_hypernova_contract_address =
            x"000000000000000000000000111122223333444455556666777788889999aaaa";
        let epochs = vector[333575];
        let versions = vector[
            x"9000007500000000000000000000000000000000000000000000000000000000"
        ];
        let new_source_event_signature_hash =
            x"106fa013e68af8a3f7e5b55f3319def7bef2d2c9ef4dbff18afbff6dd5fe4c73";
        update_sync_committee_threshold(test_account, sync_committee_threshold);
        update_source_hypernova_contract_address_and_chain_id(
            test_account, source_hypernova_contract_address, source_chain_id
        );


        update_fork_versions(test_account, epochs, versions);



        update_source_event_signature_hash(
            test_account,
            new_source_event_signature_hash
        );

        assert!(
            get_source_event_signature_hash() == new_source_event_signature_hash, 103
        );
        assert!(get_fee_per_verification() == 19196, 103);
        assert!(get_sync_committee_threshold() == sync_committee_threshold, 104);
        assert!(get_source_chain_id() == source_chain_id, 105);
        assert!(
            get_source_hypernova_core_address()
                == pad_left(source_hypernova_contract_address, 32),
            107
        );

    }

    #[test(test_account = @0xdead, user = @0x1)]
    #[expected_failure]
    fun test_initialize_light_client_store_EINITIALIZER_NOT_FOUND(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741702303);
        test_init_module_init(test_account, user);
        let slot = 6989171;
        let proposer_index = 1447;
        let parent_root =
            x"5c09a958f5847e2ffd891db21600eba8d5bffed5bb0ade719ccd1919ab42864f";
        let state_root =
            x"e4636d9902307a5a605de694caeec9ee07606beb63c5f974e285ac5c10c8cf45";
        let body_root =
            x"8e8f126732624a4341a7fd0585bfb360055d638c632646aaaa8b57d0d90d446d";
        //SyncCommittee
        let (cureent_sync_public_keys, aggregate_public_key, current_sync_committee_branch) =

            get_sync_commitee();

        // state: Option<LightClientState>,
        let source_chain_id = 1;
        let epochs = vector[50, 100, 56832, 18446744073709551615];
        let versions = vector[
            x"9000007000000000000000000000000000000000000000000000000000000000",
            x"9000007100000000000000000000000000000000000000000000000000000000",
            x"9000007200000000000000000000000000000000000000000000000000000000",
            x"9000007300000000000000000000000000000000000000000000000000000000",
            x"9000007400000000000000000000000000000000000000000000000000000000"
        ];
        let source_supranova_core = x"669fbe5e20929ded855466564b2275c10185866e";
        let sync_committee_threshold = 400;
        update_global_time_for_test_secs(1741902303);
        test_initialize_light_client_store_v2(
            user,
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
            source_supranova_core,
            sync_committee_threshold,
            x"6253c4239a235930c4597a4076cc8351362a2a8107a4acdeb5e2f7aeafb87e49"
        );
    }

    #[test(test_account = @0xdead, user = @0x1)]
    fun test_initialize_light_client_store_invalid_proof(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741702303);

        test_init_module_init(test_account, user);
        let slot = 7163770;
        let proposer_index = 783;
        let parent_root =
            x"d299bb40f46be36b835e179a88a7a9e6bb693c83d1d76050a56ce3b8c638ed53";
        let state_root =
            x"87821c21585fa61d4b11721a799bb3387e02636ec0d54d5c00d46ecad00db821";
        let body_root =
            x"39b047fbf4367aa82e7b1b3afb0b9d0cc9e653d0269f1d1c7f5a5fb6bb918438";
        let (
            cureent_sync_public_keys, aggregate_public_key, _current_sync_committee_branch
        ) = get_sync_commitee();
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
        let current_sync_committee_branch = vector[
            x"54dff2180c9ec654c9a790adaf33027ca90a3495d0603a294074bd7417f56989",
            x"9bf7d5977e79ac96cce3ccdd429a467e323680033141b5640518f931c41dfa05",
            x"08b4fa44ec9c5582fc9382d4bb1a8d302354f7f47e006a11449fa23582cac42a",
            x"676c47e9a4379d053301dc3266bef1851f4f66dc45e8eae7ccf30adda6a66230",
            x"627a3ef270d8cce3cf8e2a1957aa6dc004a238ce9ff2e96a2dd2469abd3b7c51",
            x"b83fd15f77764c922f7289fc7f438eb58651ef588f2dac66333f3d6632edc154"
        ];
        update_global_time_for_test_secs(1741902303);
        test_initialize_light_client_store_v2(
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
        test_initialize_step();
        test_initialize_step();
        // add_or_update_hypernova_config(
        //     test_account,
        //     155500,
        //     1000,
        //     1000,
        //     10,
        // );

        test_light_client_state_not_exists(signer::address_of(test_account))
    }

    #[test(test_account = @0xdead, user = @0x1)]
    #[expected_failure]
    fun test_initialize_light_client_store_init_grt_than_2(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741702303);
        test_init_module_init(test_account, user);
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

        update_global_time_for_test_secs(1741902303);
        test_initialize_light_client_store_v2(
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
        test_initialize_step();
        test_initialize_step();
        test_initialize_step();
    }

    #[test(test_account = @0xdead, user = @0x1)]
    fun process_light_client_optimistic_update(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741702303);
        test_init_module_init(test_account, user);
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

        test_initialize_light_client_store_v2(
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
        test_initialize_step();
        test_initialize_step();
        test_initializer_scratch_space_not_exists(test_account);
        // 1739871702
        let opt = get_optimistic_update_data(false);
        test_process_light_client_optimistic_update(&mut opt);
    }

    #[test(test_account = @0xdead, user = @0x1)]
    #[expected_failure]
    fun test_process_light_client_optimistic_update_EINVALID_SIGNATURE(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741702303);
        test_init_module_init(test_account, user);
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

        test_initialize_light_client_store_v2(
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
        test_initialize_step();
        test_initialize_step();
        test_initializer_scratch_space_not_exists(test_account);
        // 1739871702

        let opt = get_optimistic_update_data(true);
        test_process_light_client_optimistic_update(&mut opt);
    }

    #[test(test_account = @0xdead, user = @0x1)]
    #[expected_failure]
    fun test_process_light_client_optimistic_update_EINSUFFICIENT_PARTICIPATION(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741702303);
        test_init_module_init(test_account, user);
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

        let sync_committee_threshold = 500;

        test_initialize_light_client_store_v2(
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
        test_initialize_step();
        test_initialize_step();
        test_initializer_scratch_space_not_exists(test_account);

        let opt = get_optimistic_update_data(false);
        test_process_light_client_optimistic_update(&mut opt);
    }

    #[test_only]
    public fun test_get_safe_update_data(invalid: bool): (LightClientUpdate) {
        // LightClientOptimisticUpdate {
        let attested_block_header =
            test_construct_beacon_block_header(
                7163770,
                783,
                x"d299bb40f46be36b835e179a88a7a9e6bb693c83d1d76050a56ce3b8c638ed53",
                x"87821c21585fa61d4b11721a799bb3387e02636ec0d54d5c00d46ecad00db821",
                x"39b047fbf4367aa82e7b1b3afb0b9d0cc9e653d0269f1d1c7f5a5fb6bb918438"
            );
        let sync_committee_bits = vector[
            true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, false, true, false, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, true, false, false, true, true, false, true, true, false, true, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true
        ];
        let sync_aggr =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"85f005397cfedd9b7a402d7e730a3531ec2ae5d3d3606aa26433df874d7c8ccf82af17c7aad1a8626fcb5f58ec9041eb141d18630ad8d8f82207d711d97f281adf165010c207f27995efa29eb068f27e39565bdac9ee7c90e1e59bc5977f76d2"
            );
        let signature_slot = 7163771;
        let sync_aggr_invalid_sig =
            test_construct_sync_aggregate(
                sync_committee_bits,
                x"c19e936870d27832c1d5e0d34064c74198c97520fe08f820259363388cd724d45d803d43a5bb18455e617f2e5d8da2a117645065d1394219c622e224dab62da865c3ea116b4e4b11eacf7ae37b035ead1550c6c83ebbe43ba859fd146f722835"
            );

        if (invalid) {
            return  test_construct_lightclient_update(
                signature_slot,
                option::none(),
                attested_block_header,
                option::none(),
                sync_aggr_invalid_sig
            )
        };
        test_construct_lightclient_update(
            signature_slot,
            option::none(),
            attested_block_header,
            option::none(),
            sync_aggr
        )
    }
    #[test(test_account = @0xdead, user = @0x1)]
    fun test_process_light_client_safe_update_test(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741702303);
        test_init_module_init(test_account, user);
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
        let _temp_safety_level = 20;
        let temp_target_slot = 7163749;

        test_initialize_light_client_store_v2(
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
        test_initialize_step();
        test_initialize_step();
        test_initializer_scratch_space_not_exists(test_account);
        // update_global_time_for_test_secs(1741702303);
        let opt = test_get_safe_update_data(false);
        test_process_light_client_safe_update(&mut opt, temp_target_slot, 20);
    }

    #[test(test_account = @0xdead, user = @0x1)]
    fun process_light_client_finality_update(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741902303);
        test_init_module_init(test_account, user);
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

        test_initialize_light_client_store_v2(
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
        test_initialize_step();
        test_initialize_step();
        test_initializer_scratch_space_not_exists(test_account);
        // 1739871702
        // update_global_time_for_test_secs(1741902303);
        let opt = test_get_finality_update_data(false);
        test_process_light_client_finality_update(&mut opt);
    }

    #[test(test_account = @0xdead, user = @0x1)]
    #[expected_failure]
    fun test_process_light_client_finality_update_EINVALID_SIGNATURE_SLOT_ORDER(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741702303);
        test_init_module_init(test_account, user);
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

        test_initialize_light_client_store_v2(
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
        test_initialize_step();
        test_initialize_step();
        test_initializer_scratch_space_not_exists(test_account);
        // 1739871702

        let opt = get_finality_update_data_EINVALID_TIMESTAMP(false);
        test_process_light_client_finality_update(&mut opt);
    }

    #[test(test_account = @0xdead, user = @0x1)]
    fun test_initial_sync_committee_update(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741702303);
        test_initialize_light_client_store(test_account, user);
        let attested_slot = 7159872;
        let attested_header_proposer_index = 722;
        let attested_header_parent_root =
            x"c0bcfe59e7c94715a59f9a969ceaa90ee13429b768b97a01f90d8a4e4845b1a7";
        let attested_header_state_root =
            x"39a0b7af27ef0ec346f5af89b4f1c1a96b5270c0bd647094c16bec65a3db2b35";
        let attested_header_body_root =
            x"977744843e2e9cacfd937d7ae644572eedfa94e2cba158f8e2bedae0807c77e0";
        let next_sync_committee_public_keys = vector[
            x"824c8a1399ab199498f84e4baa49ff2c905cf94d6ac176e27ec5e2c7985140dbaa9cc6303d906a07ab5d8e19adf25d8a", x"b0e8428b7feac527da3276d1eb67f978f0aa279bc16c09bd15b799059b5670e05a4e79f3278a8b9a96f46f964e8e831e", x"b412ca62161a4fdaa884f52cfb65cca1e0f1fb483be26ea2f6ce82ab2e202cb6282f9f349769516d45601fb386108352", x"96aee5be8da3c75413e7ab87913a286fe497b7c86e7b943b1fd62e8ed191746bb91ee5c35e81b411e78358eea99dfba0", x"b77416ea9a6b819e63ae427057d5741788bd6301b02d180083c7aa662200f5ebed14a486efae63c3de81572fe0d92a9c", x"b3b6eccb2ec8509b4eea8392877887180841ab5794c512b2447be5df7165466d7e293696deaabf063173e5f2238ce763", x"930f71b09a368b8643583bba5181e0074b1ad465f9bc4cf37e222b940412b4e09e1f2172226fc5a6fcd6d50cbc9625e8", x"a102c2ade15ea2f2b0cbc7dbd8c1171de0c8092fc4ecef84b5fd2bae7424aea8be1629f851c75e4d1d0e96104e54bfbc", x"8368bb9b9bb2e17730c42ed1100eb870c88a8431601312aa8cb1e738cdb9ca2704dfd432cf1703c0db043259819631dc", x"961efdc21788e047fbe8dcb304fa1294fd5aaf5979561bc393bc88e323453e2d62ce3fdf6b5b6e8c8e52e522ec9e71df", x"a3d31b20198f326eac488e88fc5b9171276d4934b0bc573c8b55b2abd26380d5296d5bbea281de91c0945f34b37f42bb", x"b4cd409256819e8e4627edbba90ec40b7da17a57f95749104d90db0364f5007b1accc816f4d51a0dbe5ffbcb737cb37e", x"815f53751f6d3e7d76c489f3c98d2b49214938cac8c2b417e2d17bb13446c285fa76fd32a97e9c4564a68f4faa069ad2", x"a6b434ac201b511dceeed63b731111d2b985934884f07d65c9d7642075b581604e8a66afc7164fbc0eb556282e8d83d2", x"b45b285863f7303a234173b06e8eb63c8e2b70efe0dfb9872e3efddd31d52accf0f1292cfd1239b5a57492f3617a19e8", x"a52c5a63b55a8001b6b67c5db4fd5e95923052f03618369312896ed9892d99354aebc0dee8c3b365bafa29e211a5c3f9", x"941c8962debd2756f92a6a0451a2bf7fbc01f32ed03d0823dffd4a61186628a4c3c7c482b18589ff65e4c449fa35c2a4", x"a8e03a26e88e4ed03751ccf6eeed6215becbf4c2d58be27361f61d1cc4ac9b692fc6ecdb839f9b3c17f54fc2f2f4756e", x"87fec026beda4217b0a2014a2e86f5920e6113b54ac79ab727da2666f57ff8a9bc3a21b327ad7e091a07720a30c507c9", x"8eeb8a48b90bd90ccaacddd0fea54139b114e5ed4fd17f9d225c73436224393e0424b7f6028a50831b4c72c524e45c64", x"910fd030feb5538f538e5ba74b9bd017d889ed6d2a797be9c26d2be8caeba7a473006102de27e87755742ba34e445bca", x"8f44c43b80a3c5f488118859fab054745cfe5b0824821944b82fcf870fda6d93489ea9ca4220c24db2f4ad09c6080cb7", x"b31e89b4a034c1b73d43b3d63ea3bddea682a6a5327eff389c70b13e9e72185b0327682a0cb1ff3c4a4f8ba08b13d898", x"948dcd311147fcb8b28044e66d51d082e921db4183cf3fc42ae46becb9a12e7cc5c32c27d12f6d40d7d73a74f6bb6615", x"8d0e6475acfa2b904e7d53bc7acd070a2ee4894ff5720a20e560e9ecb7872ea442a51cf2f2eee4bef66604a5c08ad9eb", x"90a908b47d0c29a2d0e7e65a212d7e1788454062f46458c519c7f2ccd794ff21d4c24b91acf42a71a509aff6544f676a", x"b46f481155df4c4d576e5d76f1d4054e1129cc49398533ed32d0f681701276cecad4759e47b818f20d6a087989449529", x"a0230bdf83cd469c7248074bec535eba8280cfde587d7c63d307149e9626bc7642b4bacc9beff2d8e8f6ea398dc0ade7", x"99b433742fdcc5cbc7d56e74dc2c68e1cb50a6d03b91235501238e7007e71f1b7c22768a11df5e43645ef72338b38b8d", x"9969ab62009b6aa81734579346766937d22ba73c008d24bebc183d1b3d3cfabc90b47f41b29bc6e23d70165594c2e774", x"b930ecc2a26183240f8da107e80979b59da4e05f090316d982815ed6151d7750490b85273187ec4e07eb221813a4f279", x"a35fe9443b05f6632b080d0812e71142dba534b328f7d77e165aa89b370c158be708fed2ab8d8b3c60a3f83d6b1c4fd7", x"860c0eaee51b7de26e99033f352aa09c093943b59237f1313ecc35b0d711509bbe9f939c4bd646deb7de8103eea9ea13", x"973091c0e72354e0df4488c9078d11eec554c8cc84771955595aa1dd7a7a9dc9e29597924678aa20ecefe5be394fd2ae", x"a8bbea7eb6c75bf058c421a3735d8c651e9ae6b1931593b13a588e00aa7dfa62d0982c7cdcbde1d9800fb75a208ed0ab", x"8ceeec6c85df65d52e3d56efcf95f88b59aa085b61bb026fb228b855f088d9b676ffd5f0ee2ddbae00662b2f9ce770b1", x"906cde18b34f777027d0c64b16c94c9d8f94250449d353e94972d42c94dd4d915aa1b6c73a581da2986e09f336af9673", x"93655457967d1f62c3574c4bd85688c92dbdf256f3629818f8c2d75fe12acacc57b6fe78632bb22d4ac7bc1861e59fcf", x"a3d31b20198f326eac488e88fc5b9171276d4934b0bc573c8b55b2abd26380d5296d5bbea281de91c0945f34b37f42bb", x"abf72ec0280d56971e599b3be7915f5f224c0ccde2c440237e67b95489f0c9154ace04b7763db228473715f68053f071", x"80bdb82b7d583bf1e41653966b0ba3b4fec0e7df2ff08e3fa06fd9064bca0364263e075e1582741a5243bde786c9c32e", x"a70a79cdb02f144dd395f93d35f232569d3d0988a447099e40597d76ee3bce0241fb27bcb03a80ed3eb7e6c4003a40fa", x"b7d1d1edc5e72c11b55aa0aa85d3aacc38db925c0d30b082c7c47d39459b8ff2e7f969a754c814ac2a3e7c42a8885792", x"b9eed89e003894ad2cc9d9b93a45247e1367ac69a00b0ed5e3280c1188b4cb90eb870d449b83a852a798bd02f9d0c813", x"94b2d97448b452a986c039df1cfd651da59249b649182941556018af4ab61d2c6af82a29e69599153316f9b262efbcb5", x"aa25208385573caee2a4830f09e1cc9bd041cdb78d3ee27a4b011815a62d0d2e0295c222480947ae427b1578fb5509f5", x"88ce41025aa153a94f91f22e7b96f9342b5e0e1d76274fc70c4df7d08f66d9f7ac86e55a1c6e77693b8b01b2b38bf900", x"a58c3a4ba86d0d6b81c8411bb73a528b4f3bc2debac0e0208f788c080a3a96541d57c927143c165f595070afe14b0517", x"88b49b1130f9df26407ff3f6ac10539a6a67b6ddcc73eaf27fe2a18fb69aa2aff0581a5b0eef96b9ddd3cb761bdbbf51", x"b72de0187809aaea904652d81dcabd38295e7988e3b98d5279c1b6d097b05e35ca381d4e32083d2cf24ca73cc8289d2b", x"8c0a3c445d437ca15be0e3a083f792c893e18b9c3caa67410b0c10947a0c8b5a4fda7dbf3549482b03d971021d4a353f", x"ac0f000ab9d0e6fdfa78e708b0d829ff1dd6a71f0c9af20e29df7eff924f526e2d9a042aec03c6f5afb04c2377a218eb", x"81db8bf89aa98475a15a887c3c216690428609d09c22213b5d91cb34c7831b75ef95e219c5497c81cad1ce9da18ec41c", x"94274299f0faca1152cca89282c10d00b5d3679cd4b7b02e018f653257b778262fb3c6c49d0eb83ce388869c283c3c05", x"910fd030feb5538f538e5ba74b9bd017d889ed6d2a797be9c26d2be8caeba7a473006102de27e87755742ba34e445bca", x"871e70f0446749e5d48d0c113a27e2e2a13e88e703764dfbdc2bd31e921e6a549c54afab53968ec3d856c5e4e6d029fb", x"af7271043f8b37491778588a8c09409a1326abeda4cc72bc59714f552c6e47ac5f16692a0c9c54a42d60bfea743a6d9e", x"ac2c98a0ab3f9d041fc115d9be4a6c77bd2219bb4b851cbee0d9257a4de5791251735b5b8fad09c55d16eb0d97080eff", x"a9b0a06469c7746a0a23c459a2fe75dd474e2cb1e9806afe872febf054e6f13c2c183761ccb890c6bb4d87abe597de1e", x"9729d25a6ff016060d8b8f5e2966d91a083cd546783bf59d24ce142e3b4d1011b554b67cbb88bdb1d8b02bfcd9bfc7ec", x"8a292fbb43135b82019dbe3c28f2f3c37ff95539171285907b869e913d0f39ab690f075cc2b03eda899f4112b690b56c", x"96b478b1e5e49d4ea3fd97c4846ae0f781dcc9f9ff61ee022ca92c3d8dfba89c513c46e8bb38b73e6b678a79b9b12177", x"a38c974b57da968f0c4611f5d85d8014fd48594c8cd763ef2f721cfd2c738e828d41ff029e3591d7447e3125641db8ef", x"ab0ad421f6fd056687b4fa5e99dff97bd08840b7c4e00435eb9da80e0d7d071a447a22f8e5c1c5e93a9c729e5b875a1e", x"876561bba29e656b7122f1cb51a02dff1ac7d470217d8a4799c01e61816c4660eea91843a5a42502ddf842d2daeb0586", x"9702ebb1f2eeb3a401b0a65166fa129d829041984fe22b3f51eedfaf384578d33dab73d85164a101ecbb86db9d916419", x"866ec39b9eda580d96bc2bff76af5cd4887b6788675149ab33bfefe38db82ad01b8d64c6b60704210918f3564cde1110", x"916e770af2939ae3d933db81d8fedff334591380b379ef4a6e0d873b67ba92f5ccf514805a38b961b8e1a346b054506e", x"87587504e819bc7f0349705a05c15e8504fd6b2c25c3fd264096cdb7aaa22d8078da776215925d9d775a7f9355b6f0c0", x"a8d152e5d94b75cb9e249230db21af31de4d4f3d4ef60ccbf2212babf69aed2a38435a993ee2f13cca410ad55a4875ab", x"a639587654e9363590ddda70a97a3ec746652eb1463925f5ec3bd31f831e83db6fccc6b466ba4b9f100aa6be958ed0aa", x"83386781c73348baeae01ac0f62c3cdd1df5e9dbece81d4bc1141b43f62967430f38150173c649c93e25dadcbed46abb", x"a2ab566033062b6481eb7e4bbc64ed022407f56aa8dddc1aade76aa54a30ce3256052ce99218b66e6265f70837137a10", x"8016d3229030424cfeff6c5b813970ea193f8d012cfa767270ca9057d58eddc556e96c14544bf4c038dbed5f24aa8da0", x"8719485f6db54a101f19f574fc1fff3a446f3eb4e42c756febcea7b17c7ef4bfb581a84c5bad36831cde06fad79f4d61", x"902a533bdb93794d150e433084c4c8200555d96fe88f145c2cfaf16ba69cc534e86cc5a88f671851da7f6c11a02df6bc", x"b6af60217014d472e508dd5a1a3c2089f18553a7fe97f5a572c3f738f23a00af6405b40373a438501b0b2d893aaa48c1", x"804c021152c3304853941847e80480fdaceba3b9676fbe018268cf77d1a1856966c2f9686bb4d4aa0c4118a7e85f83cc", x"8c255655f7911bb7a7621ade885e695a5729d1940101e51c4fd4114a229dd9834da8d7c1982de4b84bb9fdc86664dbc8", x"ae36ab11be96f8c8fcfd75382bb7f4727511596bc08c25814d22f2b894952489d08396b458f7884d6b3c0adb69856a6d", x"93f941b4fe6c05621e7a651b87669eefd60b6e8a4a8e630a51fa3fee27417b9eebce39f80a5bade9ca779133ad8388f6", x"b80e8516598c59dddcf13fdb7a42d8f5a52c84e01bd6a39880f4acaefe8e4b8f09cc1b1a2423cd5121f4952201f20078", x"b72de0187809aaea904652d81dcabd38295e7988e3b98d5279c1b6d097b05e35ca381d4e32083d2cf24ca73cc8289d2b", x"aaf15335f1fa2a187f24f3db7966fcda52c2859113ed8f460167538f5cde43429750349f9714edda0adb6705d401d27c", x"a7e8775e04214e3b9898ffb9625dc8bcd1b683e333acdceddb8ca6db241df08a7b80e9d476a711b8b7d66aefca81e9cd", x"8cf06b34e7021e9401eb705dde411ecf7e7e7185f8c0b0aeed949097df31812a9fdd4db7d18f9383a8a5a8d2d58fa176", x"8eafbb7002f5bc4cea23e7b1ba1ec10558de447c7b3e209b77f4df7b042804a07bb27c85d76aea591fa5693542c070de", x"8414962d05eedffc19d7fab3aea967f5386ed62faa0f0b9b8aede8fbd5a94231aef645d3abeb345a2571c9295af60912", x"972cfaefda96f5edfe0614c01533b76153118712c1c02c505008204a5be2aa438675d97f43384199517b1c08c7c9fdb2", x"875977457a3a801e2a25d728bd3424535d82abc9d473d785b6a66b66d9bbac5ff66166ae6ae16485fa2e326828100373", x"85c9217b6f7b8baffda06ffead7174ab9d1d9ec4b10b78d99e742835796a522d6e2b5ddc5c7282757dd896c76698eafb", x"b106c6d13ca17a4c8ea599306e84918127cf2de21027ac3fe5a57d35cf6f3b1d7671c70b866f6e02168ae4e7adb56860", x"95370f2c7c8c14976e5380b300451eee0dbce987b68ed96f2d13f2340f4e4e4cfac52987377b20e4e6cddf58c7975606", x"9702ebb1f2eeb3a401b0a65166fa129d829041984fe22b3f51eedfaf384578d33dab73d85164a101ecbb86db9d916419", x"acdc948f5441a44832c73316a25e0ddcadca50895495daf2b3600206ce0f2ebc5113dc00d0ee497e9bff7d519fb8611f", x"a373408beb5e4e0d3ebd5ca3843fe39bb56b77a5d3d2121d4a7a87f9add3ec7376388e9d4b8da0ba69164850cb4b077d", x"af3f765fd293c253072b33a780ed68933f78d7e079d9a2079b6232755bedf6ebcbce9ba65c01f695602fa8ee17899867", x"ad28da04c80723df1443d5391f998ae9700de91c9fc3f1544d03d698a97cd94fe1753f9915c1d6354185734a80bab484", x"a308ed8737b3a9346ff20dc9f112efccc193472e6fde6aa218ceae11e288bbd2c35fa45c1d8bb238696a96767cd68b46", x"8719485f6db54a101f19f574fc1fff3a446f3eb4e42c756febcea7b17c7ef4bfb581a84c5bad36831cde06fad79f4d61", x"a020404547407be6d42856780a1b9cf46b5bc48122902880909bdcf45b204c083f3b03447c6e90d97fd241975566e9bf", x"a3969926aa2e52f1a48ac53074b764648b4c71bd43430944679628463cd68398f700d874c14503b53756be451c8ba284", x"9022541f84e48b655e74bf3da484179e0e0040827fc71e777b68f19bcfd0e103d385ef957692e7091fe713561f38035c", x"83f1091546b7a4b5516009c7cfae1370decfa31ca35ec9a005ecd90aa7d386eef050387114527b7de9f237ce39cbd13d", x"a322b5d2a6e3cb98b8aaa4c068e097188affef5dec2f08c3e9ce29e73687340d4e5a743a8be5f10e138f9cabbe0c7211", x"b9f02bc67fe93d74a16acc9325126710cf137ef9c8125ecd8355e071236c1ca4cde6dbf95f734b0ed2ea63384abc2646", x"b0eecd04c8d09fd364f9ca724036995c16ba6830d6c13a480b30eb2118c66c019cfdc9dacce6bfd8215abe025733e43d", x"8d4263e8a208ea0a6798e0cf956ca01d650a6e23a1beca11ed82f04db598546713dc716ec8ed81eaa8ffa48924b5dea8", x"a3d8610c2522d330df02511710e52b1d9bdc9f2b156deca12b1bf754266caeac4f449ed965d9863558df43ce9ae65a44", x"830e70476c6093d8b9c621ddf0468a7890942589cae744300416639a8b3bc59a57a7e1150b8207b6ab83dafcc5b65d3c", x"89a3da03c0d87cf8a3a166dc845824215cc6057f9d2e582866c6d4ba35ecd51e31a8c8203a6f222bc6701beb249052f4", x"8bc161f543ec5a4ef2d09ecbc9d6a26bd624a06fca6528ba0dfe09c7814145cee71ea2a0e120d0c81e30c8771d7a3abb", x"91013e0d537fb085a49bf1aa3b727239b3e2c1d74c0f52050ff066982d23d5ee6104e70b533047b685e8b1529a0f14dc", x"9604659740f6d473bd2c470c6751f2a129328e74e01b23368f692ad9b6cce0fe1509c3f82e9f01019b72f6bf3a8e4600", x"8ba45888012549a343983c43cea12a0c268d2f7884fcf563d98e8c0e08686064a9231ae83680f225e46d021a4e7959bb", x"9171a7b23f3dbb32ab35712912ebf432bcc7d320c1e278d652200b5d49ad13a49ec8e56a0c85a90888be44de11fc11b5", x"815922ad356f490910e8cc3b0f7d3934b5e28c09711b5151ae8329876670f3de6d7a3a298fd97b580ac8f693305afb21", x"af03bc1e94067741bca4978b9cf065cc6852090fde3aaf822bbe0744705ebda5baac6ed20b31144db0391309e474ba48", x"aa5ad6e6ff8d959149828f32242ce589f8581689a87c084d73ecfdf4ab95d64ba7397cf3424f6be03debfa0c1630a8fa", x"b95e3032192bdc064306c683982d885f0ded8b907a532f15526a257ffeff2c8bdd7a2334c10d74b1484909b2e3ae0e47", x"8c432e044af778fb5e5e5677dbd29cd52d6574a66b09b0cd6e2a5812e71c91559c3f257587bfc557b4b072a822973a60", x"8180ffffb5abe78c38f2a42a3b7f1a408a6d70d3f698d047d5f1eef3018068256110fcb9fb028c8bdccbc22c0a4c3a20", x"83a798f47a4f62dcb8b531d463b0fd4a876d47a8ca990710290549255033c909de709471b4e823a60bf94d8baf8b5acf", x"a80ac2a197002879ef4db6e2b1e1b9c239e4f6c0f0abf1cc9b9b7bf3da7e078a21893c01eaaab236a7e8618ac146b4a6", x"90d32e6a183a5bb2d47056c25a1f45cebccb62ef70222e0066c94db9851dffcc349a2501a93052ee3c9a5ee292f70b92", x"85ab3c57517e3c348e7ec13a878b9303ff9aad78ec95b13242e087ec41f05f4a19366ae169fda8afec5300065db58f2f", x"93e4d7740847caeeaca68e0b8f9a81b9475435108861506e3d3ccd3d716e05ced294ac30743eb9f45496acd6438b255d", x"af3e694ad71684f7214f86bed85149db039971e1c362119b979a135255aa226128802e58e2caaeaf8d89304371dd0440", x"8dc3c6478fe0150a2cc11b2bfb1b072620335516ad322dc5a644676a4a6aee71a8680eafb37db9065b5aa2f37696de07", x"860f5649c5299211728a36722a142bf1aa7cbbfbd225b671d427c67546375de96832c06709c73b7a51439b091249d34f", x"8068da6d588f7633334da98340cb5316f61fcab31ddfca2ab0d085d02819b8e0131eb7cdef8507262ad891036280702c", x"9702ebb1f2eeb3a401b0a65166fa129d829041984fe22b3f51eedfaf384578d33dab73d85164a101ecbb86db9d916419", x"a650864b7eb6769aaf0625c254891447351e702e40d2be34dfd25f3b5367370de354318d8935ba18db7929270455ae6a", x"aef7205b83123d06496fb23188c2edd527728200f8f01486b9e27d3d075d713c7092dcfa2445459fc85b798128fca051", x"887c837e3e30354a0c3f9ebe0e555406400dd882acf9b360fa848773f2f637b6586a84b4884d01e5ca3e896b89a5e331", x"93c1b107eed20ea64c303f53819aede3fc3df85ecf1009174398a8be1441e374657697936af1b9f6e655797478557cea", x"a6938eb874460735402e4e8955b2d9f67032653154eacf78d61c2fcaa36af8639fa0aa22edf5015a93fe77080aadfbe3", x"96e1482bc27d1b4158b4d482ca7ded9082b543d232b3185a579981a46501aa4dade1b579eb2aa4410039a0a4c5ccec7a", x"a448516054e31866b54f1951b9a03f0a54fb13d938b105e3f67396ed3fbb015f290a37fa538baeb077fb4f9ac86c8305", x"993726e0b1c2277b97b83c80192e14b67977bf21b6ebcde2bda30261aa1897251cd2e277cfcb6193517f1eb156d2fe86", x"a0e072aca8345464ff5156931f804d39c6578c5c47e57b53d0cfdab0fa8f49f35f4ad17284606b342c7cb54debec5ee2", x"941cd102228aa81ef99506313a4492a17c506e7169808c6b14dd330164e9e8b71b757cbe6e1bb02184372a8c26f7ad1f", x"a3e91428c65209d182cc6b95b6d6ab6ed9d6ee915a992760e29a0c99c19b2caeefdfb87803d0f675c5c5362ca367a4ab", x"94bcfcf974e77d5683704888621ca6f29bda9c5913472f9aec2cae03cb4a3b4237f8648c2ff1c7ecd73627d7babf0062", x"941c8962debd2756f92a6a0451a2bf7fbc01f32ed03d0823dffd4a61186628a4c3c7c482b18589ff65e4c449fa35c2a4", x"86793899ef71740ab2ec221d0085701f7909251b1cf59a276c8d629492f9ef15fc0b471beedc446a25b777391ab00718", x"918c1408978c5be7d482876d47ab97e70424b9b9d27a2c95f017d847bb7f152db27b63929514653e28be644c3c92a9a3", x"a57bacada151d6521c6f40371e80cc8e44bb76389dfa7da5deba7675bb9a253c59a901df26c6f1069205b37f18048b1c", x"a14d8d3f02de36328f3f55ac45331baafe5ba3611bd8b362464d69742b214cb703f37b5f39ed1b23cdcf0bf3eb90a81e", x"8370c38104527d5b510faea45b92b1d077f9a43558178fc11204e4d0486fa94dee0c1d072b42c9f49770e63673c33fdc", x"b2df29442b469c8e9e85a03cb8ea6544598efe3e35109b14c8101a0d2da5837a0427d5559f4e48ae302dec73464fec04", x"b2235bdf60dde5d0d78c72cb69e6e09153b0154efdbab97e1bc91f18d3cec4f660a80311fe6a1acd419a448ab65b18f1", x"8d5de60e934ea0471d9e0a46489f21e03abb9722f5b3633631a9a099b9524beac5d67716969c83d824498796d9c106b7", x"af2dc13a599c834b9af1b54a4fa675c0db92e807cab3bfc825f2c5571b3bc2e1c213cff941cc8b1080d894036f9f73f8", x"b6aeb7a9b934a54e811921494f271d5d717924c561cd7a23ab3ef3dd3e86184d211c53c418f0746cdb3a12a26a334fc8", x"b1bb33607d10ea8c954064ecb00c1f02b446355ef73763a122f43b9ea42cd5650b54c5c9d1cfa81d4a421d17a0a451aa", x"8302ad0f2234535b55b975c5dd752c8a555d278b85b9e04e83b1db3bb2ae06f082f134d55216b5cacbf80444e1d0af84", x"afe779a9ca4edc032fed08ee0dd069be277d7663e898dceaba6001399b0b77bbce653c9dc90f27137b4278d754c1551a", x"b3e313e79d905a3cc9cc8a86bd4dba7286fb641c2f93706adb3b932443e32eff2cbed695beeb26d93101c53d5f49d7db", x"9377aab082c8ae33b26519d6a8c3f586c7c7fccc96ec29a6f698b67d72d9266ad07378ba90d18e8c86a2ec77ecc7f137", x"8a9f7e8d45f11c4bfb0921c6008f3c79ff923452bcfa7769beb3222f1f37dcb861be979e6eae187f06cf26af05e8ee5b", x"9752561179783f336937757b619b2fdcb9dfce05aa3c4fce6d582dc966182eb85ab4ccb63e7e1736a7c5fad9d33cccd2", x"b6df01c1d26cf05ef5c647f09d494e99fa8bdfb73593d47012cbf091e12b42eba39802f23b159f8b54925afe30c0e1ca", x"af25cf204acd84f9833b7c16ce3716d2a2cad640a28e3562f10260925efe252d3f7145839784c2ce1490522b45d1ce9a", x"96cf5760c79cfc830d1d5bd6df6cfd67596bef24e22eed52cee04c290ad418add74e77965ea5748b7f0fb34ee4f43232", x"85e2013728a13c41601d4f984f0420a124db40154a98bbe8fddc99e87188b4a1272d20360406a9dbae9e49bfe3f1c11c", x"b37a2ec9dec3d7d9cbc911fa1e5310a47d23a841d02c8b99a923991c73fc0185d130a494748c64f2b5a4c07bcd06920e", x"a19f2ce14e09ece5972fe5af1c1778b86d2ab6e825eccdb0ac368bb246cfe53433327abfe0c6fa00e0553863d0a8128e", x"a3498bbeae35f75a39a3b96b4d642eb129df398926cc433cbb9ffc3814ac1e57440739ea32d9df4d3b8803e7e88fd60f", x"8f84cba7ceb7652023fc8ebde4b00ecde1f550935bab12feb630d6f49517b4148f3cde184bf55d4f6ec99a849fc6f862", x"8f9f85ae6377414fcf8297ed45a736210cd3803f54f33116b0f290b853dc61e99ea08f3c422ed9bc6bdc2f42ab4f56ba", x"a60642ede2da19e9e4a2fe5a31360fba2c871c25ceb8a867c8189fc62c191a5494cbe59a4a53f643d3025ab264e9cee8", x"8a00780f008ac29b4942ded67224be5549cdce47d047c2ca6458af643332ef5e276a69cd38b8c50f8767c6e27d5f905d", x"b0526c028e1c9a945e340d05087ff0e4b0e465a99369d3fdb8b929e79d02fa34f316741a1610076d33212ba7d357d4b1", x"8bc66e370296649989a27117c17fbc705d5ac2bda37c5dad0e4990d44fcc40d3e1872945f8b11195538af97961b5c496", x"85b63dd33e2cc178cfd55d67509717c3d8b81a40d6be468eb5579e4a1dee3d0be1a5f93c90e2f0cdd012efdffa7d9235", x"927c030d5a69f0908c08f95715f7a8d1e33bed5e95fc4cfb17f7743cb0262755b1e6b56d409adcfb7351b2706c964d3b", x"aacf809d4015c7b809713b901893a5353e59b186ddf18c8f3af02d2156db3dc49406e7c1f4aca04a46c99348ed539f8f", x"b2235bdf60dde5d0d78c72cb69e6e09153b0154efdbab97e1bc91f18d3cec4f660a80311fe6a1acd419a448ab65b18f1", x"99db0063338bd58b85c9caffbbd94e411dd17d41ab2ef5db23cc0afd4007ae4b1c120a3abbfdd148f94ab8dcd45cd3db", x"b354d0d1bd942f79002a2eaf37eb99dab650170e7040c13c824803ed7c1670dc910ccae13bbe58bde003829b140b45ea", x"b6323818d163938314b407892be8decd9a84631bb7cb5c35c6766b11f531078c699779d890787cbd5ef868b21e7fca4e", x"a35d9d6d5dd5428cce7616842203b5fa3721cb4b20f50c0113f138604954fe0cf214ca3d065b578f921054b9efe823df", x"a07b35ec8d6849e95cbd89645283050882209617a3bb53eae0149d78a60dbf8c1626d7af498e363025896febdba86ee7", x"aad4c48e1de22a43f973e9ac7d204fcbc35da23785541da7390fc85c032a7fa75f784964eaadb19d0524f09dac905dc0", x"97d076617cf0a64ab3d1f030cfd72a303b6b252c0a7b96157ff7fc8af5970f00d14492c46e8f6f37caafe837d0dc95c7", x"b0ad3c61be779023290256142d6b30200b68ff41f5405757b1a1c634b4d6bafbdcbd31a1f9d2866f111d8601d6dcae35", x"a7e0ddbae16e4491822684c0da3affecbbd17ef96c5c491ac093c6eb4e162fc7854c367535e296fd3d6265c2ed1210bb", x"b31949c4a21181a54928f25f8598ea3dfcacab697a5653beb288d218d312133e5a93f434010ffdab3f3ebd0b43b207dd", x"92b0b1e1301b1f7404789b911a672a32d96ce0e52d64f0d97f2a4c923d0824dfc8a9faef63bc93cb00f894f95e4470a0", x"91f870f372e11a473cd0e1265c2675721413d4910f6edf5433a5d8b7f6b7d0c1780b5fa8651fa7966b55bf59cb0e61fd", x"b544c692b046aad8b6f5c2e3493bc8f638659795f06327fff1e9f4ffc8e9f7abdbf4b7f6fcdfb8fe19654d8fa7d68170", x"8027e3716601f04f1bec13c787805cfdff2c85a63390cc3db377594580a3292c730b833a002ae5cfc0a826bacce666bb", x"86fa3d4b60e8282827115c50b1b49b29a371b52aa9c9b8f83cd5268b535859f86e1a60aade6bf4f52e234777bea30bda", x"820cc2ac3eed5bce7dc72df2aa3214e71690b91445d8bb1634c0488a671e3669028efbe1eae52f7132bde29b16a020b7", x"a9f6b6b04e36850d2dbbc390a9614013da239375f105b0f3738138431f0a3a8c685445f6c518e0b0e72fb3244ddc0d9e", x"91013e0d537fb085a49bf1aa3b727239b3e2c1d74c0f52050ff066982d23d5ee6104e70b533047b685e8b1529a0f14dc", x"aeddb53c6daac757916039e0992ec5305814e9deb113773f5ecf10355cc3723848fd9c55e0a6ffb6bcff4ad65ed5eb3c", x"8b8813bd2c07001a4d745cd6d9491bc2c4a9177512459a75dc2a0fa989680d173de638f76f887de3303a266b1ede9480", x"94fab50e1f826709bca45da6574aeeaae0b2b6e172c30798bbd886720e18dcfa0be4c46b43cb14219b172b6afe70c062", x"801c126abff96fe9b042be8869d2907d0c6963a79901f9db46577a445418b7465a1f4b346933d433e539536a9a2df01c", x"84ed656b5291cbb2843ecc8371cbf1447955256059bef4a77133f1a37e7529fb64cefaa2ea973c680329f6110999b22f", x"a03daf351de2b711e73fcefaa02ba23a90a8c68ae6e31672caf0f36bfe435b663846536e75279ac5fb63559b7397eb24", x"944f722d9a4879b5997dc3a3b06299182d8f68d767229220a2c9e369c00539a7a076c95f998bea86595e8ec9f1b957bb", x"8b7cb5b8de09a6dfceddcbaa498bc65f86297bcf95d107880c08854ed2289441a67721340285cfe1749c62e8ef0f3c58", x"b298aa927713c86adfe0de1a8d6f4083b718c8be27156da9fd11abd8edb3a54a926ad487801eb39cfc9363a0a3be0d44", x"8f88615a86867c4add4c6dbd2c717a7d5c9e6450e9540b56de14c31d9ff84e2495aca3f1d5be51940c183c6ced9da2d4", x"b6fdf7016529321bf715ec46c98633e08c53d04ba065cc6d59612c6c8e3970ac41b0c3923031a53c1a4689e5ca9d084a", x"b7ea5e0d3cfcf0570204b0371d69df1ab8f1fdc4e58688ecd2b884399644f7d318d660c23bd4d6d60d44a43aa9cf656d", x"9752561179783f336937757b619b2fdcb9dfce05aa3c4fce6d582dc966182eb85ab4ccb63e7e1736a7c5fad9d33cccd2", x"a23f3dec1ef45c126f040e5818a1ceea4283bc8ccbf9b8a2d3a770f93872777647893ff86fea463144a355c32a01564e", x"a7e0ddbae16e4491822684c0da3affecbbd17ef96c5c491ac093c6eb4e162fc7854c367535e296fd3d6265c2ed1210bb", x"ab671eb947490c43fd05e42a787344b21af89babb705393c82748eaa0cfcf80bee498d275a1eaf1d647ca3b2923d76ea", x"8e956ca6050684b113a6c09d575996a9c99cc0bf61c6fb5c9eaae57b453838821cc604cf8adb70111de2c5076ae9d456", x"926dc729e135f1f0bff4662ee3d6823a64597fe189b763ada34f246e77705fd4e062d85506a338e9fa98c4d225a3b27a", x"8b50e4e28539270576a0e8a83f5dedcd1e5369e4cd0be54a8e84069e7c3fdcc85483678429fd63fe2aa12db281012af2", x"a8bbea7eb6c75bf058c421a3735d8c651e9ae6b1931593b13a588e00aa7dfa62d0982c7cdcbde1d9800fb75a208ed0ab", x"9267c0e9c176eefab67362ddfcd423a3986b5301c9a7c1c8c0dab93fdb15e562d343a7a9884a0a3378818b1aa1e4091a", x"b6e6277b86cd5284299ced867d37ab98090ac44a94deef6898aeadd177e64605440c15b9609c07e71fe54c95b61873b0", x"94d4a1e3a3d28a948f14d1507372701ac6fc884a4905405a63663e170831578a2719714ef56f920baa0ca27954823e39", x"a18f4464cf5cebade8ee280fa00e0917cbf1743aeb0dacc748ab68773b909e30dc60f40fdef3041b5f082e650985f7a6", x"b505941fed274189346ac4822c06eead45c56b9c12e8caceebf79e3096ce6e081f423c205dbe7839df1d6c3fbe626193", x"adbc658d54f46fc805767257f5e87d013112f0c6335605e9e763cd4745a1271b0e0b83902d5aaea6f8b46485d2e82042", x"8f4eba540bae99599ec8d23102894362bfb72533d8ce415901576346345d16ce4fbc5abc68f9d16251d5121431774d25", x"9282add41ea47925992831d76289b09d313946c21ae4aadfe0df002ed62953d3d9aa4973e507d4d89486a5759e44b641", x"8cc5ad6a016bd2bbe7db60e497e83529341815c4301d9f3060d43efbd094dcc6e6ca01470e28d6c89e57d4adf8c2d627", x"b8fdf21b57d1d5eecd93f76c37230d379b652dcd9026a158151adc38c7ee4273cc2b99e47b89ec05f57dafdcaa7a3b4e", x"a6d7e65bf9f889532090ae4f9067bb63f15b21f05f22c2540ff1bb5b0b5d98f205e150b1b1690e9aa13d0dee37222143", x"b63fd45023f850985813a3f54eceaccb523d98d4c2ba77310a21f396e19a47c4f655f906783b4891de32b61a05dc7933", x"b8fca0f7bc276f03c526d42df9f88c19b8dc630ad1299689e2d52cd4717bbe5425479b13bdf6e6337c48832e4cd34bb5", x"9302bb41f741deaa5f2b6e3bca1427a6cf98b7ec2bf7967b7c0595efa258427323a022ef12f23426ff7a7c318462f07a", x"86b3a4ea9b1fde00cce79d5ae480353d60cb6ddce363c535bbbc3e41a4b8e39fcf2978eb430091ae1b10420d43193971", x"8a1ebfe5e8dd0aed5024fe582cd677e23544fba784c0dcb73edb2d909a716ada426d8c08b14b488257836efd37971314", x"8aa3d9dad1c122b9aed75e3cc94b3a9dab160fa4cad92ebab68a58c0151a5d93f0f6b40b86fba00e63d45bd29a93b982", x"b931f211cbda8e85b0c1075611416ac4d79dcff9015e8d507c93b30d40996e2a35e214e6f3c8ac56dcdda7026e8f7d87", x"a841fe9ff26db21ade698f6dbfba025d90ae9f81f02af9e008fa0a429b993fb04d06acb93e40a9f81c78f73334555a17", x"978299430079ea9a0868eb1289ea175e133e9f604129d56b1b1d0f768930bc4c64db921e08f352bfe6ad2296123e6ba7", x"b8aba8f15ea91d23e660736ac87f3641f5233911ca6ca65805ad6890436ebc561555429407ba6b1b39ccf3a917a03dd8", x"8a0192ef0903d7a5ed2e5614a715901f2554b324ee72390974dc90727ff08dafa580041a21a8e6c48a3e08e1b042afab", x"a02883d525e251708bcecf6cfaf7d07fc5e1be92fba24ca8f805e96b7dfe385af449f5687de1dc6707a62ccb08c1d590", x"a97b80bf780fba51a5863e620317812418204d3d5a1001710aa0cca383cb40855d9da0ddfdd40e1d2e9336a4543ca1ad", x"84f43aa4e2a9d10e6590314981b5eb2a5e486c1593a4f82bc3a82b67f6ccc29652ab82a689a9454bcb6c1f9bf7a10e2b", x"9574f43bf9da6bab6c21411d2886fa5d5717cbcee226eda84646ca4c1835f0f798d9a6523e0e007309e52deb7bf645b5", x"b1ca8fee56192611094ae865f5f7fcfed3f89303386e8fd93eace625217b51a2023d5b7adf7cdf070e85438cd73fd75f", x"935f616bc620ddcde07f28b19a66c996798792b953264d1471f686e84f3c6f125e2a3d3a7a535c4175973c7ed2e4bece", x"98b41b67eeaaec5696bfb492efa84248c386c9267a259270f214bf71874f160718b9c6dd1a1770da60d53c774490de68", x"85e8259980319bc750607f5004aa83f7d7eaf20eeb164fe3db13864e3d31e1f53ea42dd6d9b30ce710089f193c895d51", x"b3a5497365bd40a81202b8a94a5e28a8a039cc2e639d73de289294cbda2c0e987c1f9468daba09ea4390f8e4e806f3c8", x"8cc5ad6a016bd2bbe7db60e497e83529341815c4301d9f3060d43efbd094dcc6e6ca01470e28d6c89e57d4adf8c2d627", x"aefc682f8784b18d36202a069269be7dba8ab67ae3543838e6d473fbc5713d103abcc8da1729a288503b786baac182d3", x"972cfaefda96f5edfe0614c01533b76153118712c1c02c505008204a5be2aa438675d97f43384199517b1c08c7c9fdb2", x"a10f19657a9bc5a5c16ebab9f9fddc3f1d812749cd5d80cb331f51de651873ff899e0670f1b079b29a194572de387a17", x"ad2aee9a61242235f0ef6adadd5d314b18e514083d6a589ca65cc89f505e44b480724d7659a87c95b03c62caba53f487", x"85c8e7e1d7ee3ed366b530c5c9fe0a353f2907d8b80b16d00391780c04e3f7e060d433539780457732864e334039474f", x"853184f246d098139230962e511585368b44d46a115c5f06ccaeef746773951bead595fb6246c69975496bac61b42a4f", x"8d6e3df29419bd0da1deba52c1feebe37744108685b49ca703e1b76fb4d612e3959d3b60b822506e5c0aac50b2f5eee2", x"88158d759eafd2205c770f166829fd61e8f17b2c13f440777eaf45f4d88a6e2028bc507680ff435882d5fb462f813735", x"a07826925f401a7b4222d869bb8794b5714ef2fc66fba2b1170fcac98bed4ba85d976cf9ee268be8a349ae99e17ac075", x"ad28fe70a8606f87bcb5d6f44e1fca499c24bcee791971f599ffef1f403dc7aec2ab6ebed73c1f8750a9b0ff8f69a1e6", x"8f9aededb605db4e499d3c383b0984b1322007c748dea18dc2f1c73da104a5c0bece6bb41d83abdfac594954801b6b62", x"a978fb8ce8253f58e1a87da354f06af989b0bafaafec2fb3100bee272dd8664d2690f8ada7dd4817bc8b06ffb1fe23f9", x"b012bb4b7b087d9a94c320ea2e0e42e658a0887b35aa4ffb335f82d9759a4a8ad71e22fef80719d4b261d9b67095fee8", x"b31949c4a21181a54928f25f8598ea3dfcacab697a5653beb288d218d312133e5a93f434010ffdab3f3ebd0b43b207dd", x"abf19b2cb84bcc87d15e12844d053237a139d76a35ca14250cee2415ee646d98bf97c42bd2645f0790ebb388dd561d59", x"a64210fc1ec26ec77704c002a6fc418c4edaf07bd0f8008c434b5ffd5a685adbe61b0319b3646e813f920590179c9859", x"ab37a400dafa918d28ef43294b18dabcb4dd942261832f9839e59e53747c7b1bc44230967a9610b261f3abbd648e3dd8", x"b880555398668dc7d064a18ba82d574999a93a6843423703aa8e543fc196607239de7a4258710b85563f2889eacdd0fb", x"8862887763e3d310e6cab9bfedc8004098287bc96a116db16373002eb34484c166d8fe87e1a76783eb68e1e27508870b", x"a2ee6c29efa982e9b9abd3c5e4f14b99d5d0369d7bfc3c8edae1ab927398dc8a147a89e127b3324d7f4e3a7494c5d811", x"a3681ac11c5426767a2f1cdc89557746d5501d70add50bf4f2c9165fb5055af0644f3013603209cbaa0414d3dc794ee7", x"aa25208385573caee2a4830f09e1cc9bd041cdb78d3ee27a4b011815a62d0d2e0295c222480947ae427b1578fb5509f5", x"87c5670e16a84e27529677881dbedc5c1d6ebb4e4ff58c13ece43d21d5b42dc89470f41059bfa6ebcf18167f97ddacaa", x"941bbb3565f0019619aefd551a471adcf28a089bf272bfb2c84e47312d09263f3a64da317e940d857ac72191730c294b", x"9831b8c836114f6d8213170dde1e7f48d5113974878ae831fc9b4da03f5ed3636342008228b380fd50d4affe909eb54a", x"a54150d11a56c859a18cef8ce23b22ac4eda29b97010599b0d0b1f65963fb83a56e791b95b49a58155dd536c6433c3f6", x"99c935fe18699bca9852200c292690a2b834bac508890c4ee9af1aa6999a8d590bf6a3a274bb55d5a73f1b7095d10f37", x"8c432e044af778fb5e5e5677dbd29cd52d6574a66b09b0cd6e2a5812e71c91559c3f257587bfc557b4b072a822973a60", x"a343d9fed516cd9dfa04d2542d93ded6f0bf1ff5c31cfd4f87b061461dc4e46ce6583272d3032767dc26701a4dd4277a", x"a69c2bf4d972eacdb9633a799293d7f5dbc8b6ac82433a389472cdb25329d2cfa2b709778dbfde1bd87c3201f836087f", x"807c510df25c0ba10d4aa06a462e02f050c69a977c64c071401ab74f9ac1e60788aa504743b4cc1982da835ff9ac2541", x"8f72b5243a8c4f200c1041f6d8180c3e2cb6ea83143a7b3f279452ec2c8da5eee758149fb31f394a14c232bf797c9186", x"a16c910646638c4a57e94129a333ea61b8586d7fcedcd522904c9d019befd6e58344fd5e8f71819cfa841c34b3c812f5", x"87e39895ee4bcf83f007c7e8c560304d55674cdfef16e3fb5a309061dd97f37b12da2acf5b2f05c0d07fd594277d49ff", x"b7c4e55e2b48ba55a71f72387475886e5b4715100e93cd2ae09582fd37e5646b54bd93fba311b65c842bd0aae1424bc7", x"811e6a5478f708495addbb1445a2ef23e39ee90287f3a23ecd3d57d4b844e4f85b828bae8fa0f1893dfcc456f86f7889", x"ae0e15a09238508b769de83b30582cc224b31cd854d04fdb7b8008d5d8d936dbdd3f4a70fff560a8be634c141772561b", x"826be957cf66db958028fa95655b54b2337f78fb6ef26bd29e2e3a64b130b90521333f31d132c04779e4b23a6b6cd951", x"90f1d6745ed9a2fb2248d35de8cc48698f9e006dd540f690c04038ff3d22bd7f9c3979f6b3f955cb397542b3ef1c52dd", x"951aa38464912a29df2101c60771d6de7fadb63f2db3f13527f8bdacb66e9e8a97aaac7b81b19e3d1025b54e2c8facff", x"a798a0371e8cc4dc42ccd79934b0db5a3a59f18a0ae09f2eb172596428fcb3f00312e783d6fd21cbc1610317f44e08cb", x"b2349265be33d90aaf51362d015ce47c5ffe33e9e6e018c8c6e39336d9327ccdd13d25e792eb33b43ed89a162f6ac2fd", x"8804338968d999be8bc1466b29a928a7a52dad4e8332599d38879c0d7d202c248ebde96fab8b00efaf196c67263bb481", x"8ea5f88a79f4eb9e7c0b6b29f8ef2d1cc4c15ed0ed798ab11a13d28b17ab99278d16cd59c3fa8217776c6dfae3aedf88", x"96f1a36134e0d4137a7fe8bbb354f50aaa67f28f194ae2fdbe8be3eb24596678d8c9287765ee90c1f2778d0d607931e0", x"99e265966b6b8f81867f0d604bb7080322e9256e61b81f7ea3f2a06dcdc6ad62a823e7382d22d4cc2cf60ae2b008afdd", x"a6b434ac201b511dceeed63b731111d2b985934884f07d65c9d7642075b581604e8a66afc7164fbc0eb556282e8d83d2", x"b54fef3e679059cf38a721b61cbd1d2492b06672da0e8ec1132f845f2acab375bf2cba5e9e4fd6833f615586ecc21c7c", x"a75bcd04fcb44ce5cbab7eef6649155ec0bef46202e4eb86c88b4ced65e111f764ee7fb37e9f68e38067040fedf715ee", x"853ee4db23d9ee501a651fbc900ba81fbf9397d914f1a7437afc247e7a666054d0197f02c1d12a76c43ee5c82784009f", x"b504cb87a024fd71b7ee7bed2833115567461d1ae8902cccd26809005c4a56078617ec5d3fa5b29a1c5954adc3867a26", x"966256693e9cd01d67855d9a834f39a8e7628f531e136b5113b7cdb91e17b554fcbef2611929b74710606585b1df59b5", x"93042dd42e56671155bb40d85d9d56f42caf27bd965c6a7a7948b39089dba8487d4d5fd30522dba6ba392964e3ffd590", x"a8b742cb7f497adfb99bdc6bcaf7f4bdadded2a6d5958680406b3b00545e1812d78e03e20be42b471b1daba84587d574", x"a12fc78b8d3334a3eb7b535cd5e648bb030df645cda4e90272a1fc3b368ee43975051bbecc3275d6b1e4600cc07239b0", x"8a9ad977988eb8d98d9f549e4fd2305348a34e6874674bcd6e467c793bba6d7a2f3c20fa44aabbf7151ca53ecb1612f6", x"a8c167b93023b60e2050e704fcaca8951df180b2ae17bfb6af464533395ece7ed9d9ec200fd08b27b6f04dafa3a7a0bd", x"a1e7ac500e0bd6a1e17a144de8a0d5e713a22260f70fa455be3789781772ff198a31c9e11900c51b5e272dd7d6c4a1fd", x"8302ad0f2234535b55b975c5dd752c8a555d278b85b9e04e83b1db3bb2ae06f082f134d55216b5cacbf80444e1d0af84", x"b118f77f99ac947df97e7682f0fb446175185b842380af4ee7394531e4f93002c72b41a57a7c1b923a4f24b10924c84f", x"83c991703a7aac7ed7e88fe02ffdded1a5044143ac2cd038b687b2ccd37a69d6f9359de10508b3d282a9585475136f81", x"a641eaa149c366de228a2833907ad60eea423dd3edf47e76042fdf6f5dc47a5b5fc1f1b92c8b96c70e6d8a68d3b8896c", x"919c81bd1f3d9918e121e4793690f9ddd96c925ae928536322d4b98132f21979c1f34731d393f0ae6e0871af4355a8ad", x"86eac7e4bbd3a302fa5eab35697d26f17e0b646f097ed5e74fb45ad857615d06e829c7187bc20e136085af97d487744f", x"8126c80c3d28d61b00e9be970d7dd6054b299981e9b36c51e8596cbcf8ce1f5f6ab5eece17bf964186c4ef3e9156f909", x"a5b213f1d8ddcd9e42570f61f57c0e59cd6379740e50239257395f2fe7fac982c9861685e0fbee6c75bced5aa6b64849", x"a841fe9ff26db21ade698f6dbfba025d90ae9f81f02af9e008fa0a429b993fb04d06acb93e40a9f81c78f73334555a17", x"a3b7fabaabd4c2e555dce46add6c56851b68308c1bb7253576a9f32eda141522317b5c00a28b384ead3a880b8e7e40dc", x"8146e343132c970abac89f5f80e729b08462f79aebc90c7571412500781dc2f5f74a24f794f1c8e54332fb5310442cdb", x"b31949c4a21181a54928f25f8598ea3dfcacab697a5653beb288d218d312133e5a93f434010ffdab3f3ebd0b43b207dd", x"8f84cba7ceb7652023fc8ebde4b00ecde1f550935bab12feb630d6f49517b4148f3cde184bf55d4f6ec99a849fc6f862", x"80e09f3bf3ea87d48e04b53d8f3b43b7e53d61f445f8c8a5a35472b84f6bb4f58f17d9832f5881bb44fc06156151e5c5", x"854aafa329e2b2563355641eba95f2aba5b33d443ab16f5e342048f97d97c4e2812ff27c6f4180b8110272f3151be690", x"ab92b2a177dfa55d202a653532f0e04d1339ca301aebe6a0e8419bf45be3e573b6b9ae4d3d822cc8279367a3d2c39b06", x"a8b593de2c6c90392325b2d7a6cb3f54ec441b33ed584076cc9da4ec6012e3aaf02cec64cc1fd222df32bf1c452cc024", x"8bdb7d92915d1019732a095d962b0ca56bdd15ba22611170ed44c880ea0170cd2bff0dff388a1fed467a92fd756aa5ee", x"a8fd63da16dd6a4aa1532568058d7f12831698134049c156a2d20264df6539318f65ec1e1a733e0f03a9845076bb8df8", x"89e19b665ce7f6617884afaf854e88bb7b501ecdd195a5662c79802d721f5340eca8c48341ad1d6c78f519f82e5a9836", x"af18cf1e3d094b4d8423da072f98b3023d296f6a1f2a35d500f02bde522bb81dc65e9741c5bc74f7d5613bd78ce6bc03", x"918c1408978c5be7d482876d47ab97e70424b9b9d27a2c95f017d847bb7f152db27b63929514653e28be644c3c92a9a3", x"935f616bc620ddcde07f28b19a66c996798792b953264d1471f686e84f3c6f125e2a3d3a7a535c4175973c7ed2e4bece", x"ae075b66e5f211c2149c45b211d1297bbc1d9e6497cb3315363c492a9a51ae5b9d0a28bfecd755d68553736901ac6606", x"b2cf2cf8f9e750c1f28b72cae7e4e0091ee6015caac897c5e3b37148b57e64a7fc11efe99a4113a4ce0965d74cbd7a9c", x"af3e694ad71684f7214f86bed85149db039971e1c362119b979a135255aa226128802e58e2caaeaf8d89304371dd0440", x"96b478b1e5e49d4ea3fd97c4846ae0f781dcc9f9ff61ee022ca92c3d8dfba89c513c46e8bb38b73e6b678a79b9b12177", x"ae5ea228c1b91ef23c245928186fbafa1275ff1817535018d7d2d913abff0fd76bf41fd04a96d816f2f1891bd16e9264", x"a1ff5fca9d61c68110ef3b0354ecdfb7f2f069f6560e6ceb8a58050bd4bcc0b98f46835c9d36cb09b01164c4473a2da2", x"941f73b2138b4347ecafcc7b8c3d03f2a54dc49f580394ed08f22b0878ee7cb63d42978f1d320c09e7dbc67648c06f8c", x"b1e604fc3e1827c6d6c58edd4bc42b1529b2da46e2438591317258be9147359278f154e02465b938c727bb3b0c0cf8f4", x"ad5be06308651ab69fc74a2500c2fdab5a35977dd673949a5bb7d83309b6bf3fcc3c82d8770802db1556fd7abe37f052", x"ae89e41d8cfbf26057a4078f8a5146978e658801b08814190cbce017d79beaeb71558231a72bde726fa592fb0828c01c", x"b6df01c1d26cf05ef5c647f09d494e99fa8bdfb73593d47012cbf091e12b42eba39802f23b159f8b54925afe30c0e1ca", x"8548774c52eb42b88c53d9d07498eb8a3bd087a48316f7ed309b47e009daac3eb06b9cb5eebfa6a9f54042f4a5fd3923", x"b031d93b8f119211af76cfafee7c157d3759b2167ee1495d79ad5f83647d38248b4345917309ef1a10ecaa579af34760", x"b9445bafb56298082c43ccbdabac4b0bf5c2f0a60a3f9e65916af4108d773d62ffc898a35b0b8efb72ea846e214faa02", x"b187e0a317aa92aee1c6bd78abf3439c9acfc68123e0249ad799972d0f41e5cd32a8e9df200f848c0e73ad8d2fddbca7", x"890def696fc04bbb9e9ed87a2a4965b896a9ae127bc0e1cc515549b88ddbcbc02647e983561cab691f7d25cf7c7eb254", x"a72f459c87fa76a55b6dbe1e0e89a441e732e151e75bc5ce2f4459ca60b80e6dbbac5d05d599677c0f2948f345705dfe", x"8f84a01d340725976a7ba1b78e8a8046285367c2741fb27fda29de5d07b9a3564ef7b909bac9429c288bccde7381f80f", x"b7efcb232d3b639921ce21e80744c293ea77e25982b609e8cc82bd3999a734ca04ca43f41d9c7c15d162e0bbc3152495", x"93655457967d1f62c3574c4bd85688c92dbdf256f3629818f8c2d75fe12acacc57b6fe78632bb22d4ac7bc1861e59fcf", x"8c016e86b7aa752edd697c022116713d6a6b61538c7e46f4d76c99c29313615ec18cd21f48d99d495db3d9ed09fe946d", x"b65e8b290bdec2fda05cd1c09f8508f662aa46d7d19556d0a4e3244b4ec20093aa37088105ea4c2b1e5b245410241445", x"95c60b5561e53cfc26d620be90f84199ffd6dd9687c1be3a547048e7cba10a0be9bb6da000e7521cbd488d0901d48ee9", x"84f43aa4e2a9d10e6590314981b5eb2a5e486c1593a4f82bc3a82b67f6ccc29652ab82a689a9454bcb6c1f9bf7a10e2b", x"a0567c8983ca672a1176222509b5285e49cc831811cff273c51e2e4d0578a06a12c912843202108c355b0e62a0701c6d", x"8c38ab2a9558ac41c6ef736a5560e5960102e92f710efac3f631367a3f6d7227e0813579f349e661116bb29b2163b296", x"a8e03a26e88e4ed03751ccf6eeed6215becbf4c2d58be27361f61d1cc4ac9b692fc6ecdb839f9b3c17f54fc2f2f4756e", x"a9a591fdd18aec8746435eeead0a54bb88e055f55e91ffdd9bc663ce0bc2937fb296034ebb959d6adcf9af94bbd2f49b", x"8db8b6e067931e8923f8c1d95fda2fa2ebe6ce17a04f420f106eaeb08e98748e3865b9e5fca18494c2359d35627c00b8", x"8c01b901e1067a89471927d911246a8b2f1284e93be9913406d7c88aba784694317e22a0a7635583dae7db45cafb73ed", x"8e0d08f5c2db6fa838784ceeca421c579f6b1f8819a17272bbf6d1cbb41c249cdaa52eb2bd2edb1bda1a55d6c2f2a445", x"a2b27f2a3f133d4f8669ddf4fccb3bca9f1851c4ba9bb44fbda1d259c4d249801ce7bd26ba0ee2ad671e447c54651f39", x"8f7dbe5a57f7b0a45b7c9d87338b8ff67ce9977e2ec669f5502e77d1be30889a7976819c45c787b279b4dd96423b3715", x"a8d15870aab9cef8e116a77ce29afab4c1ed87e5f61f7fa0166df0be48c31b5bcc2eeb76a6da1f056a5518f665443054", x"b4bf70468eff528bf8815a8d07080a7e98d1b03da1b499573e0dbbd9846408654535657062e7a87a54773d5493fc5079", x"b083c4cefb555576bb37b71f30532822cb4b1e1998e35cb00ffb80ca14e2853193c16a6756417853d4a74d625744dd76", x"a17e8874e2c59a2bdc31cc67095a271d31d5a4852ccf2a82eb7c457a3ba8c87ee5beb93a65a8f7bd04d10247e63d6b84", x"87a51e0011dd0488009baac9c611fbde01878f9cf1584ea407599742bb32ef10586d9040dae3e9800a125de54f80c047", x"8a9f7e8d45f11c4bfb0921c6008f3c79ff923452bcfa7769beb3222f1f37dcb861be979e6eae187f06cf26af05e8ee5b", x"87ac804ccfe7f1fa156b8666664a397236832569f8945e11d4688a9e43ada4d4104efb3fda750f48ef655a29357c5e7d", x"9779ca2759dbed8081f0cbbfffcb3b842ba335e3ae48a60c5e5c77c7a2a0623e4c415ec3a023cc4e216885fcbac3ce52", x"b1f43b498cba1797f9793dc794a437500c3c44a8a4b59f9125a4d358afa304fc05b88ac31ed40b6eb68f0396b60cb7cd", x"97d076617cf0a64ab3d1f030cfd72a303b6b252c0a7b96157ff7fc8af5970f00d14492c46e8f6f37caafe837d0dc95c7", x"b50c306f78143b37986e68efa10dbe1fb047d58562e9b5c5439b341dd8f1896c7ae586afac0a3213759784a905c1caaa", x"9022541f84e48b655e74bf3da484179e0e0040827fc71e777b68f19bcfd0e103d385ef957692e7091fe713561f38035c", x"a252dc9469375102f2cdeb913cd7e206e8539c472359ece98074be6abc0ccc818e57a65e8426b0485d2ed55294eb622f", x"a698b04227e8593a6fed6a1f6f6d1eafe186b9e73f87e42e7997f264d97225165c3f76e929a3c562ec93ee2babe953ed", x"889a5cf9315383bf64dfe88e562d772213c256b0eed15ce27c41c3767c048afe06410d7675e5d59a2302993e7dc45d83", x"84faf4d90edaa6cc837e5e04dc67761084ae24e410345f21923327c9cb5494ffa51b504c89bee168c11250edbdcbe194", x"8fbc274c5882666da39e7ef636a89cf36725820c8ada6eec0ab9b5af3760524b73a2173c286e155c597b4ed717d879e4", x"a2b410b66ff050ab42cb56f8037577662801043c7dfa3cd37a9aa72bb4fe3983507c17f4fb7e73ccdecf5c536b1a2cb7", x"939fb46081cbee1f4577b182ab9b8b0772c85726f5ae643748712ab87dd70349d04051f68735f3bd0b0c0c53901301c1", x"88b49b1130f9df26407ff3f6ac10539a6a67b6ddcc73eaf27fe2a18fb69aa2aff0581a5b0eef96b9ddd3cb761bdbbf51", x"966256693e9cd01d67855d9a834f39a8e7628f531e136b5113b7cdb91e17b554fcbef2611929b74710606585b1df59b5", x"94274299f0faca1152cca89282c10d00b5d3679cd4b7b02e018f653257b778262fb3c6c49d0eb83ce388869c283c3c05", x"8a9ad977988eb8d98d9f549e4fd2305348a34e6874674bcd6e467c793bba6d7a2f3c20fa44aabbf7151ca53ecb1612f6", x"a21477f0b51d73b0816b4b411c12db1e3a83698113ff9299ab2827e8da59baa85dbcc70afb831f5b0c038e0470562f00", x"912bcfe28f56098d7f75f90fa419232787905e1a26170f274d2cfeac25636a21081b07065a7f515188233575cd85cb4a", x"8ae80eeaed3fc456f8a25c2176bd09f52a2546d45d77a70f48a9e30aa29e35ff561c510ae1f64e476e4a0f330b9fdbdd", x"a85a31dbc17a20a7b814cf9a8ce96dad2349397bd5b08fdbdfcc3e71e29bfd56ad746e88f752215e2822a193cbd2749a", x"b7e74ab2b379ceb9e660087ee2160dafe1e36926dfab1d321a001a9c5adde6c60cd48c6da146d8adfa2bd33162eeaf1a", x"b298aa927713c86adfe0de1a8d6f4083b718c8be27156da9fd11abd8edb3a54a926ad487801eb39cfc9363a0a3be0d44", x"ac568059f6526440655078ae8d5c13860cb7ec82c36db744a447f98721ba5ca88aaacf377ee9dfa6dfb8313eaac49d9c", x"ad2aee9a61242235f0ef6adadd5d314b18e514083d6a589ca65cc89f505e44b480724d7659a87c95b03c62caba53f487", x"b106c6d13ca17a4c8ea599306e84918127cf2de21027ac3fe5a57d35cf6f3b1d7671c70b866f6e02168ae4e7adb56860", x"aebb24b64beafc6460ccd8445cee4a855b7656e98ba2cd11bd47c6303a243edc2cde1ddb09a9487b21db850479572b37", x"b0e8428b7feac527da3276d1eb67f978f0aa279bc16c09bd15b799059b5670e05a4e79f3278a8b9a96f46f964e8e831e", x"96791b2b8066b155de0b57a2e4b814bc9b6b7c5a1db3d2475a2183b09f9dcd9c6f273e2b0c922a23d1cf049a6ce602a3", x"83474776ef2341051b781a8feaf971915b4a1034fa30a9232c4bf4b1bd0b57bc069c72c79510acef92e75da6f6b8843d", x"b879c91e77a8c5670f5f9c12b46d182867f1de75458474388ddae4dae88eb99105ce51fa78c2e39c5eac1127873aa1e6", x"95cf2e038c790ce7a2960add7ab44804375f04ec6829f8cc63793dfe9fc48c7471079f81b932726509394fd3d46a52e9", x"9203acd34ebb3ff76268f9fe68f066a48a3f518686ae0f2230b322e19435ccfc4f208e5ba5a39cb2a409292c48a37c22", x"952cbd8e9d5e9d23139e8f3e979a89b54206188e627f8e06cdfb3e38aa5159e610629bf79713954110bfa6f450c6e55a", x"8b027c14affe47f83ee59b504d83b2fd2d9303de2c03ee59d169bb199d9f4bd6533d7f8c812dd7a6f1e8155e3e185689", x"a1c84730a5c41dcab9a5ef9e1508a48213dbc69b00c8f814baf3f5e676355fc0b432d58a23ad542b55b527a3909b3af6", x"90e5db75f3787b819df471712f87b6f3281437090f5db7a2c21b07164446292a414c687e41de2d1ca00786b093239c64", x"9267c0e9c176eefab67362ddfcd423a3986b5301c9a7c1c8c0dab93fdb15e562d343a7a9884a0a3378818b1aa1e4091a", x"85f7ae1a7a7c793c408750ddec2d7f58b985fc3cdf9fcf6b2192bc57092b8a271b2fb6ced0639baaffe0bec3203e568b", x"91013e0d537fb085a49bf1aa3b727239b3e2c1d74c0f52050ff066982d23d5ee6104e70b533047b685e8b1529a0f14dc", x"838ff6630dc3908a04c51fb44a29eca5a0d88330f48c1d0dd68b8890411a394fd728f14215482b03477d33f39645dceb", x"b59257e70ab52f5fb145d5bb518431f5c07bd01a2a8a68c8b6b3782fe27d92d093798b75286ce0b9878bfae7184a304f", x"87fec026beda4217b0a2014a2e86f5920e6113b54ac79ab727da2666f57ff8a9bc3a21b327ad7e091a07720a30c507c9", x"8eeb8a48b90bd90ccaacddd0fea54139b114e5ed4fd17f9d225c73436224393e0424b7f6028a50831b4c72c524e45c64", x"a922d48a2a7da3540dd65bda3a8b5fb1f1741604e2335de285ac814c69c40b5373d92bc1babd3e4b2d32993f251c70b5", x"a61cb5b148cb7ff34775dead8efa7d54d7141182356bf614070dfaa710ebf07a4dfb684dad151db60c0f8261c30a4f40", x"a21477f0b51d73b0816b4b411c12db1e3a83698113ff9299ab2827e8da59baa85dbcc70afb831f5b0c038e0470562f00", x"944f722d9a4879b5997dc3a3b06299182d8f68d767229220a2c9e369c00539a7a076c95f998bea86595e8ec9f1b957bb", x"b76cb8cb446eb3cb4f682a5cd884f6c93086a8bf626c5b5c557a06499de9c13315618d48a0c5693512a3dc143a799c07", x"90ab68c372fd01bb210fb94094adb27296b7144d964bb1dd807ea8f718181747356b0f9db3feda78dd7a596209099ab8", x"8289b65d6245fde8a768ce48d7c4cc7d861880ff5ff1b110db6b7e1ffbfdc5eadff0b172ba79fd426458811f2b7095eb", x"a2db08cf00d7c15736c4ea83b0747eae36789910c58519ad10374d82a502ea289a844791a26ddfab30d0b5f16c63fadb", x"a6565a060dc98e2bfab26b59aff2e494777654015c3292653ecdcefbeeebd2ce9091a4f3d1da10f0a4061f81d721f6ec", x"a575be185551c40eb8edbdb21a0df381c801b6e99467fcf5882dd7cb34916960ce47ac732c1920ad3218f497b690cef4", x"8835b63a1e61ac48bfb54c78f1d1a9371b942ea299a706d5663b3ccc574a6fd1901d0f8b4879bc3a0980443f7f0e2b17", x"b1b0502c4b25af8147220227e09f5f7ada8e44ac266c2b27389ea777614edade2e4cbde3b120e1e8fccae6ddec475e27", x"b4ef65b4c71fa20cd0ed863f43f6c652d4c35f2677bc2083f5a9808284e8bd8988703faaf0fb4cac8ecbda19541ecc65", x"8c22f1f2a530879a93e744397fa6acca57b01fb62b62188ffa7487464815c605e1520ff4bb18e832753893649ab80d62", x"b075db32979df905cef986cfcd6db823ac21dd4013cecfe088885390ff8acd18d76dec793b80db5f7779426127daed7b", x"a02883d525e251708bcecf6cfaf7d07fc5e1be92fba24ca8f805e96b7dfe385af449f5687de1dc6707a62ccb08c1d590", x"8275eb1a7356f403d4e67a5a70d49e0e1ad13f368ab12527f8a84e71944f71dd0d725352157dbf09732160ec99f7b3b0", x"88d8a32231ff2bfc39f1f9d39ccf638727b4ead866660b1b8bfbdf59c5ab4d76efddd76930eff49ea0af048b2e396b6c", x"898c4873bd356ba8015f6f686d57088fa8f79f38a187a0ef177a6a5f2bc470f263454ee63d0863b62fca37e5a0292987", x"8d74f4c192561ce3acf87ffadc523294197831f2c9ff764734baa61cbad179f8c59ef81c437faaf0480f2b1f0ba1d4c8", x"842ba3c847c99532bf3a9339380e84839326d39d404f9c2994821eaf265185c1ac87d3dc04a7f851df4961e540330323", x"a06d4fb6dd8bbbc69e792150a52a0eec8d5eedf1ee155bc3163cb0ba2003d812a031bad35eab535551e858f7683ed02d", x"944f722d9a4879b5997dc3a3b06299182d8f68d767229220a2c9e369c00539a7a076c95f998bea86595e8ec9f1b957bb", x"847b58626f306ef2d785e3fe1b6515f98d9f72037eea0604d92e891a0219142fec485323bec4e93a4ee132af61026b80", x"b284286dd815e2897bb321e0b1f52f9c917b9ef36c9e85671f63b909c0b2c40a8132910325b20a543640b01dc63b48da", x"99efc1b9c40aafca602efa4ea00d8d9dfadcd77a962c833e347a928d8d52da51fb000f673cd17dadc80e9115ba04f91e", x"a076ea1084b7a1a33115ef62d6524f36e7820579868763a6ed1f8bce468f150cbfbf0ed04be2487aaa34100d828b0db6", x"96be7deae0729f3d4bbd39b46d028a9a1e83ce863730b97e59422bb2508d88642393d544701b90bc15c33dab8e663297", x"8068da6d588f7633334da98340cb5316f61fcab31ddfca2ab0d085d02819b8e0131eb7cdef8507262ad891036280702c", x"84926cf2265981e5531d90d8f2da1041cb73bdb1a7e11eb8ab21dbe94fefad5bbd674f6cafbcaa597480567edf0b2029", x"b75ac3d5b3dad1edf40a9f6b5d8923a81872832eb3a38e515539cec871a353b07cb477f6d55cf15ba2815a70458aac32", x"a5c225b7bd946deb3e6df3197ce80d7448785a939e586413208227d5b8b4711dfd6518f091152d2da53bd4b905896f48", x"a1304f46f9f1ea67ce613ae845d9ab8b5ba8b65e9c9a672a47105e2ca3d096924091e6d4c3580535da28c210369980ab", x"b6af60217014d472e508dd5a1a3c2089f18553a7fe97f5a572c3f738f23a00af6405b40373a438501b0b2d893aaa48c1", x"85b7ac279df87035b63aea300f6c751b84d299a78788123aba08ba26edc6f8c7352baac4f471d6f4bb6c45428e661249", x"94ffda31c9e7cca085dd988092d72e5ae78befbb14a85179fac7bcd6e89628a8f70f586c1fedd81be34d8577a0f66fd7", x"a8f2572a2cc2ecba151a3d5f4040a70172067ddadd8c12ba9d60f993eb0eab6698cb35932949c9a42e45b36a822af40e", x"978eef234c9d553ed5d83fdd49982e30bd162620b29a5d9c2b70d7ff44345acb9b72d0cbb1fc7d8dfe20a56e0f8c5f04", x"80e09f3bf3ea87d48e04b53d8f3b43b7e53d61f445f8c8a5a35472b84f6bb4f58f17d9832f5881bb44fc06156151e5c5", x"898deb30ede570d391266c81132a78239083aa9e27a9068e26a3bc14ff6468c3f2423484efb2f808b4996c16bfee0932", x"8be8d356bbf35ccd5980848662b5d6361eef583b535da90cef6c07904ccfb5963aaa230ac30ad63441f60e807434497f", x"941cd102228aa81ef99506313a4492a17c506e7169808c6b14dd330164e9e8b71b757cbe6e1bb02184372a8c26f7ad1f", x"b80e8516598c59dddcf13fdb7a42d8f5a52c84e01bd6a39880f4acaefe8e4b8f09cc1b1a2423cd5121f4952201f20078", x"a23710308d8e25a0bb1db53c8598e526235c5e91e4605e402f6a25c126687d9de146b75c39a31c69ab76bab514320e05", x"b7d1d1edc5e72c11b55aa0aa85d3aacc38db925c0d30b082c7c47d39459b8ff2e7f969a754c814ac2a3e7c42a8885792", x"a2ee6c29efa982e9b9abd3c5e4f14b99d5d0369d7bfc3c8edae1ab927398dc8a147a89e127b3324d7f4e3a7494c5d811", x"a59249e4dfb674dfdc648ae00b4226f85f8374076ecfccb43dfde2b9b299bb880943181e8b908ddeba2411843e288085", x"a8fd63da16dd6a4aa1532568058d7f12831698134049c156a2d20264df6539318f65ec1e1a733e0f03a9845076bb8df8", x"939fb46081cbee1f4577b182ab9b8b0772c85726f5ae643748712ab87dd70349d04051f68735f3bd0b0c0c53901301c1", x"878156b5b59032dd2741bccd4a61040c5698c99ad7a286365c87fc888b5ac839143325c9d379eb7c91396d2c60059e94", x"8cd9d7e953c7ae07ee785d68a999e702565960d376692d9ea468556ad141229b1f3bc97926818c078901f73ecc578e93", x"8784a8fa62e0ce23283386175007bb781a8ec91b06fd94f22a20cd869929de37259847a94a0f22078ab14bb74709fac6", x"87ca4fa85a257adf7e21af302437e0fa094e09efced2d7ebab6cf848e6a77ae7bfc7cf76079117f6ed6eded9d79ce9cb", x"a06d4fb6dd8bbbc69e792150a52a0eec8d5eedf1ee155bc3163cb0ba2003d812a031bad35eab535551e858f7683ed02d", x"aee36de701879ca9d4f954e3ecdb422842fccd72930ff09977705d8da9282284b160b6485319d1e48259b984c5e38700", x"93be3d4363659fb6fbf3e4c91ac25524f486450a3937bc210c2043773131f81018dbc042f40be623192fbdd174369be2", x"a131f61a215d689938b1997ec40357b939bd2a2565df04cea7800674e23ba068d0ce28bad32f49f3099434f34445eb4a", x"99efc1b9c40aafca602efa4ea00d8d9dfadcd77a962c833e347a928d8d52da51fb000f673cd17dadc80e9115ba04f91e", x"8df72e18449c871578601cf6bb8e0a5ecad7bc5fef4fd5838d49afb47f6bf3b241d709dbe5681ec881933a8c71d895f4", x"948dcd311147fcb8b28044e66d51d082e921db4183cf3fc42ae46becb9a12e7cc5c32c27d12f6d40d7d73a74f6bb6615", x"91efdbcaad9931312d7c41d24de977f94d7f3f7b88090a1f72d9a097a1e30cc805c5ea16180f463022d9b26b8863f958", x"b7eb6a49bf8f942dd8c37c41c1b35df43e4536e07ca9f4c1cfbbf8a8c03f84c54c1a0d8e901c49de526900aeac0f922f", x"9722c1079db7e2e1c49756288a02302b43b8fd92d5671585ac1ea7491123742a2744a526c12c9a0b4c4a80f26342a3a6", x"921b2546b8ae2dfe9c29c8bed6f7485298898e9a7e5ba47a2c027f8f75420183f5abdcfe3ec3bb068c6848d0e2b8c699", x"ab6366a7c6da8ca8ea43a3479e50ecf9a1f3b20ec01b8eae1d2a21ba2223a4ce62615836377c6395580a079c284947d3", x"b0a4c136fb93594913ffcebba98ee1cdf7bc60ad175af0bc2fb1afe7314524bbb85f620dd101e9af765588b7b4bf51d0", x"b8233d647876eafe2746c10c1b41d99beea28b2627ea2ecb67a3eb0d166fadbceee34dfe942aa4ecf39e0d55f9d6d2a6", x"9779ca2759dbed8081f0cbbfffcb3b842ba335e3ae48a60c5e5c77c7a2a0623e4c415ec3a023cc4e216885fcbac3ce52", x"8548774c52eb42b88c53d9d07498eb8a3bd087a48316f7ed309b47e009daac3eb06b9cb5eebfa6a9f54042f4a5fd3923", x"a69f0a66173645ebda4f0be19235c620c1a1024c66f90e76715068804b0d86a23dc68b60bca5a3e685cce2501d76de97", x"8c03fb67dd8c11034bd03c74a53a3d55a75a5752ea390bd2e7f74090bf30c271541b83c984d495871d32c98018088939", x"b07447c7e87459315fcbda3fb86fef27f98373b1246e2ce367e26afd87f6d698a438501fdc13cc5de9eef8d545aab768", x"811bfea6251af745d42ef3cffca201514ac9d07257e6e8afd24f20b98e2fcfbe1d45465306a6f501f32da6c3beb52fbe", x"b907ec84b6ae5729d36e2acd585a350acacdeef148bcc5dc4a91edb57505526462bd4371574865541d8bb0d786a29b2f", x"91f870f372e11a473cd0e1265c2675721413d4910f6edf5433a5d8b7f6b7d0c1780b5fa8651fa7966b55bf59cb0e61fd", x"a4822712ef5eb5ea82b7e3996eefff5f5eb75770e37e1117e3e6191e9aac860f13cbd804f6b15464fbb0d7f198e0ad59", x"b549cef11bf7c8bcf4bb11e5cdf5a289fc4bf145826e96a446fb4c729a2c839a4d8d38629cc599eda7efa05f3cf3425b", x"a02883d525e251708bcecf6cfaf7d07fc5e1be92fba24ca8f805e96b7dfe385af449f5687de1dc6707a62ccb08c1d590", x"871656153e1f359ea1cf77914a76de34b77cb62e670c99f3584e7cb2c500c04f65f36bcb5321f4630df5c3de9245a7c0", x"a14d8d3f02de36328f3f55ac45331baafe5ba3611bd8b362464d69742b214cb703f37b5f39ed1b23cdcf0bf3eb90a81e", x"a52c15840b89d92897d1e140b2b8468a88886c5e1092861e598b3a433b340ded5b35b3d632a9879820fd56f20ca3a68b", x"a3dadaba6ece9270cf95211b26a14e6eb09b5d4fbca3d6e47dc498145a46ed161df74ed83a6f81246eea1d0408957dd0", x"b8fdf21b57d1d5eecd93f76c37230d379b652dcd9026a158151adc38c7ee4273cc2b99e47b89ec05f57dafdcaa7a3b4e", x"8fb51e3ef3c1047ae7c527dc24dc8824b2655faff2c4c78da1fcedde48b531d19abaf517363bf30605a87336b8642073", x"971997a5c2bbce1e8e1520da7cc84d59d6973773e541758486856856082bfba0dfc3f8ee578c69a4412b74a5fa7c808c", x"a4cfe97f6e61e45577ed6ce6eb7d1d9aca9e323b79b30736b407000555bf3e2ecbffd6314585b09000f09ee8381903af", x"a7d76c88daa3ba893d4bd023e039e1f587565d317609cc9ddce73f2d3c4d6d9facee20fca31c85322f10fdf15267fbec", x"952a95612aecce4321d2c17aabd2fb260b1cb41df5f76f5b82b46cf818d7a4f18e5e2944cddcd2280a993c0af4f834fe", x"825aca3d3dfa1d0b914e59fc3eeab6afcc5dc7e30fccd4879c592da4ea9a4e8a7a1057fc5b3faab12086e587126aa443", x"86cef0506d35ac8afa7509561aa90bbc89663f7f880a86b0aa838464a33a36f27808cd8b68fa6f729e6eede4ab0583da", x"a5bf4aae622b58a37e722c3d1322b402907f10eec372a42c38c027b95f8ceba0b7b6f9b08956b9c3fdfedaa83d57a217", x"a3d327f48eb34998a3b19a745bca3fade6a71360022c9180efb60d5a6f4126c3f4dfa498f45b9a626ca567fdd66ffbff", x"a6d9f67ca319ea9de50c3fed513269b83fa067977adfd1e9d9ee07ad61b2ac1de64a39d7b6897ab55870cf982fe481dd", x"b1f43b498cba1797f9793dc794a437500c3c44a8a4b59f9125a4d358afa304fc05b88ac31ed40b6eb68f0396b60cb7cd", x"895ebab1992f6a81ec82efb291d7daba11fb231edf67fc1a8415b5fffdc03b10e86af93d4a7ffd1fb9735102b7ad7ce3", x"a8bca02be739bd66e9d5a92504d47c6a5208b2fb6a43a4a53b73f675c4e725765bbfca098260328ee3b24c64a82d22db", x"b9cd71ebd50b024e32558ab1ddbb50c222503492e5c9e1d282731948c0b59458fbd85cac56bab0ba47a4c6dec8549c5f", x"80d492fbdbe9d5fcd08fe962b3ce2b9c245c068f686c4838f57db5b4e8b1bfc729c98e93dd4e5cc78b661845d7459809", x"8e956ca6050684b113a6c09d575996a9c99cc0bf61c6fb5c9eaae57b453838821cc604cf8adb70111de2c5076ae9d456"
        ];
        let next_sync_committee_aggregate_public_key =
            x"a4bc0eb7710d4b599b78eeb3699774bd9e7a6ca72e000815e431083e9b647f4c6f50aae38fa4704f6cd4302375d6bc43";
        let next_committee_merkle_proof = vector[
            x"8a3cf954af4917143ac442452cdb962795c14ffd43aeb859bf764ac128c94c67",
            x"3bc5effd77b839ac333434746ea00933bddf4b5b1020196fd3b33d148bfc2bc1",
            x"3e90e10ea4e387d4e2375e0454cb4e14fcb19954b56b0de9dcb11377843ac076",
            x"b2d1fc93223cf847b078440f4874aa42be11e9028816dcb28f38af14ddd0a986",
            x"678de547ff6e3e5358d8432c00b362f9c6f7f755e1fc446dc064fbb7b4f814e1",
            x"b83fd15f77764c922f7289fc7f438eb58651ef588f2dac66333f3d6632edc154"
        ];
        let finalized_header_slot = 7159808;
        let finalized_header_proposer_index = 1431;
        let finalized_header_parent_root =
            x"3bfce9e9a473515bf926152bdf11f2b79bfbcac3cc94eaeffcead18a65ae78a8";
        let finalized_header_state_root =
            x"8bd5949b8a7811d0e4fbfd1d411bde7d399f92640e89e0c9e2220a26736c423b";
        let finalized_header_body_root =
            x"d08a98f8285f9461f2ac868f3ee52c5efd9ddac6ef93f15a49c5004517591cd1";
        let finality_merkle_proof = vector[
            x"006a030000000000000000000000000000000000000000000000000000000000",
            x"76079561d1557730adc1508ffea1152d1943b7fc81f94e0224cd46c87dc3e511",
            x"920c391726624169471fc7b64a78926333a88f5cd2d91b2f7d935071d2c083aa",
            x"3e90e10ea4e387d4e2375e0454cb4e14fcb19954b56b0de9dcb11377843ac076",
            x"b2d1fc93223cf847b078440f4874aa42be11e9028816dcb28f38af14ddd0a986",
            x"678de547ff6e3e5358d8432c00b362f9c6f7f755e1fc446dc064fbb7b4f814e1",
            x"b83fd15f77764c922f7289fc7f438eb58651ef588f2dac66333f3d6632edc154"
        ];
        let sync_committee_bits = vector[
            true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, false, true, false, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, false, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, false, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, true, false, false, true, true, false, true, true, false, true, true, true, true, true, false, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, false, true, false, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, false, true, false, true, true, true, false, true, false, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, true
        ];
        let sync_committee_signature =
            x"a5a6b7635969734a3ea6c000cf115967b28ab2b5e128ce28db6b64b77675b8992d353a00352518a4cd7766c5d74c7e9a1936290c7cf64d9bb701d99b677172f2dc4cad21bdd4009e073f502f3e86b0954a2834e8a26aa279fa34f7d9b5f3a8ec";
        let signature_slot = 7159873;
        add_or_update_hypernova_config(test_account, 155500, 1000, 1000, 10);
        // set_hypernova_pause_state(test_account, false);
        initial_sync_committee_update(
            test_account,
            attested_slot,
            attested_header_proposer_index,
            attested_header_parent_root,
            attested_header_state_root,
            attested_header_body_root,
            next_sync_committee_public_keys,
            next_sync_committee_aggregate_public_key,
            next_committee_merkle_proof,
            finalized_header_slot,
            finalized_header_proposer_index,
            finalized_header_parent_root,
            finalized_header_state_root,
            finalized_header_body_root,
            finality_merkle_proof,
            sync_committee_bits,
            sync_committee_signature,
            signature_slot
        );

        sync_committee_update(test_account);
        sync_committee_update(test_account);
        let lv = get_light_client_store();
        let (
            _update_slot ,
            _current_sync_committee_pubkeys,
            _current_sync_committee_aggregate_pubkey ,
            next_sync_committee_pubkeys ,
            next_sync_committee_aggregate_pubkey
        ) = test_get_light_client_view(lv);

        // assert!(last_update_slot == finalized_header_slot, 11);
        assert!(option::is_some(&next_sync_committee_pubkeys), 11);
        assert!(option::is_some(&next_sync_committee_aggregate_pubkey), 11);
        assert!(
            coin::balance<SupraCoin>(signer::address_of(test_account)) == 1172777,
            33
        );
    }


    #[test(test_account = @0xdead, user = @0x1)]
    #[expected_failure]
    fun test_process_light_client_finality_update_EINVALID_FINALITY_PROOF(
        test_account: &signer, user: &signer
    ) {
        set_time_has_started_for_testing(user);
        update_global_time_for_test_secs(1741902303);
        test_init_module_init(test_account, user);
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

        test_initialize_light_client_store_v2(
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
        test_initialize_step();
        test_initialize_step();
        test_initializer_scratch_space_not_exists(test_account);
        // 1739871702

        let opt = get_finality_update_data_EINVALID_FINALITY_PROOF(false);
        test_process_light_client_finality_update(&mut opt);
    }

    #[test]
    #[expected_failure]
    fun test_construct_sync_committee_EINVALID_SYNC_COMMITTEE_SIZE() {
        let public_keys = vector[
            x"932d72ae4952031f9070b1d7cc2e827e06eb606e0e10594d19f56d9460cb5d1675bb3e19ce5752512e3bec256a0d88bf",
            x"932d72ae4952031f9070b1d7cc2e827e06eb606e0e10594d19f56d9460cb5d1675bb3e19ce5752512e3bec256a0d88bf"
        ];
        let aggregate_pubkey =
            x"932d72ae4952031f9070b1d7cc2e827e06eb606e0e10594d19f56d9460cb5d1675bb3e19ce5752512e3bec256a0d88bf";
        let aggregate_pubkey_option = public_key_from_bytes(aggregate_pubkey);

        let _ = test_construct_sync_committee(
            test_convert_public_key_from_bytes_with_pop(public_keys),
            option::extract(&mut aggregate_pubkey_option)
        );
    }


    ////message_types
    #[test]
    fun test_rlp() {
        let expected = vector[
            2, 249, 2, 236, 1, 131, 164, 170, 124, 185, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 1, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8,
            0, 0, 0, 0, 32, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 249, 1, 225, 249, 1, 222, 148, 114, 89,
            231, 82, 229, 18, 53, 74, 136, 107, 103, 115, 127, 92, 211, 142, 138, 143, 164,
            23, 248, 132, 160, 98, 83, 196, 35, 154, 35, 89, 48, 196, 89, 122, 64, 118,
            204, 131, 81, 54, 42, 42, 129, 7, 164, 172, 222, 181, 226, 247, 174, 175, 184,
            126, 73, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226, 121, 78, 30, 247, 212,
            172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193, 57, 241, 12, 160, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 185, 1, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 226, 121, 78, 30, 247, 212, 172, 134, 80,
            106, 89, 71, 161, 240, 243, 66, 193, 57, 241, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 226, 121, 78, 30, 247, 212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66,
            193, 57, 241, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 110, 111, 116, 104, 105, 110, 103, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 224, 182, 179,
            167, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 1, 99, 69, 120, 93, 138, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            226, 121, 78, 30, 247, 212, 172, 134, 80, 106, 89, 71, 161, 240, 243, 66, 193,
            57, 241, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 103, 181, 169, 96
        ];
        // print(&test_decode(&mut expected));
        let _opt_logs = test_decode(&mut expected);
        let x =
            x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000100000000000000000000000000e2794e1ef7d4ac86506a5947a1f0f342c139f10c000000000000000000000000e2794e1ef7d4ac86506a5947a1f0f342c139f10c00000000000000000000000000000000000000000000000000000000000000016e6f7468696e67000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000000016345785d8a0000000000000000000000000000e2794e1ef7d4ac86506a5947a1f0f342c139f10c0000000000000000000000000000000000000000000000000000000067b5a960";
        let _offset = vector::slice(&mut x, 0, 64);
        // debug_str(&b"offset");
        // print(&offset);
        let _senderAddr = vector::slice(&mut x, 64, 96);
        // debug_str(&b"senderAddr");
        // print(&senderAddr);
        let _tokenAddress = vector::slice(&mut x, 96, 128);
        // debug_str(&b"tokenAddress");
        // print(&tokenAddress);
        let chain_id = vector::slice(&mut x, 128, 160);
        vector::reverse(&mut chain_id);
        // debug_str(&b"chain_id");
        // print(&(to_u256(chain_id) as u64));
        let payload = vector::slice(&mut x, 160, 192);
        vector::reverse(&mut payload);
        // debug_str(&b"payload");
        // print(&payload);
        let amount = vector::slice(&mut x, 192, 224);
        vector::reverse(&mut amount);
        // debug_str(&b"amount");
        // print(&amount);
        // print(&(to_u256(amount) as u64));
        let currentFee = vector::slice(&mut x, 224, 256);
        vector::reverse(&mut currentFee);
        // debug_str(&b"currentFee");
        // print(&currentFee);
        // print(&(to_u256(currentFee) as u64));
        let _receiverAddr = vector::slice(&mut x, 256, 288);
        // debug_str(&b"receiverAddr");
        // print(&receiverAddr);
        let timestamp = vector::slice(&mut x, 288, 320);
        vector::reverse(&mut timestamp);
        // debug_str(&b"timestamp");
        // print(&timestamp);
        // print(&to_u256(timestamp));
    }

    #[test]
    fun test_rlp_new_data() {
        let receipt: vector<u8> = vector[
            2, 249, 3, 163, 1, 132, 1, 16, 152, 55, 185, 1, 0, 0, 0, 4, 0, 0, 0, 0, 16, 8,
            0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 16, 0, 0, 4, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0, 0, 8, 0, 0,
            0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64, 0, 4, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 128, 4,
            32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 1, 0, 0, 0, 0, 8,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 17, 0, 0, 0, 0, 4, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0, 0, 249, 2, 151, 248, 122, 148,
            255, 249, 151, 103, 130, 212, 108, 192, 86, 48, 209, 246, 235, 171, 24, 178,
            50, 77, 107, 20, 248, 66, 160, 225, 255, 252, 196, 146, 61, 4, 181, 89, 244,
            210, 154, 139, 252, 108, 218, 4, 235, 91, 13, 60, 70, 7, 81, 194, 64, 44, 92,
            92, 201, 16, 156, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 44, 160, 124, 40,
            29, 115, 119, 194, 236, 136, 194, 62, 157, 52, 219, 41, 15, 182, 34, 61, 160,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3,
            141, 126, 164, 198, 128, 0, 248, 56, 148, 44, 160, 124, 40, 29, 115, 119, 194,
            236, 136, 194, 62, 157, 52, 219, 41, 15, 182, 34, 61, 225, 160, 93, 66, 62,
            153, 21, 223, 97, 191, 184, 26, 27, 45, 67, 233, 213, 239, 57, 217, 117, 97,
            206, 166, 188, 136, 177, 5, 82, 130, 9, 220, 226, 102, 128, 249, 1, 222, 148,
            83, 12, 210, 207, 131, 176, 67, 85, 118, 15, 133, 195, 42, 9, 20, 151, 166, 0,
            95, 192, 248, 132, 160, 16, 111, 160, 19, 230, 138, 248, 163, 247, 229, 181,
            95, 51, 25, 222, 247, 190, 242, 210, 201, 239, 77, 191, 241, 138, 251, 255,
            109, 213, 254, 76, 115, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 17, 112, 236,
            44, 103, 113, 48, 159, 126, 170, 66, 160, 77, 216, 116, 235, 130, 36, 66, 25,
            160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 7, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 185, 1, 64, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 18, 220, 226, 44, 186, 55,
            253, 127, 171, 241, 18, 22, 232, 167, 158, 30, 74, 0, 233, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 255, 249, 151, 103, 130, 212, 108, 192, 86, 48, 209, 246, 235,
            171, 24, 178, 50, 77, 107, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 170, 54, 167, 104, 101, 108, 108, 111,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            3, 141, 126, 160, 11, 154, 246, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 39, 67, 92, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 147, 161, 174, 246,
            109, 217, 125, 77, 67, 149, 71, 222, 140, 242, 157, 133, 242, 228, 101, 70, 63,
            198, 58, 96, 180, 130, 25, 57, 198, 49, 203, 150, 85, 231, 162
        ];

        let extracted_logs = test_decode(&mut receipt);
        let verified_log = test_get_log(&extracted_logs, 2);
        let x = *get_data(&verified_log);
        // let x =  x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000612dce22cba37fd7fabf11216e8a79e1e4a00e900000000000000000000000000fff9976782d46cc05630d1f6ebaa18b2324d6b14000000000000000000000000000000000000000000000000aa36a768656c6c6f00000000000000000000000000000000000000000000000000000000000000038d7ea00b9af60000000000000000000000000000000000000000000000000327435c0000000000000000000000000000000000000000000000000197a1aef66dd97d4d439547de8cf29d85f2e465463fc63a60b4821939c631cb9655e7a2";
        let _offset = vector::slice(&mut x, 0, 64);
        // debug_str(&b"offset");
        // print(&offset);
        let _senderAddr = vector::slice(&mut x, 64, 96);
        // debug_str(&b"senderAddr");
        // print(&senderAddr);

        let _tokenAddress = vector::slice(&mut x, 96, 128);
        // debug_str(&b"tokenAddress");
        // print(&tokenAddress);
        let chain_id = vector::slice(&mut x, 128, 160);
        // print(&chain_id);
        vector::reverse(&mut chain_id);
        // // debug_str(&b"chain_id");
        // print(&(from_bcs::to_u256(chain_id) as u64));
        let _payload = vector::slice(&mut x, 160, 192);
        // // vector::reverse(&mut payload);
        // // debug_str(&b"payload");
        // print(&payload);
        let finalAmount = vector::slice(&mut x, 192, 224);
        // print(&finalAmount);
        vector::reverse(&mut finalAmount);
        // // debug_str(&b"amount");
        //
        // print(&(from_bcs::to_u256(finalAmount) as u64));
        let feeCutToService = vector::slice(&mut x, 224, 256);
        // print(&feeCutToService);
        vector::reverse(&mut feeCutToService);

        // print(&(from_bcs::to_u256(feeCutToService)as u64));

        let relayerReward = vector::slice(&mut x, 256, 288);
        // print(&relayerReward);
        vector::reverse(&mut relayerReward);

        // print(&(from_bcs::to_u256(relayerReward)as u64));
        let _receiverAddr = vector::slice(&mut x, 288, 320);
        // debug_str(&b"receiverAddr");
        // print(&receiverAddr);
    }

    #[test]
    fun test_message() {
        let msg_id = vector[0x1, 0x2, 0x3];
        let source_chain_id = 1;
        let source_hn_address: address = @0x123;
        let destination_chain_id = 2;
        let destination_hn_address: address = @0x456;
        let log_hash = vector[0xA, 0xB, 0xC];
        let log_index: u64 = 100;
        let msg =
            test_construct_message(
                msg_id,
                source_chain_id,
                source_hn_address,
                destination_chain_id,
                destination_hn_address,
                log_hash,
                log_index
            );
        assert!(*test_get_msg_id(&msg) == msg_id, 1);
        assert!(test_get_source_chain_id(&msg) == 1, 2);
        assert!(test_get_source_hn_address(&msg) == @0x123, 3);
        assert!(test_get_destination_chain_id(&msg) == 2, 4);
        assert!(test_get_destination_hn_address(&msg) == @0x456, 5);
        assert!(*test_get_log_hash(&msg) == log_hash, 6);
        assert!(test_get_log_index(&msg) == 100, 7);
    }


    #[test]
    #[expected_failure]
    fun test_advance_invalid_count() {
        let b = vector[1, 2, 3];
        let mut_b = b;
        test_advance(&mut mut_b, 5);
    }

    #[test]
    fun test_rlp_encode_u64_zero() {
        let encoded = test_rlp_encode_u64(0);

        assert!(vector::length(&encoded) == 1, 0);
        assert!(*vector::borrow(&encoded, 0) == 0x80, 1);
    }

    #[test]
    #[expected_failure]
    fun test_decode_invalid_rlp_type_empty_list() {
        let data = vector::singleton(0xC0);
        let _ = test_decode(&mut data);
    }

    #[test]
    #[expected_failure]
    fun test_decode_invalid_receipt_type() {
        let data = vector::singleton(4); // invalid typed receipt (only 0-3 allowed)
        let _ = test_decode(&mut data);
    }
}
