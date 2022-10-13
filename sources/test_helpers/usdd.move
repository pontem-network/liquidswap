#[test_only]
module test_coins_extended::usdd {
    use std::string::utf8;

    use aptos_framework::coin;

    use test_coins::coins;

    struct USDD {}

    public fun register_usdd(token_admin: &signer) {
        let (cusdc_b, cusdc_f, cusdc_m) =
            coin::initialize<USDD>(
                token_admin,
                utf8(b"USDD"),
                utf8(b"USDD"),
                4,
                true
            );
        coin::destroy_freeze_cap(cusdc_f);
        coins::store_caps(token_admin, cusdc_m, cusdc_b);
    }
}
