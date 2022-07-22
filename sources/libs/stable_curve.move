/// Implements stable curve math.
module liquidswap::stable_curve {
    // !!!FOR AUDITOR!!!
    // Please, review this file really carefully and detailed.
    // Look detailed at all math here, please.
    // We threoretically could go in cycle in get_dy, to get better accuracy, but it seems it would eat too much gas.
    // Also look at all places in all contracts where the functions called and check places too and arguments.
    use u256::u256::{Self, U256};

    /// We take 10^8 as we expect most of the coins to have 6-8 decimals.
    const ONE_E_8: u128 = 100000000;

    /// Get LP value for stable curve: x^3*y + x*y^3
    /// * `x_coin` - reserves of coin X.
    /// * `x_scale` - 10 pow X coin decimals amount.
    /// * `y_coin` - reserves of coin Y.
    /// * `y_scale` - 10 pow Y coin decimals amount.
    public fun lp_value(x_coin: u128, x_scale: u64, y_coin: u128, y_scale: u64): U256 {
        let x_u256 = u256::from_u128(x_coin);
        let y_u256 = u256::from_u128(y_coin);
        let u2561e8 = u256::from_u128(ONE_E_8);

        let x_scale_u256 = u256::from_u64(x_scale);
        let y_scale_u256 = u256::from_u64(y_scale);

        let _x = u256::div(
            u256::mul(x_u256, u2561e8),
            x_scale_u256,
        );

        let _y = u256::div(
            u256::mul(y_u256, u2561e8),
            y_scale_u256,
        );

        let _a = u256::div(
            u256::mul(_x, _y),
            u2561e8,
        );

        // ((_x * _x) / 1e18 + (_y * _y) / 1e18)
        let _b = u256::add(
            u256::div(
                u256::mul(_x, _x),
                u2561e8,
            ),
            u256::div(
                u256::mul(_y, _y),
                u2561e8,
            )
        );

        u256::div(
            u256::mul(_a, _b),
            u2561e8,
        )
    }

    /// Get coin amount out by passing amount in, returns amount out (we don't take fees into account here).
    /// It probably would eat a lot of gas and better to do it offchain (on your frontend or whatever),
    /// yet if no other way and need blockchain computation we left it here.
    /// * `coin_in` - amount of coin to swap.
    /// * `scale_in` - 10 pow by coin decimals you want to swap.
    /// * `scale_out` - 10 pow by coin decimals you want to get.
    /// * `reserve_in` - reserves of coin to swap coin_in.
    /// * `reserve_out` - reserves of coin to get in exchange.
    public fun coin_out(coin_in: u128, scale_in: u64, scale_out: u64, reserve_in: u128, reserve_out: u128): u128 {
        get_dy(coin_in, scale_in, scale_out, reserve_in, reserve_out)
    }

    /// Get coin amount in by passing amount out, returns amount in (we don't take fees into account here).
    /// It probably would eat a lot of gas and better to do it offchain (on your frontend or whatever),
    /// yet if no other way and need blockchain computation we left it here.
    /// * `coin_out` - amount of coin you want to get.
    /// * `scale_in` - 10 pow by coin decimals you want to swap.
    /// * `scale_out` - 10 pow by coin decimals you want to get.
    /// * `reserve_in` - reserves of coin to swap.
    /// * `reserve_out` - reserves of coin to get in exchange.
    public fun coin_in(coin_out: u128, scale_out: u64, scale_in: u64, reserve_out: u128, reserve_in: u128): u128 {
        get_dy(coin_out, scale_out, scale_in, reserve_out, reserve_in)
    }

    /// Implementx -y(y^2+3x^2)/(x(x^2+3y^2))dx = - dx*(y*(y*y/1e8+3*x*x/1e8)/1e8)/(x*(x*x/1e8+3*y*y/1e8)/1e8).
    /// To get `coin_in` or `coin_out` using differentiate both sides.
    /// More detailed report - https://github.com/pontem-network/multi-swap/pull/19 (see my comment contains pdf).
    public fun get_dy(coin_dx: u128, scale_x: u64, scale_y: u64, reserve_x: u128, reserve_y: u128): u128 {
        let dx_u256 = u256::from_u128(coin_dx);
        let x_u256 = u256::from_u128(reserve_x);
        let y_u256 = u256::from_u128(reserve_y);
        let u2561e8 = u256::from_u128(ONE_E_8);
        let three_u256 = u256::from_u128(3);

        let x_scale_u256 = u256::from_u64(scale_x);
        let y_scale_u256 = u256::from_u64(scale_y);

        let _x = u256::div(
            u256::mul(x_u256, u2561e8),
            x_scale_u256,
        );


        let _y = u256::div(
            u256::mul(y_u256, u2561e8),
            y_scale_u256,
        );

        let _dx = u256::div(
            u256::mul(dx_u256, u2561e8),
            x_scale_u256,
        );

        // dy = -y(y^2+3x^2)/(x(x^2+3y^2))dx = - dx*(y*(y*y/1e8+3*x*x/1e8)/1e8)/(x*(x*x/1e8+3*y*y/1e8)/1e8)
        let _dy = u256::div(
            u256::mul(
                _dx, // dx*(y*(y*y/1e8+3*x*x/1e8)/1e8)
                u256::div( //  y * (3 * (x * x) / 1e18 + y * y / 1e8) / 1e8
                    u256::mul( // y * (3 * (x * x) / 1e18 + y * y / 1e8)
                        _y,
                        u256::add( // 3 * (x * x) / 1e18 + y * y / 1e8
                            u256::div(u256::mul(_y, _y), u2561e8), // y * y / 1e8
                            u256::mul( // 3 * (x * x) / 1e18
                                three_u256,
                                u256::div(u256::mul(_x, _x), u2561e8) // x * x / 1e8
                            )
                        )
                    ),
                    u2561e8
                ),
            ),
            u256::div(
                u256::mul(
                    _x, // x * ((x * x) / 1e8 + (y * y) / 1e8)
                    u256::add( // x * x / 1e8 +  3 * y * y / 1e8
                        u256::div(u256::mul(_x, _x), u2561e8), // x * x / 1e8
                        u256::mul(
                            three_u256, // 3 * y * y / 1e8
                            u256::div(u256::mul(_y, _y), u2561e8) // y * y / 1e8
                        )
                    )
                ),
                u2561e8
            )
        );

        let dy = u256::div(
            u256::mul(_dy, y_scale_u256),
            u2561e8,
        );

        u256::as_u128(dy)
    }

    #[test]
    fun test_get_dy() {
        let out = get_dy(
            251305800000,
            1000000,
            100000000,
            25582858050757,
            2558285805075712
        );
        assert!(out == 25130580000000, 0);
    }

    #[test]
    fun test_coin_out() {
        let out = coin_out(
            2513058000,
            1000000,
            100000000,
            25582858050757,
            2558285805075712
        );
        assert!(out == 251305800000, 0);
    }

    #[test]
    fun test_coin_out_vise_vera() {
        let out = coin_out(
            251305800000,
            100000000,
            1000000,
            2558285805075701,
            25582858050757
        );
        assert!(out == 2513057999, 0);
    }

    #[test]
    fun test_get_coin_in() {
        let in = coin_in(
            251305800000,
            100000000,
            1000000,
            2558285805075701,
            25582858050757
        );
        assert!(in == 2513057999, 0);
    }

    #[test]
    fun test_get_coin_in_vise_versa() {
        let in = coin_in(
            2513058000,
            1000000,
            100000000,
            25582858050757,
             2558285805075701
        );

        assert!(in == 251305800000, 0);
    }

    #[test]
    fun test_lp_value_compute() {
        // 0.3 ^ 3 * 0.5 + 0.5 ^ 3 * 0.3 = 0.051 (12 decimals)
        let lp_value = lp_value(300000, 1000000, 500000, 1000000);
        assert!(
            u256::as_u128(lp_value) == 5100000,
            0
        );

        lp_value = lp_value(
            500000899318256,
            1000000,
            25000567572582123,
            1000000000000
        );

        assert!(u256::as_u128(lp_value) == 312508781701599715772530613362069248234, 1);
    }
}
