#!/bin/bash

aptos move run \
  --function-id 0xb4d7b2466d211c1f4629e8340bb1a9e75e7f8fb38cc145c54c5c9f9d5017a318::dao_deposit::withdraw_coins_from_pool \
  --type-args 0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9::coins::BTC \
  --type-args 0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9::coins::USDT \
  --type-args "0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9::lp::LP<0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9::coins::BTC, 0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9::coins::USDT>" \
  --args address:0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9 \
  --args u64:10 \
  --args u64:10
