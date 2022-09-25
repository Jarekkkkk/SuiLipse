#![allow(unused)]

use anyhow::Result;

#[tokio::main]
async fn main() -> Result<()> {
    println!("Hello, world!");
    Ok(())
}

fn sqrt(y: u64) -> u64 {
    if (y < 4) {
        if (y == 0) {
            0u64
        } else {
            1u64
        }
    } else {
        let mut z = y;
        let mut x = y / 2 + 1;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
        z
    }
}
fn sui_sqrt(x: u64) -> u64 {
    let mut bit = 1u128 << 64;
    let mut res = 0u128;
    let mut x = (x as u128);

    while (bit != 0) {
        if (x >= res + bit) {
            x = x - (res + bit);
            res = (res >> 1) + bit;
        } else {
            res = res >> 1;
        };
        bit = bit >> 2;
    }

    (res as u64)
}
fn min(a: u64, b: u64) -> u64 {
    if a > b {
        b
    } else {
        a
    }
}
fn max(a: u64, b: u64) -> u64 {
    if a > b {
        a
    } else {
        b
    }
}

fn get_input(dx: u64, x: u64, y: u64, f: u64) -> u64 {
    let dx_fee_deduction = (10000 - f) * dx;
    let numerator = dx_fee_deduction * y;
    let denominator = 10000 * x + dx_fee_deduction;

    (numerator / denominator)
}

fn get_lp_supply(x: u64, y: u64) -> u64 {
    sqrt(x) * sqrt(y)
}

fn minted_lp_after_increase_liquidity(x: u64, y: u64, dx: u64, dy: u64, lp_supply: u64) -> u64 {
    min(dx * lp_supply / x, dy * lp_supply / y)
}

#[cfg(test)]
mod tests {
    use super::*;

    const SUI: u64 = 1_000_000;
    const TOKEN_Y: u64 = 1_000_000_000;

    #[test]
    fn test_sqrt() {
        let sui = 50;
        let token_y = 50_000;
        let lp = get_lp_supply(SUI, TOKEN_Y);
        println!("get lp\n{}", lp);
        let output = minted_lp_after_increase_liquidity(SUI, TOKEN_Y, sui, token_y, lp);

        println!("get input{}", output);
    }
}
