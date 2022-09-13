module liquidswap::lp_coin {
    use std::string::String;

    use aptos_framework::coin::{Self, MintCapability, BurnCapability};
    use liquidswap_lp::coin::LP;

    friend liquidswap::liquidity_pool;

    const ERR_NOT_INITIALIZED: u64 = 901;

    const ERR_NO_PERMISSIONS: u64 = 902;

    // struct CoinInfo<phantom CoinType> has key { decimals_scale: u64 }

    // public(friend) fun cache_decimals_scale<CoinType>(pool_account: &signer) {
    //     let decimals_scale = math::pow_10(coin::decimals<CoinType>());
    //     move_to(pool_account, CoinInfo<>)
    // }

    // public fun get_cached_decimals_scale<CoinType>(): u64 acquires CoinInfo {
    //     let coin_info = borrow_global<CoinInfo<CoinType>>(@liquidswap_pool_account);
    //     coin_info.decimals_scale
    // }

    public(friend) fun register_lp_coin<X, Y, Curve>(
        pool_account: &signer,
        lp_name: String,
        lp_symbol: String
    ): (MintCapability<LP<X, Y, Curve>>, BurnCapability<LP<X, Y, Curve>>) {
        let (lp_burn_cap, lp_freeze_cap, lp_mint_cap) =
            coin::initialize<LP<X, Y, Curve>>(
                pool_account,
                lp_name,
                lp_symbol,
                6,
                true
            );
        coin::destroy_freeze_cap(lp_freeze_cap);
        (lp_mint_cap, lp_burn_cap)
    }

    public fun is_lp_coin_registered<X, Y, Curve>(): bool {
        coin::is_coin_initialized<LP<X, Y, Curve>>()
    }
}
