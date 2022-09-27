#![allow(unused)]

use serde::Deserialize;
use std::str::FromStr;
use sui_sdk::{
    crypto::{KeystoreType, SuiKeystore},
    json::SuiJsonValue,
    rpc_types::SuiData,
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

struct Faucet {
    treasury_cap_id: ObjectID,
    coin_id: ObjectID,
    client: SuiClient,
    keystore: SuiKeystore,
}

//mirror object from move language
#[derive(Deserialize, Debug)]
struct TreasuryCapState {
    uid: UID,
    total_supply: u8,
}

impl Faucet {
    async fn get_treasury_cap_state(
        &self,
        treasury_cap: ObjectID,
    ) -> Result<TreasuryCapState, anyhow::Error> {
        let treasury_cap = self.client.read_api().get_object(treasury_cap).await?;
        treasury_cap
            .object()?
            .data
            .try_as_move()
            .unwrap()
            .deserialize()
    }

    async fn mint_and_transfer(
        &self,
        sender: Option<SuiAddress>,
        recipient: Option<SuiAddress>,
        treasury_cap: ObjectID,
    ) -> Result<(), anyhow::Error> {
        //retrieve the msg.sender in the keystore if not provided
        let sender = sender.unwrap_or_else(|| self.keystore.addresses()[0]);
        let recipient = recipient.unwrap_or_else(|| self.keystore.addresses()[0]);

        let treasury_cap_state = self.get_treasury_cap_state(treasury_cap).await?;
        // Force a sync of signer's state in gateway.
        self.client
            .wallet_sync_api()
            .sync_account_state(sender)
            .await?;

        //create tx
        let amount = 1000;
        let mint_and_transfer_call = self
            .client
            .transaction_builder()
            .move_call(
                sender,
                self.treasury_cap_id,
                "sui",
                "mint_and_transfer",
                vec![], //when should put type args
                vec![
                    SuiJsonValue::from_str(&treasury_cap_state.uid.object_id().to_hex_literal())?,
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
