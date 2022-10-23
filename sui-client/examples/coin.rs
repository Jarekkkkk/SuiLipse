#![allow(unused)]

use async_trait::async_trait;
use clap::{Parser, Subcommand};
use serde::Deserialize;
use std::{convert::TryInto, path::PathBuf, str::FromStr};
use sui_lipse::{
    default_keystore_path,
    state::{CoinState, TreasuryCapState},
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

use dotenv::dotenv;

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    dotenv().ok();
    let opts: CoinClientOpts = CoinClientOpts::parse();

    let keystore_path = opts
        .keystore_path
        .clone() // clone should be omit
        .unwrap_or_else(default_keystore_path);

    let pkg_id = &std::env::var("SUI").expect("should get Jarek::AMM");
    let coin_pkg = opts
        .coin_package_id
        .clone()
        .unwrap_or(ObjectID::from_hex_literal(pkg_id).unwrap());

    let coin_client = CoinClient::new(&opts, coin_pkg, keystore_path).await?;
    let signers = coin_client.keystore.addresses();
    for i in 0..signers.len() {
        println!("\nsigners- {} - {:?}", i, coin_client.get_signer(i));
    }

    match opts.subcommand {
        CoinCommand::MintAndTransfer {
            capability,
            recipient,
            amount,
        } => {
            println!(
                "coin_id:{:?}, \nrecipient:{:?}, \namount:{}",
                capability,
                recipient.unwrap(),
                amount
            );
            coin_client
                .mint_and_transfer(capability, recipient, amount)
                .await?;
        }
        CoinCommand::Transfer { coin, recipient } => {
            println!("\nopts\n: {:?}\n", opts);
            println!("client\n: {:?}\n", coin_client.coin_package_id);
            println!("coin_id:{:?}, \nrecipient:{:?}", coin, recipient.unwrap(),);

            coin_client.transfer(coin, recipient).await?;
        }
        CoinCommand::Join { coin_a, coin_b } => {
            println!("coin_a:{:?}", coin_a);
            println!("coin_b:{:?}", coin_b);
            coin_client.join(coin_a, coin_b).await?;
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

/// on-chain scripts for any `ERC20 fungible token`
#[async_trait]
trait CoinScript: Sized {
    async fn new(
        opts: &CoinClientOpts,
        coin_pkg: ObjectID,
        keystore_path: PathBuf,
    ) -> Result<Self, anyhow::Error>;
    fn get_signer(&self, idx: usize) -> SuiAddress;
    async fn mint_and_transfer(
        &self,
        treasury_cap: ObjectID,
        recipient: Option<SuiAddress>,
        amount: u64,
    ) -> Result<(), anyhow::Error>;
    async fn transfer(
        &self,
        object_id: ObjectID,
        recipient: Option<SuiAddress>,
    ) -> Result<(), anyhow::Error>;
    async fn join(&self, coin_a: ObjectID, coin_b: ObjectID) -> Result<(), anyhow::Error>;
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
    fn get_signer(&self, idx: usize) -> SuiAddress {
        self.keystore.addresses()[idx]
    }
    async fn mint_and_transfer(
        &self,
        treasury_cap: ObjectID,
        recipient: Option<SuiAddress>,
        amount: u64,
    ) -> Result<(), anyhow::Error> {
        //retrieve the msg.sender in the keystore if not provided
        let sender = self.get_signer(0);
        let recipient = recipient.unwrap_or(sender);

        //get the state
        let treasury_cap_obj = self
            .client
            .read_api()
            .get_object(treasury_cap)
            .await?
            .into_object()
            .unwrap();
        let treasury_cap_reference = treasury_cap_obj.reference.to_object_ref();
        let treasury_cap_state: TreasuryCapState =
            treasury_cap_obj.data.try_as_move().unwrap().deserialize()?;
        println!("treasuy_cap_state:{:?}", &treasury_cap_state);

        let treasury_cap_obj: Object = treasury_cap_obj.try_into()?;

        //Force a sync of signer's state in gateway.
        self.client
            .wallet_sync_api()
            .sync_account_state(sender)
            .await?;

        //create tx

        //generic type -- the most desireable way to retrieve the MOVE_TYPE
        let treasury_cap_type = treasury_cap_obj.get_move_template_type().unwrap();
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
                    SuiJsonValue::from_str(&treasury_cap_reference.0.to_string())?,
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
            .expect("decode created coin")
            .reference
            .object_id;

        println!("Minted `{}` JRK Coin, object id {:?}", amount, coin_id);

        Ok(())
    }
    async fn transfer(
        &self,
        coin: ObjectID,
        recipient: Option<SuiAddress>,
    ) -> Result<(), anyhow::Error> {
        let signer = self.keystore.addresses()[1];
        let recipient = recipient.unwrap_or(signer);

        self.client
            .wallet_sync_api()
            .sync_account_state(signer)
            .await?;

        //get the state
        let coin_obj = self
            .client
            .read_api()
            .get_object(coin)
            .await?
            .into_object()
            .unwrap();

        let coin_state: CoinState = coin_obj.data.try_as_move().unwrap().deserialize()?;

        println!("treasuy_cap_state:{:?}", &coin_state);

        let coin_reference = coin_obj.reference.to_object_ref();
        let coin_obj: Object = coin_obj.try_into().unwrap();

        //create tx

        // get the inner type of type
        let coin_type = coin_obj.get_move_template_type().unwrap();
        let type_args = vec![SuiTypeTag::from(coin_type)];

        let transfer_call = self
            .client
            .transaction_builder()
            .transfer_object(signer, coin_state.uid_into(), None, 1000, recipient)
            .await?;

        let signer = self.keystore.signer(signer);

        let signature = Signature::new(&transfer_call, &signer);

        let response = self
            .client
            .quorum_driver()
            .execute_transaction(Transaction::new(transfer_call, signature))
            .await?;

        let coin_id = response
            .effects
            .created
            .first() //first created object in this tx
            .expect("decode created coin")
            .reference
            .object_id;

        println!("tranfer obj_id `{}` to {:?}", coin_id, recipient);

        Ok(())
    }
    async fn join(&self, coin_a: ObjectID, coin_b: ObjectID) -> Result<(), anyhow::Error> {
        let signer = self.keystore.addresses()[0];

        let api = self.client.read_api();

        let join_call = self
            .client
            .transaction_builder()
            .merge_coins(signer, coin_a, coin_b, None, 1000)
            .await?;

        let signer = self.keystore.signer(signer);

        let signature = Signature::new(&join_call, &signer);
        let response = self
            .client
            .quorum_driver()
            .execute_transaction(Transaction::new(join_call, signature))
            .await?;
        let status = response.effects.status;
        if status.is_err() {
            eprintln!("\nErr: {:?}", status)
        }

        let coin_id = response
            .effects
            .mutated
            .first()
            .expect("decoded mut obj")
            .reference
            .object_id;

        println!("merged coin `{}`", coin_id,);

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
    #[clap(long, default_value = "https://fullnode.devnet.sui.io:443")]
    rpc_server_url: String,
    #[clap(subcommand)]
    subcommand: CoinCommand,
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
    },
    /// Merge coin_b to coin_a
    Join {
        #[clap(long)]
        coin_a: ObjectID,
        #[clap(long)]
        coin_b: ObjectID,
    },
}
//TODO: add clear printed format for cli response
