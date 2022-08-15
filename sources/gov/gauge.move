module liquidswap::gauge {
    use aptos_std::table_with_length::TableWithLength;

    struct GaugeConfig<phantom X, phantom Y, phantom LP> has key {
        weights: TableWithLength<u64, u64>,     //token_id, weight

    }

}
