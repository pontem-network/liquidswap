script {
    use AptosSwap::Scripts;
    use Sender::Tokens::{BTC, USDT, LP};

    fun add_liquidity(acc: signer, btc_amount: u128, usdt_amount: u128) {
        let pool_addr = @Sender;
        Scripts::add_liquidity<BTC, USDT, LP>(
            acc,
            pool_addr,
            btc_amount,
            btc_amount - 1,
            usdt_amount,
            usdt_amount - 1
        );
    }
}
