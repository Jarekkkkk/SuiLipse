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
    let args: Vec<String> = env::args().collect();
    println!("args{}", args[0]);
    println!("args{}", &args[1]);
    let sui = SuiClient::new_rpc_client("https://gateway.devnet.sui.io:443", None).await?;
    let address = SuiAddress::from_str("0xb73c836b1dfa662b67fd02aaba9fe1b52facf127")?;
    let objects = sui.read_api().get_objects_owned_by_address(address).await?;
    println!("{:?}", objects);
    Ok(())
}

struct Pool {
    pool_id: ObjectID,
    client: SuiClient,
    keystore: SuiKeystore,
}
