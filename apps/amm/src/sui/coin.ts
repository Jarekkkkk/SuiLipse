import { Ed25519Keypair, RawSigner, Base64DataBuffer, SuiJsonValue, getExecutionStatusType } from '@mysten/sui.js'
import { chosenGateway, connection } from "./gateway"

//take the place of Buffer
import { Buffer as BufferPolyfill } from 'buffer'
import { get_obj } from './object';
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
        let res = await get_obj(cap);

        if (!res || !res.type) {
            throw new Error("create token error")
        }

        let rpc = connection.get(chosenGateway.value)
        //create tx

        //signer.executeMoveCallWithRequestType

        //signer: 0x94c21e07df735da5a390cb0aad0b4b1490b0d4f0
        //cap: 0xffaab2206faa05c078c2b1e1f554bf33c2b28799

        //have to use local::functions
        const moveCallTxn = await signer.executeMoveCallWithRequestType({
            packageObjectId: SUI_FRAMEWORK,
            module: 'coin',
            function: 'mint_and_transfer',
            typeArguments: [res.type],
            arguments: [
                cap, amount, recipient,
            ],
            gasBudget: 1000,
            gasPayment: "0x0461a2ee33fe2a26a1e6fc3817b06661bb7ad20b",
        });
        console.log('moveCallTxn', moveCallTxn);

        let created_coin = getExecutionStatusType(moveCallTxn)

        console.log(created_coin);

    } catch (error) {
        console.error(error);
    }
}


const sign_tx = () => {
    const keypair = new Ed25519Keypair();
    const signData = new Base64DataBuffer(
        new TextEncoder().encode('hello world')
    );
    const signature = keypair.signData(signData);

}

