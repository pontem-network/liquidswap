/// Marker structures to use in LiquidityPool third generic.
module liquidswap::curves {
    use aptos_std::type_info;

    // For pairs like BTC, USDT
    struct Uncorrelated {}

    // For stablecoins like USDC, USDT
    struct Stable {}

    public fun is_uncorrelated_curve<Curve>(): bool {
        type_info::type_of<Curve>() == type_info::type_of<Uncorrelated>()
    }

    public fun is_stable_curve<Curve>(): bool {
        type_info::type_of<Curve>() == type_info::type_of<Stable>()
    }
}
