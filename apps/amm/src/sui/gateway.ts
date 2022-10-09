import { SuiObjectInfo, JsonRpcProvider } from '@mysten/sui.js'


export enum Gateway {
  devent = "Devent",
  local = "Local"
}

//as the record type, key values should be primary JS such as string, number

export const GATEWAYS: Record<Gateway, string> = {
  [Gateway.local]: "http://127.0.0.1:8080",
  [Gateway.devent]: "https://fullnode.devnet.sui.io:443",
};

// default to testnet
export function getGateway(network: Gateway | string) {
  if (Object.keys(GATEWAYS).includes(network)) {
    return GATEWAYS[network as Gateway];
  }

  return GATEWAYS[Gateway.devent]
}

const mapGatewayToRpc: Map<Gateway | string, JsonRpcProvider> = new Map()


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