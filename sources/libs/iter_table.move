module gauge_admin::iter_table {
    use std::vector;

    use aptos_std::table_with_length::{Self, TableWithLength};

    struct IterTable<K: copy + drop, phantom V> has store {
        items: TableWithLength<K, V>,
        keys: vector<K>
    }

    public fun new<K: copy + drop, V: store>(): IterTable<K, V> {
        IterTable<K, V> {
            items: table_with_length::new<K, V>(),
            keys: vector::empty<K>()
        }
    }

    public fun is_empty<K: copy + drop, V>(map: &IterTable<K, V>): bool {
        table_with_length::empty(&map.items)
    }

    public fun contains<K: copy + drop, V>(map: &IterTable<K, V>, key: K): bool {
        table_with_length::contains(&map.items, key)
    }

    public fun add<K: copy + drop, V>(map: &mut IterTable<K, V>, key: K, val: V) {
        table_with_length::add(&mut map.items, key, val);
        vector::push_back(&mut map.keys, key);
    }

    public fun keys<K: copy + drop, V>(map: &IterTable<K, V>): &vector<K> {
        &map.keys
    }

    public fun borrow<K: copy + drop, V>(map: &IterTable<K, V>, key: K): &V {
        table_with_length::borrow(&map.items, key)
    }

    public fun borrow_mut<K: copy + drop, V>(map: &mut IterTable<K, V>, key: K): &mut V {
        table_with_length::borrow_mut(&mut map.items, key)
    }

    public fun borrow_mut_with_default<K: copy + drop, V: drop>(map: &mut IterTable<K, V>, key: K, default: V): &mut V {
        if (!table_with_length::contains(&map.items, copy key)) {
            vector::push_back(&mut map.keys, copy key);
            table_with_length::add(&mut map.items, copy key, default);
        };
        table_with_length::borrow_mut(&mut map.items, key)
    }

    public fun borrow_by_index<K: copy + drop, V>(map: &IterTable<K, V>, i: u64): (&K, &V) {
        let key = vector::borrow(&map.keys, i);
        let val = table_with_length::borrow(&map.items, *key);
        (key, val)
    }

    public fun pop_back<K: copy + drop, V>(map: &mut IterTable<K, V>): (K, V) {
        let key = vector::pop_back(&mut map.keys);
        let val = table_with_length::remove(&mut map.items, copy key);
        (key, val)
    }
}
