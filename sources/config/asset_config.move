/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
/// This module defines configuration for asset_router and redeem_router
///
module dfmm_framework::asset_config {

    use aptos_std::error;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::object::{Self, Object, ExtendRef};
    use supra_framework::fungible_asset::{Metadata};
    use supra_framework::chain_id;
    use dfmm_framework::asset_util;
    use dfmm_framework::config;
    use dfmm_framework::iAsset;

    use supra_framework::event::{Self};

    const DEF_WITHDRAW_DELAY: u64 = 604800; // 1 week

    const STORAGE_SEED: vector<u8> = b"AssetConfigStorage";

    /// Already enabled
    const EALREADY_ENABLED: u64 = 1;
    /// Already disabled
    const EALREADY_DISABLED: u64 = 2;
    /// Asset not supported
    const EASSET_NOT_SUPPORTED: u64 = 3;
    /// Asset already supported
    const EASSET_ALREADY_SUPPORTED: u64 = 4;
    /// Deposit not supported
    const EDEPOSIT_NOT_SUPPORTED: u64 = 5;
    /// Withdraw not supported
    const EWITHDRAW_NOT_SUPPORTED: u64 = 6;
    /// iasset not supported
    const EIASSET_NOT_SUPPORTED: u64 = 10;
    /// Deposit limit exceeded on the asset level
    const EASSET_DEPOSIT_LIMIT_EXCEEDED: u64 = 12;

    friend dfmm_framework::asset_router;

    #[event]
    struct AssetRegisteredEvent has copy, drop, store {
        asset: Object<Metadata>
    }

    #[event]
    struct AssetDeregisteredEvent has copy, drop, store {
        asset: Object<Metadata>
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct Management has key {
        deposit_enabled: bool, // deposit flow is enabled
        withdraw_enabled: bool, // withdraw flow is enabled
        extend_ref: ExtendRef, // management of global storage
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct ServiceFees has key {
        in_fees: u64, // supra borrow_request fees
        out_fees: u64, // supra redeem_request fees
        out_fees_external: u64, // external redeem_request fees
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct AssetRegistry has key {
        /// supported assets. key is a FA, value is a deposit limit (or 0)
        supported_assets: SmartTable<Object<Metadata>, u64>,
    }

    fun init_module(account: &signer) {
        let constructor_ref = &object::create_named_object(account, STORAGE_SEED);
        let obj_signer = &object::generate_signer(constructor_ref);

        move_to(obj_signer, Management {
            deposit_enabled: false,
            withdraw_enabled: false,
            extend_ref: object::generate_extend_ref(constructor_ref), // to be able to extend the global store
        });

        move_to(obj_signer, AssetRegistry {
            supported_assets: smart_table::new(), // supported assets
        });

        move_to(obj_signer, ServiceFees {
            in_fees: 0, // no fees
            out_fees: 0, // no fees
            out_fees_external: 0, // no fees
        });
    }

    /// Set global service fees
    public entry fun set_service_fees(account: &signer, in_fees: u64, out_fees: u64, out_fees_external: u64) acquires ServiceFees {
        config::assert_admin(account);
        let fees_ref = borrow_global_mut<ServiceFees>(get_storage_address());
        fees_ref.in_fees = in_fees;
        fees_ref.out_fees = out_fees;
        fees_ref.out_fees_external = out_fees_external;
    }

    /// Set/Reset limits on deposit for the specified fa. Only admin
    public entry fun set_fa_deposit_limit(account: &signer, asset: Object<Metadata>, limit: u64) acquires AssetRegistry {
        config::assert_admin(account);
        let ref = borrow_global_mut<AssetRegistry>(get_storage_address());
        assert!(smart_table::contains(&ref.supported_assets, asset), error::invalid_state(EASSET_NOT_SUPPORTED));
        let old_limit = smart_table::borrow_mut(&mut ref.supported_assets, asset);
        *old_limit = limit;
    }

    /// Register supported fa. Only admin
    public entry fun register_fa(account: &signer, asset: Object<Metadata>) acquires AssetRegistry {
        config::assert_admin(account);
        let storage = get_storage_address();
        let registry_ref = borrow_global_mut<AssetRegistry>(storage);
        let key = asset_util::get_fa_key(asset);
        assert!(iAsset::is_iasset_registered(key, (chain_id::get() as u64)), error::invalid_state(EIASSET_NOT_SUPPORTED));
        assert!(!smart_table::contains(&registry_ref.supported_assets, asset), error::invalid_state(EASSET_ALREADY_SUPPORTED));
        smart_table::add(&mut registry_ref.supported_assets, asset, 0); // no limit by default
        event::emit(AssetRegisteredEvent {asset});
    }

    /// Deregister supported fa. Only admin
    public entry fun deregister_fa(account: &signer, asset: Object<Metadata>) acquires AssetRegistry {
        config::assert_admin(account);
        let storage = get_storage_address();
        let registry_ref = borrow_global_mut<AssetRegistry>(storage);
        assert!(smart_table::contains(&registry_ref.supported_assets, asset), error::invalid_state(EASSET_NOT_SUPPORTED));
        smart_table::remove(&mut registry_ref.supported_assets, asset);
        event::emit(AssetDeregisteredEvent {asset});
    }

    /// Enable deposits. Only admin
    public entry fun enable_deposit(account: &signer) acquires Management {
        config::assert_admin(account);
        set_deposit_enabled(true);
    }

    /// Disable deposits. Only admin
    public entry fun disable_deposit(account: &signer) acquires Management {
        config::assert_admin(account);
        set_deposit_enabled(false);
    }

    /// Enable withdraw. Only admin
    public entry fun enable_withdraw(account: &signer) acquires Management {
        config::assert_admin(account);
        set_withdraw_enabled(true);
    }

    /// Disable withdraw. Only admin
    public entry fun disable_withdraw(account: &signer) acquires Management {
        config::assert_admin(account);
        set_withdraw_enabled(false);
    }

    fun get_storage_address(): address {
        object::create_object_address(&@dfmm_framework, STORAGE_SEED)
    }

    #[view]
    /// check whether withdrawals are enabled
    public fun is_withdraw_enabled(): bool acquires Management {
        safe_management_store().withdraw_enabled
    }

    #[view]
    /// check withdraw delay in seconds
    public fun get_withdraw_delay(): u64 {
        DEF_WITHDRAW_DELAY
    }

    #[view]
    /// return service fees
    public fun get_service_fees(): (u64, u64, u64) acquires ServiceFees {
        let ref = safe_fees_store();
        (ref.in_fees, ref.out_fees, ref.out_fees_external)
    }

    #[view]
    /// return deposit limit for the fa
    public fun get_fa_deposit_limit(asset : Object<Metadata>): u64 acquires AssetRegistry {
        let ref = borrow_global<AssetRegistry>(get_storage_address());
        if (smart_table::contains(&ref.supported_assets, asset)) {
            *smart_table::borrow(&ref.supported_assets, asset)
        } else {
            0
        }
    }

    #[view]
    /// verify that this fa is currently supported
    public fun is_fa_supported(asset : Object<Metadata>): bool acquires AssetRegistry {
        smart_table::contains(&safe_registry_store().supported_assets, asset)
    }
  
    #[view]
    /// check whether deposits are enabled
    public fun is_deposit_enabled(): bool acquires Management {
        safe_management_store().deposit_enabled
    }

    /// check whether the specified asset can be deposited into the IntraLayer vault
    public fun assert_deposit_fa (asset:Object<Metadata>) acquires AssetRegistry, Management{
        let storage = get_storage_address();

        let management_ref = borrow_global<Management>(storage);
        assert!(management_ref.deposit_enabled, error::invalid_state(EDEPOSIT_NOT_SUPPORTED));

        let registry_ref = borrow_global<AssetRegistry>(storage);
        assert!(smart_table::contains(&registry_ref.supported_assets, asset), error::invalid_state(EASSET_NOT_SUPPORTED));
    }

    /// verify that the specified collateral deposit amount is within the deposit limit of the asset
    public (friend) fun assert_deposit_fa_limit (asset:Object<Metadata>, amount: u64) acquires AssetRegistry {
        let limits_ref = borrow_global<AssetRegistry>(get_storage_address());
        
        let limit = *smart_table::borrow_with_default(&limits_ref.supported_assets, asset, &0);
        // if the limit is 0, skip the check - 0 means no limit for this asset
        if (limit > 0) {
            assert!(limit >= amount, error::invalid_state(EASSET_DEPOSIT_LIMIT_EXCEEDED));
        }
    }

    /// check whether the asset is supported as liquidity (collateral) and whether withdrawals are enabled
    public fun assert_withdraw_fa (asset:Object<Metadata>) acquires Management, AssetRegistry {
        let storage = get_storage_address();

        let management_ref = borrow_global<Management>(storage);
        assert!(management_ref.withdraw_enabled, error::invalid_state(EWITHDRAW_NOT_SUPPORTED));

        let registry_ref = borrow_global<AssetRegistry>(storage);
        assert!(smart_table::contains(&registry_ref.supported_assets, asset), error::invalid_state(EASSET_NOT_SUPPORTED));
    }

    /// enable or disable deposits for the asset 
    fun set_deposit_enabled(flag: bool) acquires Management {
        let management_ref = borrow_global_mut<Management>(get_storage_address());
        assert!(management_ref.deposit_enabled != flag, error::invalid_state(if (flag) EALREADY_ENABLED else EALREADY_DISABLED));
        management_ref.deposit_enabled = flag;
    }

    /// enable or disable withdrawals for the asset
    fun set_withdraw_enabled(flag: bool) acquires Management {
        let management_ref = borrow_global_mut<Management>(get_storage_address());
        assert!(management_ref.withdraw_enabled != flag, error::invalid_state(if (flag) EALREADY_ENABLED else EALREADY_DISABLED));
        management_ref.withdraw_enabled = flag;
    }

    inline fun safe_management_store (): &Management acquires Management {
        borrow_global<Management>(get_storage_address())
    }

    inline fun safe_registry_store (): &AssetRegistry acquires AssetRegistry {
        borrow_global<AssetRegistry>(get_storage_address())
    }

    inline fun safe_fees_store (): &ServiceFees acquires ServiceFees {
        borrow_global<ServiceFees>(get_storage_address())
    }

    #[test_only]
    public fun init_for_test(deployer: &signer) acquires Management {
        init_module(deployer);
        assert!(!is_deposit_enabled(), 1); // by default is false
        assert!(!is_withdraw_enabled(), 1);  // by default is false
        enable_deposit(deployer); // enabled
        enable_withdraw(deployer); //enabled
    }

    #[test_only]
    friend dfmm_framework::asset_config_test;

}
