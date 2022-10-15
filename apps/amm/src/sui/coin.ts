import { Ed25519Keypair, RawSigner, Base64DataBuffer, SuiJsonValue, getExecutionStatusType, getMoveObject } from '@mysten/sui.js'
import { chosenGateway, connection } from "./gateway"

//take the place of Buffer
import { Buffer as BufferPolyfill } from 'buffer'
import { get_coin_obj, Coin } from './object';
import { toNamespacedPath } from 'path';
declare var Buffer: typeof BufferPolyfill;
globalThis.Buffer = BufferPolyfill

const SUI_FRAMEWORK = "0x2"
const TEST_MNEMONIC = "sorry neither pioneer despair talk taxi eager library lawsuit surround cycle off";

const get_account_from_mnemonic = () => {
    let keypair = Ed25519Keypair.deriveKeypair(TEST_MNEMONIC);
    const signer = new RawSigner(
        keypair,
        connection.get(chosenGateway.value)
    );
    return signer
}

export const createToken_ = async (cap: string, amount: number, recipient: string) => {
    try {
        //required params
        let signer = get_account_from_mnemonic()

        let rpc = connection.get(chosenGateway.value)
        if (!rpc) {
            throw new Error("fail to get rpc")
        }
        let res = await rpc.getObject(cap);
        let move_obj = getMoveObject(res);
        if (!move_obj) {
            throw new Error("fail to get move obj")
        }

        //create tx

        let coin_type = Coin.getCoinCapTypeArg(move_obj)

        //signer.executeMoveCallWithRequestType

        //signer: 0x94c21e07df735da5a390cb0aad0b4b1490b0d4f0
        //cap: 0xffaab2206faa05c078c2b1e1f554bf33c2b28799

        const gas_payments = await rpc.getGasObjectsOwnedByAddress(
            await signer.getAddress()
        );

        //have to use local::functions
        const moveCallTxn = await signer.executeMoveCallWithRequestType({
            packageObjectId: SUI_FRAMEWORK,
            module: 'coin',
            function: 'mint_and_transfer',
            typeArguments: [coin_type ?? ""],
            arguments: [
                cap, amount, recipient,
            ],
            gasBudget: 1000,
            gasPayment: gas_payments[0].objectId,
        });
        console.log('moveCallTxn', moveCallTxn);

        let created_coin = getExecutionStatusType(moveCallTxn)

        console.log(created_coin);

    } catch (error) {
        console.error(error);
    }
}

// Pending: amount should become argument
export const transfer_coin_ = async (coin: string, recipient: string) => {
    try {
        let signer = get_account_from_mnemonic()
        let rpc = connection.get(chosenGateway.value)
        if (!rpc) {
            throw new Error("fail to get rpc")
        }

        const gas_payments = await rpc.getGasObjectsOwnedByAddress(
            await signer.getAddress()
        );

        let res = await rpc.getObject(coin);
        let coin_type = Coin.getCoinTypeArg(res)
        const moveCallTxn = await signer.transferObjectWithRequestType({
            objectId: coin,
            gasBudget: 1000,
            recipient,
            gasPayment: gas_payments[0].objectId,
        });


        let created_coin = getExecutionStatusType(moveCallTxn)

        console.log(created_coin);
    } catch (error) {
        console.error(error)
    }
}
const join_ = async (coin_a: string, coin_b: string) => {
    try {
        let signer = get_account_from_mnemonic()
        let rpc = connection.get(chosenGateway.value)
        if (!rpc) {
            throw new Error("fail to get rpc")
        }

        const gas_payments = await rpc.getGasObjectsOwnedByAddress(
            await signer.getAddress()
        );
        let res_a = await rpc.getObject(coin_a);
        let coin_a_type = Coin.getCoinTypeArg(res_a)

        const merge_coin_tx = await signer.mergeCoinWithRequestType({
            primaryCoin: coin_a,
            coinToMerge: coin_b,
            gasBudget: 1000,
            gasPayment: gas_payments[0].objectId,
        });


        let status = getExecutionStatusType(merge_coin_tx)

        console.log(status);
    } catch (error) {
        console.error(error)
    }
}

const sign_tx = () => {
    const keypair = new Ed25519Keypair();
    const signData = new Base64DataBuffer(
        new TextEncoder().encode('hello world')
    );
    const signature = keypair.signData(signData);

}

