import { createRouter, createWebHashHistory} from "vue-router";

//imported components
const Home =()=> import("./components/Home.vue")
const CoinCreate = ()=> import('./components/coin/CoinCreate.vue')
const AmmCreate = () => import('./components/amm/AmmCreate.vue')

//define the routes
const routes = [
  { path: '/', name:"home",component: Home },
  { path: '/coin-create', name:"coin-create",component: CoinCreate },
  { path: '/amm-craete', name:'amm-create', component: AmmCreate },
  ]


  export default createRouter({
    history: createWebHashHistory(),
    routes,
  })