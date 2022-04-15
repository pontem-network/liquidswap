/// Module allows to work with Pontem account balances, events.
module Std::PontAccount {
    use Std::Errors;
    use Std::Signer;
    use Std::ASCII::String;

    use AptosSwap::Token::{Self, Token};

    /// A resource that holds the total value of tokens of type `TokenType`
    /// currently held by the account.
    struct Balance<phantom TokenType> has key {
        /// Stores the value of the balance in its balance field. A token has
        /// a `value` field. The amount of money in the balance is changed
        /// by modifying this field.
        token: Token<TokenType>,
    }

    /// Message for sent events
    struct SentPaymentEvent has drop, store {
        /// The amount of Token<TokenType> sent
        amount: u64,
        /// The code symbol for the token that was sent
        symbol: String,
        /// The address that was paid
        to_addr: address,
        /// Metadata associated with the payment
        metadata: vector<u8>,
    }

    /// Message for received events
    struct ReceivedPaymentEvent has drop, store {
        /// The amount of Token<TokenType> received
        amount: u64,
        /// The code symbol for the token that was received
        symbol: String,
        /// The address that sent the token
        from_addr: address,
        /// Metadata associated with the payment
        metadata: vector<u8>,
    }

    /// Tried to deposit a token whose value was zero
    const ERR_ZERO_DEPOSIT_AMOUNT: u64 = 1;
    /// The account does not hold a large enough balance in the specified token
    const ERR_INSUFFICIENT_BALANCE: u64 = 2;
    /// Tried to add a balance in a token that this account already has
    const ERR_TOKEN_BALANCE_ALREADY_EXISTS: u64 = 3;
    /// Tried to withdraw funds in a token that the account does hold
    const ERR_NO_BALANCE_FOR_TOKEN: u64 = 4;
    /// An account cannot be created at the reserved core code address of 0x1
    const ERR_CANNOT_CREATE_AT_CORE_ADDRESS: u64 = 5;

    /// Deposit `Token<TokenType>` to `to_addr` address.
    public fun deposit_token<TokenType>(to_addr: address, token: Token<TokenType>)
    acquires Balance {
        Token::assert_is_token<TokenType>();

        // Check that the `token` amount is non-zero
        let token_amount = Token::value(&token);
        assert!(token_amount > 0, Errors::invalid_argument(ERR_ZERO_DEPOSIT_AMOUNT));

        // Create signer for `to_addr` to create PontAccount and Balance resources.
        let to_addr_acc = create_signer(to_addr);

        if (!has_token_balance<TokenType>(to_addr)) {
            create_token_balance<TokenType>(&to_addr_acc);
        };

        // Deposit the `to_deposit` token
        Token::deposit(&mut borrow_global_mut<Balance<TokenType>>(to_addr).token, token);
    }

    public fun deposit_token_with_metadata<TokenType>(
        to_addr: address,
        token: Token<TokenType>,
    ) acquires Balance {
        Token::assert_is_token<TokenType>();

        // Check that the `token` amount is non-zero
        let token_amount = Token::value(&token);
        assert!(token_amount > 0, Errors::invalid_argument(ERR_ZERO_DEPOSIT_AMOUNT));

        // Create signer for `to_addr` to create PontAccount and Balance resources.
        let to_addr_acc = create_signer(to_addr);

        if (!has_token_balance<TokenType>(to_addr)) {
            create_token_balance<TokenType>(&to_addr_acc);
        };

        // Deposit the `to_deposit` token
        Token::deposit(&mut borrow_global_mut<Balance<TokenType>>(to_addr).token, token);
    }

    /// Withdraw `amount` `Token<TokenType>`'s from the account balance and return.
    public fun withdraw_tokens<TokenType>(
        from_acc: &signer,
        amount: u128,
    ): Token<TokenType> acquires Balance {
        let from_acc_addr = Signer::address_of(from_acc);
        assert!(exists<Balance<TokenType>>(from_acc_addr), Errors::not_published(ERR_NO_BALANCE_FOR_TOKEN));

        let from_acc_balance = borrow_global_mut<Balance<TokenType>>(from_acc_addr);

        let token = &mut from_acc_balance.token;
        assert!(Token::value(token) >= amount, Errors::limit_exceeded(ERR_INSUFFICIENT_BALANCE));

        Token::withdraw(token, amount)
    }

    public fun transfer_tokens<TokenType>(
        from_acc: &signer,
        to_addr: address,
        amount: u128,
    ) acquires Balance {
        transfer_tokens_with_metadata<TokenType>(
            from_acc,
            to_addr,
            amount,
        );
    }

    /// Withdraw the balance from `from_acc` account and deposit to `to_addr`.
    public fun transfer_tokens_with_metadata<TokenType>(
        from_acc: &signer,
        to_addr: address,
        amount: u128
    ) acquires Balance {
        let tokens = withdraw_tokens<TokenType>(from_acc, amount);
        deposit_token(to_addr, tokens);
    }

    /// Return the current balance of the account at `addr`.
    public fun balance<TokenType>(addr: address): u128 acquires Balance {
        assert!(exists<Balance<TokenType>>(addr), Errors::not_published(ERR_NO_BALANCE_FOR_TOKEN));
        let balance = borrow_global<Balance<TokenType>>(addr);
        Token::value<TokenType>(&balance.token)
    }

    /// Add a balance of `TokenType` type to the sending account.
    public fun create_token_balance<TokenType>(acc: &signer) {
        let addr = Signer::address_of(acc);

        // aborts if `Token` is not a token type in the system
        Token::assert_is_token<TokenType>();

        // aborts if this account already has a balance in `Token`
        assert!(
            !exists<Balance<TokenType>>(addr),
            Errors::already_published(ERR_TOKEN_BALANCE_ALREADY_EXISTS)
        );
        move_to(acc, Balance<TokenType>{ token: Token::zero<TokenType>() })
    }

    ///////////////////////////////////////////////////////////////////////////
    // General purpose methods
    ///////////////////////////////////////////////////////////////////////////
    /// If `Balance<TokenType>` exists on account.
    fun has_token_balance<TokenType>(account: address): bool {
        exists<Balance<TokenType>>(account)
    }

    native fun create_signer(addr: address): signer;
}
