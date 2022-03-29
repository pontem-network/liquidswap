/// Token Swap
module SwapAdmin::TokenSwap {
    use Std::Signer;
    use Std::BCS;
    use Std::Event;
    use Std::U256::{Self, U256};
    use Std::Compare;

    use CoreFramework::Timestamp;

    use SwapAdmin::Token;
    use SwapAdmin::SafeMath;
    use SwapAdmin::FixedPoint128;
    use SwapAdmin::TokenSwapConfig;

    struct LiquidityToken<phantom X, phantom Y> has key, store, copy, drop {}

    struct LiquidityTokenCapability<phantom X, phantom Y> has key, store {
        mint: Token::MintCapability<LiquidityToken<X, Y>>,
        burn: Token::BurnCapability<LiquidityToken<X, Y>>,
    }

    /// Event emitted when add token pair register.
    /// (Obsoleted)
    struct TokenPairRegisterEvent has drop, store {
        /// token code of X type
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
        /// signer of token pair register
        signer: address,
    }

    /// Event emitted when add token pair register.
    struct RegisterEvent has drop, store {
        /// token code of X type
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
        /// signer of token pair register
        signer: address,
    }

    /// Event emitted when add token liquidity.
    struct AddLiquidityEvent has drop, store {
        /// liquidity value by user X and Y type
        liquidity: u128,
        /// token code of X type
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
        /// signer of add liquidity
        signer: address,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    }

    /// Event emitted when remove token liquidity.
    struct RemoveLiquidityEvent has drop, store {
        /// liquidity value by user X and Y type
        liquidity: u128,
        /// token code of X type
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
        /// signer of remove liquidity
        signer: address,
        amount_x_min: u128,
        amount_y_min: u128,
    }

    /// Event emitted when token swap .
    /// (Obsoleted field)
    struct SwapFeeEvent has drop, store {
        /// token code of X type
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
        signer: address,
        fee_addree: address,
        swap_fee: u128,
        fee_out: u128,
    }

    /// Event emitted when token swap.
    struct SwapEvent has drop, store {
        /// token code of X type
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
        x_in: u128,
        y_out: u128,
        signer: address,
    }

    /// (Obsoleted)
    struct TokenPair<phantom X, phantom Y> has key, store {
        token_x_reserve: Token::Token<X>,
        token_y_reserve: Token::Token<Y>,
        last_block_timestamp: u64,
        last_price_x_cumulative: U256,
        last_price_y_cumulative: U256,
        last_k: U256,
        // token_pair_register_event: Event::EventHandle<TokenPairRegisterEvent>,

        // reserve0 * reserve1, as of immediately after the most recent liquidity event
        add_liquidity_event: Event::EventHandle<AddLiquidityEvent>,
        remove_liquidity_event: Event::EventHandle<RemoveLiquidityEvent>,
        swap_event: Event::EventHandle<SwapEvent>,

        /// Obsoleted field
        swap_fee_event: Event::EventHandle<SwapFeeEvent>,
    }

    /// Struct for swap pair
    struct TokenSwapPair<phantom X, phantom Y> has key, store {
        token_x_reserve: Token::Token<X>,
        token_y_reserve: Token::Token<Y>,
        last_block_timestamp: u64,
        last_price_x_cumulative: U256,
        last_price_y_cumulative: U256,
        last_k: U256,
    }

    /// Token swap event handle
    struct TokenSwapEventHandle has key, store {
        register_event: Event::EventHandle<RegisterEvent>,
        add_liquidity_event: Event::EventHandle<AddLiquidityEvent>,
        remove_liquidity_event: Event::EventHandle<RemoveLiquidityEvent>,
        swap_event: Event::EventHandle<SwapEvent>,
    }

    const ERROR_SWAP_INVALID_TOKEN_PAIR: u64 = 2000;
    const ERROR_SWAP_INVALID_PARAMETER: u64 = 2001;
    const ERROR_SWAP_TOKEN_INSUFFICIENT: u64 = 2002;
    const ERROR_SWAP_DUPLICATE_TOKEN: u64 = 2003;
    const ERROR_SWAP_BURN_CALC_INVALID: u64 = 2004;
    const ERROR_SWAP_SWAPOUT_CALC_INVALID: u64 = 2005;
    const ERROR_SWAP_PRIVILEGE_INSUFFICIENT: u64 = 2006;
    const ERROR_SWAP_ADDLIQUIDITY_INVALID: u64 = 2007;
    const ERROR_SWAP_TOKEN_NOT_EXISTS: u64 = 2008;
    const ERROR_SWAP_TOKEN_FEE_INVALID: u64 = 2009;

    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

    const LIQUIDITY_TOKEN_SCALE: u8 = 9;

    public fun maybe_init_event_handle(signer: &signer) {
        assert_admin(signer);
        if (!exists<TokenSwapEventHandle>(Signer::address_of(signer))) {
            move_to(signer, TokenSwapEventHandle{
                add_liquidity_event: Event::new_event_handle<AddLiquidityEvent>(signer),
                remove_liquidity_event: Event::new_event_handle<RemoveLiquidityEvent>(signer),
                swap_event: Event::new_event_handle<SwapEvent>(signer),
                register_event: Event::new_event_handle<RegisterEvent>(signer),
            });
        };
    }

    /// Check if swap pair exists
    public fun swap_pair_exists<X: copy + drop + store, Y: copy + drop + store>(): bool {
        let order = compare_token<X, Y>();
        assert!(order != 0, ERROR_SWAP_INVALID_TOKEN_PAIR);
        Token::is_registered_in<LiquidityToken<X, Y>>(TokenSwapConfig::admin_address())
    }

    // for now, only admin can register token pair
    public fun register_swap_pair<X: copy + drop + store, Y: copy + drop + store>(signer: &signer)
    acquires TokenSwapEventHandle {
        // check X,Y is token.
        assert_is_token<X>();
        assert_is_token<Y>();

        // Event handle
        maybe_init_event_handle(signer);

        let order = compare_token<X, Y>();
        assert!(order != 0, ERROR_SWAP_INVALID_TOKEN_PAIR);
        assert_admin(signer);

        let token_pair = make_token_swap_pair<X, Y>();
        move_to(signer, token_pair);

        register_liquidity_token<X, Y>(signer);

        // Emit register event
        emit_token_pair_register_event<X, Y>(signer);
    }

    fun register_liquidity_token<X: copy + drop + store, Y: copy + drop + store>(signer: &signer) {
        assert_admin(signer);
        Token::register_token<LiquidityToken<X, Y>>(signer, LIQUIDITY_TOKEN_SCALE);
        let mint_capability = Token::remove_mint_capability<LiquidityToken<X, Y>>(signer);
        let burn_capability = Token::remove_burn_capability<LiquidityToken<X, Y>>(signer);
        move_to(signer, LiquidityTokenCapability{ mint: mint_capability, burn: burn_capability });
    }

    fun make_token_pair<X: copy + drop + store, Y: copy + drop + store>(signer: &signer): TokenPair<X, Y> {
        TokenPair<X, Y>{
            token_x_reserve: Token::zero<X>(),
            token_y_reserve: Token::zero<Y>(),
            last_block_timestamp: 0,
            last_price_x_cumulative: U256::zero(),
            last_price_y_cumulative: U256::zero(),
            last_k: U256::zero(),
            // token_pair_register_event: Event::new_event_handle<TokenPairRegisterEvent>(signer),
            add_liquidity_event: Event::new_event_handle<AddLiquidityEvent>(signer),
            remove_liquidity_event: Event::new_event_handle<RemoveLiquidityEvent>(signer),
            swap_event: Event::new_event_handle<SwapEvent>(signer),
            swap_fee_event: Event::new_event_handle<SwapFeeEvent>(signer),
        }
    }

    fun make_token_swap_pair<X: copy + drop + store, Y: copy + drop + store>(): TokenSwapPair<X, Y> {
        TokenSwapPair<X, Y>{
            token_x_reserve: Token::zero<X>(),
            token_y_reserve: Token::zero<Y>(),
            last_block_timestamp: 0,
            last_price_x_cumulative: U256::zero(),
            last_price_y_cumulative: U256::zero(),
            last_k: U256::zero(),
        }
    }

    /// Liquidity Provider's methods
    /// type args, X, Y should be sorted.
    public fun mint<X: copy + drop + store, Y: copy + drop + store>(
        x: Token::Token<X>,
        y: Token::Token<Y>,
    ): Token::Token<LiquidityToken<X, Y>> acquires TokenSwapPair, LiquidityTokenCapability {
        TokenSwapConfig::assert_global_freeze();

        let total_supply: u128 = Token::market_cap<LiquidityToken<X, Y>>();
        let (x_reserve, y_reserve) = get_reserves<X, Y>();
        let x_value = Token::value<X>(&x);
        let y_value = Token::value<Y>(&y);
        let liquidity = if (total_supply == 0) {
            // 1000 is the MINIMUM_LIQUIDITY
            // sqrt(x*y) - 1000
            SafeMath::sqrt_u256(SafeMath::mul_u128(x_value, y_value)) - 1000
        } else {
            let x_liquidity = SafeMath::safe_mul_div_u128(x_value, total_supply, x_reserve);
            let y_liquidity = SafeMath::safe_mul_div_u128(y_value, total_supply, y_reserve);
            // use smaller one.
            if (x_liquidity < y_liquidity) {
                x_liquidity
            } else {
                y_liquidity
            }
        };
        assert!(liquidity > 0, ERROR_SWAP_ADDLIQUIDITY_INVALID);
        let token_pair = borrow_global_mut<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());
        Token::deposit(&mut token_pair.token_x_reserve, x);
        Token::deposit(&mut token_pair.token_y_reserve, y);
        let liquidity_cap = borrow_global<LiquidityTokenCapability<X, Y>>(TokenSwapConfig::admin_address());
        let mint_token = Token::mint_with_capability(&liquidity_cap.mint, liquidity);
        update_oracle<X, Y>(x_reserve, y_reserve);
        // emit_mint_event<X, Y>(x_value, y_value, liquidity);

        mint_token
    }


    public fun burn<X: copy + drop + store, Y: copy + drop + store>(
        to_burn: Token::Token<LiquidityToken<X, Y>>,
    ): (Token::Token<X>, Token::Token<Y>) acquires TokenSwapPair, LiquidityTokenCapability {
        TokenSwapConfig::assert_global_freeze();

        let to_burn_value = (Token::value(&to_burn) as u128);
        let token_pair = borrow_global_mut<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());
        let x_reserve = (Token::value(&token_pair.token_x_reserve) as u128);
        let y_reserve = (Token::value(&token_pair.token_y_reserve) as u128);
        let total_supply = Token::market_cap<LiquidityToken<X, Y>>();
        let x = SafeMath::safe_mul_div_u128(to_burn_value, x_reserve, total_supply);
        let y = SafeMath::safe_mul_div_u128(to_burn_value, y_reserve, total_supply);
        assert!(x > 0 && y > 0, ERROR_SWAP_BURN_CALC_INVALID);
        burn_liquidity<X, Y>(to_burn);

        let x_token = Token::withdraw(&mut token_pair.token_x_reserve, x);
        let y_token = Token::withdraw(&mut token_pair.token_y_reserve, y);
        update_oracle<X, Y>(x_reserve, y_reserve);
        // emit_burn_event<X, Y>(x, y, to_burn_value);
        (x_token, y_token)
    }


    fun burn_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        to_burn: Token::Token<LiquidityToken<X, Y>>
    ) acquires LiquidityTokenCapability {
        let liquidity_cap = borrow_global<LiquidityTokenCapability<X, Y>>(TokenSwapConfig::admin_address());
        Token::burn_with_capability<LiquidityToken<X, Y>>(&liquidity_cap.burn, to_burn);
    }

    /// Get reserves of a token pair.
    /// The order of type args should be sorted.
    public fun get_reserves<X: copy + drop + store, Y: copy + drop + store>(): (u128, u128) acquires TokenSwapPair {
        let token_pair = borrow_global<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());
        let x_reserve = Token::value(&token_pair.token_x_reserve);
        let y_reserve = Token::value(&token_pair.token_y_reserve);
        //        let last_block_timestamp = token_pair.last_block_timestamp;
        (x_reserve, y_reserve)
    }

    /// Get cumulative info of a token pair.
    /// The order of type args should be sorted.
    public fun get_cumulative_info<X: copy + drop + store, Y: copy + drop + store>(): (U256, U256, u64) acquires TokenSwapPair {
        let token_pair = borrow_global<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());
        let last_price_x_cumulative = *&token_pair.last_price_x_cumulative;
        let last_price_y_cumulative = *&token_pair.last_price_y_cumulative;
        let last_block_timestamp = token_pair.last_block_timestamp;
        (last_price_x_cumulative, last_price_y_cumulative, last_block_timestamp)
    }

    public fun swap<X: copy + drop + store,
                    Y: copy + drop + store>(
        x_in: Token::Token<X>,
        y_out: u128,
        y_in: Token::Token<Y>,
        x_out: u128,
    ): (Token::Token<X>, Token::Token<Y>, Token::Token<X>, Token::Token<Y>) acquires TokenSwapPair {
        TokenSwapConfig::assert_global_freeze();

        let x_in_value = Token::value(&x_in);
        let y_in_value = Token::value(&y_in);
        assert!(x_in_value > 0 || y_in_value > 0, ERROR_SWAP_TOKEN_INSUFFICIENT);
        let (x_reserve, y_reserve) = get_reserves<X, Y>();
        let token_pair = borrow_global_mut<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());
        Token::deposit(&mut token_pair.token_x_reserve, x_in);
        Token::deposit(&mut token_pair.token_y_reserve, y_in);
        let x_swapped = Token::withdraw(&mut token_pair.token_x_reserve, x_out);
        let y_swapped = Token::withdraw(&mut token_pair.token_y_reserve, y_out);
            {
                let x_reserve_new = Token::value(&token_pair.token_x_reserve);
                let y_reserve_new = Token::value(&token_pair.token_y_reserve);
                let (x_adjusted, y_adjusted);
                let (fee_numerator, fee_denominator) = TokenSwapConfig::get_poundage_rate<X, Y>();
                //                x_adjusted = x_reserve_new * 1000 - x_in_value * 3;
                //                y_adjusted = y_reserve_new * 1000 - y_in_value * 3;
                x_adjusted = x_reserve_new * (fee_denominator as u128) - x_in_value * (fee_numerator as u128);
                y_adjusted = y_reserve_new * (fee_denominator as u128) - y_in_value * (fee_numerator as u128);
                // x_adjusted, y_adjusted >= x_reserve, y_reserve * 1000000
                let cmp_order = SafeMath::safe_compare_mul_u128(x_adjusted, y_adjusted, x_reserve, y_reserve * 1000000);
                assert!((EQUAL == cmp_order || GREATER_THAN == cmp_order), ERROR_SWAP_SWAPOUT_CALC_INVALID);
            };

        let (x_swap_fee, y_swap_fee);
        // cacl and handle swap fee, default fee rate is 3/1000
        if (TokenSwapConfig::get_swap_fee_switch()) {
            let (actual_fee_operation_numerator, actual_fee_operation_denominator) = cacl_actual_swap_fee_operation_rate<X, Y>();
            x_swap_fee = Token::withdraw(&mut token_pair.token_x_reserve, SafeMath::safe_mul_div_u128(x_in_value, actual_fee_operation_numerator, actual_fee_operation_denominator));
            y_swap_fee = Token::withdraw(&mut token_pair.token_y_reserve, SafeMath::safe_mul_div_u128(y_in_value, actual_fee_operation_numerator, actual_fee_operation_denominator));
        } else {
            x_swap_fee = Token::zero();
            y_swap_fee = Token::zero();
        };

        update_oracle<X, Y>(x_reserve, y_reserve);
        // emit_swap_event<X, Y>(x_in_value, y_out, y_in_value, x_out);

        (x_swapped, y_swapped, x_swap_fee, y_swap_fee)
    }

    /// Emit token pair register event
    fun emit_token_pair_register_event<X: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
    ) acquires TokenSwapEventHandle {
        let event_handle = borrow_global_mut<TokenSwapEventHandle>(TokenSwapConfig::admin_address());
        Event::emit_event(&mut event_handle.register_event, RegisterEvent{
            x_token_code: Token::token_code<X>(),
            y_token_code: Token::token_code<Y>(),
            signer: Signer::address_of(signer),
        });
    }


    /// Caller should call this function to determine the order of A, B
    public fun compare_token<X: copy + drop + store, Y: copy + drop + store>(): u8 {
        let x_bytes = BCS::to_bytes<Token::TokenCode>(&Token::token_code<X>());
        let y_bytes = BCS::to_bytes<Token::TokenCode>(&Token::token_code<Y>());
        let ret: u8 = Compare::cmp_bcs_bytes(&x_bytes, &y_bytes);
        ret
    }

    fun assert_admin(signer: &signer) {
        assert!(Signer::address_of(signer) == TokenSwapConfig::admin_address(), ERROR_SWAP_PRIVILEGE_INSUFFICIENT);
    }

    public fun assert_is_token<TokenType: store>(): bool {
        assert!(Token::token_address<TokenType>() != @0x0, ERROR_SWAP_TOKEN_NOT_EXISTS);
        true
    }

    fun update_oracle<X: copy + drop + store, Y: copy + drop + store>(
        x_reserve: u128,
        y_reserve: u128,
    ) acquires TokenSwapPair {
        let token_pair = borrow_global_mut<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());

        let last_block_timestamp = token_pair.last_block_timestamp;
        let block_timestamp = Timestamp::now_seconds() % (1u64 << 32);
        let time_elapsed: u64 = block_timestamp - last_block_timestamp;
        if (time_elapsed > 0 && x_reserve != 0 && y_reserve != 0) {
            let last_price_x_cumulative = U256::mul(FixedPoint128::to_u256(FixedPoint128::div(FixedPoint128::encode(y_reserve), x_reserve)), U256::from_u64(time_elapsed));
            let last_price_y_cumulative = U256::mul(FixedPoint128::to_u256(FixedPoint128::div(FixedPoint128::encode(x_reserve), y_reserve)), U256::from_u64(time_elapsed));
            token_pair.last_price_x_cumulative = U256::add(*&token_pair.last_price_x_cumulative, last_price_x_cumulative);
            token_pair.last_price_y_cumulative = U256::add(*&token_pair.last_price_y_cumulative, last_price_y_cumulative);
        };

        token_pair.last_block_timestamp = block_timestamp;
    }

    /// if swap fee deposit to fee address fail, return back to lp pool
    public fun return_back_to_lp_pool<X: copy + drop + store,
                                      Y: copy + drop + store>(
        x_in: Token::Token<X>,
        y_in: Token::Token<Y>,
    ) acquires TokenSwapPair {
        let token_pair = borrow_global_mut<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());
        Token::deposit(&mut token_pair.token_x_reserve, x_in);
        Token::deposit(&mut token_pair.token_y_reserve, y_in);
    }

    public fun cacl_actual_swap_fee_operation_rate<X: copy + drop + store,
                                                   Y: copy + drop + store>(): (u128, u128) {
        let (fee_numerator, fee_denominator) = TokenSwapConfig::get_poundage_rate<X, Y>();
        let (operation_numerator, operation_denominator) = TokenSwapConfig::get_swap_fee_operation_rate();
        ((fee_numerator * operation_numerator as u128), (fee_denominator * operation_denominator as u128))
    }

    /// Do mint and emit `AddLiquidityEvent` event
    public fun mint_and_emit_event<X: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
        x_token: Token::Token<X>,
        y_token: Token::Token<Y>,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128): Token::Token<LiquidityToken<X, Y>>
    acquires TokenSwapPair, LiquidityTokenCapability, TokenSwapEventHandle {
        let liquidity_token = mint<X, Y>(x_token, y_token);

        let event_handle = borrow_global_mut<TokenSwapEventHandle>(TokenSwapConfig::admin_address());
        Event::emit_event(&mut event_handle.add_liquidity_event, AddLiquidityEvent{
            x_token_code: Token::token_code<X>(),
            y_token_code: Token::token_code<Y>(),
            signer: Signer::address_of(signer),
            liquidity: Token::value<LiquidityToken<X, Y>>(&liquidity_token),
            amount_x_desired,
            amount_y_desired,
            amount_x_min,
            amount_y_min,
        });
        liquidity_token
    }

    /// Do burn and emit `RemoveLiquidityEvent` event
    public fun burn_and_emit_event<X: copy + drop + store,
                                   Y: copy + drop + store>(signer: &signer,
                                                           to_burn: Token::Token<LiquidityToken<X, Y>>,
                                                           amount_x_min: u128,
                                                           amount_y_min: u128)
    : (Token::Token<X>, Token::Token<Y>) acquires TokenSwapPair, LiquidityTokenCapability, TokenSwapEventHandle {
        let liquidity = Token::value<LiquidityToken<X, Y>>(&to_burn);
        let (x_token, y_token) = burn<X, Y>(to_burn);

        let event_handle = borrow_global_mut<TokenSwapEventHandle>(TokenSwapConfig::admin_address());
        Event::emit_event(&mut event_handle.remove_liquidity_event, RemoveLiquidityEvent{
            x_token_code: Token::token_code<X>(),
            y_token_code: Token::token_code<Y>(),
            signer: Signer::address_of(signer),
            liquidity,
            amount_x_min,
            amount_y_min,
        });
        (x_token, y_token)
    }

    /// Do swap and emit `SwapEvent` event
    public fun swap_and_emit_event<X: copy + drop + store,
                                   Y: copy + drop + store>(
        signer: &signer,
        x_in: Token::Token<X>,
        y_out: u128,
        y_in: Token::Token<Y>,
        x_out: u128): (Token::Token<X>, Token::Token<Y>, Token::Token<X>, Token::Token<Y>) acquires TokenSwapPair, TokenSwapEventHandle {
        let (token_x_out, token_y_out, token_x_fee, token_y_fee) = swap<X, Y>(x_in, y_out, y_in, x_out);
        let event_handle = borrow_global_mut<TokenSwapEventHandle>(TokenSwapConfig::admin_address());
        Event::emit_event(&mut event_handle.swap_event, SwapEvent{
            x_token_code: Token::token_code<X>(),
            y_token_code: Token::token_code<Y>(),
            signer: Signer::address_of(signer),
            x_in: Token::value<X>(&token_x_out),
            y_out: Token::value<Y>(&token_y_out),
        });
        (token_x_out, token_y_out, token_x_fee, token_y_fee)
    }

    /// Maybe called by admin while upgrade
    public fun upgrade_tokenpair_to_tokenswappair<X: copy + drop + store,
                                                  Y: copy + drop + store>(signer: &signer) acquires TokenPair {
        let account = Signer::address_of(signer);
        if (exists<TokenPair<X, Y>>(account)) {
            let TokenPair<X, Y>{
                token_x_reserve,
                token_y_reserve,
                last_block_timestamp,
                last_price_x_cumulative,
                last_price_y_cumulative,
                last_k,
                add_liquidity_event,
                remove_liquidity_event,
                swap_event,
                swap_fee_event,
            } = move_from<TokenPair<X, Y>>(account);

            Event::destroy_handle(add_liquidity_event);
            Event::destroy_handle(remove_liquidity_event);
            Event::destroy_handle(swap_event);
            Event::destroy_handle(swap_fee_event);

            move_to(signer, TokenSwapPair<X, Y>{
                token_x_reserve,
                token_y_reserve,
                last_block_timestamp,
                last_price_x_cumulative,
                last_price_y_cumulative,
                last_k,
            });
        };

        maybe_init_event_handle(signer);
    }
}
