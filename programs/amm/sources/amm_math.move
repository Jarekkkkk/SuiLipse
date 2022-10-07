module sui_lipse::amm_math{

    // ====== EVENT =====
    const EZeroAmount:u64 = 0;
    const EReservesEmpty:u64 = 1;
    const EInsufficientInput:u64 = 2;
    const EInsufficientLiquidityBurned:u64 = 3;

    /// currently we are unable to get either block.timestamp & epoch, so we directly fetch the reserve's pool
    public fun get_x_price(res_x: u64, res_y:u64):u64{
        res_y / res_x
    }
    /// for fetch pool info
    public fun get_l(res_x:u64, res_y: u64):u64{
        sqrt(res_x) * sqrt(res_y)
    }
    /// for add liquidity
    /// b' (optimzied_) = (Y/X) * a, subjected to Y/X = b/a
    public fun quote(res_x:u64, res_y:u64, one_side_input:u64):u64{
        assert!(res_x > 0 && res_y > 0, EReservesEmpty);
        assert!(one_side_input > 0, EInsufficientInput);

        (res_y/ res_x) * one_side_input
    }
    /// swap
    /// dy = (dx * y) / (dx + x), at dx' = dx(1 - fee)
    public fun get_output(one_side_input:u64, reserve_in:u64, reserve_out:u64, f:u64, fee_scaling: u64):u64{
        assert!(reserve_in > 0 && reserve_out > 0, EReservesEmpty);
        assert!(one_side_input > 0, EInsufficientInput);

        let dx_fee_deduction = (fee_scaling - f) * one_side_input;
        let numerator = dx_fee_deduction * reserve_out;
        let denominator = fee_scaling * reserve_in + dx_fee_deduction;

        (numerator / denominator)
    }
    /// for remove_liquidity
    /// (dx, dy) = ((lp_input/ LP_supply) * reserve_x ,(lp_input/ LP_supply) * reserve_y)
    public fun withdraw_liquidity(res_x: u64, res_y:u64, lp_value:u64, lp_supply:u64):(u64, u64){
        assert!(lp_value > 0, EZeroAmount);
        assert!(res_x > 0 && res_y > 0, EReservesEmpty);

        let amount_x = (res_x * lp_value / lp_supply);
        let amount_y = (res_y * lp_value / lp_supply);
        assert!( amount_x > 0 && amount_y > 0, EInsufficientLiquidityBurned);

        (amount_x, amount_y)
    }
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