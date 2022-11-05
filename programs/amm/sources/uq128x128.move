module sui_lipse::uq128x128{
    const Q128: u256 = 340282366920938463463374607431768211455;

      /// When divide by zero attempted.
    const ERR_DIVIDE_BY_ZERO: u64 = 100;

    /// When a and b are equals.
    const EQUAL: u8 = 0;

    /// When a is less than b equals.
    const LESS_THAN: u8 = 1;

    /// When a is greater than b.
    const GREATER_THAN: u8 = 2;

    struct UQ128x128 has copy, store, drop{
        v: u256
    }

    public fun encode(x: u128): UQ128x128{
        let v = ( x as u256 ) * Q128;
        UQ128x128{
            v
        }
    }
    spec encode {
        ensures Q128 == MAX_U128;
        ensures result.v == x * Q128;
        ensures result.v <= MAX_U128;
    }

    public fun decode(uq: UQ128x128): u128 {
        ((uq.v / Q128) as u128)
    }
    spec decode {
        ensures result == uq.v / Q128;
    }

    /// Get `u256` from UQ128x128
    public fun to_u256(uq: UQ128x128): u256 {
        uq.v
    }
    spec to_u256{
        ensures result == uq.v;
    }


    /// Multiply a `UQ128x128` by a `u64`, returning a `UQ128x128`
    public fun mul(uq: UQ128x128, y: u128): UQ128x128 {
        // vm would direct abort when overflow occured
        let v = uq.v * (y as u256);

        UQ128x128{ v }
    }
    spec mul {
        ensures result.v == uq.v * y;
    }

    /// Divide a `UQ128x128` by a `u128`, returning a `UQ128x128`.
    public fun div(uq: UQ128x128, y: u128): UQ128x128 {
        assert!(y != 0, ERR_DIVIDE_BY_ZERO);

        let v = uq.v / (y as u256);
        UQ128x128{ v }
    }
    spec div {
        aborts_if y == 0 with ERR_DIVIDE_BY_ZERO;
        ensures result.v == uq.v / y;
    }

    /// Returns a `UQ128x128` which represents the ratio of the numerator to the denominator.
    public fun fraction(numerator: u128, denominator: u128): UQ128x128 {
        assert!(denominator != 0, ERR_DIVIDE_BY_ZERO);

        let r = (numerator as u256) * Q128;
        let v = r / (denominator as u256);

        UQ128x128{ v }
    }
    spec fraction {
        aborts_if denominator == 0 with ERR_DIVIDE_BY_ZERO;
        ensures result.v == numerator * Q128 / denominator;
    }

    /// Compare two `UQ128x128` numbers.
    public fun compare(left: &UQ128x128, right: &UQ128x128): u8 {
        if (left.v == right.v) {
            return EQUAL
        } else if (left.v < right.v) {
            return LESS_THAN
        } else {
            return GREATER_THAN
        }
    }
    spec compare {
        ensures left.v == right.v ==> result == EQUAL;
        ensures left.v < right.v ==> result == LESS_THAN;
        ensures left.v > right.v ==> result == GREATER_THAN;
    }

    /// Check if `UQ128x128` is zero
    public fun is_zero(uq: &UQ128x128): bool {
        uq.v == 0
    }
    spec is_zero {
        ensures uq.v == 0 ==> result == true;
        ensures uq.v > 0 ==> result == false;
    }

    use std::debug::print;

    fun test(numerator: u64, denominator: u64){
        let u_128 = (numerator as u128);
        let d_128 = (denominator as u128);

        let uq_fraction = fraction(u_128, d_128);
                print(&uq_fraction);
        let uq_256 = to_u256(uq_fraction);

        print(&uq_256);
    }

    #[test]
    fun foo(){
        let numerator:u64 = 100;
        let denominator:u64 = 400;

        print(&numerator);
        print(&denominator);

        test(numerator, denominator);


    }
}