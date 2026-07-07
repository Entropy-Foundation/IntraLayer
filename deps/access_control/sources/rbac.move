/// Copyright (C) Supra -- 2025
/// 
/// Role based access control module.
/// Module that allows other modules to implement role-based access control mechanisms. This is a lightweight version.
/// In essence, you will be defining multiple roles, each allowed to perform different sets of actions in your module. 
/// An account may have, for example, 'moderator', 'minter' or 'admin' roles, which you will then check inside your logic. Separately, you will be able to define rules for how accounts can be granted a role, have it revoked, and more...
/// Or you can define (optionally) some role which become invalid (for all assigned participants) after some period and no need to worry to revoke granted permissions explicitly
///
module access_control::rbac {
    
    use aptos_std::signer;
    use aptos_std::error;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::type_info::{Self, TypeInfo};

    use supra_framework::timestamp;
    use supra_framework::event::{Self};

    /// Access deniend
    const EROLE_ACCESS_DENIED: u64 = 1;
    /// Access deniend, role is expired
    const EROLE_EXPIRED: u64 = 2;
    /// Address of account which is used to initialize a new Role doesn't match the deployer of module
    const EROLE_ADDRESS_MISMATCH: u64 = 3;
    /// `RoleId` is already registered
    const EROLE_ALREADY_REGISTERED: u64 = 4;
    /// `RoleId` is not registered
    const EROLE_NOT_REGISTERED: u64 = 5;
    /// invalid expiration time
    const EROLE_INVALID_EXPIRY_TIME : u64 = 6;
    /// Role already granted
    const EROLE_ALREADY_GRANTED: u64 = 7;
    /// Role not granted yet
    const EROLE_NOT_GRANTED: u64 = 8;    

    struct RoleStore<phantom RoleId> has key {
        expiry_time: u64, // when role is no longer valid, default is 0, can be mutated via `SetExpirtyCapability`
        has_role: SmartTable<address, bool>,
    }

    /// Capability required to manage (grant/revoke) role
    struct ManageCapability<phantom RoleId> has store {}

    /// Capability to destroy role entire entity. The other capabilities ManageCapability/SetExpiryCapability must be destroyed explicitly
    struct RemoveCapability<phantom RoleId> has store {}

    /// Capability to set/reset expiry time
    struct SetExpiryCapability<phantom RoleId> has store {} 

    #[event]
    struct GrantRole has drop, store {
        account: address,
        role_type_info: TypeInfo,
    }

    #[event]
    struct RevokeRole has drop, store {
        account: address,
        role_type_info: TypeInfo,
    }    

    /// Register a new role
    public fun register_role<RoleId>(account: &signer): (ManageCapability<RoleId>, RemoveCapability<RoleId>, SetExpiryCapability<RoleId>) {
        register_role_internal(account, 0)
    }

    // Register a new role with some expired time. expired = now_seconds() + ttl
    public fun register_role_with_ttl<RoleId>(account: &signer, ttl: u64): (ManageCapability<RoleId>, RemoveCapability<RoleId>, SetExpiryCapability<RoleId>) {
        register_role_internal(account, ttl)
    }    

    /// Remove role
    public fun remove_role<RoleId>(cap:RemoveCapability<RoleId>) acquires RoleStore {
        let r_address = role_address<RoleId>();
        assert!(exists<RoleStore<RoleId>>(r_address), error::not_found(EROLE_NOT_REGISTERED));
        let RoleStore<RoleId> {expiry_time: _, has_role} = move_from<RoleStore<RoleId>>(r_address);
        smart_table::destroy(has_role);
        let RemoveCapability {} = cap;
        // Tthe other capabilities should be destroyed explicitly. 
        // it is useless to use Manage/Expiry capabilities when role is removed
    }

    /// Set expiration for the existing role
    public fun set_expiration<RoleId>(expiry_time: u64, _cap: &SetExpiryCapability<RoleId>) acquires RoleStore {
        let r_address = role_address<RoleId>();
        assert!(exists<RoleStore<RoleId>>(r_address), error::not_found(EROLE_NOT_REGISTERED));
        let role = borrow_global_mut<RoleStore<RoleId>>(r_address);
        // if role is expired, then grant/revoke operation is not allowed
        assert!(expiry_time == 0 || expiry_time > timestamp::now_seconds() , error::invalid_argument(EROLE_INVALID_EXPIRY_TIME));
        role.expiry_time = expiry_time;
    }

    ///Grant an existing role from the user. If role has been already granted error is thrown
    public fun grant_role<RoleId>(to: address, _cap: &ManageCapability<RoleId>) acquires RoleStore {
        set_role_internal<RoleId>(to, true);
    }

    /// Revoke an existing role from the user. If role hasn't been granted yet error is thrown
    public fun revoke_role<RoleId>(to: address, _cap: &ManageCapability<RoleId>) acquires RoleStore {
        set_role_internal<RoleId>(to, false);
    }    

    /// Destroy a manage capability.
    public fun destroy_manage_cap<RoleId>(manage_cap: ManageCapability<RoleId>) {
        let ManageCapability<RoleId> {} = manage_cap;
    }

    /// Destroy a remove capability.
    public fun destroy_remove_cap<RoleId>(remove_cap: RemoveCapability<RoleId>) {
        let RemoveCapability<RoleId> {} = remove_cap;
    }

    /// Destroy a expiry capability.
    public fun destroy_expiry_cap<RoleId>(expiry_cap: SetExpiryCapability<RoleId>) {
        let SetExpiryCapability<RoleId> {} = expiry_cap;
    }

    /// Asserts if role is not registered or expired or user hasn't been granted yet
    public fun assert_has_role<RoleId>(account: address) acquires RoleStore {
        let r_address = role_address<RoleId>();
        assert!(exists<RoleStore<RoleId>>(r_address),error::not_found(EROLE_NOT_REGISTERED));
        let role = borrow_global<RoleStore<RoleId>>(r_address);
        // check expired field and assert if role entity already expired
        assert!(role.expiry_time == 0 || role.expiry_time > timestamp::now_seconds(), error::permission_denied(EROLE_EXPIRED));
        let has_role = smart_table::contains(&role.has_role, account);
        assert!(has_role, error::permission_denied(EROLE_ACCESS_DENIED));
    }

    /// Checks if the role is registered and not expired and user has been granted by this role
    public fun has_role<RoleId>(account: address): bool acquires RoleStore {
        let r_address = role_address<RoleId>();
        if (!exists<RoleStore<RoleId>>(r_address)) return false;
        let role = borrow_global<RoleStore<RoleId>>(r_address);
        // if expired field is set, then return false role entity already expired 
        if (role.expiry_time > 0 && timestamp::now_seconds() > role.expiry_time) return false;
        return smart_table::contains(&role.has_role, account)
    }    

    fun set_role_internal<RoleId> (to: address, grant : bool) acquires RoleStore {
        let r_address = role_address<RoleId>();
        assert!(exists<RoleStore<RoleId>>(r_address),error::not_found(EROLE_NOT_REGISTERED));
        let role = borrow_global_mut<RoleStore<RoleId>>(r_address);
        // if role is expired, then grant/revoke operation is not allowed
        assert!(role.expiry_time == 0 || role.expiry_time > timestamp::now_seconds() , error::permission_denied(EROLE_EXPIRED));

        if (grant) {
            assert!(!smart_table::contains(&mut role.has_role, to), error::invalid_argument(EROLE_ALREADY_GRANTED));
            smart_table::add(&mut role.has_role, to, true); // grant operation
            event::emit<GrantRole>(
                GrantRole {
                    account: to,
                    role_type_info: type_info::type_of<RoleId>()
                }
            );            
        } else {
            assert!(smart_table::contains(&mut role.has_role, to), error::invalid_argument(EROLE_NOT_GRANTED));
            smart_table::remove(&mut role.has_role, to); // revoke operation
            event::emit<RevokeRole>(
                RevokeRole {
                    account: to,
                    role_type_info: type_info::type_of<RoleId>()
                }
            );            
        }
    }

    #[view]
    /// Returns true if the RoleId is already registered
    public fun is_role_registered<RoleId>(): bool {
        exists<RoleStore<RoleId>>(role_address<RoleId>())
    }

    #[view]
    /// Returns true if the RoleId is already registered and ttl is either 0 or greather than current time
    public fun is_role_alive<RoleId>(): bool acquires RoleStore {
        if (!is_role_registered<RoleId>()) {
            return false
        };
        let role = safe_role_store<RoleId>();
        (role.expiry_time == 0 || role.expiry_time > timestamp::now_seconds())
        
    }         

    inline fun safe_role_store<RoleId>(): &RoleStore<RoleId> acquires RoleStore {
        borrow_global<RoleStore<RoleId>>(role_address<RoleId>())
    }

    fun role_address<RoleId>(): address {
        let type_info = type_info::type_of<RoleId>();
        type_info::account_address(&type_info)
    }

    fun register_role_internal<RoleId>(account: &signer, expiry_time: u64): (ManageCapability<RoleId>, RemoveCapability<RoleId>, SetExpiryCapability<RoleId>) {
        let account_addr = signer::address_of(account);

        // only deployer of the module can register the role
        assert!(role_address<RoleId>() == account_addr, error::invalid_argument(EROLE_ADDRESS_MISMATCH));
        assert!(!exists<RoleStore<RoleId>>(account_addr),error::already_exists(EROLE_ALREADY_REGISTERED));
        assert!(expiry_time == 0 || expiry_time > timestamp::now_seconds(), error::invalid_argument(EROLE_INVALID_EXPIRY_TIME));

        let role_store = RoleStore<RoleId> {
            expiry_time : expiry_time,
            has_role: smart_table::new(),
        };

        move_to(account, role_store);       
        (ManageCapability<RoleId> {}, RemoveCapability<RoleId> {}, SetExpiryCapability<RoleId> {})
    }


    // Unit tests
    #[test_only]
    struct Role_A {}
    #[test_only]
    struct Role_B {}    
    
    #[test_only]
    use supra_framework::account;

    #[test(supra = @0x1, deployer = @access_control)]
    fun test_register_role(supra: &signer, deployer: &signer) acquires RoleStore{
        let deployer_addr = signer::address_of(deployer);
        account::create_account_for_test(deployer_addr);
        let (manage_cap, remove_cap, expiry_cap) = register_role<Role_A>(deployer);

        assert!(is_role_registered<Role_A>(), 1);
        assert!(!is_role_registered<Role_B>(), 1); // not registered

        assert!(is_role_alive<Role_A>(), 1);
        assert!(!is_role_alive<Role_B>(), 1);

        // role with ttl
        let t0 = 100001000000;
        let expiry_time = t0 + 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(t0);
        let (manage_cap_b, remove_cap_b, expiry_cap_b) = register_role_with_ttl<Role_B>(deployer, expiry_time);
        assert!(is_role_registered<Role_B>(), 1); // registered
        assert!(is_role_alive<Role_B>(), 1);

        // move time
        timestamp::fast_forward_seconds(expiry_time + 1);
        assert!(is_role_registered<Role_B>(), 1); // registered
        assert!(!is_role_alive<Role_B>(), 1); // not alive, expired

        let ManageCapability<Role_A> {} = manage_cap;
        let RemoveCapability<Role_A> {} = remove_cap;
        let SetExpiryCapability<Role_A> {} = expiry_cap;

        let ManageCapability<Role_B> {} = manage_cap_b;
        let RemoveCapability<Role_B> {} = remove_cap_b; 
        let SetExpiryCapability<Role_B> {} = expiry_cap_b;       
    }

    #[test(supra = @0x1, deployer = @access_control)]
    #[expected_failure(abort_code = 65542, location = Self )] // error::invalid_argument(EINVALID_EXPIRY_TIME)
    fun test_register_expired_role(supra: &signer, deployer: &signer) {
        let deployer_addr = signer::address_of(deployer);
        account::create_account_for_test(deployer_addr);
        // role with ttl
        let t0 = 100001000000;
        let expiry_time = t0 - 1;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(t0);        

        let (manage_cap, remove_cap, expiry_cap) = register_role_with_ttl<Role_A>(deployer, expiry_time);

        let ManageCapability<Role_A> {} = manage_cap;
        let RemoveCapability<Role_A> {} = remove_cap;
        let SetExpiryCapability<Role_A> {} = expiry_cap;
    }

    #[test(supra = @0x1, deployer = @access_control, user1 = @0x987, user2 = @0x876)]
    fun test_set_expiry(supra: &signer, deployer: &signer, user1: address, user2: address) acquires RoleStore {
        let deployer_addr = signer::address_of(deployer);
        account::create_account_for_test(deployer_addr);
        // role with ttl
        let t0 = 100001000000;
        let delta = 3600;
        let expiry_time = t0 + delta;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(t0);        

        let (manage_cap_a, remove_cap_a, expiry_cap_a) = register_role_with_ttl<Role_A>(deployer, expiry_time);
        let (manage_cap_b, remove_cap_b, expiry_cap_b) = register_role<Role_B>(deployer);

        grant_role<Role_A>(user1, &manage_cap_a); // grant role A to user1
        grant_role<Role_B>(user2, &manage_cap_b); // grant role B to user2

        assert!(has_role<Role_A>(user1), 1);
        assert!(has_role<Role_B>(user2), 1); 

        timestamp::fast_forward_seconds(delta + 1); // role1 is expired, role2 is valid
        assert!(!has_role<Role_A>(user1), 1);
        assert!(has_role<Role_B>(user2), 1);

        set_expiration<Role_B>(t0 + 2*delta, &expiry_cap_b); // role2 has an expiry time, but it is valid
        assert!(!has_role<Role_A>(user1), 1);
        assert!(has_role<Role_B>(user2), 1);
        
        timestamp::fast_forward_seconds(delta); // both roles expired
        assert!(!has_role<Role_A>(user1), 1);
        assert!(!has_role<Role_B>(user2), 1);

        set_expiration<Role_A>(t0 + 3*delta, &expiry_cap_a); // change expiry time for role1, valid role
        set_expiration<Role_B>(t0 + 3*delta, &expiry_cap_b); // change expiry time for role1, valid role

        assert!(has_role<Role_A>(user1), 1);
        assert!(has_role<Role_B>(user2), 1);

        timestamp::fast_forward_seconds(3* delta); // both roles expired

        assert!(!has_role<Role_A>(user1), 1); // not valid
        assert!(!has_role<Role_B>(user2), 1); // not valid
        assert!(!is_role_alive<Role_A>(), 1);
        assert!(!is_role_alive<Role_B>(), 1);

        set_expiration<Role_A>(0, &expiry_cap_a); // no expiry time for role1
        assert!(has_role<Role_A>(user1), 1); // valid
        assert!(is_role_alive<Role_A>(), 1);

        destroy_manage_cap(manage_cap_a); 
        destroy_remove_cap(remove_cap_a);
        destroy_expiry_cap(expiry_cap_a);

        destroy_manage_cap(manage_cap_b); 
        destroy_remove_cap(remove_cap_b);
        destroy_expiry_cap(expiry_cap_b);
    }    

    #[test(deployer = @access_control, user1 = @0x987, user2 = @0x876)]
    fun test_grant_role(deployer: &signer, user1 : address, user2 : address) acquires RoleStore{
        let deployer_addr = signer::address_of(deployer);
        account::create_account_for_test(deployer_addr);
        let (manage_cap_a, remove_cap_a, expiry_cap_a) = register_role<Role_A>(deployer);
        let (manage_cap_b, remove_cap_b, expiry_cap_b) = register_role<Role_B>(deployer);
        grant_role<Role_A>(user1, &manage_cap_a); // grant role A to user1
        grant_role<Role_B>(user2, &manage_cap_b); // grant role B to user2

        assert_has_role<Role_A>(user1);
        assert_has_role<Role_B>(user2);

        let ManageCapability<Role_A> {} = manage_cap_a;
        let RemoveCapability<Role_A> {} = remove_cap_a;
        let SetExpiryCapability<Role_A> {} = expiry_cap_a;

        let ManageCapability<Role_B> {} = manage_cap_b;
        let RemoveCapability<Role_B> {} = remove_cap_b;
        let SetExpiryCapability<Role_B> {} = expiry_cap_b;      
    }

    #[test(deployer = @access_control, user1 = @0x987, user2 = @0x876)]
    fun test_remove_capability(deployer: &signer, user1 : address, user2 : address) acquires RoleStore{
        let deployer_addr = signer::address_of(deployer);
        account::create_account_for_test(deployer_addr);
        let (manage_cap_a, remove_cap_a, expiry_cap_a) = register_role<Role_A>(deployer);
        let (manage_cap_b, remove_cap_b, expiry_cap_b) = register_role<Role_B>(deployer);
        
        grant_role<Role_A>(user1, &manage_cap_a); // grant role A to user1
        grant_role<Role_A>(user2, &manage_cap_a); // grant role A to user2
        grant_role<Role_B>(user1, &manage_cap_b); // grant role B to user1
        grant_role<Role_B>(user2, &manage_cap_b); // grant role B to user2

        assert!(has_role<Role_A>(user1), 1);
        assert!(has_role<Role_A>(user2), 1);

        assert!(has_role<Role_B>(user1), 1);
        assert!(has_role<Role_B>(user2), 1);        

        destroy_manage_cap(manage_cap_a);
        destroy_remove_cap(remove_cap_a);
        destroy_expiry_cap(expiry_cap_a);

        // roles still granted, only capabilities removed
        assert!(has_role<Role_A>(user1), 1);
        assert!(has_role<Role_A>(user2), 1);
        assert!(has_role<Role_B>(user1), 1);
        assert!(has_role<Role_B>(user2), 1);

        destroy_manage_cap(manage_cap_b);
        destroy_remove_cap(remove_cap_b);
        destroy_expiry_cap(expiry_cap_b);     
    }    

    #[test(deployer = @access_control, user1 = @0x987)]
    fun test_remove(deployer: &signer, user1 : address) acquires RoleStore{
        let deployer_addr = signer::address_of(deployer);
        account::create_account_for_test(deployer_addr);
        let (manage_cap_a, remove_cap_a, expiry_cap_a) = register_role<Role_A>(deployer);
        grant_role<Role_A>(user1, &manage_cap_a); // grant role A to user1

        assert_has_role<Role_A>(user1);
        assert!(has_role<Role_A>(user1), 1);

        remove_role<Role_A>(remove_cap_a);

        let ManageCapability<Role_A> {} = manage_cap_a;
        let SetExpiryCapability<Role_A> {} = expiry_cap_a;
    }

    #[test(deployer = @access_control, user1 = @0x987, user2 = @0x876)]
    #[expected_failure(abort_code = 393221, location = Self )] // error::not_found(EROLE_ID_NOT_REGISTERED)
    fun test_grant_upon_remove(deployer: &signer, user1 : address, user2 : address) acquires RoleStore{
        let deployer_addr = signer::address_of(deployer);
        account::create_account_for_test(deployer_addr);
        let (manage_cap_a, remove_cap_a, expiry_cap_a) = register_role<Role_A>(deployer);
        grant_role<Role_A>(user1, &manage_cap_a); // grant role A to user1

        assert_has_role<Role_A>(user1);
        assert!(has_role<Role_A>(user1), 1);
        assert!(!has_role<Role_A>(user2), 1);

        remove_role<Role_A>(remove_cap_a);
        grant_role<Role_A>(user2, &manage_cap_a); // grant role A to user2, error

        let ManageCapability<Role_A> {} = manage_cap_a;
        let SetExpiryCapability<Role_A> {} = expiry_cap_a;
    }


    #[test(deployer = @access_control, user1 = @0x987, user2 = @0x876)]
    fun test_destroy_cap_upon_remove(deployer: &signer, user1 : address, user2 : address) acquires RoleStore{
        let deployer_addr = signer::address_of(deployer);
        account::create_account_for_test(deployer_addr);
        let (manage_cap_a, remove_cap_a, expiry_cap_a) = register_role<Role_A>(deployer);
        grant_role<Role_A>(user1, &manage_cap_a); // grant role A to user1

        assert_has_role<Role_A>(user1);
        assert!(has_role<Role_A>(user1), 1);
        assert!(!has_role<Role_A>(user2), 1);

        remove_role<Role_A>(remove_cap_a); // remove cap is removed here

        // remove other capabilities
        destroy_manage_cap(manage_cap_a);
        destroy_expiry_cap(expiry_cap_a);
    }    


    #[test(deployer = @access_control, user1 = @0x987, user2 = @0x876)]
    fun test_grant_revoke_role(deployer: &signer, user1 : address, user2 : address) acquires RoleStore{
        let deployer_addr = signer::address_of(deployer);
        account::create_account_for_test(deployer_addr);
        let (manage_cap_a, remove_cap_a, expiry_cap_a) = register_role<Role_A>(deployer);
        grant_role<Role_A>(user1, &manage_cap_a); // grant role A to user1
        grant_role<Role_A>(user2, &manage_cap_a); // grant role A to user2

        assert_has_role<Role_A>(user1);
        assert_has_role<Role_A>(user2);

        assert!(has_role<Role_A>(user1), 1);
        assert!(has_role<Role_A>(user2), 1);

        revoke_role<Role_A>(user1, &manage_cap_a);
        revoke_role<Role_A>(user2, &manage_cap_a);
        assert!(!has_role<Role_A>(user1), 1);
        assert!(!has_role<Role_A>(user2), 1);

        let ManageCapability<Role_A> {} = manage_cap_a;
        let RemoveCapability<Role_A> {} = remove_cap_a;
        let SetExpiryCapability<Role_A> {} = expiry_cap_a;
    }

    #[test(supra = @0x1, deployer = @access_control, user1 = @0x987)]
    #[expected_failure(abort_code = 327682, location = Self )] //(EROLE_ID_ROLE_EXPIRED)
    fun test_expired_grant(supra : &signer, deployer: &signer, user1 : address) acquires RoleStore{

        let t0 = 100001000000;
        let delta = 3600;
        let expiry_time = t0 + delta;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(t0);
        
        let deployer_addr = signer::address_of(deployer);
        account::create_account_for_test(deployer_addr);
        let (manage_cap_a, remove_cap_a, expiry_cap_a) = register_role_with_ttl<Role_A>(deployer, expiry_time);
        grant_role<Role_A>(user1, &manage_cap_a); // grant role A to user1

        assert_has_role<Role_A>(user1);
        assert!(has_role<Role_A>(user1), 1);

        // move time
        timestamp::fast_forward_seconds(delta - 5);

        // still ok
        assert_has_role<Role_A>(user1);
        assert!(has_role<Role_A>(user1), 1);

        // move time
        timestamp::fast_forward_seconds(6);
        assert!(!has_role<Role_A>(user1), 1); // expired role

        // again, error because role already expired
        grant_role<Role_A>(user1, &manage_cap_a); 

        let ManageCapability<Role_A> {} = manage_cap_a;
        let RemoveCapability<Role_A> {} = remove_cap_a;
        let SetExpiryCapability<Role_A> {} = expiry_cap_a;
    }     

    #[test(deployer = @access_control, user1 = @0x987)]
    #[expected_failure(abort_code = 65543, location = Self )] // error::invalid_argument(EROLE_ALREADY_GRANTED)
    fun test_already_granted(deployer: &signer, user1 : address) acquires RoleStore{
        let deployer_addr = signer::address_of(deployer);
        account::create_account_for_test(deployer_addr);
        let (manage_cap_a, remove_cap_a, expiry_cap_a) = register_role<Role_A>(deployer);
        grant_role<Role_A>(user1, &manage_cap_a); // grant role A to user1
        // again
        grant_role<Role_A>(user1, &manage_cap_a); // grant role A to user1

        let ManageCapability<Role_A> {} = manage_cap_a;
        let RemoveCapability<Role_A> {} = remove_cap_a;
        let SetExpiryCapability<Role_A> {} = expiry_cap_a;
    } 

    #[test(deployer = @access_control, user1 = @0x987)]
    #[expected_failure(abort_code = 65544, location = Self )] // error::invalid_argument(EROLE_NOT_GRANTED)
    fun test_already_revoked(deployer: &signer, user1 : address) acquires RoleStore{
        let deployer_addr = signer::address_of(deployer);
        account::create_account_for_test(deployer_addr);
        let (manage_cap_a, remove_cap_a, expiry_cap_a) = register_role<Role_A>(deployer);
        grant_role<Role_A>(user1, &manage_cap_a); // grant role A to user1

        assert_has_role<Role_A>(user1);
        assert!(has_role<Role_A>(user1), 1);

        revoke_role<Role_A>(user1, &manage_cap_a);
        revoke_role<Role_A>(user1, &manage_cap_a); // not allowed

        let ManageCapability<Role_A> {} = manage_cap_a;
        let RemoveCapability<Role_A> {} = remove_cap_a;
        let SetExpiryCapability<Role_A> {} = expiry_cap_a;

    }

    #[test(deployer = @access_control, user1 = @0x987)]
    #[expected_failure(abort_code = 65544, location = Self )] // error::not_found(EROLE_NOT_GRANTED)
    fun test_not_granted_yet(deployer: &signer, user1 : address) acquires RoleStore{
        let deployer_addr = signer::address_of(deployer);
        account::create_account_for_test(deployer_addr);
        let (manage_cap_a, remove_cap_a, expiry_cap_a) = register_role<Role_A>(deployer);

        assert!(!has_role<Role_A>(user1), 1);
        revoke_role<Role_A>(user1, &manage_cap_a); // not allowed

        let ManageCapability<Role_A> {} = manage_cap_a;
        let RemoveCapability<Role_A> {} = remove_cap_a;
        let SetExpiryCapability<Role_A> {} = expiry_cap_a;
    }          
}