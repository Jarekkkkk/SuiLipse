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

//TODO: add env file

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    let opts: CoinClientOpts = CoinClientOpts::parse();
    let keystore_path = opts
        .keystore_path
        .clone() // clone should be omit
        .unwrap_or_else(default_keystore_path);

    let coin_pkg = opts
        .coin_package_id
        .clone()
        .unwrap_or(ObjectID::from_hex_literal("0x2")?);

    let coin_client = CoinClient::new(&opts, coin_pkg, keystore_path).await?;

    match opts.subcommand {
        CoinCommand::MintAndTransfer {
            capability,
            recipient,
            amount,
        } => {
            coin_client
                .mint_and_transfer(capability, recipient, amount)
                .await?;
        }
        CoinCommand::Transfer {
            coin,
            recipient,
            amount,
        } => {
            println!("\nopts\n: {:?}\n", opts);
            println!("client\n: {:?}\n", coin_client.coin_package_id);
            println!("sender\n: {:?}\n", &coin_client.keystore.addresses()[0]);
            println!(
                "coin_id:{:?}, \nrecipient:{:?}, \namount:{}",
                coin,
                recipient.unwrap(),
                amount
            );
        }
    }

    Ok(())
}

struct CoinClient {
    coin_package_id: ObjectID,
    //coin_id: ObjectID,
    client: SuiClient,
    keystore: SuiKeystore,
}

//mirror object from move language
#[derive(Deserialize, Debug)]
struct CoinState {
    uid: UID,
    balance: u64,
}
#[derive(Deserialize, Debug)]
struct TreasuryCapState {
    uid: UID,
    total_supply: u64,
}

/// on-chain scripts for any `ERC20 fungible token`
#[async_trait]
trait CoinScript: Sized {
    async fn new(
        opts: &CoinClientOpts,
        coin_pkg: ObjectID,
        keystore_path: PathBuf,
    ) -> Result<Self, anyhow::Error>;
    async fn mint_and_transfer(
        &self,
        treasury_cap: ObjectID,
        recipient: Option<SuiAddress>,
        amount: u64,
    ) -> Result<(), anyhow::Error>;
    async fn transfer(
        &self,
        object_id: ObjectID,
        recipient: SuiAddress,
    ) -> Result<(), anyhow::Error>;
    fn split_and_transfer(&self) {}
    fn burn() {}
    //retrieve the genreic type coin
    //fn get_move_type();
}

#[async_trait]
impl CoinScript for CoinClient {
    async fn new(
        opts: &CoinClientOpts,
        coin_pkg: ObjectID,
        keystore_path: PathBuf,
    ) -> Result<Self, anyhow::Error> {
        let keystore = KeystoreType::File(keystore_path).init()?;
        let coin_client = CoinClient {
            coin_package_id: coin_pkg,
            client: SuiClient::new_rpc_client(&opts.rpc_server_url, None).await?,
            keystore,
        };

        Ok(coin_client)
    }
    async fn mint_and_transfer(
        &self,
        treasury_cap: ObjectID,
        recipient: Option<SuiAddress>,
        amount: u64,
    ) -> Result<(), anyhow::Error> {
        //retrieve the msg.sender in the keystore if not provided
        let sender = self.keystore.addresses()[0];
        let recipient = recipient.unwrap_or_else(|| self.keystore.addresses()[0]);

        //Force a sync of signer's state in gateway.
        self.client
            .wallet_sync_api()
            .sync_account_state(sender)
            .await?;

        //get the state
        let treasury_cap_obj = self
            .client
            .read_api()
            .get_object(treasury_cap)
            .await?
            .into_object()?;

        let treasury_cap_state: TreasuryCapState =
            treasury_cap_obj.data.try_as_move().unwrap().deserialize()?;

        println!("treasuy_cap_state:{:?}", &treasury_cap_state);

        let treasury_cap_reference = treasury_cap_obj.reference.to_object_ref();
        let treasury_cap_obj: Object = treasury_cap_obj.try_into()?;

        //create tx

        //generic type -- the most desireable way to retrieve the MOVE_TYPE
        let treasury_cap_type = treasury_cap_obj.get_move_template_type()?;
        let type_args = vec![SuiTypeTag::from(treasury_cap_type)];

        let mint_and_transfer_call = self
            .client
            .transaction_builder()
            .move_call(
                sender,
                self.coin_package_id,
                "coin",
                "mint_and_transfer",
                type_args,
                vec![
                    SuiJsonValue::from_str(&amount.to_string())?,
                    SuiJsonValue::from_str(&recipient.to_string())?, //recipient
                ],
                None, // The gateway server will pick a gas object belong to the signer if not provided.
                1000,
            )
            .await?;

        // get signer
        let signer = self.keystore.signer(sender);

        // sign the tx
        let signature = Signature::new(&mint_and_transfer_call, &signer);

        //execute the tx
        let response = self
            .client
            .quorum_driver()
            .execute_transaction(Transaction::new(mint_and_transfer_call, signature))
            .await?;

        //render the response
        let coin_id = response
            .effects
            .created
            .first() //first created object in this tx
            .unwrap()
            .reference
            .object_id;

        println!("Minted `{}` JRK Coin, object id {:?}", amount, coin_id);

        Ok(())
    }
    async fn transfer(&self, coin: ObjectID, recipient: SuiAddress) -> Result<(), anyhow::Error> {
        let sender = self.keystore.addresses()[0];

        self.client
            .wallet_sync_api()
            .sync_account_state(sender)
            .await?;

        //get the state
        let coin_obj = self
            .client
            .read_api()
            .get_object(coin)
            .await?
            .into_object()?;

        let coin_state: CoinState = coin_obj.data.try_as_move().unwrap().deserialize()?;

        println!("treasuy_cap_state:{:?}", &coin_state);

        let coin_reference = coin_obj.reference.to_object_ref();
        let coin_obj: Object = coin_obj.try_into()?;

        //create tx

        //generic type -- the most desireable way to retrieve the MOVE_TYPE
        let coin_type = coin_obj.get_move_template_type()?;
        let type_args = vec![SuiTypeTag::from(coin_type)];

        Ok(())
    }
}

// Clap command line args parser
#[derive(Parser, Debug)]
#[clap(
    name = "coin-client",
    about = "calling `coin` modules of package `sui` at address 0x2",
    rename_all = "kebab-case"
)]
struct CoinClientOpts {
    //TODO: without input coin package "0x2"
    #[clap(long)]
    coin_package_id: Option<ObjectID>,
    #[clap(long)]
    keystore_path: Option<PathBuf>,
    #[clap(long, default_value = "https://gateway.devnet.sui.io:443")]
    rpc_server_url: String,
    #[clap(subcommand)]
    subcommand: CoinCommand,
}

fn default_keystore_path() -> PathBuf {
    match dirs::home_dir() {
        ///$HOME/dev/sui/SuiLipse
        Some(v) => v
            .join("dev")
            .join("sui")
            .join("SuiLipse")
            .join("sui.keystore"),
        None => panic!("Cannot obtain home directory path"),
    }
}

#[derive(Subcommand, Debug)]
#[clap(rename_all = "kebab-case")]
enum CoinCommand {
    /// Mint and Transfer Coin with signer holding Capability
    MintAndTransfer {
        #[clap(long)]
        capability: ObjectID,
        #[clap(long)]
        recipient: Option<SuiAddress>,
        #[clap(long)]
        amount: u64,
    },
    /// Transger Coin
    Transfer {
        //Questions: is that possible to insert dynamic sized vector input
        #[clap(long)]
        coin: ObjectID,
        #[clap(long)]
        recipient: Option<SuiAddress>,
        #[clap(long)]
        amount: u64,
    },
}
//TODO: add clear printed format for cli response
