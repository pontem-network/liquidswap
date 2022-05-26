# Multi Swap 

**The project is currently at MVP stage, not for production usage yet.**

**MultiSwap** is clone of [Uniswap](https://uniswap.org/) for [Aptos](https://www.aptos.com/) project. 

Inspired from original Uniswap code, docs and math.

The current repository contains: 

* Low level core
* Base router
* Scripts
* Tests
* Formal verification (in the future)

### Build

[Aptos CLI](https://github.com/aptos-labs/aptos-core/releases) required:

    aptos move compile

### Test

    aptos move test

### Pool example

Repo contains sample implementation of the pool in the `./lp-pool-example`. It defines `USDT`, `BTC` tokens for the exchange, 
and `LP` token for the liquidity. 


### License

See [LICENSE](LICENSE)

