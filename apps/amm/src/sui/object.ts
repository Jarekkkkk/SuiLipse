
import { SuiObjectInfo, getMoveObjectType, getObjectOwner, ObjectOwner, getObjectType } from '@mysten/sui.js';
import { connection, chosenGateway } from "./gateway";

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


//return (type, digest, inner value)
export const get_obj = async (id: string) => {
    try {
        const rpc = connection.get(chosenGateway.value);
        let res = await rpc?.getObject(id);
        if (!res) {
            throw new Error("unable to receive response of getObject")
        }
        let type = getMoveObjectType(res)
        let owner = getObjectOwner(res);

        if (type && owner) {
            return { id, type: type.slice(23, -1), owner: getOwnerStr(owner) }
        } else {
            throw new Error("")
        }
    } catch (error) {
        console.error(error)
    }
}





