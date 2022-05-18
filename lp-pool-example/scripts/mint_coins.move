script {
    use Sender::Coins;
    use AptosFramework::Coin;

    fun mint_tokens(token_admin: signer, addr: address, btc_amount: u64, usdt_amount: u64) {
        let btc = Coins::mint_btc(&token_admin, btc_amount);
        let usdt = Coins::mint_usdt(&token_admin, usdt_amount);

        Coin::deposit(addr, btc);
        Coin::deposit(addr, usdt);
    }
}
