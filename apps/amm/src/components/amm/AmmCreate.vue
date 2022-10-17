<template >
    <div>
        <h1 class="title is-3">COIN</h1>
        <div class="cards-container">
            <template v-for="(item,idx) in coin_objs">
                <CardVue :idx="idx" :objectId="item.objectId" :type="item.type" value="100" />
            </template>
        </div>
    </div>
</template>


<script setup lang="ts">
import CardVue from "@/components/Card.vue"
import { COIN_TYPE, getCoinAfterSplit, SuiObject, SuiObjectInfo } from "@mysten/sui.js";
import { onMounted, ref } from "vue";
import { connection, chosenGateway } from '../../sui/gateway'

const max_amount = 50;
const colors = {
    normal: '#A8A77A',
    fire: '#EE8130',
    water: '#6390F0',
    electric: '#F7D02C',
    grass: '#7AC74C',
    ice: '#96D9D6',
    fighting: '#C22E28',
    poison: '#A33EA1',
    ground: '#E2BF65',
    flying: '#A98FF3',
    psychic: '#F95587',
    bug: '#A6B91A',
    rock: '#B6A136',
    ghost: '#735797',
    dragon: '#6F35FC',
    dark: '#705746',
    steel: '#B7B7CE',
    fairy: '#D685AD',
};

const SIGNER = "0x94c21e07df735da5a390cb0aad0b4b1490b0d4f0"
//let displayCoins =

let coin_objs = ref<SuiObjectInfo[]>([]);

const getCoins = async () => {
    try {
        let rpc = connection.get(chosenGateway.value)
        if (!rpc) {
            throw new Error("fail to get rpc")
        }
        let coin_objects = await rpc.getObjectsOwnedByAddress(SIGNER).then(data => data.filter(o => o.type.startsWith(COIN_TYPE)));
        console.log(coin_objects);
        coin_objs.value = coin_objects ?? null
    } catch (error) {
        console.error(error)
    }
}

onMounted(async () => {
    await getCoins()
})
</script>

<style scoped>
.cards-container {
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto;
    max-width: 1200px;
}
</style>