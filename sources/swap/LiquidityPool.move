/// Liquidity pool.
module SwapAdmin::LiquidityPool {
    use Std::Signer;
    use Std::ASCII::String;
    use Std::BCS;
    use Std::Compare;
    use SwapAdmin::Token::{Self, Token};
    use SwapAdmin::SafeMath;

    // Constants.

    /// LP token default decimals.
    const LP_TOKEN_DECIMALS: u8 = 9;

    /// Minimal liquidity.
    const MINIMAL_LIQUIDITY: u128 = 1000;

    // Error codes.
    /// When tokens used to create pair have wrong ordering.
    const ERR_WRONG_PAIR_ORDERING: u64 = 101;

    /// When provided LP token already has minted supply.
    const ERR_LP_HAS_SUPPLY: u64 = 102;

    /// When pair already exists on account.
    const ERR_PAIR_EXISTS: u64 = 103;

    /// When not enough liquidity minted.
    const ERR_NOT_ENOUGH_LIQUIDITY: u64 = 104;

    /// When both X and Y provided for swap are equal zero.
    const ERR_EMPTY_IN: u64 = 105;

    /// When incorrect INs/OUTs arguments passed during swap and math doesn't work.
    const ERR_INCORRECT_SWAP: u64 = 106;

    // TODO: events.

    /// Liquidity pool with reserves.
    /// LP token should go outside of this module.
    /// Probably we only need mint capability?
    struct LiquidityPool<phantom X, phantom Y, phantom LP> has key, store {
        token_x_reserve: Token<X>,
        token_y_reserve: Token<Y>,
        lp_mint_cap: Token::MintCapability<LP>,
        lp_burn_cap: Token::BurnCapability<LP>,
    }

    /// Register liquidity pool (by pairs).
    public fun register_liquidity_pool<X: store, Y: store, LP>(account: &signer, lp_mint_cap: Token::MintCapability<LP>, lp_burn_cap: Token::BurnCapability<LP>) {
        Token::assert_is_token<X>();
        Token::assert_is_token<Y>();
        Token::assert_is_token<LP>();

        let cmp = compare_token<X, Y>();

        assert!(cmp != 0, ERR_WRONG_PAIR_ORDERING);
        assert!(Token::total_value<LP>() == 0, ERR_LP_HAS_SUPPLY);
        assert!(!exists<LiquidityPool<X, Y, LP>>(Signer::address_of(account)), ERR_PAIR_EXISTS);

        let token_pair = LiquidityPool<X, Y, LP>{
            token_x_reserve: Token::zero<X>(),
            token_y_reserve: Token::zero<Y>(),
            lp_mint_cap: lp_mint_cap,
            lp_burn_cap: lp_burn_cap,
        };

        move_to(account, token_pair);
    }

    /// Mint new liquidity.
    public fun mint_liquidity<X: store, Y: store, LP>(owner: address, token_x: Token<X>, token_y: Token<Y>): Token<LP> acquires LiquidityPool {
        let total_supply: u128 = Token::total_value<LP>();

        let (x_reserve, y_reserve) = get_reserves<X, Y, LP>(owner);

        let x_value = Token::value<X>(&token_x);
        let y_value = Token::value<Y>(&token_y);

        let liquidity = if (total_supply == 0) {
            SafeMath::sqrt_u256(SafeMath::mul_u128(x_value, y_value)) - MINIMAL_LIQUIDITY
        } else {
            let x_liquidity = SafeMath::safe_mul_div_u128(x_value, total_supply, x_reserve);
            let y_liquidity = SafeMath::safe_mul_div_u128(y_value, total_supply, y_reserve);

            if (x_liquidity < y_liquidity) {
                x_liquidity
            } else {
                y_liquidity
            }
        };

        assert!(liquidity > 0, ERR_NOT_ENOUGH_LIQUIDITY);

        let liquidity_pool = borrow_global_mut<LiquidityPool<X, Y, LP>>(owner);
        Token::deposit(&mut liquidity_pool.token_x_reserve, token_x);
        Token::deposit(&mut liquidity_pool.token_y_reserve, token_y);

        let lp_tokens = Token::mint<LP>(liquidity, &liquidity_pool.lp_mint_cap);

        // TODO: We should update oracle?

        lp_tokens
    }

    /// Swap tokens (can swap both x and y in the same time).
    /// In the most of situation only X or Y tokens argument has value (similar with *_out, only one _out will be non-zero).
    /// Because an user usually exchanges only one token, yet function allow to exchange both tokens.
    /// * x_in - X tokens to swap.
    /// * x_out - exptected amount of X tokens to get out.
    /// * y_in - Y tokens to swap.
    /// * y_out - exptected amount of Y tokens to get out.
    /// Returns - both exchanged X and Y token.
    public fun swap<X: store, Y: store, LP>(owner: address, x_in: Token<X>, x_out: u128, y_in: Token<Y>, y_out: u128): (Token<X>, Token<Y>)  acquires LiquidityPool {
        let x_in_value = Token::value(&x_in);
        let y_in_value = Token::value(&y_in);

        assert!(x_in_value > 0 || y_in_value > 0, ERR_EMPTY_IN);

        let (x_reserve, y_reserve) = get_reserves<X, Y, LP>(owner);
        let liquidity_pool = borrow_global_mut<LiquidityPool<X, Y, LP>>(owner);

        // Deposit new tokens to liquidity pool.
        Token::deposit(&mut liquidity_pool.token_x_reserve, x_in);
        Token::deposit(&mut liquidity_pool.token_y_reserve, y_in);

        // Withdraw expected amount from reserves.
        let x_swapped = Token::withdraw(&mut liquidity_pool.token_x_reserve, x_out);
        let y_swapped = Token::withdraw(&mut liquidity_pool.token_y_reserve, y_out);

        // Get new reserves.
        let x_reserve_new = Token::value(&liquidity_pool.token_x_reserve);
        let y_reserve_new = Token::value(&liquidity_pool.token_y_reserve);        

        // Check we can do swap with provided info.
        let x_adjusted = x_reserve_new * 3 - x_in_value * 1000;
        let y_adjusted = y_reserve_new * 3 - y_in_value * 1000;
        let cmp_order = SafeMath::safe_compare_mul_u128(x_adjusted, y_adjusted, x_reserve, y_reserve * 1000000);

        assert!((SafeMath::CNST_EQUAL() == cmp_order || SafeMath::CNST_GREATER_THAN() == cmp_order), ERR_INCORRECT_SWAP);

        // TODO: We should update oracle?

        // Return swapped amount.
        (x_swapped, y_swapped)
    }

    /// Caller should call this function to determine the order of A, B.
    public fun compare_token<X, Y>(): u8 {
        let x_bytes = BCS::to_bytes<String>(&Token::symbol<X>());
        let y_bytes = BCS::to_bytes<String>(&Token::symbol<Y>());
        let ret: u8 = Compare::cmp_bcs_bytes(&x_bytes, &y_bytes);
        ret
    }

    /// Get reserves of a token pair.
    /// The order of type args should be sorted.
    public fun get_reserves<X: store, Y: store, LP>(owner: address): (u128, u128) acquires LiquidityPool {
        let liquidity_pool = borrow_global<LiquidityPool<X, Y, LP>>(owner);
        let x_reserve = Token::value(&liquidity_pool.token_x_reserve);
        let y_reserve = Token::value(&liquidity_pool.token_y_reserve);

        (x_reserve, y_reserve)
    }
}
