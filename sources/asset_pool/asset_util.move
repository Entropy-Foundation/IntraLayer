/// SPDX-License-Identifier: BUSL-1.1
/// Copyright (c) 2025 Supra Labs
///
/// Utility functions used by asset pools and poel
/// 
module dfmm_framework::asset_util {

    use std::bcs;
    use std::vector;
    use std::option::{Self, Option};
    use std::string::{Self};
    use aptos_std::object::{Self, Object};
    use aptos_std::type_info::{Self};
    use aptos_std::from_bcs;
    use aptos_std::error;
    use aptos_std::math128;
    use supra_framework::fungible_asset::{Metadata};
    use supra_framework::supra_coin::SupraCoin;

    /// Largest 64-bit unsigned integer.
    const MAX_U64: u64 = 18446744073709551615;

    /// Zero price not allowed for calculation
    const EPRICE_ZERO: u64 = 1;

    ///  return asset value in the price2 based on its price1
    #[view]
    public fun get_asset_value_in(asset_amount:u64, price_1: u128, decimal_1: u16, price_2: u128, decimal_2: u16): u128 {
        assert!(price_1 > 0 && price_2 > 0, error::invalid_state(EPRICE_ZERO));
        let nprice_1 = scale(price_1, decimal_1, 18); // 18 is the biggest decimals from oracle
        let nprice_2 = scale(price_2, decimal_2, 18); // 18 is the biggest decimals from oracle
        let calculated_amount = math128::mul_div((asset_amount as u128), nprice_1, nprice_2);
        calculated_amount
    }

    public fun get_asset_value_in_safe_u64(asset_amount:u64, price_1: u128, decimal_1: u16, price_2: u128, decimal_2: u16): u64 {
        option::destroy_some(safe_u128_to_u64(
            get_asset_value_in(asset_amount, price_1, decimal_1, price_2, decimal_2)
        ))
    }

    /// Rescale value from from_scale decimals to to_scale decimals
    public fun scale (value:u128, from_scale:u16, to_scale: u16):u128 {
        if (from_scale > to_scale) {
            value / math128::pow(10, ((from_scale  - to_scale) as u128))
        } else if (from_scale < to_scale) {
            value * math128::pow(10, ((to_scale - from_scale) as u128))
        }else value
    }

    /// Convenience: treat an incoming u64 (assumed to be at 8 decimals) and scale to to_scale
    public fun scale_to_origin (value:u64, to_scale: u16):u128 {
        scale((value as u128), 8, to_scale)
    }

    /// Convert a big-endian byte vector to u64
    public fun bytes_to_u64 (x: vector<u8>): u64 {
        vector::reverse(&mut x);
        (from_bcs::to_u256(x) as u64)
    }

    public fun get_address_from_key (key: vector<u8>):address {
        from_bcs::to_address(key)
    }

    public fun get_address_key (addr: &address):vector<u8> {
        bcs::to_bytes(addr)
    }

    public fun get_fa_metadata(key: vector<u8>): Object<Metadata> {
        let addr = get_address_from_key(key);
        object::address_to_object<Metadata>(addr)
    }

    public fun get_fa_key(asset: Object<Metadata>): vector<u8> {
        bcs::to_bytes(&object::object_address(&asset))
    }

    public fun get_supra_coin_key(): vector<u8> {
        *string::bytes(&type_info::type_name<SupraCoin>())
    }

    public fun safe_u128_to_u64(value: u128): Option<u64> {
        if (value <= (MAX_U64 as u128)) {
            option::some((value as u64))
        } else {
            option::none<u64>()
        }
    }
}
