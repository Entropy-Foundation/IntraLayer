/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
/// This module represents a general configuration for package.
/// It holds an admin, has assertation methods to check admin access and also store basic parameters/settings.
///
module dfmm_framework::config {

    use aptos_std::signer;
    use aptos_std::error;
    use aptos_std::object::{Self, ExtendRef};
    use supra_framework::event::{Self};
    use access_control::rbac;

    const EINVALID_MIN_COLL_RATE: u64 = 1;

    const STORAGE_SEED: vector<u8> = b"ConfigStorage";
    const WITHDRAWAL_KEY: vector<u8> = b"WithdrawalAddress";
    const SERVICE_FEES_KEY: vector<u8> = b"ServiceFeesAddress";
    const REWARDS_KEY: vector<u8> = b"RewardsAddress";

    const REDEEM_SUPRA_ASSETS_KEY: vector<u8> = b"RedeemSupraAssets";
    const REDEEM_EXTERNAL_CHAINS_KEY: vector<u8> = b"RedeemExternalChains";
    const ALLOCATE_REWARDS_KEY: vector<u8> = b"AllocateRewards";

    const DEFAULT_MIN_COLL_RATE: u64 = 1_100;
    const DEFAULT_MAX_COLL_FIRST: u64 = 1_100;
    const DEFAULT_MAX_COLL_SECOND: u64 = 1_100;

    const NUM_OF_EPOCHS_IN_CYCLE: u64 = 3;

    /// Access deniend
    const EACCESS_DENIED: u64 = 1;
    /// Rewards allocation process is disabled
    const EREWARDS_ALLOCATION_NOT_ALLOWED: u64 = 2;
    /// Reward Reduction rate too high
    const EREWARD_REDUCTION_RATE_TOO_HIGH: u64 = 3;
    /// Smallest portion rewards too high
    const ESMALLEST_REWARD_PORTION_TOO_HIGH: u64 = 4;
    ///Default minimum amount of rewards that must accrue before they can be allocated
    const DEF_THRESHOLD_REWARDS: u64 = 1000000000; // 10 supra
    ///Default minimum interval between two reward allocation events
    const DEF_MIN_FREQUENCY_REWARDS_ALLOCATION: u64 = 120; // 120 seconds

    // Multiplier used in conjunction  of reward_reduction_rate
    const REWARD_CALCULATION_MULTIPLIER:u64 = 10000;


    #[event]
    struct WithdrawalAddressUpdatedEvent has copy, drop, store {
        new_address: address,
    }

    #[event]
    struct ServiceFeesAddressUpdatedEvent has copy, drop, store {
        new_address: address,
    }

    #[event]
    struct RewardsDistributionAddressUpdatedEvent has copy, drop, store {
        new_address: address,
    }

    #[event]
    struct AllocateRewardsUpdatedEvent has copy, drop, store {
        value: bool,
    }

    #[event]
    struct ParametersUpdatedEvent has copy, drop, store {
        min_collateralisation: u64,
        length_of_epoch : u64,
        lockup_cycle_length: u64,
        number_of_epoch_in_apy: u64,
        max_collateralisation_first: u64,
        max_collateralisation_second: u64,
        reward_reduction_rate: u64,
        pool_max_delegation_cap: u64,
        smallest_portion_of_distributable_rewards: u64,
        threshold_rewards_to_distribute: u64,
        min_frequency_rewards_allocation: u64,
        number_of_epoch_in_cycle: u64
    }

    // RBAC :: Owner Role - who can assign other roles
    struct OwnerRole {}
    // RBAC :: Admin Role - who can apply various settings
    struct AdminRole {}
    // RBAC :: Pool Manager Role - who can replace delegation pools
    struct PoolManagerRole {}

    /// Aggregates the RBAC capabilities for a specific role
    struct RoleCapabilities<phantom RoleId> has store{
        manage: rbac::ManageCapability<RoleId>,
        remove: rbac::RemoveCapability<RoleId>,
        expiry: rbac::SetExpiryCapability<RoleId>,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    ///  Top-level management state and capabilities for the system
    struct Management has key {
        owner: address, // owner, deployer
        owner_role_cap: RoleCapabilities<OwnerRole>, // owner role capabilities
        admin_role_cap: RoleCapabilities<AdminRole>, // admin role capabilities
        pm_role_cap: RoleCapabilities<PoolManagerRole>, // pool manager role capabilities
        extend_ref: ExtendRef, // management of global storage
    }

    struct BasicSettings has store, copy {
        /// who receives supra coins in case of decreasing borrowable amount and withdrawal of surplus rewards
        withdrawal_address: address,
        /// who receives portion of iassets as fees (in case of borrow_request and redeem_request)
        service_fee_address: address,
        /// who receives the withdrawn stimulation rewards 
        rewards_address: address,
        /// reward allocation disabled or enabled 
        allocate_rewards: bool,
    }

    /// Global parameters of the system 
    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct MutableParameters has key {
        // minimum collateralisation rate 
        min_collateralisation: u64,
        // epoch length (in seconds)
        length_of_epoch: u64,
        // lockup-cycle length (in seconds)
        length_of_lockup_cycle: u64,
        // number of epochs used as the APY calculation window
        number_of_epoch_in_apy: u64,
        // maximum collateralization rate, applied when the desired weight is <= the target weight
        max_collateralisation_first: u64,
        // maximum collateralisation rate, applied when desired weight is exceeds target weight 
        max_collateralisation_second: u64,
        // portion of earned rewards allocated to the stimulus budget
        reward_reduction_rate: u64,
        // maximum SUPRA delegation cap per delegation pool
        pool_max_delegation_cap: u64,
        // minimum share of rewards earned that should be allocated
        smallest_portion_of_distributable_rewards: u64,
        // minimum amount of rewards that must accrue before they can be allocated
        threshold_rewards_to_distribute: u64, 
        // minimum interval between two reward allocation events
        min_frequency_rewards_allocation: u64, 
        // duration of lockup cycle in epochs
        number_of_epoch_in_cycle: u64,
        // ddditional settings bundled into a separate struct
        basic_settings: BasicSettings
    }


    fun init_module(account: &signer) {
        let constructor_ref = &object::create_named_object(account, STORAGE_SEED);
        let obj_signer = &object::generate_signer(constructor_ref);
        let account_address = signer::address_of(account);

        // owner role
        let (owner_manage_cap, owner_remove_cap, owner_expiry_cap) = rbac::register_role<OwnerRole>(account);

        // admin role
        let (admin_manage_cap, admin_remove_cap, admin_expiry_cap) = rbac::register_role<AdminRole>(account);

        // pool manager role
        let (pm_manage_cap, pm_remove_cap, pm_expiry_cap) = rbac::register_role<PoolManagerRole>(account);

        // assign roles
        rbac::grant_role<OwnerRole>(account_address, &owner_manage_cap); // grant role owner to deployer
        rbac::grant_role<AdminRole>(account_address, &admin_manage_cap); // grant role admin to deployer
        rbac::grant_role<PoolManagerRole>(account_address, &pm_manage_cap); // grant role pool manager to deployer

        // if dfmm_admin is not the deployer
        if (@dfmm_admin != account_address) {
            rbac::grant_role<AdminRole>(@dfmm_admin, &admin_manage_cap); // grant admin role to dfmm_admin
        };

        move_to(obj_signer, Management {
            owner: account_address, // who can grant admin role, delegation pool manager role, etc.
            owner_role_cap: RoleCapabilities {
                manage: owner_manage_cap,
                remove: owner_remove_cap,
                expiry: owner_expiry_cap,
            },
            admin_role_cap: RoleCapabilities {
                manage: admin_manage_cap,
                remove: admin_remove_cap,
                expiry: admin_expiry_cap,
            },
            pm_role_cap: RoleCapabilities {
                manage: pm_manage_cap,
                remove: pm_remove_cap,
                expiry: pm_expiry_cap,
            },
            extend_ref: object::generate_extend_ref(constructor_ref),
        });

        move_to(obj_signer, MutableParameters {
            min_collateralisation: DEFAULT_MIN_COLL_RATE,
            length_of_epoch: 0,
            length_of_lockup_cycle: 0,
            number_of_epoch_in_apy: 0,
            max_collateralisation_first: DEFAULT_MAX_COLL_FIRST,
            max_collateralisation_second: DEFAULT_MAX_COLL_SECOND,
            reward_reduction_rate: 0,
            pool_max_delegation_cap: 0,
            smallest_portion_of_distributable_rewards: 0,
            threshold_rewards_to_distribute: DEF_THRESHOLD_REWARDS,
            min_frequency_rewards_allocation: DEF_MIN_FREQUENCY_REWARDS_ALLOCATION,
            number_of_epoch_in_cycle: NUM_OF_EPOCHS_IN_CYCLE,
            basic_settings: BasicSettings {
                withdrawal_address: account_address,
                service_fee_address: account_address,
                rewards_address: account_address,
                allocate_rewards: true,
            }
        });

    }

    /// Ensure signer is owner
    public fun assert_owner(account: &signer) {
        assert!(rbac::has_role<OwnerRole>(signer::address_of(account)), error::permission_denied(EACCESS_DENIED));
    }

    /// Ensure signer is admin 
    public fun assert_admin (account: &signer) {
        assert!(rbac::has_role<AdminRole>(signer::address_of(account)), error::permission_denied(EACCESS_DENIED));
    }

    /// Ensure signer is pool manager 
    public fun assert_delegation_pools (account: &signer) {
        assert!(rbac::has_role<PoolManagerRole>(signer::address_of(account)), error::permission_denied(EACCESS_DENIED));
    }

    /// Ensure rewards are allocable
    public fun assert_allocate_rewards() acquires MutableParameters {
        assert!(is_allocate_rewards(), error::permission_denied(EREWARDS_ALLOCATION_NOT_ALLOWED));
    }

    /// Grant/Revoke admin role
    public entry fun set_admin_role(account: &signer, new_address: address, grant : bool) acquires Management {
        let management_ref = borrow_global<Management>(get_storage_address());
        assert_owner(account);
        if (grant){
            rbac::grant_role<AdminRole>(new_address, &management_ref.admin_role_cap.manage);
        } else {
            rbac::revoke_role<AdminRole>(new_address, &management_ref.admin_role_cap.manage);
        }
    }

    /// Grant/Revoke owner role
    public entry fun set_owner_role(account: &signer, new_address: address, grant : bool) acquires Management {
        let management_ref = borrow_global<Management>(get_storage_address());
        // only deployer can grant owner role!
        assert!(management_ref.owner == signer::address_of(account), error::permission_denied(EACCESS_DENIED));
        if (grant){
            rbac::grant_role<OwnerRole>(new_address, &management_ref.owner_role_cap.manage);
        } else {
            rbac::revoke_role<OwnerRole>(new_address, &management_ref.owner_role_cap.manage);
        }
    }

    /// Grant/Revoke delegation_pools_manager role
    public entry fun set_delegation_pools_role(account: &signer, new_address: address, grant : bool) acquires Management {
        let management_ref = borrow_global_mut<Management>(get_storage_address());
        assert_owner(account);
        if (grant) {
            rbac::grant_role<PoolManagerRole>(new_address, &management_ref.pm_role_cap.manage);
        }else {
            rbac::revoke_role<PoolManagerRole>(new_address, &management_ref.pm_role_cap.manage);
        }
    }

    /// Set withdawal address entity
    public entry fun set_withdrawal_address(account: &signer, new_address: address) acquires MutableParameters {
        assert_owner(account);
        let mut_ref = borrow_global_mut<MutableParameters>(get_storage_address());
        mut_ref.basic_settings.withdrawal_address = new_address;
        event::emit<WithdrawalAddressUpdatedEvent>(
            WithdrawalAddressUpdatedEvent {
                new_address,
            }
        );
    }

    /// Set service fees entity
    public entry fun set_service_fees_address(account: &signer, new_address: address) acquires MutableParameters {
        assert_admin(account);
        let mut_ref = borrow_global_mut<MutableParameters>(get_storage_address());
        mut_ref.basic_settings.service_fee_address = new_address;
        event::emit<ServiceFeesAddressUpdatedEvent>(
            ServiceFeesAddressUpdatedEvent {
                new_address,
            }
        );
    }

    /// Set rewards distribution entity
    public entry fun set_rewards_distribution_address(account: &signer, new_address: address) acquires MutableParameters {
        assert_admin(account);
        let mut_ref = borrow_global_mut<MutableParameters>(get_storage_address());
        mut_ref.basic_settings.rewards_address = new_address;
        event::emit<RewardsDistributionAddressUpdatedEvent>(
            RewardsDistributionAddressUpdatedEvent {
                new_address,
            }
        );
    }

    /// Turn on/off allocate rewards process
    public entry fun set_allocate_rewards(account: &signer, value: bool) acquires MutableParameters {
        assert_admin(account);
        let mut_ref = borrow_global_mut<MutableParameters>(get_storage_address());
        mut_ref.basic_settings.allocate_rewards = value;
        event::emit<AllocateRewardsUpdatedEvent>(
            AllocateRewardsUpdatedEvent {
                value,
            }
        );
    }

    /// Set parameters
    public entry fun set_parameters(
        account: &signer,
        min_collateralisation: u64,
        length_of_epoch: u64,
        length_of_lockup_cycle: u64,
        number_of_epoch_in_apy: u64,
        max_collateralisation_first: u64,
        max_collateralisation_second: u64,
        reward_reduction_rate: u64,
        pool_max_delegation_cap: u64,
        smallest_portion_of_distributable_rewards: u64,
        threshold_rewards_to_distribute: u64,
        min_frequency_rewards_allocation: u64,
        number_of_epoch_in_cycle: u64
    ) acquires MutableParameters {
        assert_admin(account);
        // control the range
        assert!(reward_reduction_rate <= REWARD_CALCULATION_MULTIPLIER, error::invalid_state(EREWARD_REDUCTION_RATE_TOO_HIGH));
        assert!(smallest_portion_of_distributable_rewards <= REWARD_CALCULATION_MULTIPLIER, error::invalid_state(ESMALLEST_REWARD_PORTION_TOO_HIGH));
        let mutable_params_ref = borrow_global_mut<MutableParameters>(get_storage_address());

        assert!(min_collateralisation > 0, error::invalid_argument(EINVALID_MIN_COLL_RATE));
        assert!(min_collateralisation <= max_collateralisation_first && min_collateralisation <= max_collateralisation_second, error::invalid_argument(EINVALID_MIN_COLL_RATE));

        mutable_params_ref.min_collateralisation = min_collateralisation;
        mutable_params_ref.length_of_epoch = length_of_epoch;
        mutable_params_ref.length_of_lockup_cycle = length_of_lockup_cycle;
        mutable_params_ref.number_of_epoch_in_apy = number_of_epoch_in_apy;
        mutable_params_ref.max_collateralisation_first = max_collateralisation_first;
        mutable_params_ref.max_collateralisation_second = max_collateralisation_second;
        mutable_params_ref.reward_reduction_rate = reward_reduction_rate;
        mutable_params_ref.pool_max_delegation_cap = pool_max_delegation_cap;
        mutable_params_ref.smallest_portion_of_distributable_rewards = smallest_portion_of_distributable_rewards;
        mutable_params_ref.threshold_rewards_to_distribute = threshold_rewards_to_distribute;
        mutable_params_ref.min_frequency_rewards_allocation = min_frequency_rewards_allocation;
        mutable_params_ref.number_of_epoch_in_cycle = number_of_epoch_in_cycle;

         event::emit<ParametersUpdatedEvent>(
            ParametersUpdatedEvent {
                min_collateralisation,
                length_of_epoch,
                lockup_cycle_length: length_of_lockup_cycle,
                number_of_epoch_in_apy,
                max_collateralisation_first,
                max_collateralisation_second,
                reward_reduction_rate,
                pool_max_delegation_cap,
                smallest_portion_of_distributable_rewards,
                threshold_rewards_to_distribute,
                min_frequency_rewards_allocation,
                number_of_epoch_in_cycle
            }
        );
    }

    fun get_storage_address(): address {
        object::create_object_address(&@dfmm_framework, STORAGE_SEED)
    }

    #[view]
    /// checks whether the given address is an admin
    public fun is_admin(account: address): bool {
        rbac::has_role<AdminRole>(account)
    }

    #[view]
    /// checks whether the given address is an owner
    public fun is_owner(account: address): bool {
        rbac::has_role<OwnerRole>(account)
    }

    #[view]
    /// checks whether the given address is an delegation pool manager
    public fun is_admin_delegation_pools(account: address): bool {
        rbac::has_role<PoolManagerRole>(account)
    }

    #[view]
    /// return service fees address
    public fun get_service_fees_address(): address acquires MutableParameters {
        let mut_ref = borrow_global<MutableParameters>(get_storage_address());
        mut_ref.basic_settings.service_fee_address
    }

    #[view]
    /// return withdrawal address
    public fun get_withdrawal_address(): address acquires MutableParameters {
        let mut_ref = borrow_global<MutableParameters>(get_storage_address());
        mut_ref.basic_settings.withdrawal_address
    }

    #[view]
    /// return rewards_distribution address
    public fun get_rewards_distribution_address(): address acquires MutableParameters {
        let mut_ref = borrow_global<MutableParameters>(get_storage_address());
        mut_ref.basic_settings.rewards_address
    }

    #[view]
    /// return flag if rewards allocation is enabled
    public fun is_allocate_rewards(): bool acquires MutableParameters {
        let mut_ref = borrow_global<MutableParameters>(get_storage_address());
        mut_ref.basic_settings.allocate_rewards
    }

    #[view]
    /// return system parameters
    public fun get_mut_params(): (u64, u64, u64, u64, u64, u64, u64, u64, u64, u64, u64, u64) acquires MutableParameters {
        let mutable_params_ref = borrow_global<MutableParameters>(get_storage_address());

        return (
            mutable_params_ref.min_collateralisation ,
            mutable_params_ref.length_of_epoch,
            mutable_params_ref.length_of_lockup_cycle ,
            mutable_params_ref.number_of_epoch_in_apy,
            mutable_params_ref.max_collateralisation_first ,
            mutable_params_ref.max_collateralisation_second ,
            mutable_params_ref.reward_reduction_rate ,
            mutable_params_ref.pool_max_delegation_cap,
            mutable_params_ref.smallest_portion_of_distributable_rewards,
            mutable_params_ref.threshold_rewards_to_distribute,
            mutable_params_ref.min_frequency_rewards_allocation,
            mutable_params_ref.number_of_epoch_in_cycle
        )
    }

    #[view]
    /// returns minimum amount of rewards that must accrue before they can be allocated
    public fun get_threshold_rewards_to_distribute(): u64 acquires MutableParameters {
        let mutable_params_ref = borrow_global<MutableParameters>(get_storage_address());
        mutable_params_ref.threshold_rewards_to_distribute
    }

    #[view]
    /// returns the duration of the lockup cycle
    public fun get_length_of_lockup_cycle(): u64 acquires MutableParameters {
        let mutable_params_ref = borrow_global<MutableParameters>(get_storage_address());
        mutable_params_ref.length_of_lockup_cycle
    }

    #[view]
    /// returns the duration of epoch
    public fun get_length_of_epoch(): u64 acquires MutableParameters {
        let mutable_params_ref = borrow_global<MutableParameters>(get_storage_address());
        mutable_params_ref.length_of_epoch
    }

    #[view]
    /// returns the APY calculation window for iAssets, in epochs
    public fun get_number_of_epoch_in_apy(): u64 acquires MutableParameters {
        let mutable_params_ref = borrow_global<MutableParameters>(get_storage_address());
        mutable_params_ref.number_of_epoch_in_apy
    }

    #[view]
    /// returns duration of lockup cycle in epochs 
    public fun get_number_of_epoch_in_cycle(): u64 acquires MutableParameters {
        let mutable_params_ref = borrow_global<MutableParameters>(get_storage_address());
        mutable_params_ref.number_of_epoch_in_cycle
    }

    #[test_only]
    public fun init_for_test(deployer: &signer) {
        init_module(deployer);
    }

    #[test_only]
    public fun get_default_min_coll(): u64 {
       DEFAULT_MIN_COLL_RATE
    }

}
