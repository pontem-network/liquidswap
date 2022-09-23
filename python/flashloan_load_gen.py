from abc import abstractmethod, ABCMeta
from dataclasses import dataclass
from typing import List

from aptos_sdk.account import Account
from aptos_sdk.account_address import AccountAddress
from aptos_sdk.bcs import Serializer
from aptos_sdk.client import RestClient, FaucetClient
from aptos_sdk.transactions import TransactionPayload, ScriptFunction, ModuleId, TransactionArgument
from aptos_sdk.type_tag import TypeTag, StructTag

NODE_URL = 'http://0.0.0.0:8080/v1'
FAUCET_URL = 'http://0.0.0.0:8081'

LIQUIDSWAP_ADDR = "0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9"
FLASHLOAN_TEST_ADDR = "0x2"
COINS_ADDR = "0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9"
EXTENDED_COINS_ADDR = "0xb4d7b2466d211c1f4629e8340bb1a9e75e7f8fb38cc145c54c5c9f9d5017a318"

LIQUIDSWAP_PK = "TO_ADD"
FLASHLOAN_PK = "TO_ADD"


@dataclass
class LiquidityPool:
    x_coin: TypeTag
    y_coin: TypeTag
    curve: TypeTag


class Module(metaclass=ABCMeta):
    _rest_client: RestClient

    def __init__(self, rest_client: RestClient):
        self._rest_client = rest_client

    def execute_transaction(self,
                            pool: 'LiquidityPool',
                            account: Account,
                            function_name: str,
                            args: list[TransactionArgument]):
        function_call = ScriptFunction(self.module_id(),
                                       function_name,
                                       [pool.x_coin, pool.y_coin, pool.curve],
                                       args)
        payload = TransactionPayload(function_call)
        signed_txn = self._rest_client.create_single_signer_bcs_transaction(account, payload)

        txn_hash = self._rest_client.submit_bcs_transaction(signed_txn)
        self._rest_client.wait_for_transaction(txn_hash)

    @abstractmethod
    def module_id(self) -> ModuleId:
        raise NotImplementedError


class LiquidityPoolModule(Module):
    def register_pool(self, account: Account, x_coin: TypeTag, y_coin: TypeTag, curve: TypeTag) -> LiquidityPool:
        pool = LiquidityPool(x_coin, y_coin, curve)
        self.execute_transaction(pool, account, "register", [])
        return pool

    def module_id(self) -> ModuleId:
        return ModuleId(AccountAddress.from_hex(LIQUIDSWAP_ADDR), "liquidity_pool")


class FlashloanTestModule(Module):
    def identity_swap(self, sender: Account, pool: LiquidityPool, y_coins: int):
        self.execute_transaction(pool,
                                 sender, "identity_swap",
                                 [TransactionArgument(y_coins, Serializer.u64)])

    def module_id(self) -> ModuleId:
        return ModuleId(AccountAddress.from_hex(FLASHLOAN_TEST_ADDR), "liquidity_pool")


class RouterModule:
    _rest_client: RestClient

    def __init__(self, rest_client: RestClient):
        self._rest_client = rest_client

    def add_liquidity(self, pool: LiquidityPool):
        pass


def BTC() -> TypeTag:
    return TypeTag(StructTag(AccountAddress.from_hex(COINS_ADDR), "coins", "BTC", []))


def USDT() -> TypeTag:
    return TypeTag(StructTag(AccountAddress.from_hex(COINS_ADDR), "coins", "USDT", []))


def Uncorrelated() -> TypeTag:
    return TypeTag(StructTag(AccountAddress.from_hex(LIQUIDSWAP_ADDR), "curves", "Uncorrelated", []))


def Stable() -> TypeTag:
    return TypeTag(StructTag(AccountAddress.from_hex(LIQUIDSWAP_ADDR), "curves", "Stable", []))


if __name__ == '__main__':
    rest_client = RestClient(NODE_URL)
    faucet_client = FaucetClient(FAUCET_URL, rest_client)

    liquidswap_admin = Account.load_key(LIQUIDSWAP_PK)
    flashloan_test_acc = Account.load_key(FLASHLOAN_PK)

    pool_module = LiquidityPoolModule(rest_client)
    pool = pool_module.register_pool(liquidswap_admin, BTC(), USDT(), Uncorrelated())

    flashloan_test_module = FlashloanTestModule(rest_client)
    flashloan_test_module.identity_swap(flashloan_test_acc, pool, 100000)

    print(f"Alice balance: {rest_client.account_balance(liquidswap_admin.address().hex())}")
