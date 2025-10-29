/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
/// This module serves as a router for interacting with asset pools
///
module dfmm_framework::asset_router {

    use aptos_std::signer;
    use aptos_std::error;
    use aptos_std::object::{Self, Object, ExtendRef};
    use aptos_std::smart_table::{Self, SmartTable};

    use supra_framework::fungible_asset::{Metadata};
    use supra_framework::chain_id;
    use supra_framework::timestamp;
    use supra_framework::event::{Self};

    use dfmm_framework::config;
    use dfmm_framework::asset_config;
    use dfmm_framework::asset_pool;
    use dfmm_framework::asset_util;
    use dfmm_framework::poel;
    use dfmm_framework::iAsset;

    const STORAGE_SEED: vector<u8> = b"AssetRouterStorage";

    /// Not enough funds
    const EPOOL_INSUFFICIENT_FUNDS: u64 = 1;
    /// Withdraw request is not registered
    const EWITHDRAW_REQ_MISSED: u64 = 2;
    /// Thrown when insufficient time has passed
    const ENOT_ENOUGH_TIME_PASSED: u64 = 3;
    /// Zero amount
    const EAMOUNT_ZERO: u64 = 4;    
    /// Thrown when the amount cannot cover service fees
    const ECANT_COVER_FEES: u64 = 20;

    #[event]
    struct AdminWithdrawRequestEvent has drop, store {
        amount: u64,
        asset: Object<Metadata>,
        destination: address,
    }

    #[event]
    struct AdminWithdrawRequestRemovedEvent has drop, store {
        amount: u64,
        asset: Object<Metadata>,
        destination: address,
    }    

    /// Details of a single withdrawal request
    struct WithdrawRequest has store, copy, drop {
        amount: u64,
        ts: u64,
        destination: address,        
    }

    /// Details of the liquidity (collateral) pool
    struct FAPoolDetails has copy, drop {
        balance : u64,
        total_deposited: u128,
        total_withdrawn : u128,
        limit : u64,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct RouterController has key {
        extend_ref: ExtendRef, // management of global storage
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Admin-side(owner) registry of pending withdrawal requests per asset
    struct AdminWithdraw has key {
        assets: SmartTable<Object<Metadata>, WithdrawRequest>,
    }    

    fun init_module(account: &signer) {
        let constructor_ref = &object::create_named_object(account, STORAGE_SEED);
        let obj_signer = &object::generate_signer(constructor_ref);

        move_to(obj_signer, RouterController {
            extend_ref: object::generate_extend_ref(constructor_ref), // to be able to extend the global store
        });
        move_to(obj_signer, AdminWithdraw {
            assets: smart_table::new(),
        });        
    }

    /// Deposits a fungible asset (FA) into the liquidity pool and triggers PoEL integration
    public entry fun deposit_fa (account: &signer, asset: Object<Metadata>, amount: u64) {
        // ensures that deposits are enabled and amount is greater than 0
        asset_config::assert_deposit_fa(asset);
        assert!(amount > 0, error::invalid_state(EAMOUNT_ZERO));
        let (balance, _, _) = asset_pool::get_fa_pool_details(asset);
        // assertion to handle cases where the limit is exceeded
        asset_config::assert_deposit_fa_limit(asset, balance + amount); 
        // desposit assets in the pool 
        asset_pool::deposit_fa(account, asset, amount);

        // PoEL integration
        let iasset = iAsset::get_iasset_metadata(asset_util::get_fa_key(asset), (chain_id::get() as u64)); 

        // rdetails users need during deposit operation (expected iAsset to receive and fees)
        let deposit_info = poel::get_deposit_calculations(iasset, amount);
        let (_, _, fee_asset, n_amount, _) = iAsset::deconstruct_calculations(&deposit_info);
        // ensure user can cover the fees
        assert!(n_amount > fee_asset, error::invalid_state(ECANT_COVER_FEES));

        // borrow_request/ preminting of iassets 
        poel::borrow_request(iasset, 
            (n_amount - fee_asset), signer::address_of(account), // for the user
            fee_asset, config::get_service_fees_address(), // service fee
            0, @0x0 // nothing for relayer
        );
    }

    /// A two-step process is applied to enable the admin account(owner) to withdraw funds from the fa pool
    public fun admin_withdraw_request_fa (account: &signer, asset: Object<Metadata>, amount: u64, destination: address) acquires AdminWithdraw{
        config::assert_owner(account);
        // ensure the withdrawal amount is > 0 and the pool has sufficient balance
        assert!(amount > 0, error::invalid_state(EAMOUNT_ZERO));
        let (balance, _, _) = asset_pool::get_fa_pool_details(asset);
        assert!(balance >= amount , error::invalid_state(EPOOL_INSUFFICIENT_FUNDS));

        let admin_withdraw = borrow_global_mut<AdminWithdraw>(get_storage_address());

        // record the withdraw request, update the amount/ts for the certaint asset
        if (smart_table::contains(&admin_withdraw.assets, asset)) {
            let asset_info = smart_table::borrow_mut(&mut admin_withdraw.assets, asset);
            asset_info.amount = asset_info.amount + amount; // increment amount
            asset_info.ts = timestamp::now_seconds(); // update the time
            asset_info.destination = destination; // recent address
        }else {
            smart_table::add(&mut admin_withdraw.assets, asset, WithdrawRequest {
                amount: amount,
                ts: timestamp::now_seconds(),
                destination : destination,                
            });
        };

        event::emit<AdminWithdrawRequestEvent>(
            AdminWithdrawRequestEvent {amount, asset, destination}
        );
    }

    /// Cancels (resets) the pending admin withdrawal request for the given asset
    public fun admin_remove_withdraw_fa (account: &signer, asset: Object<Metadata>) acquires AdminWithdraw {
        config::assert_owner(account);

        let admin_withdraw = borrow_global_mut<AdminWithdraw>(get_storage_address());

        // cancel by reseting the withdrawal request record to zero
        if (smart_table::contains(&admin_withdraw.assets, asset)) {
            let asset_info = smart_table::borrow_mut(&mut admin_withdraw.assets, asset);

            assert!(asset_info.amount > 0, error::invalid_state(EWITHDRAW_REQ_MISSED));

            let destination = asset_info.destination;
            let amount = asset_info.amount;

            // reset to 0
            asset_info.amount = 0; 
            asset_info.ts = 0;
            asset_info.destination = @0x0;

            event::emit<AdminWithdrawRequestRemovedEvent>(
                AdminWithdrawRequestRemovedEvent {amount, asset, destination}
            );
        } else {
            abort error::invalid_state(EWITHDRAW_REQ_MISSED)
        };
    }

    /// Executes the admin withdrawal from the given FA pool after the delay elapses
    public fun admin_withdraw_fa (account: &signer, asset: Object<Metadata>) acquires AdminWithdraw {
        config::assert_owner(account);

        let admin_withdraw = borrow_global_mut<AdminWithdraw>(get_storage_address());

        // execute withdrawal based on the submitted request 
        if (smart_table::contains(&admin_withdraw.assets, asset)) {
            let asset_info = smart_table::borrow_mut(&mut admin_withdraw.assets, asset);
            // ensure a pending withdrawal exists and the required delay has elapsed
            assert!(asset_info.amount > 0, error::invalid_state(EWITHDRAW_REQ_MISSED));
            assert!(asset_info.ts + asset_config::get_withdraw_delay() <= timestamp::now_seconds(), error::invalid_state(ENOT_ENOUGH_TIME_PASSED));

            // ensure the pool has sufficient balance
            let (balance, _, _) = asset_pool::get_fa_pool_details(asset);
            assert!(balance > 0 , error::invalid_state(EPOOL_INSUFFICIENT_FUNDS));
            // withdraw the requested amount, or the remaining balance, whichever is smaller
            let amount = if (balance >= asset_info.amount) {
                asset_info.amount
            }else {
                balance
            };
            let destination = asset_info.destination;
            // reset the withdrawal request details 
            asset_info.amount = 0; 
            asset_info.ts = 0;
            asset_info.destination = @0x0;

            // withdraw the assets and transfer them to the destination address
            asset_pool::withdraw_fa(asset, amount, destination);
        } else {
            abort error::invalid_state(EWITHDRAW_REQ_MISSED)
        };
    }

    #[view]
    /// Return FAPoolDetails (balance, total_deposited, total_withdrawn, limit)
    public fun get_fa_pool_details (asset: Object<Metadata>): FAPoolDetails {
        let (balance, total_deposited, total_withdrawn) = asset_pool::get_fa_pool_details(asset);
        let limit = asset_config::get_fa_deposit_limit(asset);
        FAPoolDetails {balance, total_deposited, total_withdrawn, limit}
    }

    /// Retrieves values from FAPoolDetails struct (balance, total_deposited, total_withdrawn, limit)
    public fun deconstruct_fa_pool_details (item : &FAPoolDetails) : (u64, u128, u128, u64) {
        (item.balance, item.total_deposited, item.total_withdrawn, item.limit)
    }

    #[view]
    /// Returns the admin withdrawal request for an asset, if present
    public fun get_admin_withdraw_request (asset: Object<Metadata>) : WithdrawRequest acquires AdminWithdraw {
        let admin_withdraw = borrow_global<AdminWithdraw>(get_storage_address());
        if (smart_table::contains(&admin_withdraw.assets, asset)) {
            *smart_table::borrow(&admin_withdraw.assets, asset)
        }else {
            WithdrawRequest {
                amount:0, 
                ts: 0, 
                destination: @0x0
            }
        }
    }

    public fun deconstruct_withdraw_request (item : &WithdrawRequest) : (u64, u64, address) {
        (item.amount, item.ts, item.destination)
    }

    fun get_storage_address(): address {
        object::create_object_address(&@dfmm_framework, STORAGE_SEED)
    }

    #[test_only]
    public fun init_for_test(deployer: &signer) {
        init_module(deployer);
        asset_pool::init_for_test(deployer);
    }

}
