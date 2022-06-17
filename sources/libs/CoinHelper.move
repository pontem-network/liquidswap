/// The `CoinHelper` module contains helper funcs to work with `AptosFramework::Coin` module.
module MultiSwap::CoinHelper {
    use Std::BCS;
    use Std::ASCII::{Self, String, as_bytes};
    use Std::Option;
    use Std::Errors;
    use Std::Vector;

    use AptosFramework::Coin;

    use MultiSwap::Compare;

    // Errors.

    /// When both coins have same names and can't be ordered.
    const ERR_CANNOT_BE_THE_SAME_COIN: u64 = 100;

    /// When provided CoinType is not a coin.
    const ERR_IS_NOT_COIN: u64 = 101;

    // Constants.

    /// When both coin names are equal.
    const EQUAL: u8 = 0;
    /// When coin `X` name is less than coin `Y` name.
    const LESS_THAN: u8 = 1;
    /// When coin `X` name is greater than coin `X` name.
    const GREATER_THAN: u8 = 2;

    /// Check if provided generic `CoinType` is a coin.
    public fun assert_is_coin<CoinType>() {
        assert!(Coin::is_coin_initialized<CoinType>(), Errors::not_published(ERR_IS_NOT_COIN));
    }

    /// Compare two coins, `X` and `Y`, using names.
    /// Caller should call this function to determine the order of A, B.
    public fun compare<X, Y>(): u8 {
        let x_bytes = BCS::to_bytes<String>(&Coin::symbol<X>());
        let y_bytes = BCS::to_bytes<String>(&Coin::symbol<Y>());
        Compare::cmp_bcs_bytes(&x_bytes, &y_bytes)
    }

    /// Check that coins generics `X`, `Y` are sorted in correct ordering.
    /// X != Y && X.symbol < Y.symbol
    public fun is_sorted<X, Y>(): bool {
        let order = compare<X, Y>();
        assert!(order != EQUAL, Errors::invalid_argument(ERR_CANNOT_BE_THE_SAME_COIN));
        order == LESS_THAN
    }

    /// Get supply for `CoinType`.
    /// Would throw error if supply for `CoinType` doesn't exist.
    public fun supply<CoinType>(): u64 {
        Option::extract(&mut Coin::supply<CoinType>())
    }

    /// Generate LP coin name for pair `X`/`Y`.
    /// Returns generated symbol and name (`symbol<X>()` + "-" + `symbol<Y>()`).
    public fun generate_lp_name<X, Y>(): (String, String) {
        let symbol = b"LP-";
        Vector::append(&mut symbol, *as_bytes(&Coin::symbol<X>()));
        Vector::push_back(&mut symbol, 0x2d);
        Vector::append(&mut symbol, *as_bytes(&Coin::symbol<Y>()));

        (ASCII::string(b"LiquidSwap LP"), ASCII::string(symbol))
    }
}
