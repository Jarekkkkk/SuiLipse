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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sqrt() {
        let sui = 1_000_000;
        let token_y = 1_000_000_000;
        let res = sqrt(sui) * sqrt(token_y);
        println!("res\n{}", res);
    }
}
