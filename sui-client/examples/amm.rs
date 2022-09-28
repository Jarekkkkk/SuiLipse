#![allow(unused)]

use std::env;
use std::str::FromStr;
use sui_sdk::{
    crypto::{KeystoreType, SuiKeystore},
    json::SuiJsonValue,
    types::{
        base_types::{ObjectID, SuiAddress},
        crypto::Signature,
        id::UID,
        messages::Transaction,
    },
    SuiClient,
};

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    Ok(())
}

struct Pool {
    pool_id: ObjectID,
    client: SuiClient,
    keystore: SuiKeystore,
}

impl Pool {
    async fn create_pool(){}
    async fn add_liquidity(){}
    async fn remove_liquidity(){}
    async fn swap_sui(){}
    async fn swap_token_y(){}
}
