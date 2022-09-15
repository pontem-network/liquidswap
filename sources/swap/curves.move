/// Marker structures to use in LiquidityPool third generic.
module liquidswap::curves {
    use aptos_std::type_info;

    /// For pairs like BTC, Aptos, ETH.
    struct Uncorrelated {}

    /// For stablecoins like USDC, USDT.
    struct Stable {}

    /// Check provided `Curve` type is Uncorrelated.
    public fun is_uncorrelated<Curve>(): bool {
        type_info::type_of<Curve>() == type_info::type_of<Uncorrelated>()
    }

    /// Check provided `Stable` type is Stable.
    public fun is_stable<Curve>(): bool {
        type_info::type_of<Curve>() == type_info::type_of<Stable>()
    }
}
