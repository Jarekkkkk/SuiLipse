

<template >
    <nav class="level">
        <div class="level-item has-text-centered">
            <div>
                <p class="heading">Tweets</p>
                <p class="title">3,456</p>
            </div>
        </div>
        <div class="level-item has-text-centered">
            <div>
                <p class="heading">Following</p>
                <p class="title">sfsd</p>
            </div>
        </div>
        <div class="level-item has-text-centered">
            <div>
                <p class="heading">Followers</p>
                <p class="title">456K</p>
            </div>
        </div>
        <div class="level-item has-text-centered">
            <div>
                <p class="heading">Likes</p>
                <p class="title">789</p>
            </div>
        </div>
    </nav>
    <section>
        <table class="table is-fullwidth">
            <thead>
                <tr>
                    <th>
                    </th>
                    <th><abbr title="ObjectId">ObjectId</abbr></th>
                    <th><abbr title="Type">Type</abbr></th>
                    <th><abbr title="Owner">Owner</abbr></th>
                    <th><abbr title="Version">version</abbr></th>
                </tr>
            </thead>
            <tbody>
                <template v-for="(item,idx) in items">
                    <Item :idx="idx" :object-id="item.objectId" :type="item.type" :owner="getOwnerStr(item.owner)"
                        :version="item.version" />
                </template>
            </tbody>
        </table>

    </section>
</template>

<script setup lang="ts">
import { SuiObjectInfo } from '@mysten/sui.js';
import { getOwnerStr } from '../sui/object'
import { onMounted, ref } from 'vue';
import { connection, chosenGateway } from '../sui/gateway';
import Item from './home/Item.vue'


const SIGNER = "0x94c21e07df735da5a390cb0aad0b4b1490b0d4f0"

let items = ref<SuiObjectInfo[]>([])

onMounted(async () => {
    try {
        let rpc = connection.get(chosenGateway.value);
        if (rpc) {
            const objects = await rpc.getObjectsOwnedByAddress(
                SIGNER
            );
            items.value = objects
        }
    } catch (error) {
        console.error(error)
    }
})
</script>
<style scoped>
section {
    max-width: 1200px;
    margin: 0 auto;
}

.level {
    margin: 1rem;
    display: flex;
    align-items: center;
    justify-content: space-evenly
}

table {
    width: 100%;
    margin-top: 4rem;
    border-spacing: 10px;
    text-align: center
}

th,
td {
    padding: 20px;
}
</style>