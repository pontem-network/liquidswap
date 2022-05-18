script {
    use Std::ASCII::string;

    use AptosSwap::Router;

    use Sender::Coins::{USDT, BTC, LP};
    use AptosFramework::Coin;

    fun register_pool(token_admin: signer, pool_owner: signer) {
        let (m, b) = Coin::initialize<LP>(&token_admin,
            string(b"LPToken"), string(b"LP"), 10, true);

        Router::register_liquidity_pool<BTC, USDT, LP>(&pool_owner, m, b);
    }
}
