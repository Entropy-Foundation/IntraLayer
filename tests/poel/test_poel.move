/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
#[test_only]
module dfmm_framework::poel_test  {
    use dfmm_framework::config;
    use dfmm_framework::iAsset;
    use dfmm_framework::poel;
    use aptos_std::signer;
    use aptos_std::vector;
    use supra_framework::coin;
    use supra_framework::account;
    use supra_framework::supra_account;
    use supra_framework::supra_coin;
    use supra_framework::object::{Self, Object};
    use supra_framework::timestamp;
    use supra_framework::primary_fungible_store;
    use supra_framework::fungible_asset::{Self, Metadata};
    use supra_framework::chain_id;
    use std::option::{Self};
    use std::string::{Self};
    use supra_framework::reconfiguration;
    use supra_oracle::supra_oracle_storage;
    use supra_framework::stake;
    use supra_framework::pbo_delegation_pool::{Self, withdraw};

    use dfmm_framework::test_util::clean_up;
    use dfmm_framework::asset_router as router;
    use dfmm_framework::asset_config;
    use dfmm_framework::test_util;
    use dfmm_framework::asset_util;
    use supra_framework::supra_coin::SupraCoin;

    const DEF_DECIMALS :u8 = 8;
    const ORIGIN_TOKEN_CHAIN_ID: u64 = 1;
    const ORIGIN_TOKEN_ADDRESS: vector<u8> = x"e2794e1ef7d4ac86506a5947a1f0f342c139f10c";
    const SOURCE_TOKEN_DECIMALS:u16 = 8;
    const SOURCE_TOKEN_ADDRESS: vector<u8> = x"e2794e1139f10c";
    const CHAIN_ID:u8 = 6;

    const LOCKUP_CYCLE_SECONDS: u64 = 2592000;
    const ONE_SUPRA: u64 = 100000000;
    const VALIDATOR_SUPRA: u64 = 1000 * 100000000;
    const VALIDATOR_A: address = @0x1;
    const VALIDATOR_A_AMOUNT: u64 = 10 * 100000000;
    const VALIDATOR_B_AMOUNT: u64 = 20 * 100000000;
    const VALIDATOR_B: address = @0x2;

    #[test(supra = @0x1, deployer = @dfmm_framework)]
    fun test_poel_vault_empty(supra : &signer, deployer: &signer) {

        let deployer_addr = signer::address_of(deployer);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);

        let vault_addr = poel::get_vault_address();
        assert_vault_address_initialization(deployer_addr, vault_addr);

        clean_up(burn_cap, mint_cap);

    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice = @0x999)]
    fun test_increase_borrowable_amount(supra : &signer, deployer: &signer, alice : &signer) {

        let deployer_addr = signer::address_of(deployer);
        let supra_addr = signer::address_of(supra);
        let alice_addr = signer::address_of(alice);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        let vault_addr = poel::get_vault_address();
        assert_vault_address_initialization(deployer_addr, vault_addr);

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        // check if minted
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 20000, 0);
        // transfer to alice 6k
        supra_account::transfer(supra, alice_addr, 6000);
        // transfer to deployer 5k
        supra_account::transfer(supra, deployer_addr, 5000);
        // supra_framework 9k
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 9000, 0);
        // alice = 6k
        assert!(coin::balance<supra_coin::SupraCoin>(alice_addr) == 6000, 0);
        // deployer = 5k
        assert!(coin::balance<supra_coin::SupraCoin>(deployer_addr) == 5000, 0);

        // send money to PoEL, 2k
        poel::increase_borrowable_amount(deployer, 2000);
        // deployer = 5k - 2k = 3k
        assert!(coin::balance<supra_coin::SupraCoin>(deployer_addr) == 3000, 0);
        // Poel Vault = 2k
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == 2000, 0);
        // total_borrowable_amount = 2000
        assert!(poel::get_total_borrowable_amount() == 2000, 0);

        // send more money to PoEL, 1k
        poel::increase_borrowable_amount(deployer, 1000);
        // deployer = 3k - 1k = 2k
        assert!(coin::balance<supra_coin::SupraCoin>(deployer_addr) == 2000, 0);
        // Poel Vault = 3k
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == 3000, 0);
        // total_borrowable_amount = 3000
        assert!(poel::get_total_borrowable_amount() == 3000, 0);

        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice = @0x999)]
    #[expected_failure(abort_code = 327681, location = config )] // 327681 = ((0x5 << 16) + 1); assert!(signer::address_of(account) == get_admin_address(), error::permission_denied(ENOT_ADMIN));
    fun test_increase_borrowable_amount_not_authorized(supra : &signer, deployer: &signer, alice : &signer) {

        let supra_addr = signer::address_of(supra);
        let alice_addr = signer::address_of(alice);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        // check if minted
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 20000, 0);
        // transfer to alice 6k
        supra_account::transfer(supra, alice_addr, 6000);
        // supra_framework 14k
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 14000, 0);
        // alice = 6k
        assert!(coin::balance<supra_coin::SupraCoin>(alice_addr) == 6000, 0);

        // send money to PoEL, 2k :: error, not authorized
        poel::increase_borrowable_amount(alice, 2000);

        clean_up(burn_cap, mint_cap);
    }


    #[test(supra = @0x1, deployer = @dfmm_framework)]
    #[expected_failure(abort_code = 65542, location = poel )] // 65542 = ((0x1 << 16) + 6); assert!(user_balance >= amount, error::invalid_argument(EINSUFICIENT_CALLER_BALANCE))
    fun test_increase_borrowable_amount_not_insufficient(supra : &signer, deployer: &signer) {

        let deployer_addr = signer::address_of(deployer);
        let supra_addr = signer::address_of(supra);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        // check if minted
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 20000, 0);
        // transfer to deployer 6k
        supra_account::transfer(supra, deployer_addr, 6000);
        // supra_framework 14k
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 14000, 0);
        // deployer = 6k
        assert!(coin::balance<supra_coin::SupraCoin>(deployer_addr) == 6000, 0);

        // send money to PoEL, 8k :: error, not enough
        poel::increase_borrowable_amount(deployer, 8000);

        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice =@0x123)]
    fun test_withdraw_revenue(supra : &signer, deployer: &signer, alice: &signer) {

        let deployer_addr = signer::address_of(deployer);
        let supra_addr = signer::address_of(supra);
        let alice_addr = signer::address_of(alice);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        // check if minted
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 20000, 0);
        supra_account::transfer(supra, deployer_addr, 6000);
        assert!(coin::balance<supra_coin::SupraCoin>(deployer_addr) == 6000, 0);// deployer = 6k

        // send money to PoEL, 4k
        let increased_rentable = 4000;
        poel::increase_borrowable_amount(deployer, increased_rentable); // increased total_borrowable
        assert!(poel::get_total_borrowable_amount() == increased_rentable, 0);

        let vault_addr = poel::get_vault_address();
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == increased_rentable, 0);

        let extra = 2000;
        supra_account::transfer(supra, vault_addr, extra); // send coins directly to poel vault
        let vault_balance = coin::balance<supra_coin::SupraCoin>(vault_addr);
        assert!(vault_balance == extra + increased_rentable , 0); // 6k

        let alice_balance = coin::balance<supra_coin::SupraCoin>(alice_addr);
        // set withdrawal_address
        config::set_withdrawal_address(deployer, alice_addr);
        assert!(config::get_withdrawal_address() == alice_addr, 0);

        // withdraw 1k
        let requested = 500;

        // 1st atempt
        poel::withdraw_surplus_rewards(deployer, requested);
        assert!(coin::balance<supra_coin::SupraCoin>(alice_addr) == alice_balance + requested, 0);
        // 2d atempt
        poel::withdraw_surplus_rewards(deployer, requested);
        // checks
        assert!(coin::balance<supra_coin::SupraCoin>(alice_addr) == alice_balance + 2 * requested, 0);
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == vault_balance - 2 * requested, 0);
        assert!(poel::get_total_borrowable_amount() == increased_rentable, 0); // total_borrowable is not modified

        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice =@0x123)]
    #[expected_failure(abort_code = 196619, location = poel )] // error::invalid_argument(EAMOUNT_EXCEEDED)
    fun test_withdraw_revenue_too_much(supra : &signer, deployer: &signer, alice: &signer) {

        let deployer_addr = signer::address_of(deployer);
        let supra_addr = signer::address_of(supra);
        let alice_addr = signer::address_of(alice);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        supra_account::transfer(supra, deployer_addr, 6000);

        // send money to PoEL, 4k
        let increased_rentable = 4000;
        poel::increase_borrowable_amount(deployer, increased_rentable); // increased total_borrowable
        assert!(poel::get_total_borrowable_amount() == increased_rentable, 0);

        let vault_addr = poel::get_vault_address();
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == increased_rentable, 0);

        let extra = 2000;
        supra_account::transfer(supra, vault_addr, extra); // send coins directly to poel vault
        let vault_balance = coin::balance<supra_coin::SupraCoin>(vault_addr);
        assert!(vault_balance == extra + increased_rentable , 0); // 6k

        // set withdrawal_address
        config::set_withdrawal_address(deployer, alice_addr);

        // withdraw 5k
        let requested = 5000; // balance is 6k, but total borrowable is  4k

        poel::withdraw_surplus_rewards(deployer, requested); // error expected
        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice =@0x123)]
    #[expected_failure(abort_code = 327681, location = config )] // error::invalid_argument(ENOT_ADMIN)
    fun test_withdraw_revenue_not_authorized(supra : &signer, deployer: &signer, alice: &signer) {

        let deployer_addr = signer::address_of(deployer);
        let supra_addr = signer::address_of(supra);
        let alice_addr = signer::address_of(alice);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        supra_account::transfer(supra, deployer_addr, 6000);

        // send money to PoEL, 4k
        let increased_rentable = 4000;
        poel::increase_borrowable_amount(deployer, increased_rentable); // increased total_borrowable
        assert!(poel::get_total_borrowable_amount() == increased_rentable, 0);

        // set withdrawal_address
        config::set_withdrawal_address(deployer, alice_addr);

        poel::withdraw_surplus_rewards(alice, 1000); // not authorized
        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice =@0x123)]
    fun test_withdraw_stimulated_rewards(supra : &signer, deployer: &signer, alice: &signer) {

        let deployer_addr = signer::address_of(deployer);
        let supra_addr = signer::address_of(supra);
        let alice_addr = signer::address_of(alice);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        reconfiguration::initialize_for_test(supra);

        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        iAsset::init_iAsset_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        // check if minted
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 20000, 0);

        let stimulated = 4000;
        let stimulated_2 = 1000;
        let allocated_rewards = 10_000;
        let vault_addr = poel::get_vault_address();
        supra_account::transfer(supra, vault_addr, stimulated + 2 * stimulated_2 );
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == stimulated + 2 * stimulated_2, 0);

        poel::increase_stimulation_rewards_accumulated(stimulated); // increase stimulated rewards
        let (stimulation_rewards_accumulated, stimulation_rewards_claimed, _) = poel::get_stimulation_rewards();
        assert!(stimulation_rewards_accumulated == stimulated, 1);
        assert!(stimulation_rewards_claimed == 0, 1);

        // set rewards_distribution_address
        config::set_rewards_distribution_address(deployer, alice_addr);
        assert!(config::get_rewards_distribution_address() == alice_addr, 0);

        let alice_balance = coin::balance<supra_coin::SupraCoin>(alice_addr);

        poel::increase_allocated_reward_balance(allocated_rewards); // set allocated rewards balance
        let allocated_rewards_balance = poel::get_allocated_rewards_balance();
        assert!(allocated_rewards == allocated_rewards_balance, 1);

        // 1st atempt
        poel::withdraw_stimulation_rewards(deployer);
        // only claim, no balance modification
        assert!(coin::balance<supra_coin::SupraCoin>(alice_addr) == alice_balance, 0);
        let (stimulation_rewards_accumulated, stimulation_rewards_claimed, stimulation_rewards_claim_epoch) = poel::get_stimulation_rewards();
        assert!(stimulation_rewards_accumulated == stimulated, 1);
        assert!(stimulation_rewards_claimed == stimulated, 1);
        let allocated_rewards_balance = poel::get_allocated_rewards_balance();
        assert!(allocated_rewards == allocated_rewards_balance, 1); // still the same, no withdraw        

        poel::increase_stimulation_rewards_accumulated(stimulated + stimulated_2); // increase stimulated rewards
        let (stimulation_rewards_accumulated, stimulation_rewards_claimed, stimulation_rewards_claim_epoch) = poel::get_stimulation_rewards();
        assert!(stimulation_rewards_accumulated == stimulated + stimulated_2, 1);
        assert!(stimulation_rewards_claimed == stimulated, 1);

        // 2d atempt
        timestamp::fast_forward_seconds(120);
        reconfiguration::reconfigure_for_test_custom();
        iAsset::update_cycle_info(stimulation_rewards_claim_epoch + 1);
        
        poel::withdraw_stimulation_rewards(deployer);
        let allocated_rewards_balance = poel::get_allocated_rewards_balance();
        assert!(allocated_rewards_balance == allocated_rewards - stimulated, 1); // update

        let (stimulation_rewards_accumulated, stimulation_rewards_claimed, stimulation_rewards_claim_epoch) = poel::get_stimulation_rewards();
        assert!(stimulation_rewards_accumulated == stimulated_2, 1);
        assert!(stimulation_rewards_claimed == 0, 1);
        assert!(stimulation_rewards_claim_epoch == 0, 1);
        assert!(coin::balance<supra_coin::SupraCoin>(alice_addr) == alice_balance + stimulated, 0);

        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice =@0x123)]
    #[expected_failure(abort_code = 196627, location = poel )] // error::invalid_state(ENOT_ENOUGH_TIME_PASSED)
    fun test_withdraw_stimulated_rewards_not_enough_time(supra : &signer, deployer: &signer, alice: &signer) {

        let deployer_addr = signer::address_of(deployer);
        let supra_addr = signer::address_of(supra);
        let alice_addr = signer::address_of(alice);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        reconfiguration::initialize_for_test(supra);

        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        iAsset::init_iAsset_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        // check if minted
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 20000, 0);

        let stimulated = 4000;
        let vault_addr = poel::get_vault_address();
        supra_account::transfer(supra, vault_addr, 2 * stimulated );
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) ==  2* stimulated, 0);

        poel::increase_stimulation_rewards_accumulated(stimulated); // increase stimulated rewards
        let (stimulation_rewards_accumulated, stimulation_rewards_claimed, _) = poel::get_stimulation_rewards();
        assert!(stimulation_rewards_accumulated == stimulated, 1);
        assert!(stimulation_rewards_claimed == 0, 1);

        // set rewards_distribution_address
        config::set_rewards_distribution_address(deployer, alice_addr);
        assert!(config::get_rewards_distribution_address() == alice_addr, 0);

        // 1st atempt
        poel::withdraw_stimulation_rewards(deployer);
        let (stimulation_rewards_accumulated, stimulation_rewards_claimed, stimulation_rewards_claim_epoch) = poel::get_stimulation_rewards();
        assert!(stimulation_rewards_accumulated == stimulated, 1);
        assert!(stimulation_rewards_claimed == stimulated, 1);

        // 2d atempt
        poel::withdraw_stimulation_rewards(deployer); // claimed, but not enough time to withdraw

        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice = @0x999)]
    fun test_decrease_borrowable_amount(supra : &signer, deployer: &signer, alice : &signer) {

        config::init_for_test(deployer);
        iAsset::init_iAsset_for_test(deployer);
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(100001000000);
        timestamp::fast_forward_seconds(10);
        let deployer_addr = signer::address_of(deployer);
        let supra_addr = signer::address_of(supra);
        let alice_addr = signer::address_of(alice);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        // init pool
        poel::init_poel_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        let vault_addr = poel::get_vault_address();

        // alice is a person who receives the money from withdrawal
        config::set_withdrawal_address(deployer, alice_addr);

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        // check if minted
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 20000, 0);
        // transfer to alice 6k
        supra_account::transfer(supra, alice_addr, 6000);
        // transfer to deployer 5k
        supra_account::transfer(supra, deployer_addr, 5000);
        // supra_framework 9k
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 9000, 0);
        // alice = 6k
        assert!(coin::balance<supra_coin::SupraCoin>(alice_addr) == 6000, 0);
        // deployer = 5k
        assert!(coin::balance<supra_coin::SupraCoin>(deployer_addr) == 5000, 0);
        // send money to PoEL, 2k
        poel::increase_borrowable_amount(deployer, 2000);
        // deployer = 5k - 2k = 3k
        assert!(coin::balance<supra_coin::SupraCoin>(deployer_addr) == 3000, 0);
        // Poel Vault = 2k
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == 2000, 0);
        // total_borrowable_amount = 2000
        assert!(poel::get_total_borrowable_amount() == 2000, 0);

        // decrease money from PoEL, 0.5k
        poel::decrease_borrowable_amount(deployer, 500);
        // alice address is saved as withdrawal_address = 6k + 0.5
        assert!(coin::balance<supra_coin::SupraCoin>(alice_addr) == 6500, 0);
        // Poel Vault = 2k - 0.5
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == 1500, 0);
        // total_borrowable_amount = 2k - 0.5
        assert!(poel::get_total_borrowable_amount() == 1500, 0);

        clean_up(burn_cap, mint_cap);

    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice = @0x999)]
    #[expected_failure(abort_code = 196619, location = poel )] // 327691 = ((0x3 << 11) + 1);  assert!(total_borrowable_amount >= amount, error::invalid_state(EAMOUNT_EXCEEDED));
    fun test_decrease_borrowable_amount_not_enough(supra : &signer, deployer: &signer, alice : &signer) {

        config::init_for_test(deployer);
        iAsset::init_iAsset_for_test(deployer);
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(100001000000);
        let deployer_addr = signer::address_of(deployer);
        let supra_addr = signer::address_of(supra);
        let alice_addr = signer::address_of(alice);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        // init pool
        poel::init_poel_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        let vault_addr = poel::get_vault_address();

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        // check if minted
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 20000, 0);
        // transfer to alice 6k
        supra_account::transfer(supra, alice_addr, 6000);
        // transfer to deployer 5k
        supra_account::transfer(supra, deployer_addr, 5000);
        // supra_framework 9k
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 9000, 0);
        // alice = 6k
        assert!(coin::balance<supra_coin::SupraCoin>(alice_addr) == 6000, 0);
        // deployer = 5k
        assert!(coin::balance<supra_coin::SupraCoin>(deployer_addr) == 5000, 0);
        // send money to PoEL, 2k
        poel::increase_borrowable_amount(deployer, 2000);
        // Poel Vault = 2k
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == 2000, 0);
        // total_borrowable_amount = 2000
        assert!(poel::get_total_borrowable_amount() == 2000, 0);

        // decrease money from PoEL, 5k
        poel::decrease_borrowable_amount(deployer, 5000);

        clean_up(burn_cap, mint_cap);

    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice = @0x999)]
    #[expected_failure(abort_code = 327681, location = config )] // 327681 = ((0x5 << 16) + 1); assert!(signer::address_of(account) == get_admin_address(), error::permission_denied(ENOT_ADMIN));
    fun test_decrease_borrowable_amount_not_authorized(supra : &signer, deployer: &signer, alice : &signer) {

        timestamp::set_time_has_started_for_testing(supra);
        let deployer_addr = signer::address_of(deployer);
        let supra_addr = signer::address_of(supra);
        let alice_addr = signer::address_of(alice);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        // init pool
        config::init_for_test(deployer);
        iAsset::init_iAsset_for_test(deployer);
        poel::init_poel_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        let vault_addr = poel::get_vault_address();

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        // check if minted
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 20000, 0);
        // transfer to alice 6k
        supra_account::transfer(supra, alice_addr, 6000);
        // transfer to deployer 5k
        supra_account::transfer(supra, deployer_addr, 5000);
        // supra_framework 9k
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 9000, 0);
        // alice = 6k
        assert!(coin::balance<supra_coin::SupraCoin>(alice_addr) == 6000, 0);
        // deployer = 5k
        assert!(coin::balance<supra_coin::SupraCoin>(deployer_addr) == 5000, 0);
        // send money to PoEL, 2k
        poel::increase_borrowable_amount(deployer, 2000);
        // Poel Vault = 2k
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == 2000, 0);
        // total_borrowable_amount = 2000
        assert!(poel::get_total_borrowable_amount() == 2000, 0);

        // decrease money from PoEL, 1k, not authorized
        poel::decrease_borrowable_amount(alice, 1000);

        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice = @0x999)]
    fun test_send_directly_to_poel_vault(supra : &signer, deployer: &signer, alice : &signer) {

        let deployer_addr = signer::address_of(deployer);
        let supra_addr = signer::address_of(supra);
        let alice_addr = signer::address_of(alice);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        let vault_addr = poel::get_vault_address();
        assert_vault_address_initialization(deployer_addr, vault_addr);

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        // check if minted
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 20000, 0);
        // transfer to alice 6k
        supra_account::transfer(supra, alice_addr, 6000);
        // supra_framework 14k
        assert!(coin::balance<supra_coin::SupraCoin>(supra_addr) == 14000, 0);
        // alice = 6k
        assert!(coin::balance<supra_coin::SupraCoin>(alice_addr) == 6000, 0);

        // Alice sends directly to poel vaul 3k
        // we explicitly use coin::transfer to be sure, resource account is ready to accept supra in anyway
        coin::transfer<supra_coin::SupraCoin>(alice, vault_addr, 3000);
        //supra_account::transfer(alice, vault_addr, 3000);
        // Poel vault 3k
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == 3000, 0);
        // total_borrowable_amount = 0 because user sends money directly to address
        assert!(poel::get_total_borrowable_amount() == 0, 0);
        // alice = 3k
        assert!(coin::balance<supra_coin::SupraCoin>(alice_addr) == 3000, 0);

        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework)]
    fun test_borrow_request(supra : &signer, deployer: &signer) {

        let recipient_1 = @0x71;
        let recipient_2 = @0x72;

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        reconfiguration::initialize_for_test(supra);

        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        // init asset entry
        iAsset::init_iAsset_for_test(deployer);

        poel::create_new_iasset(deployer, b"BTC", b"iBTC", 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        let asset = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);
        assert!(object::owner(asset) == signer::address_of(deployer), 1);

        let asset_amount1= 5000;
        // user1
        poel::borrow_request(asset, asset_amount1, recipient_1, 0, @0x0, 0, @0x0);

        let user1_liq_address = iAsset::get_total_liquidity_provider_table_value_for_test(recipient_1);
        let (_, preminted_iassets, _, _, _) = iAsset::get_liquidity_provider_asset_entry_items_for_test(user1_liq_address, asset);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_,_,_,_, total_borrow_requests, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&items);

        assert!(preminted_iassets == asset_amount1, 1); // ensure preminted_iasset is valid
        assert!(total_borrow_requests == asset_amount1, 1); // ensure total_borrow_requests is valid
        assert!(primary_fungible_store::balance(recipient_1, asset) == 0, 1); // balance is 0, no real minting

        // user1: the subsequent borrow_request for the same recipient is a valid scenario
        poel::borrow_request(asset, asset_amount1, recipient_1, 0, @0x0, 0, @0x0);
        let (_, preminted_iassets, _, _, _) = iAsset::get_liquidity_provider_asset_entry_items_for_test(user1_liq_address, asset);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_,_,_,_, total_borrow_requests, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&items);
        assert!(preminted_iassets == (asset_amount1 *2) , 1); // ensure preminted_iasset is valid
        assert!(total_borrow_requests == (asset_amount1 *2) , 1); // ensure total_borrow_requests is valid
        assert!(primary_fungible_store::balance(recipient_1, asset) == 0, 1); // balance is 0, no real minting

        // user2: the borrow_request for the another recipient
        let asset_amount2= 3000;
        poel::borrow_request(asset, asset_amount2, recipient_2, 0, @0x0, 0, @0x0);
        let user2_liq_address = iAsset::get_total_liquidity_provider_table_value_for_test(recipient_2);
        let (_, preminted_iassets, _, _, _) = iAsset::get_liquidity_provider_asset_entry_items_for_test(user2_liq_address, asset);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_,_,_,_, total_borrow_requests, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&items);
        assert!(preminted_iassets == asset_amount2 , 1); // ensure preminted_iasset is valid
        assert!(total_borrow_requests == (asset_amount1 *2 + asset_amount2) , 1); // ensure total_borrow_requests is valid
        assert!(primary_fungible_store::balance(recipient_2, asset) == 0, 1); // balance is 0, no real minting

        let supply = fungible_asset::supply(asset);
        assert!(option::get_with_default(&supply, 0) == 0, 1); // supply is 0

        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_borrow_request_service_fee(supra : &signer, deployer: &signer, supra_oracles: &signer) {

        supra_oracle_storage::init_module_for_test(supra_oracles);
        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        let supra_price: u64 = 1000;
        let asset_price: u64 = 100 * supra_price;
        supra_oracle_storage::set_price(1, (asset_price as u128), 18);
        supra_oracle_storage::set_price(500, (supra_price as u128), 18); // supra

        let recipient_1 = @0x71;
        let iasset_fee = 3; // according to the current model :  let converted_service_fee = service_fee / (price as u64);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        reconfiguration::initialize_for_test(supra);

        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        // init asset entry
        iAsset::init_iAsset_for_test(deployer);

        let service_feees_address = config::get_service_fees_address(); // who receives iasset as a fees

        poel::create_new_iasset(deployer, b"BTC", b"iBTC", 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        let asset = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);
        assert!(object::owner(asset) == signer::address_of(deployer), 1);

        let asset_amount1= 500000;
        let fee_amount: u64 = 10000;
        poel::borrow_request(asset, asset_amount1, recipient_1, fee_amount, service_feees_address, 0, @0x0);

        let user1_liq_address = iAsset::get_total_liquidity_provider_table_value_for_test(recipient_1); // for recipient
        let service_fees_liq = iAsset::get_total_liquidity_provider_table_value_for_test(service_feees_address); // for service fee address

        let (_, preminted_iassets, _, _, _) = iAsset::get_liquidity_provider_asset_entry_items_for_test(user1_liq_address, asset);
        let (_, preminted_iassets_service_fees, _, _, _) = iAsset::get_liquidity_provider_asset_entry_items_for_test(service_fees_liq, asset);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_,_,_,_, total_borrow_requests, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&items);

        assert!(preminted_iassets == asset_amount1, 1);
        assert!(preminted_iassets_service_fees == fee_amount, 1);
        assert!(total_borrow_requests == asset_amount1 + fee_amount, 1); // ensure total_borrow_requests is valid
        assert!(primary_fungible_store::balance(recipient_1, asset) == 0, 1); // balance is 0, no real minting
        assert!(primary_fungible_store::balance(service_feees_address, asset) == 0, 1); // balance is 0, no real minting

        let supply = fungible_asset::supply(asset);
        assert!(option::get_with_default(&supply, 0) == 0, 1); // supply is 0

        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_borrow_empty_premint(supra : &signer, deployer: &signer, supra_oracles: &signer) {
        let recipient_1 = @0x71;

        account::create_account_for_test(signer::address_of(supra));
        let time0 = 100001000000;
        let delta = 3600;

        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);
        reconfiguration::initialize_for_test(supra);
        supra_oracle_storage::init_module_for_test(supra_oracles);
        supra_oracle_storage::set_price(1, 500_000_000, 18);
        supra_oracle_storage::set_price(500, 100_000_000, 18);
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        // init asset entry
        iAsset::init_iAsset_for_test(deployer);
        let asset = iAsset::create_new_iasset(
             deployer,
             b"BTC",
             b"iBTC",
             8,
             1,
             b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
             ORIGIN_TOKEN_ADDRESS,
             ORIGIN_TOKEN_CHAIN_ID,
             SOURCE_TOKEN_DECIMALS,
             SOURCE_TOKEN_ADDRESS);
        let asset = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);
        iAsset::create_iasset_entry_for_test(recipient_1, asset);

        let asset_amount1:u64= 5000;
        poel::borrow_request(asset, asset_amount1, recipient_1, 0, @0x0, 0, @0x0);

        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        poel::update_borrowed_amount(deployer);

        // user1 :: borrow before the borrow_request!!
        poel::borrow(asset, recipient_1);

        let user1_liq_address = iAsset::get_total_liquidity_provider_table_value_for_test(recipient_1);
        let (_, preminted_iassets, _, _, _) = iAsset::get_liquidity_provider_asset_entry_items_for_test(user1_liq_address, asset);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_,_,_,_, total_borrow_requests, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&items);

        assert!(preminted_iassets == 0, 1); // ensure preminted_iasset is valid
        assert!(total_borrow_requests == 0, 1);

        assert!(primary_fungible_store::balance(recipient_1, asset) == asset_amount1, 1);

        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_borrow(supra : &signer, deployer: &signer, supra_oracles: &signer) {
        let recipient_1 = @0x71;

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        let time0 = 100001000000;
        let delta = 3600;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);
        reconfiguration::initialize_for_test(supra);

        supra_oracle_storage::init_module_for_test(supra_oracles);
        supra_oracle_storage::set_price(1, 500_000_000, 18);
        supra_oracle_storage::set_price(500, 100_000_000, 18);

        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        // init asset entry
        iAsset::init_iAsset_for_test(deployer);

        poel::create_new_iasset(deployer, b"BTC", b"iBTC", 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        let asset = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);
        assert!(object::owner(asset) == signer::address_of(deployer), 1);

        let asset_amount1:u64= 5000;
        // user1 : borrow_request
        poel::borrow_request(asset, asset_amount1, recipient_1, 0, @0x0, 0, @0x0);

        let user1_liq_address = iAsset::get_total_liquidity_provider_table_value_for_test(recipient_1);
        let (_, preminted_iassets, _, _, _) = iAsset::get_liquidity_provider_asset_entry_items_for_test(user1_liq_address, asset);
        let items =  iAsset::get_liquidity_table_items(asset);
        let (_,_,_,_, total_borrow_requests, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&items);

        assert!(preminted_iassets == asset_amount1, 1); // ensure preminted_iasset is valid
        assert!(total_borrow_requests == asset_amount1, 1);

        assert!(primary_fungible_store::balance(recipient_1, asset) == 0, 1); // balance is 0, no real minting

        // change epoch because mint/borrow is allowed in the next epoch only
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();
        timestamp::fast_forward_seconds(delta);
        reconfiguration::reconfigure_for_test_custom();

        poel::update_borrowed_amount(deployer);
        // user1: borrow

        poel::borrow(asset, recipient_1);
        let (_, preminted_iassets, _, _, _) = iAsset::get_liquidity_provider_asset_entry_items_for_test(user1_liq_address, asset);
        assert!(preminted_iassets == 0 , 1); // preminted_iassets should be set to 0
        assert!(primary_fungible_store::balance(recipient_1, asset) == asset_amount1, 1);

        // user1: borrow again, no errors, not changes in the state
        poel::borrow(asset, recipient_1);
        let (_, preminted_iassets, _, _, _) = iAsset::get_liquidity_provider_asset_entry_items_for_test(user1_liq_address, asset);
        assert!(preminted_iassets == 0, 1); // preminted_iassets should be set to 0
        assert!(primary_fungible_store::balance(recipient_1, asset) == asset_amount1, 1);

        let supply = fungible_asset::supply(asset);
        assert!(option::get_with_default(&supply, 0) == (asset_amount1 as u128), 1);
        clean_up(burn_cap, mint_cap);
    }

    #[test(supra =@0x1, deployer = @dfmm_framework, validator_1 = @0x1, validator_2 = @0x2)]
    fun test_init_delegation_pools(supra: &signer, deployer: &signer, validator_1: &signer, validator_2: &signer) {
        let (pool_1, pool_2) = init_validators(supra, deployer, validator_1, validator_2);
        let pools = poel::get_delegation_pools();
        assert!(vector::length(&pools) == 0, 1);

        poel::initialize_delegation_pools(deployer, vector[pool_1, pool_2]);
        pools = poel::get_delegation_pools();
        assert!(vector::contains<address>(&pools, &pool_1), 1);
        assert!(vector::contains<address>(&pools, &pool_2), 1);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice = @0x999, validator_1 = @0x1, validator_2 = @0x2)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_init_delegation_pools_not_authorized(supra : &signer, deployer: &signer, alice : &signer, validator_1: &signer, validator_2: &signer) {
        let (pool_1, pool_2) = init_validators(supra, deployer, validator_1, validator_2);
        // init pools not authorized
        poel::initialize_delegation_pools(alice, vector[pool_1, pool_2]);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework,  validator_1 = @0x1, validator_2 = @0x2)]
    #[expected_failure(abort_code = 196624, location = poel )] // error::invalid_state(EPOOL_REGISTERED));
    fun test_init_delegation_pools_duplicate(supra : &signer, deployer: &signer, validator_1: &signer, validator_2: &signer) {
       let (pool_1, pool_2) = init_validators(supra, deployer, validator_1, validator_2);
        // init pools not authorized
        poel::initialize_delegation_pools(deployer, vector[pool_1, pool_2]);
        poel::initialize_delegation_pools(deployer, vector[pool_1]);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework)]
    fun test_create_iasset(supra : &signer, deployer: &signer) {
        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        // init asset entry
        iAsset::init_iAsset_for_test(deployer);
        poel::create_new_iasset(deployer, b"BTC", b"iBTC", 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        let asset = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);
        let (origin_token_address, origin_token_chain_id, source_token_decimals, source_bridge_address) = iAsset::deconstruct_iasset_source(&iAsset::get_iasset_source(asset));
        assert!(ORIGIN_TOKEN_ADDRESS == origin_token_address, 1);
        assert!(ORIGIN_TOKEN_CHAIN_ID == origin_token_chain_id, 1);
        assert!(SOURCE_TOKEN_DECIMALS == source_token_decimals, 1);
        assert!(SOURCE_TOKEN_ADDRESS == source_bridge_address, 1);
        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework)]
    fun test_update_pair_id(supra : &signer, deployer: &signer) {
        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        // init asset entry
        iAsset::init_iAsset_for_test(deployer);
        let pair_id = 0;
        poel::create_new_iasset(deployer, b"wBTC", b"iWBTC", pair_id,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/wbtc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        let asset = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);
        
        let (wbtc_pair_id, _, _, _, _, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&iAsset::get_liquidity_table_items(asset));
        assert!(wbtc_pair_id == pair_id, 1);

        let new_pair_id = 166;
        poel::batch_update_pair_ids(deployer, vector [asset], vector[new_pair_id]);
        let (wbtc_pair_id, _, _, _, _, _, _, _, _) = iAsset::deconstruct_liquidity_table_items(&iAsset::get_liquidity_table_items(asset));
        assert!(wbtc_pair_id == new_pair_id, 1);        

        clean_up(burn_cap, mint_cap);
    }


    #[test(supra = @0x1, deployer = @dfmm_framework)]
    #[expected_failure(abort_code = 327681, location = config )]
    fun test_update_pair_id_not_authorized(supra : &signer, deployer: &signer) {
        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        // init asset entry
        iAsset::init_iAsset_for_test(deployer);
        let pair_id = 0;
        poel::create_new_iasset(deployer, b"wBTC", b"iWBTC", pair_id,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/wbtc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        let asset = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);

        let new_pair_id = 166;
        poel::batch_update_pair_ids(supra, vector [asset], vector[new_pair_id]);

        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework)]
    #[expected_failure(abort_code = 327681, location = config )] // error::permission_denied(ENOT_ADMIN));
    fun test_create_iasset_not_authorized(supra : &signer, deployer: &signer) {
        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);
        // init pool
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        // init asset entry
        iAsset::init_iAsset_for_test(deployer);
        poel::create_new_iasset(supra, b"BTC", b"iBTC", 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/btc.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        clean_up(burn_cap, mint_cap);
    }


    fun assert_vault_address_initialization (deployer_addr:address, vault_addr:address) {
        // vault address is not deployer
        assert!(poel::get_vault_address() != deployer_addr, 0);
        // Poel Vault = 0
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == 0, 0);
        // counter is 0
        assert!(poel::get_total_borrowable_amount() == 0, 0);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, supra_oracles = @supra_oracle)]
    fun test_total_rentable(supra : &signer, deployer: &signer, supra_oracles: &signer) {

        supra_oracle_storage::init_module_for_test(supra_oracles);
        let time0 = 100001000000;
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(time0);

        let supra_price: u128 = 4700000000000000;
        let asset_price: u128 = 2610000000000000000000;
        supra_oracle_storage::set_price(1, asset_price, 18); // eth
        supra_oracle_storage::set_price(500, supra_price, 18); // supra

        let deployer_address = signer::address_of(deployer);

        config::init_for_test(deployer);
        asset_config::init_for_test(deployer);
        let (burn_cap, mint_cap) = test_util::init_router_poel_iasset(deployer, supra); // poel, iasset
        chain_id::initialize_for_test(supra, CHAIN_ID);

        poel::create_new_iasset(deployer, b"iETH", b"iETH", 1,
            b"https://qa-supra-nova-ui.supra.com/images/currency-icons/ethereum.svg", b"https://qa-supra-nova-ui.supra.com/iasset-factory",
            ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID, SOURCE_TOKEN_DECIMALS, SOURCE_TOKEN_ADDRESS);
        let ieth_asset = iAsset::get_iasset_metadata(ORIGIN_TOKEN_ADDRESS, ORIGIN_TOKEN_CHAIN_ID);

        // 0.05eth  = 5000000
        let eth_amount= 5000000;
        let supra_amount = 10_000_00000000;
        poel::borrow_request(ieth_asset, eth_amount, deployer_address, 0, @0x0, 0, @0x0);

        let user1_liq_address = iAsset::get_total_liquidity_provider_table_value_for_test(deployer_address); // for recipient
        let (_, preminted_ieth, _, _, _) = iAsset::get_liquidity_provider_asset_entry_items_for_test(user1_liq_address, ieth_asset);
        assert!(preminted_ieth == eth_amount, 1); // ensure preminted_iasset is valid

        //2221276595000
        let principle_amount = iAsset::calculate_principle(1050, 1150, 1250);
        assert!(2221276595000 == principle_amount, 1);
        clean_up(burn_cap, mint_cap);
    }

    #[test(supra_framework = @supra_framework, deployer = @dfmm_framework, validator_1 = @0x1, validator_2 = @0x2)]
    fun test_delegate_with_inactive(deployer: &signer, supra_framework: &signer, validator_1: &signer, validator_2: &signer) {
        let (pool_address_1, pool_address_2) = init_validators(supra_framework, deployer, validator_1, validator_2);
        poel::initialize_delegation_pools(deployer, vector[pool_address_1, pool_address_2]);
        let obj_address = poel::get_vault_address();

        let (active_stake_1, _, _) = pbo_delegation_pool::get_stake(pool_address_1, obj_address);
        let (active_stake_2, _, _) = pbo_delegation_pool::get_stake(pool_address_2, obj_address);
        assert!(active_stake_1 / ONE_SUPRA == 9, 1);
        assert!(active_stake_2 / ONE_SUPRA == 19, 1);

        stake::leave_validator_set(validator_1, pool_address_1); // inactive 1st
        let delegated = poel::delegate_tokens_for_test(40 * ONE_SUPRA, 30 * ONE_SUPRA);
        assert!(delegated / ONE_SUPRA == 10, 1); // 1st is not active, only 10 delegated

        let (active_stake_1, _, _) = pbo_delegation_pool::get_stake(pool_address_1, obj_address);
        let (active_stake_2, _, _) = pbo_delegation_pool::get_stake(pool_address_2, obj_address);

        assert!(active_stake_1 / ONE_SUPRA == 9, 1); // not delegated, it is not active
        assert!(active_stake_2 / ONE_SUPRA == 29, 1); // delegated 10
    }

    #[test(supra_framework = @supra_framework, deployer = @dfmm_framework, validator_1 = @0x1, validator_2 = @0x2)]
    fun test_delegate_fits_under_cap(deployer: &signer, supra_framework: &signer, validator_1: &signer, validator_2: &signer) {
        let (pool_address_1, pool_address_2) = init_validators(supra_framework, deployer, validator_1, validator_2);
        poel::initialize_delegation_pools(deployer, vector[pool_address_1, pool_address_2]);
        let obj_address = poel::get_vault_address();

        let delegated = poel::delegate_tokens_for_test(40 * ONE_SUPRA, 30 * ONE_SUPRA);
        assert!(delegated / ONE_SUPRA == 30, 1); // return the total delegated counter

        let (active_stake_1, _, _) = pbo_delegation_pool::get_stake(pool_address_1, obj_address);
        let (active_stake_2, _, _) = pbo_delegation_pool::get_stake(pool_address_2, obj_address);

        assert!(active_stake_1 / ONE_SUPRA == 29, 1);
        assert!(active_stake_2 / ONE_SUPRA == 29, 1);
    }

    #[test(supra_framework = @supra_framework, deployer = @dfmm_framework, supra = @0x1, validator_1 = @0x123, validator_2 = @0x2)]
    public fun test_replace_success(supra_framework: &signer, deployer: &signer, supra: &signer,  validator_1: &signer, validator_2: &signer) {
        let (old_pool, new_pool) = init_validators(supra_framework, deployer, validator_1, validator_2);
        iAsset::init_iAsset_for_test(deployer);
        poel::initialize_delegation_pools(deployer, vector[old_pool, new_pool]);

        let pool_vec = poel::get_delegation_pools();
        assert!(vector::length(&pool_vec) == 2, 1001); // 2 pools

        poel::replace_delegation_pool_request(deployer, old_pool);

        let pool_vec = poel::get_delegation_pools();
        assert!(!vector::contains(&pool_vec, &old_pool), 1001);

        let (replaced_pool, _, _) = poel::deconstruct_replaced_delegation_pool(&poel::get_replaced_delegation_pool());
        assert!(replaced_pool == old_pool, 1001);

        iAsset::update_recent_cycle_update_epoch(4);

        timestamp::fast_forward_seconds(2592060);
        stake::end_epoch();

        poel::replace_delegation_pool(deployer, new_pool);
        let pool_vec = poel::get_delegation_pools();
        assert!(vector::length(&pool_vec) == 1, 1001); // 1 pool

        let (replaced_pool, replaced_delegated, replaced_lockup_cycle_update_epoch) = poel::deconstruct_replaced_delegation_pool(&poel::get_replaced_delegation_pool());
        assert!(replaced_pool == @0x0, 1002);
        assert!(replaced_delegated == 0, 1003);
        assert!(replaced_lockup_cycle_update_epoch == 0, 1004);

        let (_, inactive_after, _) = pbo_delegation_pool::get_stake(old_pool, poel::get_vault_address());
        assert!(inactive_after == 0, 1005);

        let pool_vec = poel::get_delegation_pools();
        assert!(vector::length(&pool_vec) == 1, 1001);
        assert!(vector::contains(&pool_vec, &new_pool), 1001);
    }

    #[test(supra_framework = @supra_framework, deployer = @dfmm_framework, supra = @0x1, validator_1 = @0x123, validator_2 = @0x2)]
    #[expected_failure(abort_code = 196636)]
    public fun test_replace_pool_with_leftover(supra_framework: &signer, deployer: &signer, supra: &signer,  validator_1: &signer, validator_2: &signer) {
        let (old_pool, new_pool) = init_validators(supra_framework, deployer, validator_1, validator_2);
        poel::initialize_delegation_pools(deployer, vector[old_pool, new_pool]);
        iAsset::init_iAsset_for_test(deployer);
        let pool_vec = poel::get_delegation_pools();
        assert!(vector::length(&pool_vec) == 2, 1001); // 2 pools

        poel::replace_delegation_pool_request(deployer, old_pool);

        let pool_vec = poel::get_delegation_pools();
        assert!(!vector::contains(&pool_vec, &old_pool), 1001);

        let (replaced, _, _) = poel::deconstruct_replaced_delegation_pool(&poel::get_replaced_delegation_pool());
        assert!(replaced == old_pool, 1001);

        iAsset::update_recent_cycle_update_epoch(4);
        timestamp::fast_forward_seconds(2592060);

        poel::replace_delegation_pool(deployer, new_pool);
    }

    #[test(supra_framework = @supra_framework, deployer = @dfmm_framework, supra = @0x1, validator_1 = @0x123, validator_2 = @0x234)]
    public fun test_unlock_tokens(supra_framework: &signer, deployer: &signer, supra: &signer, validator_1: &signer, validator_2: &signer) {
        let (pool_1, pool_2) = init_validators(supra_framework, deployer, validator_1, validator_2);
        poel::initialize_delegation_pools(deployer, vector[pool_1, pool_2]);
        let unlock = poel::unlock_tokens_for_test(20 * ONE_SUPRA, 20 * ONE_SUPRA);
        assert!((unlock / ONE_SUPRA) == 20, 1001);
    }

    #[test(supra_framework = @supra_framework, deployer = @dfmm_framework, supra = @0x1, validator_1 = @0x123, validator_2 = @0x234)]
    public fun test_unlock_tokens_with_inactive(supra_framework: &signer, deployer: &signer, supra: &signer, validator_1: &signer, validator_2: &signer) {
        let (pool_1, pool_2) = init_validators(supra_framework, deployer, validator_1, validator_2);
        
        poel::initialize_delegation_pools(deployer, vector[pool_1, pool_2]); // 10 tokens, 20 tokens
        stake::leave_validator_set(validator_1, pool_1); // inactive 1st

        let unlock = poel::unlock_tokens_for_test(10 * ONE_SUPRA, 20 * ONE_SUPRA);
        assert!((unlock / ONE_SUPRA) == 10, 1001);

        let unlock = poel::unlock_tokens_for_test(10 * ONE_SUPRA, 20 * ONE_SUPRA);
        assert!((unlock / ONE_SUPRA) == 8, 1001);        
    }

    #[test(supra_framework = @supra_framework, deployer = @dfmm_framework, supra = @0x1, validator_1 = @0x123, validator_2 = @0x234, validator_3 = @0x323, validator_4 = @0x434)]
    public fun test_top_bottom_pools(supra_framework: &signer, deployer: &signer, supra: &signer, validator_1: &signer, validator_2: &signer, validator_3: &signer, validator_4: &signer) {
        pbo_delegation_pool::initialize_for_test(supra_framework);
        config::init_for_test(deployer);
        iAsset::init_iAsset_for_test(deployer);
        poel::init_poel_for_test(deployer);

        let principle_lockup_time = 0;
        let principle_stake = vector[];
        let coin_1 = stake::mint_coins(0 * ONE_SUPRA);
        let coin_2 = stake::mint_coins(0 * ONE_SUPRA);
        let coin_3 = stake::mint_coins(0 * ONE_SUPRA);
        let coin_4 = stake::mint_coins(0 * ONE_SUPRA);

        let val_1_address = signer::address_of(validator_1);
        let val_2_address = signer::address_of(validator_2);
        let val_3_address = signer::address_of(validator_3);
        let val_4_address = signer::address_of(validator_4);

        let delegator_address_vec = vector[];
        pbo_delegation_pool::initialize_test_validator(
            validator_1,
            VALIDATOR_SUPRA,
            true,
            true,
            0,
            delegator_address_vec,
            principle_stake,
            coin_1,
            option::none(),
            vector[2, 2, 3],
            10,
            principle_lockup_time,
            LOCKUP_CYCLE_SECONDS
        );
        pbo_delegation_pool::initialize_test_validator(
            validator_2,
            VALIDATOR_SUPRA,
            true,
            true,
            0,
            delegator_address_vec,
            principle_stake,
            coin_2,
            option::none(),
            vector[2, 2, 3],
            10,
            principle_lockup_time,
            LOCKUP_CYCLE_SECONDS
        );
        pbo_delegation_pool::initialize_test_validator(
            validator_3,
            VALIDATOR_SUPRA,
            true,
            true,
            0,
            delegator_address_vec,
            principle_stake,
            coin_3,
            option::none(),
            vector[2, 2, 3],
            10,
            principle_lockup_time,
            LOCKUP_CYCLE_SECONDS
        );
        pbo_delegation_pool::initialize_test_validator(
            validator_4,
            VALIDATOR_SUPRA,
            true,
            true,
            0,
            delegator_address_vec,
            principle_stake,
            coin_4,
            option::none(),
            vector[2, 2, 3],
            10,
            principle_lockup_time,
            LOCKUP_CYCLE_SECONDS
        );
        let pool_address_1 = pbo_delegation_pool::get_owned_pool_address(val_1_address);
        let pool_address_2 = pbo_delegation_pool::get_owned_pool_address(val_2_address);
        let pool_address_3 = pbo_delegation_pool::get_owned_pool_address(val_3_address);
        let pool_address_4 = pbo_delegation_pool::get_owned_pool_address(val_4_address);

        poel::initialize_delegation_pools(deployer, vector[pool_address_1, pool_address_2]);

        poel::mint_stake(vector[pool_address_1, pool_address_2, pool_address_3, pool_address_4],
            vector[10 * ONE_SUPRA, 20 * ONE_SUPRA, 5 * ONE_SUPRA, 40 * ONE_SUPRA]);

        let (_, max_idx_1,  _, max_idx_2) = poel::find_top_pools_for_test(&vector[pool_address_1, pool_address_2,pool_address_3, pool_address_4], poel::get_vault_address());
        let (_, min_idx_1,  _, min_idx_2) = poel::find_bottom_pools_for_test(&vector[pool_address_1, pool_address_2,pool_address_3, pool_address_4], poel::get_vault_address(), 100 * ONE_SUPRA);

        assert!(min_idx_1 == 2, 1001);
        assert!(min_idx_2 == 0, 1002);

        assert!(max_idx_1 == 3, 1003);
        assert!(max_idx_2 == 1, 1004);
    }

    #[test(admin = @dfmm_framework, supra_oracles = @supra_oracle, supra = @0x1)]
    public fun test_get_coll_rates(
        admin:   &signer,
        supra:   &signer,
        supra_oracles: &signer
    )  {
        // init_poel_for_test(admin);
        iAsset::init_iAsset_for_test(admin);
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(1);
        supra_oracle_storage::init_module_for_test(supra_oracles);
        config::init_for_test(admin);

        supra_oracle_storage::set_price(1, 1, 18);
        supra_oracle_storage::set_price(2, 2, 18);
        supra_oracle_storage::set_price(500, 10, 18);

        let (asset, _) = iAsset::create_test_assets(admin);

        config::set_parameters(
            admin,
            50,
            0, 0, 0,
            75,
            100,
            0, 0, 0, 0, 0, 0
        );

        iAsset::increase_collateral_supply(asset, 100);


        let rates = iAsset::get_coll_rates();

        assert!(vector::length(&rates) == 2, 1001);

        let (pair_asset, pair_value) = iAsset::deconstruct_asset_value_pair(vector::borrow(&rates, 0));
        assert!(pair_asset == iAsset::get_asset_address(asset), 1002);
        assert!(pair_value == 100, 1003);
    }

    fun test_dummy_fa (admin:&signer, name:vector<u8>, symbol:vector<u8>) : Object<Metadata> {
        let metadata_constructor_ref = &object::create_named_object(admin, symbol);

        // Create a store enabled fungible asset
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            metadata_constructor_ref,
            option::none(),
            string::utf8(name),
            string::utf8(symbol),
            8,
            string::utf8(b""),
            string::utf8(b""),
        );
        let metadata = object::object_from_constructor_ref(metadata_constructor_ref);
        metadata
    }

    #[test_only]
    fun init_validators(supra_framework: &signer, deployer: &signer, validator_1: &signer, validator_2: &signer): (address, address) {
        pbo_delegation_pool::initialize_for_test(supra_framework);
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        let principle_lockup_time = 0;
        let principle_stake = vector[];
        let coin_1 = stake::mint_coins(0 * ONE_SUPRA);
        let coin_2 = stake::mint_coins(0 * ONE_SUPRA);

        let val_1_address = signer::address_of(validator_1);
        let val_2_address = signer::address_of(validator_2);
        let delegator_address_vec = vector[];
        pbo_delegation_pool::initialize_test_validator(
            validator_1,
            VALIDATOR_SUPRA,
            true,
            true,
            0,
            delegator_address_vec,
            principle_stake,
            coin_1,
            option::none(),
            vector[2, 2, 3],
            10,
            principle_lockup_time,
            LOCKUP_CYCLE_SECONDS
        );
        pbo_delegation_pool::initialize_test_validator(
            validator_2,
            VALIDATOR_SUPRA,
            true,
            true,
            0,
            delegator_address_vec,
            principle_stake,
            coin_2,
            option::none(),
            vector[2, 2, 3],
            10,
            principle_lockup_time,
            LOCKUP_CYCLE_SECONDS
        );
        let pool_address_1 = pbo_delegation_pool::get_owned_pool_address(val_1_address);
        let pool_address_2 = pbo_delegation_pool::get_owned_pool_address(val_2_address);

        poel::mint_stake(vector[pool_address_1, pool_address_2], vector[10 * ONE_SUPRA, 20 * ONE_SUPRA]);

        (pool_address_1, pool_address_2)
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice = @0x999)]
    fun test_add_single_asset_extra_rewards(supra : &signer, deployer: &signer, alice : &signer) {

        let deployer_addr = signer::address_of(deployer);
        let supra_addr = signer::address_of(supra);
        let alice_addr = signer::address_of(alice);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        // init
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        iAsset::init_iAsset_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        let vault_addr = poel::get_vault_address();
        assert_vault_address_initialization(deployer_addr, vault_addr);

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        // transfer to alice 6k
        supra_account::transfer(supra, alice_addr, 6000);
        // transfer to deployer 5k
        supra_account::transfer(supra, deployer_addr, 5000);

        let (iasset1, iasset2) = iAsset::create_test_assets(deployer);

        assert!(poel::get_total_borrowable_amount() == 0, 0);
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == 0, 0);

        // iasset 1
        poel::add_single_asset_extra_rewards(alice, iasset1, 2000); // add 2k
        assert!(poel::get_single_asset_reward_balance_for_test(iasset1) == 2000, 1);
        
        poel::add_single_asset_extra_rewards(alice, iasset1, 1000); // add 1k
        assert!(poel::get_single_asset_reward_balance_for_test(iasset1) == 3000, 1);
        assert!(poel::get_allocated_rewards_balance() == 3000, 1);

        // iasset 2
        assert!(poel::get_single_asset_reward_balance_for_test(iasset2) == 0, 1);   
        poel::add_single_asset_extra_rewards(deployer, iasset2, 2000); // add 2k
        assert!(poel::get_single_asset_reward_balance_for_test(iasset2) == 2000, 1);

        assert!(poel::get_total_borrowable_amount() == 0, 0);
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == 5000, 0); // 1k + 2k + 2k
        assert!(poel::get_allocated_rewards_balance() == 5000, 1);

        clean_up(burn_cap, mint_cap);
    }

    #[test(supra = @0x1, deployer = @dfmm_framework, alice = @0x999)]
    fun test_add_multi_asset_extra_rewards(supra : &signer, deployer: &signer, alice : &signer) {

        let deployer_addr = signer::address_of(deployer);
        let supra_addr = signer::address_of(supra);
        let alice_addr = signer::address_of(alice);

        account::create_account_for_test(signer::address_of(supra));
        let (burn_cap, mint_cap) = supra_framework::supra_coin::initialize_for_test(supra);

        // init
        config::init_for_test(deployer);
        poel::init_poel_for_test(deployer);
        coin::register<supra_coin::SupraCoin>(supra);

        let vault_addr = poel::get_vault_address();
        assert_vault_address_initialization(deployer_addr, vault_addr);

        // mint some Supra tp supra_framework
        coin::deposit(supra_addr, coin::mint(20000, &mint_cap));
        // transfer to alice 6k
        supra_account::transfer(supra, alice_addr, 6000);
        // transfer to deployer 5k
        supra_account::transfer(supra, deployer_addr, 5000);

        assert!(poel::get_total_borrowable_amount() == 0, 0);
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == 0, 0);

        poel::add_multi_asset_extra_rewards(alice, 2000); // add 2k
        assert!(poel::get_multiple_asset_reward_balance_for_test() == 2000, 1);

        poel::add_multi_asset_extra_rewards(deployer, 3000); // add 3k
        assert!(poel::get_multiple_asset_reward_balance_for_test() == 5000, 1);        
        
        assert!(poel::get_allocated_rewards_balance() == 5000, 1);
        assert!(poel::get_total_borrowable_amount() == 0, 0);
        assert!(coin::balance<supra_coin::SupraCoin>(vault_addr) == 5000, 0);
        assert!(poel::get_allocated_rewards_balance() == 5000, 1);

        clean_up(burn_cap, mint_cap);
    }    

}