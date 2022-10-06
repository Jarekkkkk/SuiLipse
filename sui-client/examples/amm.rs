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
    rpc_types::{SuiData, SuiObject, SuiObjectRef, SuiRawData, SuiTypeTag},
    types::parse_sui_type_tag,
    types::{
        base_types::{ObjectID, SuiAddress},
        crypto::Signature,
        error::SuiError,
        id::UID,
        messages::{SingleTransactionKind, Transaction},
        object::Object,
    },
    SuiClient,
};

use async_trait::async_trait;
use dotenv::dotenv;
use sui_lipse::{
    default_keystore_path,
    state::{CapabilityState, CoinState, NFTState, Pool},
};

const SUI_AMT: u64 = 10_000_000;
const JRK_AMT: u64 = 100_000_000; // SUI/JRK = 10

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    dotenv().ok();
    let opts: AmmClientOpts = AmmClientOpts::parse();

    let keystore_path = opts
        .keystore_path
        .clone() // clone should be omit
        .unwrap_or_else(default_keystore_path);

    let suilipse_pkg = opts
        .suilipse_packagae_id
        .clone()
        .unwrap_or(ObjectID::from_hex_literal(
            &std::env::var("AMM_PACKAGE").expect("should get Jarek::AMM"),
        )?);

    let amm_client = AmmClient::new(&opts, suilipse_pkg, keystore_path).await?;

    println!("signer\n: {:?}\n", &amm_client.get_signer(0));

    //deseriazlie
    match opts.subcommand {
        AmmCommand::CreatePool {
            capability,
            token_x,
            token_y,
            fee,
            name,
            symbol,
        } => {
            amm_client
                .create_pool(capability, token_x, token_y, fee, name, symbol)
                .await?;
        }
        AmmCommand::AddLiquidity { pool } => {
            print!("add liquidity")
        }
        AmmCommand::RemoveLiquidity { pool } => {
            print!("add liquidity")
        }
        AmmCommand::SwapX { pool } => {
            print!("swap x ")
        }
        AmmCommand::SwapY { pool } => {
            print!("swap y")
        }
    }
    Ok(())
}

struct AmmClient {
    pool_package_id: ObjectID,
    client: SuiClient,
    keystore: SuiKeystore,
}

//TODO: add client trait
#[async_trait]
pub trait Client {
    fn get_object<T>(&self) -> Result<T, anyhow::Error> {
        todo!()
    }
}

//mirror scripts for calling on-chain smart contract
#[async_trait]
trait PoolScript: Sized {
    async fn create_pool() -> Result<(), anyhow::Error>;
    async fn add_liquidity() -> Result<(), anyhow::Error>;
    async fn remove_liquidity() -> Result<(), anyhow::Error>;
    async fn swap_token_x() -> Result<(), anyhow::Error>;
    async fn swap_token_y() -> Result<(), anyhow::Error>;
}

impl AmmClient {
    async fn new(
        opts: &AmmClientOpts,
        pool_package_id: ObjectID,
        keystore_path: PathBuf,
    ) -> Result<Self, anyhow::Error> {
        let keystore = KeystoreType::File(keystore_path).init()?;
        let amm_client = Self {
            pool_package_id,
            client: SuiClient::new_rpc_client(&opts.rpc_server_url, None).await?,
            keystore,
        };

        Ok(amm_client)
    }

    pub fn load_file(path: &str) -> PathBuf {
        match dirs::home_dir() {
            ///$HOME/dev/sui/SuiLipse
            Some(v) => v.join("dev").join("sui").join("SuiLipse").join(path),
            None => panic!("Cannot obtain home directory path"),
        }
    }

    fn get_signer(&self, idx: usize) -> SuiAddress {
        self.keystore.addresses()[idx]
    }

    async fn create_pool(
        &self,
        capability: ObjectID,
        token_x: ObjectID,
        token_y: ObjectID,
        fee_percentage: u64,
        name: String,
        symbol: String,
    ) -> Result<(), anyhow::Error> {
        let signer = self.get_signer(0); // without public to block out high-level control

        self.client
            .wallet_sync_api()
            .sync_account_state(signer)
            .await?;

        //get the state
        let capability_obj = self
            .client
            .read_api()
            .get_object(capability)
            .await?
            .into_object()?;
        let token_x_obj = self
            .client
            .read_api()
            .get_object(token_x)
            .await?
            .into_object()?;
        let token_y_obj = self
            .client
            .read_api()
            .get_object(token_y)
            .await?
            .into_object()?;

        let capability_state: CapabilityState =
            capability_obj.data.try_as_move().unwrap().deserialize()?;
        let token_x_state: CoinState = token_x_obj.data.try_as_move().unwrap().deserialize()?;
        let token_y_state: CoinState = token_y_obj.data.try_as_move().unwrap().deserialize()?;

        println!("\ncap_x_state:{:?}", &capability_state);
        println!("\ncoin_x_state:{:?}", &token_x_state);
        println!("\ncoin_y_state:{:?}", &token_y_state);

        let cap_reference = capability_obj.reference.to_object_ref();
        let cap_obj: Object = capability_obj.try_into()?;
        let token_x_reference = token_x_obj.reference.to_object_ref();
        let token_x_obj: Object = token_x_obj.try_into()?;
        let token_y_reference = token_y_obj.reference.to_object_ref();
        let token_y_obj: Object = token_y_obj.try_into()?;

        //create tx
        let foo = cap_obj.data.type_().unwrap();
        println!("foo{:?}", foo);
        let type_args = vec![
            //SuiTypeTag::from(TypeTag::(foo)),
            SuiTypeTag::from(token_x_obj.get_move_template_type()?),
            SuiTypeTag::from(token_y_obj.get_move_template_type()?),
        ];
        println!("signer {}", &signer);
        let create_pool_call = self
            .client
            .transaction_builder()
            .move_call(
                signer,
                self.pool_package_id,
                "amm_script", //while this is amm_client, for simplicity consideration, we directly called function in nft module
                "create_pool",
                type_args,
                vec![
                    SuiJsonValue::from_str(&cap_reference.0.to_string())?,
                    SuiJsonValue::from_str(&token_x_reference.0.to_string())?,
                    SuiJsonValue::from_str(&token_y_reference.0.to_string())?,
                    SuiJsonValue::from_str(&fee_percentage.to_string())?,
                    SuiJsonValue::from_str(&name)?,
                    SuiJsonValue::from_str(&symbol)?,
                ],
                None,
                10000,
            )
            .await?;

        let signer = self.keystore.signer(signer);

        let signature = Signature::new(&create_pool_call, &signer);

        let response = self
            .client
            .quorum_driver()
            .execute_transaction(Transaction::new(create_pool_call, signature))
            .await?;

        let mutated_obj = response.effects.mutated.iter();

        for (idx, mut_obj) in mutated_obj.enumerate() {
            println!("\n idx: {} - {:?}", idx, mut_obj.reference);
        }
        Ok(())
    }
    async fn add_liquidity(
        &self,
        pool: ObjectID,
        token_x: ObjectID,
        token_y: ObjectID,
    ) -> Result<(), anyhow::Error> {
        Ok(())
    }
    async fn remove_liquidity(
        &self,
        pool: ObjectID,
        token_x: ObjectID,
        token_y: ObjectID,
    ) -> Result<(), anyhow::Error> {
        Ok(())
    }
    async fn swap_x(&self, pool: ObjectID, token_x: ObjectID) -> Result<(), anyhow::Error> {
        Ok(())
    }
    async fn swap_y(&self, pool: ObjectID, token_y: ObjectID) -> Result<(), anyhow::Error> {
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
    /// Create Pool object by module publisher
    CreatePool {
        #[clap(long)]
        capability: ObjectID,
        #[clap(long)]
        token_x: ObjectID,
        #[clap(long)]
        token_y: ObjectID,
        #[clap(long)]
        fee: u64,
        #[clap(long)]
        name: String,
        #[clap(long)]
        symbol: String,
    },
    /// Add liquidity by givend pool
    AddLiquidity {
        #[clap(long)]
        pool: ObjectID,
    },
    /// Remove liquidity by givend pool
    RemoveLiquidity {
        #[clap(long)]
        pool: ObjectID,
    },
    /// Swap token X in given pool
    SwapX {
        #[clap(long)]
        pool: ObjectID,
    },
    /// Swap token Y in given pool
    SwapY {
        #[clap(long)]
        pool: ObjectID,
    },
}
