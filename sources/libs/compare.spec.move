spec liquidswap::compare {
    spec cmp_bcs_bytes {
        let i1 = len(v1);
        let i2 = len(v2);
        ensures i1 == i2 && (forall i in 0..(i1-1): v1[i] == v2[i]) ==> result == EQUAL;
        ensures i1 < i2 ==> result == LESS_THAN;
        ensures i1 > i2 ==> result == GREATER_THAN;
    }

    spec cmp_u8 {
        ensures i1 == i2 ==> result == EQUAL;
        ensures i1 < i2 ==> result == LESS_THAN;
        ensures i1 > i2 ==> result == GREATER_THAN;
    }

    spec cmp_u64 {
        ensures i1 == i2 ==> result == EQUAL;
        ensures i1 < i2 ==> result == LESS_THAN;
        ensures i1 > i2 ==> result == GREATER_THAN;
    }
}
