import json
import time
from abc import abstractmethod, ABCMeta
from dataclasses import dataclass
from typing import Any, Dict

from aptos_sdk.account import Account
from aptos_sdk.account_address import AccountAddress
from aptos_sdk.client import RestClient, FaucetClient, ApiError
from aptos_sdk.transactions import ModuleId
from aptos_sdk.type_tag import TypeTag, StructTag

NODE_URL = 'http://0.0.0.0:8080/v1'
FAUCET_URL = 'http://0.0.0.0:8081'

LIQUIDSWAP_ADDR = "0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9"
FLASHLOAN_TEST_ADDR = "0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9"
TEST_COINS_ADDR = "0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9"
EXTENDED_COINS_ADDR = "0xb4d7b2466d211c1f4629e8340bb1a9e75e7f8fb38cc145c54c5c9f9d5017a318"

LIQUIDSWAP_PK = "TO_ADD"
FLASHLOAN_PK = LIQUIDSWAP_PK


@dataclass
class LiquidityPool:
    x_coin: TypeTag
    y_coin: TypeTag
    curve: TypeTag


class FixedRestClient(RestClient):
    def submit_transaction(self, sender: Account, payload: Dict[str, Any]) -> str:
        """
        1) Generates a transaction request
        2) submits that to produce a raw transaction
        3) signs the raw transaction
        4) submits the signed transaction
        """

        txn_request = {
            "sender": f"{sender.address()}",
            "sequence_number": str(self.account_sequence_number(sender.address())),
            "max_gas_amount": "10000",
            "gas_unit_price": "100",
            "expiration_timestamp_secs": str(int(time.time()) + 600),
            "payload": payload,
        }
        print(txn_request)
        response = self.client.post(
            f"{self.base_url}/transactions/encode_submission", json=txn_request
        )
        if response.status_code >= 400:
            raise ApiError(response.text, response.status_code)

        to_sign = bytes.fromhex(response.json()[2:])
        signature = sender.sign(to_sign)
        txn_request["signature"] = {
            "type": "ed25519_signature",
            "public_key": f"{sender.public_key()}",
            "signature": f"{signature}",
        }

        headers = {"Content-Type": "application/json"}
        response = self.client.post(
            f"{self.base_url}/transactions", headers=headers, json=txn_request
        )
        if response.status_code >= 400:
            raise ApiError(response.text, response.status_code)
        return response.json()["hash"]


class Module(metaclass=ABCMeta):
    _rest_client: RestClient

    def __init__(self, rest_client: RestClient):
        self._rest_client = rest_client

    def execute_transaction(self,
                            sender: Account,
                            function_name: str,
                            type_args: list[str],
                            args: list[Any]):
        full_function_name = f"{self.module_id()}::{function_name}"
        payload = {
            "type": "entry_function_payload",
            "function": full_function_name,
            "type_arguments": type_args,
            "arguments": args
        }
        txn_hash = self._rest_client.submit_transaction(sender, payload)
        self._rest_client.wait_for_transaction(txn_hash)

    @abstractmethod
    def module_id(self) -> ModuleId:
        raise NotImplementedError


class FlashloanTestModule(Module):
    def identity_swap(self, sender: Account, usdt_coins_amount: int):
        self.execute_transaction(sender,
                                 "identity_swap",
                                 [],
                                 [f"u64:{usdt_coins_amount}"])

    def module_id(self) -> ModuleId:
        return ModuleId(AccountAddress.from_hex(FLASHLOAN_TEST_ADDR), "flashloan_swap")


class ScriptsModule(Module):
    # def register_pool_and_add_liquidity(self,
    #                                     account: Account,
    #                                     pool: LiquidityPool,
    #                                     coin_x_val: int, coin_y_val: int):
    #     self.execute_transaction_with_pool(pool, account, "register_pool_and_add_liquidity",
    #                                        [
    #                                            TransactionArgument(coin_x_val, Serializer.u64),
    #                                            TransactionArgument(coin_x_val, Serializer.u64),
    #                                            TransactionArgument(coin_y_val, Serializer.u64),
    #                                            TransactionArgument(coin_y_val, Serializer.u64)
    #                                        ])

    # def swap_x_to_y(self, pool: LiquidityPool, account: Account, x_val: int):
    #     self.execute_transaction_with_pool(pool, account,
    #                                        "swap",
    #                                        [
    #                                            TransactionArgument(x_val, Serializer.u64),
    #                                            TransactionArgument(x_val, Serializer.u64)
    #                                        ])
    #
    # def swap_y_to_x(self, pool: LiquidityPool, y_val: int):
    #     pass

    def module_id(self) -> ModuleId:
        return ModuleId(AccountAddress.from_hex(LIQUIDSWAP_ADDR), "scripts")


def BTC() -> TypeTag:
    return TypeTag(StructTag(AccountAddress.from_hex(TEST_COINS_ADDR), "coins", "BTC", []))


def USDT() -> TypeTag:
    return TypeTag(StructTag(AccountAddress.from_hex(TEST_COINS_ADDR), "coins", "USDT", []))


def Uncorrelated() -> TypeTag:
    return TypeTag(StructTag(AccountAddress.from_hex(LIQUIDSWAP_ADDR), "curves", "Uncorrelated", []))


def Stable() -> TypeTag:
    return TypeTag(StructTag(AccountAddress.from_hex(LIQUIDSWAP_ADDR), "curves", "Stable", []))


if __name__ == '__main__':
    rest_client = FixedRestClient(NODE_URL)
    faucet_client = FaucetClient(FAUCET_URL, rest_client)

    liquidswap_admin = Account.load_key(LIQUIDSWAP_PK)
    flashloan_test_acc = Account.load_key(FLASHLOAN_PK)

    flashloan_test_module = FlashloanTestModule(rest_client)

    pool = LiquidityPool(BTC(), USDT(), Uncorrelated())
    flashloan_test_module.identity_swap(flashloan_test_acc, 100000)

    print(f"Alice balance: {rest_client.account_balance(liquidswap_admin.address().hex())}")
