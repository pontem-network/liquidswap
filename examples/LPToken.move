module AptosSwap::LPToken {
    use AptosSwap::Token;
    use Std::ASCII::string;

    struct LPToken has store { 
        val: u128 
    }

    /// ONLY FOR EXAMPLE PROPOSES!
    /// Register information about new LP token.
    /// What's important, the function should be called from address which contains information about all tokens for now.
    /// It can be changed later with clear Token library by Aptos team.
    public fun register(account: &signer): (Token::MintCapability<LPToken>, Token::BurnCapability<LPToken>) {
        Token::register_token<LPToken>(account, 10, string(b"LPToken"))
    }
}
