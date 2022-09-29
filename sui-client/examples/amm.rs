#![allow(unused)]

use clap::{Parser, Subcommand};
use serde::Deserialize;
use std::{convert::TryInto, path::PathBuf, str::FromStr};
use sui_sdk::{
    crypto::{KeystoreType, SuiKeystore},
    json::SuiJsonValue,
    rpc_types::{SuiData, SuiObjectRef, SuiTypeTag},
    types::parse_sui_type_tag,
    types::{
        base_types::{ObjectID, SuiAddress},
        crypto::Signature,
        id::UID,
        messages::{SingleTransactionKind, Transaction},
        object::Object,
    },
    SuiClient,
};

use async_trait::async_trait;
#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    Ok(())
}

struct PoolClient {
    pool_id: ObjectID,
    client: SuiClient,
    keystore: SuiKeystore,
}

//mirror scripts for calling on-chain smart contract
#[async_trait]
trait PoolScript: Sized {
    async fn create_pool() -> Self;
    async fn add_liquidity() -> Result<(), anyhow::Error>;
    async fn remove_liquidity() -> Result<(), anyhow::Error>;
    async fn swap_sui() -> Result<(), anyhow::Error>;
    async fn swap_token_y() -> Result<(), anyhow::Error>;
}
