<template >
    <div class="card">
        <div class="img-container">
            <img src="../assets/vite.svg" alt={{idx}}>
        </div>
        <div class="info">
            <span class="number">{{objectId}}</span>
            <h3 class="type">{{type}}</h3>
            <small class="value">Value: <span>{{value}}</span></small>
        </div>
    </div>
</template>



<script setup lang="ts">import { computed } from 'vue';


const props = defineProps<{
    idx: number,
    objectId: string,
    type: string,
    value: number,
}>();

const foo = computed(() => {
    let str = props.objectId
    console.log(str);
    let left = str.substring(0, 4)
    let right = str.substring(str.length - 2)

    return left + "..." + right
})

</script>

<style>
.card {
    background-color: rgb(208, 234, 255);
    border-radius: 10px;
    box-shadow: 0 3px 15px rgba(100, 100, 100, 0.5);
    margin: 10px;
    padding: 20px;
    text-align: center;
}

.card .img-container {
    background-color: rgb(255, 241, 223);
    border-radius: 50%;
    width: 120px;
    height: 120px;
    text-align: center;
    display: flex;
    align-items: center;
    justify-content: center
}

.card .img-container img {
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
</style>