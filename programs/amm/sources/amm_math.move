module sui_lipse::amm_math{

    // ====== EVENT =====
    const EZeroAmount:u64 = 0;
    const EReservesEmpty:u64 = 1;
    const EInsufficientAAmount:u64 = 2;

    /// currently we are unable to get either block.timestamp & epoch, so we directly fetch the reserve's pool
    public fun get_x_price(x_res: u64, y_res:u64):u64{
        y_res / x_res
    }
    /// for fetch pool info
    public fun get_l(token_x_value:u64, token_y_value: u64):u64{
        sqrt(token_x_value) * sqrt(token_y_value)
    }
    /// for add liquidity
    /// b' (optimzied_) = (Y/X) * a, subjected to Y/X = b/a
    public fun quote(reserve_a:u64, reserve_b:u64, input_a:u64):u64{
        assert!(reserve_a > 0 && reserve_b > 0, EReservesEmpty);
        assert!(input_a > 0, EInsufficientAAmount);

        (reserve_b/ reserve_a) * input_a
    }
    /// swap
    /// dy = (dx * y) / (dx + x), at dx' = dx(1 - fee)
    public fun get_dy(dx:u64, x:u64, y:u64, f:u64, fee_scaling: u64):u64{
        let dx_fee_deduction = (fee_scaling - f) * dx;
        let numerator = dx_fee_deduction * y;
        let denominator = fee_scaling * x + dx_fee_deduction;

        (numerator / denominator)
    }
    /// for remove_liquidity
    /// (dx, dy) = ((lp_input/ LP_supply) * reserve_x ,(lp_input/ LP_supply) * reserve_y)
    public fun withdraw_liquidity(token_x_r: u64, token_y_r:u64, lp_value:u64, lp_supply:u64):(u64, u64){
        assert!(lp_value > 0, EZeroAmount);
        assert!(token_x_r > 0 && token_y_r > 0, EReservesEmpty);

        ((token_x_r * lp_value / lp_supply), (token_y_r * lp_value / lp_supply))
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