import { ObjectOwner } from '@mysten/sui.js';
export function getOwnerStr(owner: ObjectOwner | string): string {
    if (typeof owner === 'object') {
        if ('AddressOwner' in owner) return owner.AddressOwner;
        if ('ObjectOwner' in owner) return owner.ObjectOwner;
        if ('SingleOwner' in owner) return owner.SingleOwner;
    }
    return owner;
}

