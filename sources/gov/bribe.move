module liquidswap::bribe {
    use aptos_framework::coin::Coin;

    use liquidswap::liquid::LAMM;

    struct Bribe has store {
        rewards: Coin<LAMM>
    }
}
