# AptosSwap 

**The project is currently at MVP stage, not for production usage yet.**

**AptosSwap** is clone of [Uniswap](https://uniswap.org/) for [Aptos](https://www.aptos.com/) project. 

Inspired from original Uniswap code, docs and math.

The current repository contains: 

* Low level core
* Base router
* Scripts
* Tests
* Formal verification (in the future)

### Build

[Dove](https://github.com/pontem-network/dove) or [move-cli](https://github.com/aptos-labs/aptos-core) required:

    dove build

### Test

    dove test

### Pool example

Repo contains sample implementation of the pool in the `./lp-pool-example`. It defines `USDT`, `BTC` tokens for the exchange, 
and `LP` token for the liquidity. 


