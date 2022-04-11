module AptosSwap::MyPool {
    use AptosSwap::Token;
    use AptosSwap::LiquidityPool;

    struct LP { val: u128 }

    public(script) fun register_pool<X, Y>(pool_owner: &signer) {
        let (lp_mint_cap, lp_burn_cap) = Token::register_token<LP>(&pool_owner, )
        PontAccount::create_token_balance<>()
        LiquidityPool::register<X, Y, LP>(&pool_owner, )
    }
}

script {

    fun main<X: store, Y: store, LP>(pool_owner: signer) {
    }
}
