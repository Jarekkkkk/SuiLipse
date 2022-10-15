
import { SuiObjectInfo, getMoveObjectType, getObjectOwner, ObjectOwner, Coin as CoinAPI, SUI_TYPE_ARG, COIN_TYPE, SuiMoveObject, getObjectExistsResponse, getMoveObject } from '@mysten/sui.js';
import { BaseTransition } from 'vue';
import { connection, chosenGateway } from "./gateway";
import { Coin } from '../sui/coin'

const EXAMPLE_OBJECT: SuiObjectInfo = {
    objectId: '8dc6a6f70564e29a01c7293a9c03818fda2d049f',
    version: 0,
    digest: 'CI8Sf+t3Xrt5h9ENlmyR8bbMVfg6df3vSDc08Gbk9/g=',
    owner: {
        AddressOwner: '0x215592226abfec8d03fbbeb8b30eb0d2129c94b0',
    },
    type: 'moveObject',
    previousTransaction: '4RJfkN9SgLYdb0LqxBHh6lfRPicQ8FLJgzi9w2COcTo=',
};

export function getOwnerStr(owner: ObjectOwner | string): string {
    if (typeof owner === 'object') {
        if ('AddressOwner' in owner) return owner.AddressOwner;
        if ('ObjectOwner' in owner) return owner.ObjectOwner;
        if ('SingleOwner' in owner) return owner.SingleOwner;
    }
    return owner;
}



export const get_coin_obj = async (id: string) => {
    try {
        const rpc = connection.get(chosenGateway.value);
        let res = await rpc?.getObject(id);
        if (!res) {
            throw new Error("unable to receive response of getObject")
        }

        let move_obj = getMoveObject(res);
        let owner = getObjectOwner(res);

        if (move_obj && owner) {
            let res = Coin.getCoinCapTypeArg(move_obj)
            return { id, type: res ? res[1] : null, owner: getOwnerStr(owner) }
        } else {
            throw new Error("")
        }
    } catch (error) {
        console.error(error)
    }
}



