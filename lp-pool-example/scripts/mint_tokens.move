script {
    use Std::PontAccount;
    use AptosSwap::Token;
    use Sender::Tokens::{BTC, USDT};

    fun mint_tokens(token_admin: signer, addr: address, btc_amount: u128, usdt_amount: u128) {
        let btcs = Token::mint_with_token_admin<BTC>(&token_admin, btc_amount);
        let usdts = Token::mint_with_token_admin<USDT>(&token_admin, usdt_amount);
        PontAccount::deposit_token(addr, btcs);
        PontAccount::deposit_token(addr, usdts);
    }
}
