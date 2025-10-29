/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
module dfmm_framework::asset_pool {

    use aptos_std::signer;
    use aptos_std::object::{Self, Object, ExtendRef};
    use aptos_std::smart_table::{Self, SmartTable};

    use supra_framework::primary_fungible_store;
    use supra_framework::fungible_asset::{Metadata};
    use supra_framework::account;
    use supra_framework::coin;
    use supra_framework::supra_coin::SupraCoin;

    use supra_framework::event::{Self};

    const STORAGE_SEED: vector<u8> = b"AssetPoolStorage";
    const TREASURY_SEED: vector<u8> = b"AssetTreasury";

    friend dfmm_framework::asset_router;
    //friend dfmm_framework::asset_config;
    friend dfmm_framework::redeem_router;

    #[event]
    struct PoolDeposit has drop, store {
        account: address,
        amount: u64,
        asset: Object<Metadata>,
    }

    #[event]
    struct PoolWithdraw has drop, store {
        account: address,
        amount: u64,
        asset: Object<Metadata>,
    }

    /// Per-asset cumulative accounting
    struct AssetPoolInfo has store {
        // Cumulative sum of all deposits for this asset
        total_deposited: u128,
        // Cumulative sum of all withdrawals for this asset
        total_withdrawn: u128,
    }

    /// Controller resource enabling pool creation/extension and treasury control
    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct PoolController has key {
        extend_ref: ExtendRef, // create asset pools
        vault_signer_cap: account::SignerCapability,
    }

    /// Registry mapping FA metadata objects to their cumulative accounting info
    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct AssetPoolVault has key {
        assets: SmartTable<Object<Metadata>, AssetPoolInfo>,
    }

    /// Module initialization: creates storage object, resource account, and publishes
    /// controller and vault registries under the storage object address
    fun init_module(account: &signer) {
        let constructor_ref = &object::create_named_object(account, STORAGE_SEED);
        let obj_signer = &object::generate_signer(constructor_ref);
        let extend_ref = object::generate_extend_ref(constructor_ref);

        // create a resource account to keep all funds
        let (vault_signer, vault_signer_cap) = account::create_resource_account(account, TREASURY_SEED);
        coin::register<SupraCoin>(&vault_signer);

        move_to(obj_signer, PoolController {
            extend_ref: extend_ref,
            vault_signer_cap: vault_signer_cap// to manage all funds
            }
        );

        move_to(obj_signer, AssetPoolVault {
            assets: smart_table::new(),
        });
    }

    /// Deposit a fungible asset into the vault
    public (friend) fun deposit_fa (account: &signer, asset: Object<Metadata>, amount: u64) acquires AssetPoolVault {
        let pool = borrow_global_mut<AssetPoolVault>(get_storage_address());
        let account_address = signer::address_of(account);
        // Move funds into the vault
        primary_fungible_store::transfer(
            account,
            asset,
            get_vault_address(),
            amount
        );

        // Update cumulative accounting
        if (smart_table::contains(&pool.assets, asset)) {
            let asset_info = smart_table::borrow_mut(&mut pool.assets, asset);
            asset_info.total_deposited = asset_info.total_deposited + (amount as u128);
        }else {
            smart_table::add(&mut pool.assets, asset, AssetPoolInfo {
                total_deposited: (amount as u128),
                total_withdrawn: 0,
            });
        };

        event::emit<PoolDeposit>(
            PoolDeposit {
                account : account_address,
                amount : amount,
                asset : asset
            }
        );
    }

    /// Withdraw a fungible asset from the vault to destination
    public (friend) fun withdraw_fa (asset: Object<Metadata>, amount: u64, destination: address) acquires PoolController, AssetPoolVault {
        let pool = borrow_global_mut<AssetPoolVault>(get_storage_address());
        // transfer out from the vault
        primary_fungible_store::transfer(
            &get_vault_signer(),
            asset,
            destination,
            amount
        );

        // update cumulative accounting
        if (smart_table::contains(&pool.assets, asset)) {
            let asset_info = smart_table::borrow_mut(&mut pool.assets, asset);
            asset_info.total_withdrawn = asset_info.total_withdrawn + (amount as u128);
        }else {
            smart_table::add(&mut pool.assets, asset, AssetPoolInfo {
                total_deposited: 0,
                total_withdrawn: (amount as u128),
            });
        };

        event::emit<PoolWithdraw>(
            PoolWithdraw {
                account : destination,
                amount : amount,
                asset : asset
            }
        );
    }

    #[view]
    public fun get_vault_address(): address {
        account::create_resource_address(&@dfmm_framework, TREASURY_SEED)
    }

    #[view]
    /// Return fa pool details (balance, total_deposited, total_withdrawn)
    public fun get_fa_pool_details(asset: Object<Metadata>): (u64, u128, u128) acquires  AssetPoolVault {
        let pool = borrow_global_mut<AssetPoolVault>(get_storage_address());
        if (smart_table::contains(&pool.assets, asset)) {
            let asset_info = smart_table::borrow(& pool.assets, asset);
            (primary_fungible_store::balance(get_vault_address(), asset), asset_info.total_deposited, asset_info.total_withdrawn)
        }else {
            (0,0,0) // nothing yet
        }
    }

    fun get_storage_address(): address {
        object::create_object_address(&@dfmm_framework, STORAGE_SEED)
    }

    fun get_vault_signer(): signer acquires PoolController {
        let controller_ref = borrow_global<PoolController>(get_storage_address());
        account::create_signer_with_capability(&controller_ref.vault_signer_cap)
    }

    fun get_pool_storage_signer(): signer acquires PoolController {
        let controller_ref = borrow_global<PoolController>(get_storage_address());
        object::generate_signer_for_extending(&controller_ref.extend_ref)
    }

    #[test_only]
    public fun init_for_test(deployer: &signer) {
        init_module(deployer);
    }

    #[test_only]
    friend dfmm_framework::asset_pool_test;
}
