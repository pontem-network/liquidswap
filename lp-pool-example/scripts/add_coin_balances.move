script {
    use AptosFramework::Coin;
    use Sender::Coins::{BTC, USDT};

    fun register_for_tokens(acc: signer) {
        Coin::register<BTC>(&acc);
        Coin::register<USDT>(&acc);
    }
}
