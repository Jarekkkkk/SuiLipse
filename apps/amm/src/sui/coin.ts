import { SignerWithProvider, Provider, Ed25519Keypair, RawSigner, JsonRpcProvider, Base64DataBuffer, getMoveObjectType } from '@mysten/sui.js'
import { chosenGateway, connection } from "./gateway"

//take the place of Buffer
import { Buffer as BufferPolyfill } from 'buffer'
import { get_obj } from './object';
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

        if (!res) {
            throw new Error("create token error")
        }

        let rpc = connection.get(chosenGateway.value)
        //create tx


        //depreciated
        const moveCallTxn = await signer.executeMoveCall({
            packageObjectId: SUI_FRAMEWORK,
            module: 'coin',
            function: 'mint_and_transfer',
            typeArguments: [res.type],
            arguments: [
                cap, amount, recipient,
            ],
            gasBudget: 10000,
        });
        console.log('moveCallTxn', moveCallTxn);

        let created_coin = moveCallTxn.effects.created?.at(1)?.reference.objectId

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


const get_account_from_seed = async () => {

}

