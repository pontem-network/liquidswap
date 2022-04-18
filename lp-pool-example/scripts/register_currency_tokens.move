script {
    use Std::ASCII::string;
    use AptosSwap::Token;

    use Sender::Tokens;

    fun register_currency_tokens(token_admin: signer) {
        Token::register_token_to_acc<Tokens::BTC>(&token_admin, 1, string(b"BTC"));
        Token::register_token_to_acc<Tokens::USDT>(&token_admin, 1, string(b"USDT"));
    }
}
