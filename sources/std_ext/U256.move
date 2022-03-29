/// Implementation u256.
module Std::U256 {

    use Std::Vector;

    const WORD: u8 = 4;


    const ERR_INVALID_LENGTH: u64 = 100;
    const ERR_OVERFLOW: u64 = 200;

    /// use vector to represent data.
    /// so that we can use buildin vector ops later to construct U256.
    /// vector should always has two elements.
    struct U256 has copy, drop, store {
        /// little endian representation
        val: vector<u8>,
    }

    spec module {
        pragma verify = false;
    }

    public fun zero(): U256 {
        from_u128(0u128)
    }

    public fun one(): U256 {
        from_u128(1u128)
    }

    /// Creates a `U256` from the given `u64`.
    native public fun from_u64(value: u64): U256;

    /// Creates a `U256` from the given `u128`.
    native public fun from_u128(value: u128): U256;

    /// Converts from `U256` to `u128` with overflow checking.
    native public fun as_u128(value: U256): u128;

    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

    public fun compare(a: &U256, b: &U256): u8 {
        let i = (WORD as u64);
        while (i > 0) {
            i = i - 1;
            let a_bits = *Vector::borrow(&a.val, i);
            let b_bits = *Vector::borrow(&b.val, i);
            if (a_bits != b_bits) {
                if (a_bits < b_bits) {
                    return LESS_THAN
                } else {
                    return GREATER_THAN
                }
            }
        };
        EQUAL
    }

    #[test]
    fun test_compare() {
        let a = from_u64(111);
        let b = from_u64(111);
        let c = from_u64(112);
        let d = from_u64(110);
        assert!(compare(&a, &b) == EQUAL, 0);
        assert!(compare(&a, &c) == LESS_THAN, 1);
        assert!(compare(&a, &d) == GREATER_THAN, 2);
    }


    native public fun add(a: U256, b: U256): U256;

    #[test]
    fun test_add() {
        let a = Self::one();
        let b = Self::from_u128(10);
        let ret = Self::add(a, b);
        assert!(compare(&ret, &from_u64(11)) == EQUAL, 0);
    }

    native public fun sub(a: U256, b: U256): U256;

    #[test]
    #[expected_failure]
    fun test_sub_overflow() {
        let a = Self::one();
        let b = Self::from_u128(10);
        let _ = Self::sub(a, b);
    }

    #[test]
    fun test_sub_ok() {
        let a = Self::from_u128(10);
        let b = Self::one();
        let ret = Self::sub(a, b);
        assert!(compare(&ret, &from_u64(9)) == EQUAL, 0);
    }

    native public fun mul(a: U256, b: U256): U256;

    #[test]
    fun test_mul() {
        let a = Self::from_u128(10);
        let b = Self::from_u64(10);
        let ret = Self::mul(a, b);
        assert!(compare(&ret, &from_u64(100)) == EQUAL, 0);
    }

    native public fun div(a: U256, b: U256): U256;

    #[test]
    fun test_div() {
        let a = Self::from_u128(10);
        let b = Self::from_u64(2);
        let c = Self::from_u64(3);
        // as U256 cannot be implicitly copied, we need to add copy keyword.
        assert!(compare(&Self::div(copy a, b), &from_u64(5)) == EQUAL, 0);
        assert!(compare(&Self::div(copy a, c), &from_u64(3)) == EQUAL, 0);
    }

    //    public fun rem(a: U256, b: U256): U256 {
    //        native_rem(&mut a, &b);
    //        a
    //    }

    //    #[test]
    //    fun test_rem() {
    //        let a = Self::from_u128(10);
    //        let b = Self::from_u64(2);
    //        let c = Self::from_u64(3);
    //        assert!(compare(&Self::rem(copy a, b), &from_u64(0)) == EQUAL, 0);
    //        assert!(compare(&Self::rem(copy a, c), &from_u64(1)) == EQUAL, 0);
    //    }

    //    public fun pow(a: U256, b: U256): U256 {
    //        native_pow(&mut a, &b);
    //        a
    //    }

    //    #[test]
    //    fun test_pow() {
    //        let a = Self::from_u128(10);
    //        let b = Self::from_u64(1);
    //        let c = Self::from_u64(2);
    //        let d = Self::zero();
    //        assert!(compare(&Self::pow(copy a, b), &from_u64(10)) == EQUAL, 0);
    //        assert!(compare(&Self::pow(copy a, c), &from_u64(100)) == EQUAL, 0);
    //        assert!(compare(&Self::pow(copy a, d), &from_u64(1)) == EQUAL, 0);
    //    }

    spec fun value_of_U256(a: U256): num {
        (a.val[0]             // 0 * 64
         + a.val[1] << 64     // 1 * 64
                       + a.val[2] << 128    // 2 * 64
                                     + a.val[3] << 192    // 3 * 64
        )
    }

    spec from_u128 {
        pragma opaque;
        ensures value_of_U256(result) == v;
    }

    spec add {
        pragma opaque;
        // TODO: mvp doesn't seem to be using these specs
        aborts_if value_of_U256(a) + value_of_U256(b) >= (1 << 256);
        ensures value_of_U256(result) == value_of_U256(a) + value_of_U256(b);
    }

    spec sub {
        pragma opaque;
        // TODO: mvp doesn't seem to be using these specs
        aborts_if value_of_U256(a) > value_of_U256(b);
        ensures value_of_U256(result) == value_of_U256(a) - value_of_U256(b);
    }

    spec mul {
        pragma opaque;
        // TODO: mvp doesn't seem to be using these specs
        aborts_if value_of_U256(a) * value_of_U256(b) >= (1 << 256);
        ensures value_of_U256(result) == value_of_U256(a) * value_of_U256(b);
    }

    spec div {
        pragma opaque;
        // TODO: mvp doesn't seem to be using these specs
        aborts_if value_of_U256(b) == 0;
        ensures value_of_U256(result) == value_of_U256(a) / value_of_U256(b);
    }

    //    spec rem {
    //        pragma opaque;
    //        // TODO: mvp doesn't seem to be using these specs
    //        aborts_if value_of_U256(b) == 0;
    //        ensures value_of_U256(result) == value_of_U256(a) % value_of_U256(b);
    //    }

    //    spec pow {
    //        pragma opaque;
    //        // TODO: mvp doesn't seem to be using these specs
    //        // aborts_if value_of_U256(a) * value_of_U256(b) >= (1 << 256);
    //        // ensures value_of_U256(result) == value_of_U256(a) / value_of_U256(b);
    //    }
}
