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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sqrt() {
        let sui = 1_000_000;
        let token_y = 1_000_000_000;
        //let res = sqrt(sui) * sqrt(token_y);
        let res = sui_sqrt(sui) * sui_sqrt(token_y);
        println!("res\n{}", res);
    }
}
