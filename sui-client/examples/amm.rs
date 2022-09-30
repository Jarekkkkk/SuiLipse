#![allow(unused)]

use clap::{Parser, Subcommand};
use serde::Deserialize;
use std::{
    convert::TryInto,
    fs::File,
    io::{BufReader, Read},
    path::PathBuf,
    str::FromStr,
};
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
use sui_elipse::default_keystore_path;
const SUI_LIPSE: &str = "0x24ca9e97e43aa83111be28ce1a280214238ebfa7";

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    let opts: AmmClientOpts = AmmClientOpts::parse();

    let keystore_path = opts
        .keystore_path
        .clone() // clone should be omit
        .unwrap_or_else(default_keystore_path);

    let suilipse_pkg = opts
        .suilipse_packagae_id
        .clone()
        .unwrap_or(ObjectID::from_hex_literal(SUI_LIPSE)?);

    let pool_client = PoolClient::new(&opts, suilipse_pkg, keystore_path).await?;

    println!("signer\n: {:?}\n", &pool_client.get_signer(1));

    match opts.subcommand {
        AmmCommand::ChangeCard { card, name, symbol } => {
            println!("card {:?}", card);
            println!("name {:?}", name.unwrap());
            println!("symbol {:?}", symbol);

            pool_client.update_svg(nft, contents).await?;
        }
    }
    Ok(())
}

struct PoolClient {
    pool_package_id: ObjectID,
    client: SuiClient,
    keystore: SuiKeystore,
}

#[derive(Deserialize, Debug)]
struct NFTState {
    uid: UID,
    name: String,
    description: String,
    url: String, //i
}
//mirror scripts for calling on-chain smart contract
#[async_trait]
trait PoolScript: Sized {
    async fn change_card() -> Result<(), anyhow::Error>;
    async fn create_pool() -> Result<(), anyhow::Error>;
    async fn add_liquidity() -> Result<(), anyhow::Error>;
    async fn remove_liquidity() -> Result<(), anyhow::Error>;
    async fn swap_sui() -> Result<(), anyhow::Error>;
    async fn swap_token_y() -> Result<(), anyhow::Error>;
}

impl PoolClient {
    async fn new(
        opts: &AmmClientOpts,
        pool_package_id: ObjectID,
        keystore_path: PathBuf,
    ) -> Result<Self, anyhow::Error> {
        let keystore = KeystoreType::File(keystore_path).init()?;
        let pool_client = Self {
            pool_package_id,
            client: SuiClient::new_rpc_client(&opts.rpc_server_url, None).await?,
            keystore,
        };

        Ok(pool_client)
    }
    pub fn load_svg_file(path: &str) -> PathBuf {
        match dirs::home_dir() {
            ///$HOME/dev/sui/SuiLipse
            Some(v) => v.join("dev").join("sui").join("SuiLipse").join(path),
            None => panic!("Cannot obtain home directory path"),
        }
    }

    fn get_signer(&self, idx: usize) -> SuiAddress {
        self.keystore.addresses()[idx]
    }

    async fn update_svg(&self, nft: ObjectID, content: String) -> Result<(), anyhow::Error> {
        let signer = self.keystore.addresses()[1];

        self.client
            .wallet_sync_api()
            .sync_account_state(signer)
            .await?;

        //get the state
        let nft_obj = self
            .client
            .read_api()
            .get_object(nft)
            .await?
            .into_object()?;

        let coin_state: NFTState = nft_obj.data.try_as_move().unwrap().deserialize()?;

        println!("treasuy_cap_state:{:?}", &coin_state);

        let coin_reference = nft_obj.reference.to_object_ref();
        let nft_obj: Object = nft_obj.try_into()?;

        //create tx

        //generic type -- the most desireable way to retrieve the MOVE_TYPE

        let update_call = self
            .client
            .transaction_builder()
            .move_call(
                signer,
                self.pool_package_id,
                "nft",
                "update_svg",
                vec![],
                vec![
                    SuiJsonValue::from_str(&nft.to_string())?,
                    SuiJsonValue::from_str(content.as_str())?,
                ],
                None,
                10000,
            )
            .await?;

        let signer = self.keystore.signer(signer);

        let signature = Signature::new(&update_call, &signer);

        let response = self
            .client
            .quorum_driver()
            .execute_transaction(Transaction::new(update_call, signature))
            .await?;

        let coin_id = response
            .effects
            .created
            .first() //first created object in this tx
            .expect("decode created coin")
            .reference
            .object_id;

        Ok(())
    }
}

// Clap command line args parser
#[derive(Parser, Debug)]
#[clap(
    name = "suilipse-client",
    about = "calling scripts of modules package `sui_lipse` at address 0xb6be10d536c4ea538a58d52dca2d669f8d38f528",
    rename_all = "kebab-case"
)]

struct AmmClientOpts {
    //TODO: without input coin package "0x2"
    #[clap(long)]
    suilipse_packagae_id: Option<ObjectID>,
    #[clap(long)]
    keystore_path: Option<PathBuf>,
    #[clap(long, default_value = "https://gateway.devnet.sui.io:443")]
    rpc_server_url: String,
    #[clap(subcommand)]
    subcommand: AmmCommand,
}

#[derive(Subcommand, Debug)]
#[clap(rename_all = "kebab-case")]
enum AmmCommand {
    /// Change card's info
    ChangeCard {
        #[clap(long)]
        card: ObjectID,
        #[clap(long)]
        name: Option<String>,
        #[clap(long)]
        symbol: Option<String>,
    },
}
