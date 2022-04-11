script {
    use Std::PontAccount;
    use Std::Signer;

    use AptosSwap::Token;
    use AptosSwap::Router;

    fun add_liquidity<X: store, Y: store, LP>(
        provider: signer,
        pool_addr: address,
        token_x_num: u128,
        token_x_num_min: u128,
        token_y_num: u128,
        token_y_num_min: u128
    ) {
        let token_x = PontAccount::withdraw_tokens<X>(&provider, token_x_num);
        let token_y = PontAccount::withdraw_tokens<Y>(&provider, token_y_num);

        let (token_x_remainder, token_y_remainder, lp_tokens) =
            Router::add_liquidity<X, Y, LP>(pool_addr, token_x, token_x_num_min, token_y, token_y_num_min);

        let provider_addr = Signer::address_of(&provider);
        PontAccount::deposit_token(provider_addr, token_x_remainder, provider_addr);
        PontAccount::deposit_token(provider_addr, token_y_remainder, provider_addr);
        PontAccount::deposit_token(provider_addr, lp_tokens, pool_addr);
    }
}
