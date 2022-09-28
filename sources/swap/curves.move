/// Marker structures to use in LiquidityPool third generic.
module liquidswap::curves {
    use aptos_std::type_info;

    const ERR_INVALID_CURVE: u64 = 10001;

    /// For pairs like BTC, Aptos, ETH.
    struct Uncorrelated {}

    /// For stablecoins like USDC, USDT.
    struct Stable {}

    /// Check provided `Curve` type is Uncorrelated.
    public fun is_uncorrelated<Curve>(): bool {
        type_info::type_of<Curve>() == type_info::type_of<Uncorrelated>()
    }

    /// Check provided `Curve` type is Stable.
    public fun is_stable<Curve>(): bool {
        type_info::type_of<Curve>() == type_info::type_of<Stable>()
    }

    /// Is `Curve` type valid or not (means correct type used).
    public fun is_valid_curve<Curve>(): bool {
        is_uncorrelated<Curve>() || is_stable<Curve>()
    }

    /// Checks if `Curve` is valid (means correct type used).
    public fun assert_valid_curve<Curve>() {
        assert!(is_valid_curve<Curve>(), ERR_INVALID_CURVE);
    }
}
