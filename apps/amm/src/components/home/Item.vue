<template >
    <tr>
        <th>{{idx}}</th>
        <td>{{objectId}}</td>
        <td>{{type}}</td>
        <td>{{owner}}</td>
        <td>{{version}}</td>
    </tr>
</template>
<script setup lang="ts">
defineProps<{
    idx: number,
    objectId: string,
    type: string, //0x2::coin::Coin&lt;0x2::sui::SUI&gt
    owner: string,
    version: number
}>()
</script>
<style>
.post {
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: space-around
}
</style>