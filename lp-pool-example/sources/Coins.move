module Sender::Coins {
    use AptosFramework::Coin::{Coin, MintCapability, BurnCapability};
    use Std::Signer;
    use AptosFramework::Coin;
    use Std::ASCII::string;

    struct USDT has store {}

    struct BTC has store {}

    struct LP has store {}

    struct Caps<CoinType> has key {
        mint: MintCapability<CoinType>,
        burn: BurnCapability<CoinType>,
    }

    public(script) fun register_coins(token_admin: signer) {
        let (btc_m, btc_b) =
            Coin::initialize<BTC>(&token_admin,
                string(b"Bitcoin"), string(b"BTC"), 8, true);
        let (usdt_m, usdt_b) =
            Coin::initialize<USDT>(&token_admin,
                string(b"Tether"), string(b"USDT"), 10, true);
        move_to(&token_admin, Caps<BTC> { mint: btc_m, burn: btc_b });
        move_to(&token_admin, Caps<USDT> { mint: usdt_m, burn: usdt_b });
    }

    public(script) fun mint_coin<CoinType>(token_admin: &signer, acc_addr: address, amount: u64) acquires Caps {
        let token_admin_addr = Signer::address_of(token_admin);
        let caps = borrow_global<Caps<CoinType>>(token_admin_addr);
        let coins = Coin::mint<CoinType>(amount, &caps.mint)
        Coin::deposit(acc_addr, coins);
    }
}
