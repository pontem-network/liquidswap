script {
    use Std::PontAccount;

    use AptosSwap::Token;
    use AptosSwap::Router;

    fun add_liquidity<X: store, Y: store, LP>(
        liquidity_provider: signer,
        pool_addr: address,
        token_x_num: u128,
        token_y_num: u128
    ) {
        let token_x = PontAccount::withdraw_tokens<X>(&liquidity_provider, token_x_num);
        let token_y = PontAccount::withdraw_tokens<Y>(&liquidity_provider, token_y_num);

        Router::add_liquidity<X, Y, LP>(pool_addr, token_x, token_x_num)
    }
}
