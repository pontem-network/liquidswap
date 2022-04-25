module AptosSwap::Scripts {
    use Std::PontAccount;
    use Std::Signer;

    use AptosSwap::Router;

    /// Add liquidity to pool.
    /// * pool_addr - address of account registered pool.
    /// * token_x_val - amount of token X to add as liquidity.
    /// * token_x_val_min - minimum amount of token X to add as liquidity (slippage).
    /// * token_y_val - minimum amount of token Y to add as liquidity.
    /// * token_y_val_min - minimum amount of token Y to add as liquidity (slippage).
    public(script) fun add_liquidity<X: store, Y: store, LP>(
        account: signer,
        pool_addr: address,
        token_x_val: u128,
        token_x_val_min: u128,
        token_y_val: u128,
        token_y_val_min: u128
    ) {
        let token_x = PontAccount::withdraw_tokens<X>(&account, token_x_val);
        let token_y = PontAccount::withdraw_tokens<Y>(&account, token_y_val);

        let (token_x_remainder, token_y_remainder, lp_tokens) =
            Router::add_liquidity<X, Y, LP>(pool_addr, token_x, token_x_val_min, token_y, token_y_val_min);

        let account_addr = Signer::address_of(&account);
        PontAccount::deposit_token(account_addr, token_x_remainder);
        PontAccount::deposit_token(account_addr, token_y_remainder);
        PontAccount::deposit_token(account_addr, lp_tokens);
    }

    /// Remove (burn) liquidity tokens and get X,Y tokens back.
    /// * pool_addr - address of account registered pool.
    /// * lp_val - amount of LP tokens to burn.
    public(script) fun remove_liquidity<X: store, Y: store, LP>(
        account: signer,
        pool_addr: address,
        lp_val: u128,
        min_x_out_val: u128,
        min_y_out_val: u128,
    ) {
        let lp_tokens = PontAccount::withdraw_tokens<LP>(&account, lp_val);

        let (token_x, token_y) = Router::remove_liquidity<X, Y, LP>(pool_addr, lp_tokens, min_x_out_val, min_y_out_val);

        let account_addr = Signer::address_of(&account);
        PontAccount::deposit_token(account_addr, token_x);
        PontAccount::deposit_token(account_addr, token_y);
    }

    /// Swap exact token X for at least minimum token Y.
    /// * pool_addr - address of account registered pool.
    /// * token_val - amount of tokens X to swap.
    /// * token_out_min_val - minimum expected amount of tokens Y to get.
    public(script) fun swap<X: store, Y: store, LP>(account: signer, pool_addr: address, token_val: u128, token_out_min_val: u128) {
        let token_x = PontAccount::withdraw_tokens<X>(&account, token_val);

        let token_y = Router::swap_exact_token_for_token<X, Y, LP>(pool_addr, token_x, token_out_min_val);

        let account_addr = Signer::address_of(&account);
        PontAccount::deposit_token(account_addr, token_y);
    }

    /// Swap maximum token X for exact token Y.
    /// * pool_addr - address of account registered pool.
    /// * token_out - how much of tokens Y should be returned.
    /// * token_max_val - how much of tokens X can be used to get Y tokens.
    public(script) fun swap_into<X: store, Y: store, LP>(account: signer, pool_addr: address, token_val_max: u128, token_out: u128) {
        let token_x = PontAccount::withdraw_tokens<X>(&account, token_val_max);

        let (token_x, token_y) = Router::swap_token_for_exact_token<X, Y, LP>(pool_addr, token_x, token_out);

        let account_addr = Signer::address_of(&account);
        PontAccount::deposit_token(account_addr, token_x);
        PontAccount::deposit_token(account_addr, token_y);
    }
}
