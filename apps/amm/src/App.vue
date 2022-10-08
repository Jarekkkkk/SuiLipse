
<script setup lang="ts">
import Nav from './components/Nav.vue';

// get the gateway and required state from sui.pkg

</script>

<template>
  <Nav />
  <div style="display: flex" class="is-justify-content-center">
    <div style="width: 650px; margin-bottom: 40px" class="mt-6">
      <router-view></router-view>
    </div>
  </div>
</template>

<style scoped>
body {
  font-family: 'Roboto Slab', serif;
  margin: 0;
  padding: 0;
}
</style>
