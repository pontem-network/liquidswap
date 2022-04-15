/// TEMPORARY CLONED FROM PONTEM STDLIB, as Aptos still doesn't support tokens.

/// The `Token` module describes the concept of a token in the Pontem framework. It introduces the
/// resource `Token::Token<TokenType>`, representing a token of given type.
/// The module defines functions operating on tokens as well as functionality like
/// minting and burning of tokens.
module AptosSwap::Token {
    use Std::Event::{Self, EventHandle};
    use Std::Signer;
    use Std::ASCII::String;

    /// The `Token` resource defines the token in the Pontem ecosystem.
    /// Each "token" is coupled with a type `TokenType` specifying the
    /// token type, and a `value` field specifying the value of the token.
    struct Token<phantom TokenType> has store {
        /// The value of this token in the base units for `TokenType`
        value: u128
    }

    /// A `MintEvent` is emitted every time a Token is minted. This
    /// contains the `amount` minted (in base units of the token being
    /// minted) along with the `symbol` for the token(s) being
    /// minted, and that is defined in the `symbol` field of the `TokenInfo`
    /// resource for the token.
    struct MintEvent has drop, store {
        /// Funds added to the system
        amount: u128,
        /// Symbol, e.g. "NOX".
        symbol: String,
    }

    /// A `BurnEvent` is emitted every time Token is burned.
    /// It contains the `amount` burned in base units for the
    /// token, along with the `symbol` for the tokens being burned.
    struct BurnEvent has drop, store {
        /// Funds removed from the system
        amount: u128,
        /// Symbol, e.g. "NOX".
        symbol: String,
    }

    /// The `MintCapability` resource defines a capability to allow minting
    /// of token of `TokenType` by the holder of this capability.
    /// This capability should be held by minter of the token or can be dropped.
    struct MintCapability<phantom TokenType> has key, store {}

    /// The `BurnCapability` resource defines a capability to allow tokens
    /// of `TokenType` token to be burned by the holder of it.
    /// This capability should be held by minter of the token or can be dropped.
    /// The token deployer can create additional functions in his token module to allow users to burn their tokens.
    struct BurnCapability<phantom TokenType> has key, store {}

    /// The `TokenInfo<TokenType>` resource stores the various
    /// pieces of information needed for a token (`TokenType`) that is
    /// registered on-chain. This resource _must_ be published under the
    /// address of token module deployer in order for the registration of
    /// `TokenType` as a recognized token on-chain to be successful. At
    /// the time of registration, the `MintCapability<TokenType>` and
    /// `BurnCapability<TokenType>` capabilities are returned to the caller.
    /// Unless they are specified otherwise the fields in this resource are immutable.
    struct TokenInfo<phantom TokenType> has key {
        /// The total value for the token represented by `TokenType`. Mutable.
        total_supply: u128,
        /// Decimals amount of `TokenType` token.
        decimals: u8,
        /// The code symbol for this `TokenType`.
        /// e.g. for "NOX" this is x"504f4e54". No character limit.
        symbol: String,
        /// Event stream for minting and where `MintEvent`s will be emitted.
        mint_events: EventHandle<MintEvent>,
        /// Event stream for burning, and where `BurnEvent`s will be emitted.
        burn_events: EventHandle<BurnEvent>,
    }

    /// Maximum u64 value.
    const MAX_U64: u64 = 18446744073709551615;
    /// Maximum u128 value.
    const MAX_U128: u128 = 340282366920938463463374607431768211455;

    /// A property expected of a `TokenInfo` resource didn't hold
    const ERR_TOKEN_INFO: u64 = 1;

    const ERR_TOKEN_ALREADY_EXISTS: u64 = 10;
    const ERR_UNKNOWN_TOKEN_IN_SYMBOL: u64 = 11;
    const ERR_NOT_ENOUGH_SUPPLY_TO_BURN: u64 = 12;
    const ERR_TOO_MUCH_SUPPLY_TO_MINT: u64 = 13;

    /// A property expected of the token provided didn't hold
    const ERR_INVALID_TOKEN: u64 = 2;

    const ERR_TOKEN_VALUE_OVERFLOWS: u64 = 21;

    /// The destruction of a non-zero token was attempted. Non-zero tokens must be burned.
    const ERR_DESTRUCTION_OF_NONZERO_TOKEN: u64 = 3;
    /// A withdrawal greater than the value of the token was attempted.
    const ERR_AMOUNT_EXCEEDS_TOKEN_VALUE: u64 = 4;
    /// When token registered not from deployer.
    const ERR_ACC_IS_NOT_TOKEN_DEPLOYER: u64 = 5;

    const ERR_NOT_ADMIN: u64 = 6;

    /// Create a new `Token<TokenType>` with a value of `0`. Anyone can call
    /// this and it will be successful as long as `TokenType` is a registered token.
    public fun zero<TokenType>(): Token<TokenType> {
        assert_is_token<TokenType>();
        Token<TokenType>{ value: 0 }
    }

    /// Returns the `value` of the passed in `token`. The value is
    /// represented in the base units for the token represented by
    /// `TokenType`.
    public fun value<TokenType>(token: &Token<TokenType>): u128 {
        token.value
    }

    /// Removes `amount` of value from the passed in `token`. Returns the
    /// remaining balance of the passed in `token`, along with another token
    /// with value equal to `amount`. Calls will fail if `amount > Token::value(&token)`.
    public fun split<TokenType>(token: Token<TokenType>, amount: u128): (Token<TokenType>, Token<TokenType>) {
        let other = withdraw(&mut token, amount);
        (token, other)
    }

    /// Withdraw `amount` from the passed-in `token`, where the original token is modified in place.
    /// After this function is executed, the original `token` will have
    /// `value = original_value - amount`, and the new token will have a `value = amount`.
    /// Calls will abort if the passed-in `amount` is greater than the
    /// value of the passed-in `token`.
    public fun withdraw<TokenType>(token: &mut Token<TokenType>, amount: u128): Token<TokenType> {
        // Check that `amount` is less than the token's value
        assert!(token.value >= amount, ERR_AMOUNT_EXCEEDS_TOKEN_VALUE);
        token.value = token.value - amount;
        Token{ value: amount }
    }

    /// Return a `Token<TokenType>` worth `token.value` and reduces the `value` of the input `token` to
    /// zero. Does not abort.
    public fun withdraw_all<TokenType>(token: &mut Token<TokenType>): Token<TokenType> {
        let val = token.value;
        withdraw(token, val)
    }

    /// Takes two tokens as input, returns a single token with the total value of both tokens.
    /// Destroys on of the input tokens.
    public fun join<TokenType>(token1: Token<TokenType>, token2: Token<TokenType>): Token<TokenType> {
        deposit(&mut token1, token2);
        token1
    }

    /// "Merges" the two tokens.
    /// The token passed in by reference will have a value equal to the sum of the two tokens
    /// The `check` tokens is consumed in the process
    public fun deposit<TokenType>(token: &mut Token<TokenType>, check: Token<TokenType>) {
        let Token{ value } = check;
        assert!(MAX_U128 - token.value >= value, ERR_TOKEN_VALUE_OVERFLOWS);
        token.value = token.value + value;
    }

    /// Destroy a zero-value token. Calls will fail if the `value` in the passed-in `token` is non-zero
    /// so it is impossible to "burn" any non-zero amount of `Pontem` without having
    /// a `BurnCapability` for the specific `TokenType`.
    public fun destroy_zero<TokenType>(token: Token<TokenType>) {
        let Token{ value } = token;
        assert!(value == 0, ERR_DESTRUCTION_OF_NONZERO_TOKEN)
    }

    /// Mint new tokens of `TokenType`.
    /// The function requires `MintCapability`, returns created tokens `Token<TokenType>`.
    public fun mint<TokenType>(
        value: u128,
        _capability: &MintCapability<TokenType>
    ): Token<TokenType> acquires TokenInfo {
        assert_is_token<TokenType>();

        // update market cap resource to reflect minting
        let info = borrow_global_mut<TokenInfo<TokenType>>(@TokenAdmin);
        assert!(MAX_U128 - info.total_supply >= value, ERR_TOO_MUCH_SUPPLY_TO_MINT);

        info.total_supply = info.total_supply + value;

        Token<TokenType>{ value }
    }

    public fun mint_with_token_admin<TokenType>(token_admin: &signer, value: u128): Token<TokenType>
    acquires MintCapability, TokenInfo {
        let token_admin_addr = Signer::address_of(token_admin);
        let mint_cap = borrow_global<MintCapability<TokenType>>(token_admin_addr);
        mint<TokenType>(value, mint_cap)
    }

    /// Burn `to_burn` tokens.
    /// The function requires `BurnCapability`.
    public fun burn<TokenType>(
        to_burn: Token<TokenType>,
        _burn_cap: &BurnCapability<TokenType>,
    ) acquires TokenInfo {
        assert_is_token<TokenType>();

        // Destroying tokens.
        let Token{ value } = to_burn;
        let info = borrow_global_mut<TokenInfo<TokenType>>(@TokenAdmin);

        assert!(info.total_supply >= (value as u128), ERR_NOT_ENOUGH_SUPPLY_TO_BURN);
        info.total_supply = info.total_supply - (value as u128);
    }

    /// Register new token.
    /// Should be called the deployer of module contains `TokenType`.
    /// Registering new token.
    public fun register_token<TokenType>(
        acc: &signer,
        decimals: u8,
        symbol: String,
    ): (MintCapability<TokenType>, BurnCapability<TokenType>) {
        assert!(Signer::address_of(acc) == @TokenAdmin, ERR_NOT_ADMIN);
        assert!(
            !exists<TokenInfo<TokenType>>(Signer::address_of(acc)),
            ERR_TOKEN_ALREADY_EXISTS
        );

        move_to(acc, TokenInfo<TokenType>{
            total_supply: 0,
            decimals,
            symbol,
            mint_events: Event::new_event_handle<MintEvent>(acc),
            burn_events: Event::new_event_handle<BurnEvent>(acc),
        });
        (MintCapability<TokenType>{}, BurnCapability<TokenType>{})
    }

    /// Register new token.
    /// Should be called the deployer of module contains `TokenType`.
    /// Registering new token.
    public fun register_token_to_acc<TokenType>(
        acc: &signer,
        decimals: u8,
        symbol: String,
    ) {
        let (m, b) =
            register_token<TokenType>(acc, decimals, symbol);
        move_to(acc, m);
        move_to(acc, b);
    }

    /// Returns the total amount of token minted of type `TokenType`.
    public fun total_supply<TokenType>(): u128
    acquires TokenInfo {
        assert_is_token<TokenType>();
        borrow_global<TokenInfo<TokenType>>(@TokenAdmin).total_supply
    }

    /// Returns `true` if the type `TokenType` is a registered token.
    /// Returns `false` otherwise.
    public fun is_token<TokenType>(): bool {
        exists<TokenInfo<TokenType>>(@TokenAdmin)
    }

    /// Returns the token code for the registered token as defined in
    /// its `TokenInfo` resource.
    public fun symbol<TokenType>(): String acquires TokenInfo {
        assert!(is_token<TokenType>(), ERR_UNKNOWN_TOKEN_IN_SYMBOL);
        *&borrow_global<TokenInfo<TokenType>>(@TokenAdmin).symbol

    }

    public fun assert_is_admin(acc: &signer) {
        assert!(Signer::address_of(acc) == @AptosSwap, ERR_NOT_ADMIN);
    }


    ///////////////////////////////////////////////////////////////////////////
    // Helper functions
    ///////////////////////////////////////////////////////////////////////////

    /// Asserts that `TokenType` is a registered token.
    public fun assert_is_token<TokenType>() {
        assert!(is_token<TokenType>(), ERR_TOKEN_INFO);
    }
}
