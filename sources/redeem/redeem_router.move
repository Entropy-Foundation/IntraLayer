/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
/// Router to execute redemption of iAssets into their underlying token
///
module dfmm_framework::redeem_router {
    use aptos_std::object::{Object};
    use aptos_std::error;

    use supra_framework::fungible_asset::{Metadata};
    use supra_framework::chain_id;
    use supra_framework::event;

    use dfmm_framework::asset_config as config;
    use dfmm_framework::asset_pool;
    use dfmm_framework::asset_util;

    // Obsolete event. Poel::RedeemEvent is used instead
    #[event]
    struct IAssetRedeemedEvent has copy, drop, store {
        asset: Object<Metadata>,
        amount: u64,
        destination: address,
    }

    /// nothing to redeem
    const ENOTHING_TO_REDEEM: u64 = 11;
    /// asset pool doesn't have enough tokens
    const ENOT_ENOUGH_FUNDS_IN_POOL: u64 = 12;
    /// not supported scenario for redeem
    const EREDEEM_EXTERNAL: u64 = 13;

    friend dfmm_framework::poel;


    /// redeem an iAsset into its origin asset, either a Supra-native fungible asset or an external token via bridge
    public (friend) fun redeem_iasset(
        origin_token_address: vector<u8>, // origin token address
        origin_token_chain_id: u64,  // origin chain id
        _source_bridge_address: vector<u8>, // source bridge, need to reserve this param
        amount: u128, destination: vector<u8>) {

        assert!(amount > 0, error::invalid_state(ENOTHING_TO_REDEEM));
        let chain_id = (chain_id::get() as u64);
        // supra network or not
        if (origin_token_chain_id == chain_id) {
            let amount64 = (amount as u64);
            // address validation is needed here as well
            let asset = asset_util::get_fa_metadata(origin_token_address); // origin asset
            let destination = asset_util::get_address_from_key(destination);

            // ensure the pool has sufficient balance
            let (balance, _, _) = asset_pool::get_fa_pool_details(asset);
            assert! (balance >= amount64, error::invalid_state(ENOT_ENOUGH_FUNDS_IN_POOL));
            config::assert_withdraw_fa(asset); // prevent withdraw if not allowed

            // withdraw the assets 
            asset_pool::withdraw_fa(asset, amount64, destination);

        } else {
            // It is an external coin
            // emit an event to HyperNova, but it is not supported now
            abort error::invalid_state(EREDEEM_EXTERNAL)
        }
    }

    #[test_only]
    friend dfmm_framework::redeem_router_test;

}
