
<script setup lang="ts">
import Nav from "@/components/Nav.vue"
import { onMounted } from "vue";
import { changeClient, chosenGateway } from "./sui/gateway";

onMounted(async () => {
  try {
    changeClient(chosenGateway.value)
  } catch (error) {
    console.error(error)
  }
})
</script>

<template>
  <Nav />
  <section class="section">
    <router-view />
  </section>
</template>

<style>
body {
  font-family: 'Roboto Slab', serif;
  height: 100vh;
  width: 100%;
  overflow: hidden;
  margin: 0;
  padding: 0;
}

section {
  max-width: 1200px;
  margin: 0 auto;
}
</style>
