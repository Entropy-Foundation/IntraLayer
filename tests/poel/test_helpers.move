/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
#[test_only]
module dfmm_framework::poel_test_helpers {
    use aptos_std::signer;
    use dfmm_framework::config;
    use dfmm_framework::iAsset;
    use dfmm_framework::poel;
    use dfmm_framework::test_util::clean_up;
    use supra_framework::account;
    use supra_framework::fungible_asset::Metadata;
    use supra_framework::object::Object;
    use supra_framework::reconfiguration;
    use supra_framework::timestamp;
    use supra_oracle::supra_oracle_storage;

    const ORIGIN_TOKEN_ADDRESS: vector<u8> = x"e2794e1ef7d4ac86506a5947a1f0f342c139f10c";
    const SOURCE_TOKEN_DECIMALS: u16 = 8;
    const SOURCE_TOKEN_ADDRESS: vector<u8> = x"e2794e1139f10c";

    const PRICE_BTC: u128 = 100000000000000000000000; // $100k
    const PRICE_SOL: u128 = 50000000000000000000000; //  $50k
    const PRICE_ETH: u128 = 50000000000000000000000; //  $50k
    const PRICE_DOT: u128 = 50000000000000000000000; //  $50k
    const PRICE_SUP: u128 = 20000000000000000; //  $0.02

    public fun setup_env_with_users_and_assets(
        supra: &signer,
        deployer: &signer,
        supra_oracles: &signer,
        require_four_assets: bool,
    ): (
        Object<Metadata>,
        Object<Metadata>,
        Object<Metadata>,
        Object<Metadata>,
        address,
        address,
        address,
        address,
    ) {
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(100001000000);
        // oracle / time / config bootstrap
        supra_oracle_storage::init_module_for_test(supra_oracles);
        supra_oracle_storage::set_price(0, PRICE_BTC, 18);
        supra_oracle_storage::set_price(10, PRICE_SOL, 18);
        supra_oracle_storage::set_price(100, PRICE_ETH, 18);
        supra_oracle_storage::set_price(1000, PRICE_DOT, 18);
        supra_oracle_storage::set_price(500, PRICE_SUP, 18);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        reconfiguration::initialize_for_test(supra);

        config::init_for_test(deployer);
        config::set_parameters(deployer, config::get_default_min_coll(), 300, 48*60*1000, 2, 1_200,1_200,0,0,0, 1000000000, 120, 3); // 10 supra 120sec
        //config::set_parameters(deployer, 1000, 300, 48*60*1000, 3, 1000, 1000, 0,0,0, 1000000000, 120, 3); // 10 supra 120sec
        poel::init_poel_for_test(deployer);
        iAsset::init_iAsset_for_test(deployer);

        // create iBTC / iSOL /iETH/ iDOT
        poel::create_new_iasset(
            deployer,
            b"BTC",
            b"iBTC",
            0,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS,
            0,
            SOURCE_TOKEN_DECIMALS,
            SOURCE_TOKEN_ADDRESS,
        );
        poel::create_new_iasset(
            deployer,
            b"SOL",
            b"iSOL",
            10,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/ethereum.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS,
            10,
            SOURCE_TOKEN_DECIMALS,
            SOURCE_TOKEN_ADDRESS,
        );

        if (require_four_assets) {
            poel::create_new_iasset(
                deployer,
                b"ETH",
                b"iETH",
                100,
                b"https://qa-supra-nova-ui.supra.com/images/currency-icons/ethereum.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
                ORIGIN_TOKEN_ADDRESS,
                100,
                SOURCE_TOKEN_DECIMALS,
                SOURCE_TOKEN_ADDRESS,
            );
            poel::create_new_iasset(
                deployer,
                b"DOT",
                b"iDOT",
                1000,
                b"https://qa-supra-nova-ui.supra.com/images/currency-icons/dot.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
                ORIGIN_TOKEN_ADDRESS,
                1000,
                SOURCE_TOKEN_DECIMALS,
                SOURCE_TOKEN_ADDRESS,
            );
        };

        let asset_btc = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, 0);
        let asset_sol = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, 10);

        let asset_eth = asset_btc;
        let asset_dot = asset_sol;

        if (require_four_assets) {
            asset_eth = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, 100);
            asset_dot = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, 1000);
        };

        // two dummy users
        let user1 = @0x71;
        let user2 = @0x72;
        let user3 = @0x73;
        let user4 = @0x74;
        account::create_account_for_test(user1);
        account::create_account_for_test(user2);
        account::create_account_for_test(user3);
        account::create_account_for_test(user4);

        clean_up(burn_cap, mint_cap);

        if (require_four_assets) {
            (asset_btc, asset_sol, asset_eth, asset_dot, user1, user2, user3, user4)
        } else {
            (asset_btc, asset_sol, asset_btc, asset_sol, user1, user2, user3, user4)
        }
    }

    public fun setup_btc_eth(
        supra: &signer,
        deployer: &signer,
        supra_oracles: &signer,
        btc_price_value: u128,
        eth_price_value: u128,
        supra_priva_value: u128
    ): (
        Object<Metadata>,
        Object<Metadata>,
    ) {
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(100001000000);
        supra_oracle_storage::init_module_for_test(supra_oracles);
        supra_oracle_storage::set_price(0, btc_price_value, 18);
        supra_oracle_storage::set_price(1, eth_price_value, 18);
        supra_oracle_storage::set_price(500, supra_priva_value, 18);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        reconfiguration::initialize_for_test(supra);

        config::init_for_test(deployer);

        poel::init_poel_for_test(deployer);
        iAsset::init_iAsset_for_test(deployer);

        let btc_token = x"e2794e1ef7d4ac86506a5947a1f0f342c139f10c";
        let eth_token = x"e2794e1ef7d4ac86506a5947a1f0f342c139f30c";
        let bridge = x"e2794e1139f10c";

        // create iBTC / iSOL /iETH/ iDOT
        poel::create_new_iasset(
            deployer,
            b"BTC",
            b"iBTC",
            0, // pair
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            btc_token,
            11155111, // chain
            18,
            bridge,
        );
        poel::create_new_iasset(
            deployer,
            b"ETH",
            b"iETH",
            1, // pair
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/ethereum.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            eth_token,
            11155111, // chain
            18,
            bridge,
        );

        let asset_btc = iAsset::get_iasset_metadata(btc_token, 11155111);
        let asset_eth = iAsset::get_iasset_metadata(eth_token, 11155111);

        clean_up(burn_cap, mint_cap);

        (asset_btc, asset_eth)
        
    }

    public fun setup_usdt_eth(
        supra: &signer,
        deployer: &signer,
        supra_oracles: &signer,
        usdt_price_value: u128,
        eth_price_value: u128,
        supra_priva_value: u128
    ): (
        Object<Metadata>,
        Object<Metadata>,
    ) {
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(100001000000);
        supra_oracle_storage::init_module_for_test(supra_oracles);
        supra_oracle_storage::set_price(999999, usdt_price_value, 8);// usdt, 999999 means no oracle
        supra_oracle_storage::set_price(1, eth_price_value, 18); // eth
        supra_oracle_storage::set_price(500, supra_priva_value, 18);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        reconfiguration::initialize_for_test(supra);

        config::init_for_test(deployer);

        poel::init_poel_for_test(deployer);
        iAsset::init_iAsset_for_test(deployer);

        let usdt_token = x"e2794e1ef7d4ac86506a5947a1f0f342c139f10c";
        let eth_token = x"e2794e1ef7d4ac86506a5947a1f0f342c139f30c";
        let bridge = x"e2794e1139f10c";

        poel::create_new_iasset(
            deployer,
            b"USDT",
            b"iUSDT",
            999999, // pair
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/usdt.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            usdt_token,
            11155111, // chain
            6,
            bridge,
        );
        poel::create_new_iasset(
            deployer,
            b"ETH",
            b"iETH",
            1, // pair
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/ethereum.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            eth_token,
            11155111, // chain
            18,
            bridge,
        );

        let asset_usdt = iAsset::get_iasset_metadata(usdt_token, 11155111);
        let asset_eth = iAsset::get_iasset_metadata(eth_token, 11155111);

        clean_up(burn_cap, mint_cap);

        (asset_usdt, asset_eth)
        
    }

}