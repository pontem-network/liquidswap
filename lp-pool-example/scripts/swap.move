script {
    use AptosSwap::Scripts;
    use Sender::Coins::{BTC, USDT, LP};

    fun swap(acc: signer, pool_addr: address, btc_in: u64, usdt_out_min: u64) {
        Scripts::swap<BTC, USDT, LP>(acc, pool_addr, btc_in, usdt_out_min);
    }
}
