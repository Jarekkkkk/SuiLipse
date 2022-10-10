<script setup lang="ts">
import { objectToString } from '@vue/shared';
import { onMounted, computed } from 'vue';
import { GATEWAYS, Gateway, chosenGateway, changeClient } from '../sui/gateway'
const currentClusterWithEmoji = computed(() => {
    let emoji
    let gateway

    switch (chosenGateway.value) {
        case GATEWAYS.Devent:
            gateway = "Devnet"
            emoji = "💦";
            break;
        case GATEWAYS.Local:
            gateway = "Local"
            emoji = "💧";
            break;
    }
    console.log(chosenGateway.value)
    return gateway + " " + emoji
})


</script>
<template >
    <nav class="navbar" role="navigation" aria-label="main navigation">
        <div class="navbar-brand">
            <a class="navbar-item" href="https://medium.com">
                <img src="../assets/dinosaur.jpeg" alt="dinasour">
                <h1 class="title is-3 pl-1">SuiLbipse</h1>
            </a>

            <a role="button" class="navbar-burger" aria-label="menu" aria-expanded="false"
                data-target="navbarBasicExample">
                <span aria-hidden="true"></span>
                <span aria-hidden="true"></span>
                <span aria-hidden="true"></span>
            </a>
        </div>

        <div id="navbarBasicExample" class="navbar-menu">
            <div class="navbar-start">
                <router-link :to="{ name: 'home' }">
                    <a class="navbar-item">
                        Home
                    </a>
                </router-link>
                <router-link :to="{ name: 'coin-create' }">
                    <a class="navbar-item">
                        Coin
                    </a>
                </router-link>
                <router-link :to="{ name: 'amm-create' }">
                    <a class="navbar-item">
                        Amm
                    </a>
                </router-link>
            </div>
            <div id="login" class="navbar-item has-dropdown is-hoverable">
                <a class="navbar-link">{{ currentClusterWithEmoji }} </a>

                <div class="navbar-dropdown is-right">
                    <a v-for="cluster in GATEWAYS" :key="cluster" :class="{
                      'has-background-light': cluster === chosenGateway,
                      'has-text-black': cluster === chosenGateway
                    }" class="navbar-item" @click="changeClient(cluster)">{{ cluster }}</a>
                </div>
            </div>
        </div>
    </nav>
</template>
<style scoped>
.navbar {
    padding: 12px;
    font-size: 1.2rem;
    font-weight: 700;
    background-color: rgb(168, 212, 237)
}

.navbar-brand {
    width: 200px
}

.navbar-start {
    margin: 0 auto
}

.navbar-end {
    width: 200px
}

#login {
    width: 200px
}
</style>