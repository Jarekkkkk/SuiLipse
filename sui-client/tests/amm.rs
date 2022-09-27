use sui_elipse::*;

const SUI: u64 = 1_000_000;
const TOKEN_Y: u64 = 1_000_000_000;

#[test]
fn test_sqrt() {
    let sui = 50;
    let token_y = 50_000;
    let lp = sqrt(SUI) * sqrt(TOKEN_Y);
    println!("get lp\n{}", lp);
    let output = minted_lp_after_increase_liquidity(SUI, TOKEN_Y, sui, token_y, lp);

    println!("get input{}", output);
}
