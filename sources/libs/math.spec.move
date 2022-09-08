spec liquidswap::math {
    spec overflow_add {
        ensures result <= MAX_U128;
        ensures a + b <= MAX_U128 ==> result == a + b;
        ensures a + b > MAX_U128 ==> result != a + b;
        ensures a + b > MAX_U128 && a < (MAX_U128 - b) ==> result == a - (MAX_U128 - b) - 1;
        ensures a + b > MAX_U128 && b < (MAX_U128 - a) ==> result == b - (MAX_U128 - a) - 1;
        ensures a + b <= MAX_U128 ==> result == a + b;
    }

    spec mul_div {
        aborts_if z == 0 with ERR_DIVIDE_BY_ZERO;
        aborts_if x * y > MAX_U128;
        aborts_if x * y / z > MAX_U64;
        ensures result == x * y / z;
    }

    spec mul_div_u128 {
        aborts_if z == 0 with ERR_DIVIDE_BY_ZERO;
        aborts_if x * y > MAX_U128;
        aborts_if x * y / z > MAX_U64;
        ensures result == x * y / z;
    }

    spec mul_to_u128 {
        ensures result == x * y;
    }

    spec fun spec_pow(y: u64, x: u64): u64 {
        if (x == 0) {
            1
        } else {
            y * spec_pow(y, x-1)
        }
    }
    spec pow_10 {
        ensures degree == 0 ==> result == 1;
        ensures result == spec_pow(10, degree);
    }
}
