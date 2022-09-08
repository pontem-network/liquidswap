#[test_only]
module test_coin_admin::test_coins {
    use std::string::utf8;
    use std::signer;

    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability};
    use aptos_framework::account;

    struct BTC {}

    struct USDT {}

    struct USDC {}

    struct Capabilities<phantom CoinType> has key {
        mint_cap: MintCapability<CoinType>,
        burn_cap: BurnCapability<CoinType>,
    }

    // Register one coin with custom details.
    public fun register_coin<CoinType>(coin_admin: &signer, name: vector<u8>, symbol: vector<u8>, decimals: u8) {
        let (burn_cap, freeze_cap, mint_cap, ) = coin::initialize<CoinType>(
            coin_admin,
            utf8(name),
            utf8(symbol),
            decimals,
            true,
        );
        coin::destroy_freeze_cap(freeze_cap);

        move_to(coin_admin, Capabilities<CoinType> {
            mint_cap,
            burn_cap,
        });
    }

    public fun create_coin_admin(): signer {
        account::create_account_for_test(@test_coin_admin)
    }

    public fun create_admin_with_coins(): signer {
        let coin_admin = create_coin_admin();
        register_coins(&coin_admin);
        coin_admin
    }

    // Register all known coins in one func.
    public fun register_coins(coin_admin: &signer) {
        let (usdt_burn_cap, usdt_freeze_cap, usdt_mint_cap) =
            coin::initialize<USDT>(
                coin_admin,
                utf8(b"USDT"),
                utf8(b"USDT"),
                6,
                true
            );

        let (btc_burn_cap, btc_freeze_cap, btc_mint_cap) =
            coin::initialize<BTC>(
                coin_admin,
                utf8(b"BTC"),
                utf8(b"BTC"),
                8,
                true
            );

        let (usdc_burn_cap, usdc_freeze_cap, usdc_mint_cap) =
            coin::initialize<USDC>(
                coin_admin,
                utf8(b"USDC"),
                utf8(b"USDC"),
                4,
                true,
            );

        move_to(coin_admin, Capabilities<USDT> {
            mint_cap: usdt_mint_cap,
            burn_cap: usdt_burn_cap,
        });

        move_to(coin_admin, Capabilities<BTC> {
            mint_cap: btc_mint_cap,
            burn_cap: btc_burn_cap,
        });

        move_to(coin_admin, Capabilities<USDC> {
            mint_cap: usdc_mint_cap,
            burn_cap: usdc_burn_cap,
        });

        coin::destroy_freeze_cap(usdt_freeze_cap);
        coin::destroy_freeze_cap(usdc_freeze_cap);
        coin::destroy_freeze_cap(btc_freeze_cap);
    }

    public fun mint<CoinType>(coin_admin: &signer, amount: u64): Coin<CoinType> acquires Capabilities {
        let caps = borrow_global<Capabilities<CoinType>>(signer::address_of(coin_admin));
        coin::mint(amount, &caps.mint_cap)
    }

    public fun burn<CoinType>(coin_admin: &signer, coins: Coin<CoinType>) acquires Capabilities {
        if (coin::value(&coins) == 0) {
            coin::destroy_zero(coins);
        } else {
            let caps = borrow_global<Capabilities<CoinType>>(signer::address_of(coin_admin));
            coin::burn(coins, &caps.burn_cap);
        };
    }
}
