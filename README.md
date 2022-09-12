# Liquidswap

**Liquidswap** is AMM protocol for [Aptos](https://www.aptos.com/) blockchain. 

We support two curves:

* For uncorrelated swaps.
* For stable swaps.

The current repository contains: 

* Low level core.
* Base router.
* Scripts.
* Tests.

## Add as dependency

Update your `Move.toml` with

```toml
[dependencies.Liquidswap]
git = 'https://github.com/pontem-network/liquidswap.git'
rev = 'v0.2.7'

[dependencies.LiquidswapLP]
git = 'https://github.com/pontem-network/liquidswap-lp.git'
rev = 'v0.4.11'
```

And use in code:

```move
use liquidswap::router;
use liquidswap::liquidity_pool::Uncorrelated;

use liquidswap_lp::coins::{USDT, BTC};

...
let pool_owner_addr = @0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9;
let usdt_coins_to_get = 5292719411;
let btc_coins_to_swap_val = router::get_amount_in<BTC, USDT, Uncorrelated>(pool_owner_addr, usdt_coins_to_get);
let btc_coins_to_swap = coin::withdraw<BTC>(account, btc_coins_to_swap_val);

let (coin_x, coin_y) = router::swap_coin_for_exact_coin<BTC, USDT, Uncorrelated>(
    pool_owner_addr,
    btc_coins_to_swap,
    usdt_coins_to_get
);
```


### Build

[Aptos CLI](https://github.com/aptos-labs/aptos-core/releases) required:

    aptos move compile

### Test

    aptos move test

### License

See [LICENSE](LICENSE)

