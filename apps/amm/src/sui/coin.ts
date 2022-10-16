import { Coin as CoinAPI, SuiMoveObject, SuiObjectInfo } from '@mysten/sui.js'

export const EXAMPLE_COIN_OBJECT: SuiObjectInfo = {
    digest:
        "GoEFoIBS9MUIEnJS3V3BLt2zK1RKYfQBnazNvuloqp4=",
    objectId:
        "0x0461a2ee33fe2a26a1e6fc3817b06661bb7ad20b",
    owner:
        { AddressOwner: '0x94c21e07df735da5a390cb0aad0b4b1490b0d4f0' },
    previousTransaction:
        "JlEhizxCRdbpCIiz6TkBCjcbNa627x7gOZxCk4x+lNo=",
    type:
        "0x2::coin::Coin<0x2::sui::SUI>",
    version:
        3
};


// ref: https://github.com/MystenLabs/sui/blob/87e1314ef61fc39904a612bcf9d96481065f02bb/apps/wallet/src/ui/app/redux/slices/sui-objects/Coin.ts
export const COIN_TYPE = '0x2::coin::Coin';
export const COIN_TYPE_ARG_REGEX = /^0x2::coin::Coin<(.+)>$/;
export const COIN_CAP_TYPE_ARG_REGEX = /^0x2::coin::TreasuryCap<(.+)>$/;
export class Coin extends CoinAPI {
    public static getCoinCapTypeArg(obj: SuiMoveObject) {
        const res = obj.type.match(COIN_CAP_TYPE_ARG_REGEX);
        return res ? res[1] : null;
    }
}