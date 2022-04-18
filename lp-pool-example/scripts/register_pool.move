script {
    use Std::ASCII::string;

    use AptosSwap::Router;
    use AptosSwap::Token;

    use Sender::Tokens::{USDT, BTC, LP};

    fun register_pool(token_admin: signer, pool_owner: signer) {
        let (m, b) =
            Token::register_token<LP>(&token_admin, 10, string(b"LP"));
        Router::register_liquidity_pool<BTC, USDT, LP>(&pool_owner, m, b);
    }
}
