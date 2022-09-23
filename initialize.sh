#!/bin/bash

set -e
set -x

NODE_URL=http://0.0.0.0:8080/v1
FAUCET_URL=http://0.0.0.0:8081/

aptos init \
    --rest-url $NODE_URL \
    --faucet-url $FAUCET_URL \
    --private-key TO_ADD

aptos account fund-with-faucet --account 43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9

cd ../uq64x64/
aptos move publish
cd -

cd ../U256/
aptos move publish
cd -

cd liquidswap_init/
aptos move publish
cd -

cd liquidswap_lp/
aptos move compile --save-metadata
LP_COIN_METADATA_BCS_HEX=$(cat ./build/LiquidswapLP/package-metadata.bcs | hexdump -ve '/1 "%02x"')
LP_COIN_BYTECODE_HEX=$(cat ./build/LiquidswapLP/bytecode_modules/lp_coin.mv | hexdump -ve '/1 "%02x"')
aptos move run \
    --function-id 0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9::lp_account::initialize_lp_account \
    --args hex:$LP_COIN_METADATA_BCS_HEX \
    --args hex:$LP_COIN_BYTECODE_HEX
cd -

aptos move publish
aptos move run \
    --function-id 0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9::liquidity_pool::initialize

cd ../test-coins
aptos move publish
cd -

