#[test_only]
module TestCoinAdmin::TestCoins {
    use Std::ASCII::string;
    use Std::Signer;

    use AptosFramework::Coin::{Self, Coin, MintCapability, BurnCapability};

    struct BTC {}

    struct USDT {}

    struct USDC {}

    struct Capabilities<phantom CoinType> has key {
        mint_cap: MintCapability<CoinType>,
        burn_cap: BurnCapability<CoinType>,
    }

    public fun register_coins(coin_admin: &signer) {
        let (usdt_mint_cap, usdt_burn_cap) =
            Coin::initialize<USDT>(
                coin_admin,
                string(b"USDT"),
                string(b"USDT"),
                6,
                true
            );

        let (btc_mint_cap, btc_burn_cap) =
            Coin::initialize<BTC>(
                coin_admin, string(b"BTC"),
                string(b"BTC"),
                8,
                true
            );

        let (usdc_mint_cap, usdc_burn_cap) =
            Coin::initialize<USDC>(
                coin_admin,
                string(b"USDC"),
                string(b"USDC"),
                4,
                true,
            );

        move_to(coin_admin, Capabilities<USDT>{
            mint_cap: usdt_mint_cap,
            burn_cap: usdt_burn_cap,
        });

        move_to(coin_admin, Capabilities<BTC>{
            mint_cap: btc_mint_cap,
            burn_cap: btc_burn_cap,
        });

        move_to(coin_admin, Capabilities<USDC> {
            mint_cap: usdc_mint_cap,
            burn_cap: usdc_burn_cap,
        });
    }

    public fun mint<CoinType>(coin_admin: &signer, amount: u64): Coin<CoinType> acquires Capabilities {
        let caps = borrow_global<Capabilities<CoinType>>(Signer::address_of(coin_admin));
        Coin::mint(amount, &caps.mint_cap)
    }

    public fun burn<CoinType>(coin_admin: &signer, coins: Coin<CoinType>) acquires Capabilities {
        let caps = borrow_global<Capabilities<CoinType>>(Signer::address_of(coin_admin));
        Coin::burn(coins, &caps.burn_cap);
    }
}