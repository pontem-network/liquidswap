module liquidswap::gauge {
    use aptos_std::table::{Self, Table};

    struct Gauge has store {
        token_ids: Table<address, u64>,
        balance: Table<address, u64>,
    }
}
