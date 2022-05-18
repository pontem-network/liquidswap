script {
    use Sender::Coins;

    fun register_currency_tokens(token_admin: signer) {
        Coins::register_tokens(token_admin);
    }
}
