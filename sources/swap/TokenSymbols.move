module AptosSwap::TokenSymbols {
    use Std::BCS;
    use Std::Compare;
    use Std::ASCII::String;

    use AptosSwap::Token;

    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

    const ERR_CANNOT_BE_THE_SAME_TOKENS: u64 = 701;

    /// Caller should call this function to determine the order of A, B.
    public fun compare<X, Y>(): u8 {
        let x_bytes = BCS::to_bytes<String>(&Token::symbol<X>());
        let y_bytes = BCS::to_bytes<String>(&Token::symbol<Y>());
        Compare::cmp_bcs_bytes(&x_bytes, &y_bytes)
    }

    /// X != Y && X.symbol < Y.symbol
    public fun is_sorted<X, Y>(): bool {
        let order = compare<X, Y>();
        assert!(order != EQUAL, ERR_CANNOT_BE_THE_SAME_TOKENS);
        order == LESS_THAN
    }
}
