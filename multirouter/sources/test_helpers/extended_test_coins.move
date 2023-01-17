#[test_only]
module test_coin_admin::extended_test_coins {
    use std::signer;
    use std::string::utf8;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability};

    struct ETH {}

    struct DAI {}

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
        let (eth_burn_cap, eth_freeze_cap, eth_mint_cap) =
            coin::initialize<ETH>(
                coin_admin,
                utf8(b"ETH"),
                utf8(b"ETH"),
                8,
                true
            );

        let (dai_burn_cap, dai_freeze_cap, dai_mint_cap) =
            coin::initialize<DAI>(
                coin_admin,
                utf8(b"DAI"),
                utf8(b"DAI"),
                8,
                true
            );

        move_to(coin_admin, Capabilities<ETH> {
            mint_cap: eth_mint_cap,
            burn_cap: eth_burn_cap
        });

        move_to(coin_admin, Capabilities<DAI> {
            mint_cap: dai_mint_cap,
            burn_cap: dai_burn_cap
        });

        coin::destroy_freeze_cap(eth_freeze_cap);
        coin::destroy_freeze_cap(dai_freeze_cap);
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