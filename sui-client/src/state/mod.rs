use serde::Deserialize;
use sui_sdk::types::{base_types::ObjectID, id::UID};

// ===== coin_pkg =====

#[derive(Deserialize, Debug)]
pub struct CoinState {
    uid: UID,
    balance: u64,
}
impl CoinState {
    pub fn uid_into(&self) -> ObjectID {
        self.uid.object_id().to_owned()
    }
}
#[derive(Deserialize, Debug)]
pub struct TreasuryCapState {
    uid: UID,
    total_supply: u64,
}

// ===== amm_pkg =====

#[derive(Deserialize, Debug)]
pub struct Pool {
    id: UID,
    name: String,
    symbol: String,
    reserve_x: u64,
    reserve_y: u64,
    lp_supply: u64,
    fee_percentage: u64, //[1,10000] --> [0.01%, 100%]
}

// ===== NFT =====
#[derive(Deserialize, Debug)]
pub struct NFTState {
    uid: UID,
    name: String,
    description: String,
    url: String, //i
}
