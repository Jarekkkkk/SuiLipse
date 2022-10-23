<template >
    <div class="card">
        <div class="img-container">
            <img :src="img_src" alt={{idx}} class="avatar">
        </div>
        <div class="info">
            <div class="tooltip" @mouseover="toggle_hover" @mouseleave="reset_hover" style="position: relative">
                <span class="tip-text" :class="hover_class">{{objectId}}</span>
                <span class="number">{{slice_str(objectId)}}</span>
            </div>
            <div>
                <h3 class="type">{{type.length > 15 ? slice_str(type):type}}</h3>
                <small class="value">Value: <span>{{coin.balance}}</span></small>
            </div>
        </div>
    </div>
</template>


<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { COIN_TYPE_ARG_REGEX } from '../sui/coin'
import { chosenGateway, connection } from '../sui/gateway';
import { getMoveObject } from '@mysten/sui.js'


//coin
interface Coin {
    id: string,
    balance: number
}

let coin = ref<Coin>({
    id: "",
    balance: 0
})


const props = defineProps<{
    idx: number,
    objectId: string,
    type: string,
    value: string,
}>();

//hover effect
let hover_class = ref("")
const toggle_hover = () => hover_class.value = "hovered"
const reset_hover = () => hover_class.value = ""

//text visibility
const slice_str = (str: string) => {
    return str.substring(0, 5) + "..." + str.substring(str.length - 3)
}
const type = computed(() => {
    let s = props.type.match(COIN_TYPE_ARG_REGEX)
    return s ? s[1] : null
})

//read img file
const images = {
    SUI: "../src/assets/sui.svg",
    JRK: "https://arweave.net/Ys5-KyxJYjywCNeEwj0n0Q3ZxF4mgoAGcmawO76qbuM",
}
type Images = 'SUI' | 'JRK';
const img_src = ref("")
const get_img = (type: string) => {
    let img = type.substring(type.length - 3);
    img_src.value = images[img as Images]
}

//fetch the price
const fetch_price = async () => {
    try {
        let rpc = connection.get(chosenGateway.value);
        if (!rpc) {
            throw Error("rpc fetched");
        }

        let res = await rpc.getObject("0x5bf0b9ce8972d614d631618a7a149e211d1d70fd");
        let m_obj = getMoveObject(res);
        if (m_obj) {
            coin.value = m_obj.fields as Coin;
        }
    } catch (error) {
        console.error(error);
    }
}



onMounted(async () => {
    if (type.value) {
        get_img(type.value)
        await fetch_price()
    }
})

</script>

<style scoped>
.card {
    background-color: rgb(208, 234, 255);
    border-radius: 10px;
    box-shadow: 0 3px 15px rgba(100, 100, 100, 0.5);
    margin: 10px;
    padding: 20px;
    text-align: center;
    display: flex;
    flex-direction: column;
    align-items: center;
}

.avatar {
    vertical-align: middle;
    border-radius: 50%;
    background-color: #fff;
}

.card .img-container {
    border-radius: 50%;
    width: 120px;
    height: 120px;
    text-align: center;
    display: flex;
    align-items: center;
    justify-content: center
}

.card .img-container {
    max-width: 90%;
    margin-top: 20px;
}

.card .info {
    margin-top: 20px;
}

.card .info .number {
    background-color: rgba(0, 0, 0, 0.1);
    padding: 5px 10px;
    border-radius: 10px;
    font-size: 0.8rem;
}

.card .info .name {
    margin: 15px 0 7px;
    letter-spacing: 1px;
}


.tip-text {
    position: absolute;
    left: 50%;
    top: 0;
    transform: translateX(-50%);
    background-color: rgb(129, 201, 255);
    color: #fff;
    white-space: nowrap;
    border-radius: 7px;
    visibility: hidden;
    padding: 0 10px;
}

.tip-text::before {
    content: "";
    position: absolute;
    left: 50%;
    top: 100%;
    transform: translateX(-50%);
    border: 10px solid;
    border-color: rgb(129, 201, 255) #0000 #0000 #0000
}

.hovered {
    top: -130%;
    visibility: visible;
    opacity: 1;
}
</style>