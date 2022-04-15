script {
    use Std::Signer;
    use AptosSwap::Router;
    use AptosSwap::LPToken::{Self, LPToken};

    // Errors. 
    const ERR_POOL_ALREADY_EXISTS: u64 = 101;

    /// Just an example how to register new pool X/Y with your own LP token.
    /// You can take this example, modify for your LP token and use.
    fun register_pool_example<X: store, Y: store>(
        account: signer, 
    ) {
        let (mint_cap, burn_cap) = LPToken::register(&account);

        let pool_addr = Signer::address_of(&account);

        assert!(Router::pool_exists_at<X, Y, LPToken>(pool_addr), ERR_POOL_ALREADY_EXISTS);

        Router::register_liquidity_pool<X, Y, LPToken>(&account, mint_cap, burn_cap);
    }
}
