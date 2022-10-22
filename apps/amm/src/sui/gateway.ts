import { ref } from "vue"
import { JsonRpcProvider } from "@mysten/sui.js";

// === TYPE ===
export enum Gateway {
  devent = "Devent",
  local = "Local"
}
//as the record type, key values should be primary JS such as string, number
export const GATEWAYS: Record<Gateway, string> = {
  [Gateway.local]: "http://127.0.0.1:8080",
  [Gateway.devent]: "https://fullnode.devnet.sui.io:443",
};
export function getGateway(network: Gateway | string): string {
  if (Object.keys(GATEWAYS).includes(network)) {
    return GATEWAYS[network as Gateway];
  }
  return network // customized RPC
}

// === Client ===
export const connection: Map<Gateway | string, JsonRpcProvider> = new Map()
const create_connection = (network: Gateway | string) => {
  const client = connection.get(network);
  if (client) {
    return client
  }
  //otherwise, bulid up new connection
  let new_client = new JsonRpcProvider(getGateway(network));
  connection.set(network, new_client);
  return new_client
}

export const chosenGateway = ref<Gateway | string>(GATEWAYS[Gateway.devent]);//questions: what's precise type
export const changeClient = (network: Gateway | string) => {
  create_connection(network)
  chosenGateway.value = network
}