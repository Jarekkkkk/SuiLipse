
<script setup lang="ts">
import Nav from "@/components/Nav.vue"

// TODO: onMounted
// import { onMounted } from "vue";
// import { changeClient, chosenGateway } from "./sui/gateway"
// onMounted(() => {
//   changeClient(chosenGateway.value)
// }),

</script>

<template>
  <Nav />
  <router-view></router-view>
</template>

<style>
body {
  font-family: 'Roboto Slab', serif;
  margin: 0;
  padding: 0;
}
</style>
