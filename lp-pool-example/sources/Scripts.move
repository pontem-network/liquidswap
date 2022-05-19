module Sender::Scripts {
    use AptosFramework::Coin;
    use AptosSwap::Router;
    use Sender::Coins::{LP, BTC, USDT};
    use Std::ASCII::string;
    use AptosSwap::Scripts;

    public(script) fun register_pool(pool_owner: signer) {
        let (m, b) = Coin::initialize<LP>(&pool_owner,
            string(b"LPToken"), string(b"LP"), 10, true);
        Router::register_liquidity_pool<BTC, USDT, LP>(&pool_owner, m, b);
    }

    public(script) fun add_liquidity(acc: signer, pool_addr: address, btc_amount: u64, usdt_amount: u64) {
        Scripts::add_liquidity<BTC, USDT, LP>(
            acc,
            pool_addr,
            btc_amount,
            btc_amount - 1,
            usdt_amount,
            usdt_amount - 1
        )
    }

    public(script) fun swap(acc: signer, pool_addr: address, btc_in: u64, usdt_out_min: u64) {
        Scripts::swap<BTC, USDT, LP>(
            acc, pool_addr, btc_in, usdt_out_min);
    }
}
