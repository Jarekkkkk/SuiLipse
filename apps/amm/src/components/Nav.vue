<script setup lang="ts">
import { ref, onMounted } from 'vue'




</script>
<template >
    <nav class="navbar" role="navigation" aria-label="main navigation">
        <div class="navbar-brand">
            <a class="navbar-item" href="https://medium.com">
                <img src="../assets/dinosaur.jpeg" alt="dinasour">
                <h1 class="title is-3 pl-1">Suilipse</h1>
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
            <div id="login">
                <div class="navbar-item">
                    <div class="buttons">
                        <a class="button is-primary">
                            <strong>Login</strong>
                        </a>
                    </div>
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