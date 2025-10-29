/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
#[test_only]
module dfmm_framework::evm_hypernova_adapter_test  {
    use supra_framework::chain_id;
    use supra_framework::block;
    use dfmm_framework::config;
    use dfmm_framework::iAsset;
    use dfmm_framework::poel;
    use dfmm_framework::evm_hypernova_adapter;
    use dfmm_framework::test_util;
    use aptos_std::signer;
    use supra_framework::account;
    use supra_framework::coin;
    use supra_framework::supra_coin;
    use supra_framework::timestamp;
    use hypernova_core::hypernova_core;
    use hypernova_core::message_types;

    use supra_framework::reconfiguration;

    // WETH9 address, origin token address
    const ORIGIN_TOKEN_ADDRESS: vector<u8> = x"000000000000000000000000fff9976782d46cc05630d1f6ebab18b2324d6b14";
    // token bridge proxy address
    const SOURCE_BRIDGE_ADDRESS: vector<u8> = x"000000000000000000000000E618Bd4Cfeb2ddAeeE1F5139c39791a1Fd18b2D1";
    const ORIGIN_TOKEN_CHAIN_ID: u64 = 11155111;

    const IASSET_NAME: vector<u8> = b"iETH";
    const IASSET_SYMBOL: vector<u8> = b"iETH";
    const SOURCE_TOKEN_DECIMALS:u16 = 18;
    const PAIR_ID: u32 = 1; // eth

    #[test(supra = @0x1, deployer = @dfmm_framework, hypernova_core = @hypernova_core, relayer = @123)]
    fun test_hypernova(supra : &signer, deployer: &signer, hypernova_core:&signer, relayer: &signer) {
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        evm_hypernova_adapter::init_module_for_test(deployer);

        account::create_account_for_test(signer::address_of(supra));
        account::create_account_for_test(signer::address_of(deployer));
        chain_id::initialize_for_test(supra, 245);
        block::initialize_for_test(supra,1748973688);
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(1748973688);
        reconfiguration::initialize_for_test(supra);

        hypernova_core::test_only_init_module(hypernova_core);

        coin::register<supra_coin::SupraCoin>(deployer);
        coin::deposit(signer::address_of(deployer), coin::mint(50_00000000, &mint_cap)); // mint to acc


        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        iAsset::init_iAsset_for_test(deployer);
                // create ieth
        poel::create_new_iasset(
            deployer,
            IASSET_NAME,
            IASSET_SYMBOL,
            PAIR_ID,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/ethereum.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS,
            ORIGIN_TOKEN_CHAIN_ID,
            SOURCE_TOKEN_DECIMALS,
            SOURCE_BRIDGE_ADDRESS);

        assert!(iAsset::is_bridge_valid(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_BRIDGE_ADDRESS), 123);

        let logs = message_types::create_extracted_log(
            // address
            x"000000000000000000000000d687b11aefa9e22e983ab45cb777048a47bd4b81",
            // topics
            vector[
                x"106fa013e68af8a3f7e5b55f3319def7bef2d2c9ef4dbff18afbff6dd5fe4c73",
                x"000000000000000000000000e618bd4cfeb2ddaeee1f5139c39791a1fd18b2d1",
                x"0000000000000000000000000000000000000000000000000000000000010a79", //36946
                x"00000000000000000000000000000000000000000000000000000000000000f5"  // 245
            ],
            // data
            x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000100000000000000000000000000d2f24b047b3ead105885a1a99eb40fecaed66668000000000000000000000000fff9976782d46cc05630d1f6ebab18b2324d6b140000000000000000000000000000000000000000000000000000000000aa36a764666d6d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003093c2000000000000000000000000000000000000000000000000000000000000403e00000000000000000000000000000000000000000000000000000000000000df46541ee138920e00595c0af4aa04f1e248d22af6c6e90e834b13b04ce9b55cec"
        );
        evm_hypernova_adapter::process_extracted_log(signer::address_of(relayer), logs, x"e3e3fdfa3b4b43c3d688b29a6e4175b99eee00fed44b381e6d7772a8145ef907");

        // load iasset, ieth
        let iasset = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);
        // eth amount = 0.032 ETH
        // fees (+relayer rewards) = 0.032 ETH
        // [debug] "final_amount: 3183554"
        //[debug] "service_fee: 16446"
        //[debug] "relayer_reward: 223"
        let items =  iAsset::get_liquidity_table_items(iasset);
        let (_,_,_,_,_,_,preminted,_,deposited) = iAsset::deconstruct_liquidity_table_items(&items);
        assert!(preminted == 3200000, 1);
        assert!(deposited == 3200000, 1);

        //recipient_address 0x46541ee138920e00595c0af4aa04f1e248d22af6c6e90e834b13b04ce9b55cec"
        let (_, preminted_user, _, _) = iAsset::deconstruct_asset_premint(&iAsset::get_preminted_per_asset(@0x46541ee138920e00595c0af4aa04f1e248d22af6c6e90e834b13b04ce9b55cec, iasset));
        let (_, preminted_service, _, _) = iAsset::deconstruct_asset_premint(&iAsset::get_preminted_per_asset(config::get_service_fees_address(), iasset));
        let (_, preminted_relayer, _, _) = iAsset::deconstruct_asset_premint(&iAsset::get_preminted_per_asset(signer::address_of(relayer), iasset));
        
        assert!(preminted_user == 3183554, 1);
        assert!(preminted_service == 16223, 1);
        assert!(preminted_relayer == 223, 1);

        test_util::clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, hypernova_core = @hypernova_core, relayer = @123)]
    #[expected_failure(abort_code = 196612, location = evm_hypernova_adapter )] // EINVALID_EVENT_TOPICS_LENGTH
    fun test_hypernova_invalid_topics(supra : &signer, deployer: &signer, hypernova_core:&signer, relayer: &signer) {
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        evm_hypernova_adapter::init_module_for_test(deployer);

        hypernova_core::test_only_init_module(hypernova_core);

        // init pool
        config::init_for_test(deployer);
        let logs = message_types::create_extracted_log(
            // address
            x"000000000000000000000000e618bd4cfeb2ddaeee1f5139c39791a1fd18b2d1",
            // topics
            vector[
                x"6253c4239a235930c4597a4076cc8351362a2a8107a4acdeb5e2f7aeafb87e49",
                x"000000000000000000000000e618bd4cfeb2ddaeee1f5139c39791a1fd18b2d1",
            ],
            // data
            x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000100000000000000000000000000d2f24b047b3ead105885a1a99eb40fecaed66668000000000000000000000000fff9976782d46cc05630d1f6ebab18b2324d6b140000000000000000000000000000000000000000000000000000000000aa36a764666d6d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000182a700000000000000000000000000000000000000000000000000000000000003f90000000000000000000000000000000000000000000000000000000000000102fca28e9ac6e61fa5cfaf43eb7f3c5bad77b3e4e357286fd89ece436eb9821998"
        );
        evm_hypernova_adapter::process_extracted_log(signer::address_of(relayer), logs, x"e3e3fdfa3b4b43c3d688b29a6e4175b99eee00fed44b381e6d7772a8145ef907");
        test_util::clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, hypernova_core = @hypernova_core, relayer = @123)]
    #[expected_failure(abort_code = 196609, location = evm_hypernova_adapter )] // EINVALID_MESSAGE_DATA_SIZE
    fun test_hypernova_invalid_data_size(supra : &signer, deployer: &signer, hypernova_core:&signer, relayer: &signer) {
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        evm_hypernova_adapter::init_module_for_test(deployer);

        hypernova_core::test_only_init_module(hypernova_core);

        // init pool
        config::init_for_test(deployer);
        let logs = message_types::create_extracted_log(
            // address
            x"000000000000000000000000d687b11aefa9e22e983ab45cb777048a47bd4b81",
            // topics
            vector[
                x"6253c4239a235930c4597a4076cc8351362a2a8107a4acdeb5e2f7aeafb87e49",
                x"000000000000000000000000d687b11aefa9e22e983ab45cb777048a47bd4b81",
                x"0000000000000000000000000000000000000000000000000000000000009052", //36946
                x"00000000000000000000000000000000000000000000000000000000000000f5"  // 245
            ],
            // truncated data
            x"000000000000000000000000FFF9976782D46CC05630D1F6EBAB18B2324D6B140000000000000000000000000000000000000000000000000000000000aa36a748656c6c6f2100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000028db3066eac00000000000000000000000000000000000000000000000000000000000000000004d32537c4e7773cda63e2594bf2134c379b510c2dd9a68c2dfe53c7abccc61ba"
        );
        evm_hypernova_adapter::process_extracted_log(signer::address_of(relayer), logs, x"e3e3fdfa3b4b43c3d688b29a6e4175b99eee00fed44b381e6d7772a8145ef907");
        test_util::clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, hypernova_core = @hypernova_core)]
    fun test_verification_strategy_type(supra : &signer, deployer: &signer, hypernova_core:&signer) {
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        evm_hypernova_adapter::init_module_for_test(deployer);

        hypernova_core::test_only_init_module(hypernova_core);
        config::init_for_test(deployer);

        let (paused, verification_strategy_type, safety_level) = evm_hypernova_adapter::status();
        assert!(!paused, 1);
        assert!(verification_strategy_type == 3, 1);
        assert!(safety_level == 20, 1); // def

        evm_hypernova_adapter::set_verification_strategy_type(deployer, 1, 10);

        let (paused, verification_strategy_type, safety_level) = evm_hypernova_adapter::status();
        assert!(!paused, 1);
        assert!(verification_strategy_type == 1, 1);
        assert!(safety_level == 10, 1);

        test_util::clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, relayer = @123)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_verification_strategy_type_not_authorized(supra : &signer, deployer: &signer, relayer: &signer) {
        evm_hypernova_adapter::init_module_for_test(deployer);
        config::init_for_test(deployer);
        let (paused, verification_strategy_type, safety_level) = evm_hypernova_adapter::status();
        assert!(!paused, 1);
        assert!(verification_strategy_type == 3, 1);
        assert!(safety_level == 20, 1); // def
        evm_hypernova_adapter::set_verification_strategy_type(relayer, 1, 10); // error
    }

    #[test(supra = @0x1, deployer = @dfmm_framework)]
    #[expected_failure(abort_code = 196613, location = evm_hypernova_adapter )] // EPAUSED
    fun test_verification_strategy_paused(supra : &signer, deployer: &signer) {
        evm_hypernova_adapter::init_module_for_test(deployer);
        config::init_for_test(deployer);
        let (paused, verification_strategy_type, safety_level) = evm_hypernova_adapter::status();
        assert!(!paused, 11);
        assert!(verification_strategy_type == 3, 11);
        assert!(safety_level == 20, 11); // def
        evm_hypernova_adapter::set_pause(deployer, true);
        let (paused, _, _) = evm_hypernova_adapter::status();
        assert!(paused, 11);

        evm_hypernova_adapter::set_verification_strategy_type(deployer, 1, 10); // error
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, hypernova_core = @hypernova_core)]
    #[expected_failure(abort_code = 196614, location = evm_hypernova_adapter )] //EINVALID_VERIFICATION_STRATEGY_TYPE_RANGE
    fun test_verification_strategy_type_invalid_strategy(supra : &signer, deployer: &signer, hypernova_core:&signer) {
        evm_hypernova_adapter::init_module_for_test(deployer);
        config::init_for_test(deployer);
        evm_hypernova_adapter::set_verification_strategy_type(deployer, 5, 10); // error
    }

    #[test(deployer = @dfmm_framework)]
    fun test_record_executed_event_hash(deployer: &signer) {
        evm_hypernova_adapter::init_module_for_test(deployer);
        let log_hash =  x"e3e3fdfa3b4b43c3d688b29a6e4175b99eee00fed44b381e6d7772a8145ef907";
        assert!(!evm_hypernova_adapter::has_executed_event_hash(log_hash), 1);
        evm_hypernova_adapter::record_executed_event_hash_for_test(log_hash);
        assert!(evm_hypernova_adapter::has_executed_event_hash(log_hash), 1);
    }

    #[test(deployer = @dfmm_framework)]
    #[expected_failure(abort_code = 196610, location = dfmm_framework::evm_hypernova_adapter )] // EEVENT_ALREADY_EXECUTED
    fun test_record_executed_event_hash_duplicate(deployer: &signer) {
        evm_hypernova_adapter::init_module_for_test(deployer);
        let log_hash =  x"e3e3fdfa3b4b43c3d688b29a6e4175b99eee00fed44b381e6d7772a8145ef907";
        assert!(!evm_hypernova_adapter::has_executed_event_hash(log_hash), 1);
        evm_hypernova_adapter::record_executed_event_hash_for_test(log_hash);
        evm_hypernova_adapter::record_executed_event_hash_for_test(log_hash);
    }

}
