module sui_lipse::amm_math{

    public fun sqrt(y: u64): u64 {
        if (y < 4) {
            if (y == 0) {
                0u64
            } else {
                1u64
            }
        } else {
            let z = y;
            let x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            };
            z
        }
    }

    public fun min(a: u64, b: u64): u64 {
        if (a > b) b else a
    }

    public fun max(a: u64, b: u64): u64 {
        if (a < b) b else a
    }

    public fun pow(base: u64, exp: u8): u64 {
        let result = 1u64;
        loop {
            if (exp & 1 == 1) { result = result * base; };
            exp = exp >> 1;
            base = base * base;
            if (exp == 0u8) { break };
        };
        result
    }

}