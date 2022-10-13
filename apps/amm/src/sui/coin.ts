import { SignerWithProvider, Provider, Ed25519Keypair, RawSigner, JsonRpcProvider } from '@mysten/sui.js'
import { chosenGateway, connection } from "./gateway"
import { Buffer } from 'buffer'

const TEST_SECRT = "AFYFTnEn3L4LrgZpEfklixXKFuRam5p418WNz6hlnhL+5jihhTKTZcT8drv1InWwCnt/0Id/y7zNZ/IH4OxwsBo=="
const SUI_TEST = "mdqVWeFekT7pqy5T49+tV12jO0m+ESW7ki4zSU9JiCgbL0kJbj5dvQ/PqcDAzZLZqzshVEs01d1KZdmLh4uZIg=="

export const createToken = async () => {
    try {
        const rpc = connection.get(chosenGateway.value)
        const secretKey = Buffer.from(TEST_SECRT, 'base64');
        const keypair = Ed25519Keypair.fromSecretKey(secretKey);




        console.log(secretKey);
        // const signer = new RawSigner(
        //     keypair,
        //     new JsonRpcProvider('https://gateway.devnet.sui.io:443')
        // );


    } catch (error) {
        console.error(error)
    }
}