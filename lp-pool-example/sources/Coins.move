module Sender::Coins {
    use AptosFramework::Coin::{Coin, MintCapability, BurnCapability};
    use Std::Signer;
    use AptosFramework::Coin;
    use Std::ASCII::string;

    struct USDT has store {}

    struct BTC has store {}

    struct LP has store {}

    struct Capabilities has key {
        btc_mint_cap: MintCapability<BTC>,
        btc_burn_cap: BurnCapability<BTC>,
        usdt_mint_cap: MintCapability<USDT>,
        usdt_burn_cap: BurnCapability<USDT>,
    }

    public(script) fun register_tokens(token_admin: signer) {
        let (btc_m, btc_b) =
            Coin::initialize<BTC>(&token_admin,
                string(b"Bitcoin"), string(b"BTC"), 8, true);
        let (usdt_m, usdt_b) =
            Coin::initialize<USDT>(&token_admin,
                string(b"Tether"), string(b"USDT"), 10, true);
        let caps = Capabilities{
            btc_mint_cap: btc_m,
            btc_burn_cap: btc_b,
            usdt_mint_cap: usdt_m,
            usdt_burn_cap: usdt_b
        };
        move_to(&token_admin, caps);
    }

    public(script) fun mint_btc(token_admin: &signer, amount: u64): Coin<BTC> acquires Capabilities {
        let token_admin_addr = Signer::address_of(token_admin);
        let caps = borrow_global<Capabilities>(token_admin_addr);
        Coin::mint(amount, &caps.btc_mint_cap)
    }

    public(script) fun mint_usdt(token_admin: &signer, amount: u64): Coin<USDT> acquires Capabilities {
        let token_admin_addr = Signer::address_of(token_admin);
        let caps = borrow_global<Capabilities>(token_admin_addr);
        Coin::mint(amount, &caps.usdt_mint_cap)
    }
}
