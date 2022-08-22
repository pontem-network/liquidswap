module liquidswap::bribe {
    use aptos_framework::coin::Coin;

    use liquidswap::liquid::LAMM;
    use aptos_framework::coin;

    friend liquidswap::gauge;

    struct Bribe has store {
        rewards: Coin<LAMM>
    }

    public(friend) fun zero_bribe(): Bribe {
        Bribe {
            rewards: coin::zero()
        }
    }
}
