#!/usr/bin/env bash
set -x
set -e

dove sandbox clean && dove sandbox --test publish

dove sandbox run --test --signers "0x12" -- ./scripts/register_currency_tokens.move
dove sandbox run --test --signers "0x12 0x42" -- ./scripts/register_pool.move

dove sandbox run --test --signers "0x12" --args "0x42 202u128 20200u128" -- ./scripts/mint_tokens.move

dove sandbox run --test --signers "0xa550c18" -- ./scripts/genesis.move
#
dove sandbox run --test --signers "0x42" --args "0x42 101u128 10100u128" -- ./scripts/add_liquidity.move
dove sandbox run --test --signers "0x42" --args "0x42 10u128 900u128" -- ./scripts/swap.move



