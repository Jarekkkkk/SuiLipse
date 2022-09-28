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
        messages::Transaction,
        object::Object,
    },
    SuiClient,
};

//TODO: add env file

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    let opts: CoinClientOpts = CoinClientOpts::parse();
    let keystore_path = opts
        .keystore_path
        .clone() // this shoule be optimized
        .unwrap_or_else(default_keystore_path);

    let coin_client = CoinClient::new(&opts, keystore_path).await?;

    match opts.subcommand {
        CoinCommand::MintAndTransfer {
            capability,
            recipient,
            amount,
        } => {
            println!("command: {:?}\n", opts);
            println!("sender: {:?}\n", &coin_client.keystore.addresses()[0]);
            println!(
                "capability_object_id:{:?}, \nrecipient:{:?}, \namount:{}",
                capability,
                recipient.unwrap(),
                amount
            );

            coin_client
                .mint_and_transfer(capability, recipient, amount)
                .await?;
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
struct TreasuryCapState {
    uid: UID,
    total_supply: u64,
}

impl CoinClient {
    //build the CoinClient based on given cli command
    async fn new(opts: &CoinClientOpts, keystore_path: PathBuf) -> Result<Self, anyhow::Error> {
        let keystore = KeystoreType::File(keystore_path).init()?;
        let coin_client = CoinClient {
            coin_package_id: opts.coin_package_id,
            client: SuiClient::new_rpc_client(&opts.rpc_server_url, None).await?,
            keystore,
        };

        Ok(coin_client)
    }

    // async fn get_treasury_cap_state(
    //     &self,
    //     treasury_cap: ObjectID,
    // ) -> Result<(Object, SuiObjectRef), anyhow::Error> {
    //     let treasury_cap = self
    //         .client
    //         .read_api()
    //         .get_object(treasury_cap)
    //         .await?
    //         .into_object()?;

    //     let state: TreasuryCapState = treasury_cap.data.try_as_move().unwrap().deserialize()?;

    //     println!("treasuy_cap_state:{:?}", &state);

    //     let treasury_cap_reference = treasury_cap.reference.to_object_ref();
    //     let treasury_cap: Object = treasury_cap.try_into()?;

    //     //println!("cap {:?}\n", treasury_cap);

    //     Ok((treasury_cap, treasury_cap_reference))
    // }

    async fn mint_and_transfer(
        &self,
        treasury_cap: ObjectID,
        recipient: Option<SuiAddress>,
        amount: u64,
    ) -> Result<(), anyhow::Error> {
        //retrieve the msg.sender in the keystore if not provided
        let sender = self.keystore.addresses()[0];
        let recipient = recipient.unwrap_or_else(|| self.keystore.addresses()[0]);

        //get the state
        //let treasury_cap_state = self.get_treasury_cap_state(treasury_cap).await?;

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

        // Force a sync of signer's state in gateway.
        self.client
            .wallet_sync_api()
            .sync_account_state(sender)
            .await?;

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
                type_args, //"0x2::coin::TreasuryCap<0xca269a2deb69fed64a2729eb574d558b9394446::jrk::JRK>"
                vec![
                    SuiJsonValue::from_str(&treasury_cap_state.uid.object_id().to_hex_literal())?, //0x2::balance::Supply<0xca269a2deb69fed64a2729eb574d558b9394446::jrk::JRK>
                    SuiJsonValue::from_str(&amount.to_string())?, //amount
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
    async fn burn() {}
}

// Clap command line args parser
#[derive(Parser, Debug)]
#[clap(
    name = "coin-client",
    about = "calling `coin` modules of package `sui` at address 0x2",
    rename_all = "kebab-case"
)]
struct CoinClientOpts {
    #[clap(long)]
    coin_package_id: ObjectID,
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
    /// Mint and Transfer Coin, make sure sender get the Capability
    MintAndTransfer {
        #[clap(long)]
        capability: ObjectID,
        #[clap(long)]
        recipient: Option<SuiAddress>,
        #[clap(long)]
        amount: u64,
    },
}
