spec liquidswap::math {
    spec overflow_add {
        ensures result <= MAX_U128;
        ensures a + b <= MAX_U128 ==> result == a + b;
        ensures a + b > MAX_U128 ==> result != a + b;
    }

    spec mul_div {
        aborts_if z == 0;
        aborts_if x * y / z > MAX_U64;
    }

    spec mul_div_u128 {
        aborts_if z == 0;
        aborts_if x * y > MAX_U128;
        aborts_if x * y / z > MAX_U64;
    }

    spec mul_to_u128 {
        // never aborts
        aborts_if false;
    }
}
