module PontemFramework::PontAccount {
    friend SwapAdmin::Token;
    
    public(friend) native fun create_signer(addr: address): signer;
}
