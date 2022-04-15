#!/usr/bin/env bash

dove sandbox clean && dove sandbox publish

dove sandbox run --signers "0x12" -- ./scripts/register_currency_tokens.move
dove sandbox run --signers "0x12 0x42" -- ./scripts/register_pool.move

dove sandbox run --signers "0x12" --args "0x42 101u128 10100u128" -- ./scripts/mint_tokens.move

