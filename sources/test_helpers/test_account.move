#[test_only]
module test_helpers::test_account {
    use std::signer;

    use aptos_framework::account;

    public fun create_account(acc: &signer) {
        account::create_account(signer::address_of(acc));
    }
}