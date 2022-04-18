script {
    use Std::PontAccount;
    use Std::Signer;
    use AptosSwap::Scripts;
    use Sender::Tokens::{BTC, USDT, LP};

    fun swap(acc: signer, pool_addr: address, btc_in: u128, usdt_out_min: u128) {
        Scripts::swap<BTC, USDT, LP>(acc, pool_addr, btc_in, usdt_out_min);
    }
}
