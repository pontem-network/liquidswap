script {
    use AptosSwap::Scripts;
    use Sender::Coins::{BTC, USDT, LP};

    fun add_liquidity(acc: signer, pool_addr: address, btc_amount: u64, usdt_amount: u64) {
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
