<script setup lang="ts">
// get the gateway and required state from sui.pkg
</script>

<template>
  <nav class="navbar" role="navigation" aria-label="main navigation">
    <div class="navbar-brand">
      <a class="navbar-item" href="https://medium.com">
        <img src="./assets/dinosaur.jpeg" alt="dinasour">
        <h1 class="title is-3 pl-1">SuiLipse</h1>
      </a>

      <a role="button" class="navbar-burger" aria-label="menu" aria-expanded="false" data-target="navbarBasicExample">
        <span aria-hidden="true"></span>
        <span aria-hidden="true"></span>
        <span aria-hidden="true"></span>
      </a>
    </div>

    <div id="navbarBasicExample" class="navbar-menu">
      <div class="navbar-start">
        <a class="navbar-item">
          Home
        </a>
        <a class="navbar-item">
          Token
        </a>
        <a class="navbar-item">
          Swap
        </a>
      </div>

      <div id="login">
        <div class="navbar-item">
          <div class="buttons">
            <a class="button is-primary">
              <strong>Sign up</strong>
            </a>
          </div>
        </div>
      </div>
    </div>
  </nav>

</template>

<style scoped>
body {
  font-family: 'Roboto Slab', serif;
  margin: 0;
  padding: 0;
}

/** Navbar */
nav {
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
