#[test_only]
module liquidswap::test_account {
    use aptos_framework::account;
    use std::signer;

    public fun create_account(acc: &signer) {
        account::create_account(signer::address_of(acc));
    }
}