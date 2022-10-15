<template >
    <h1 class="title is-3">COIN CREATOR</h1>
    <div style="margin-top: 30px">
        <article v-if="createdTokenAddress" class="message is-black">
            <div class="message-body">
                Success! Take a look at your created token:
                <a :href="tokenLink" target="_blank" rel="noopener noreferrer">{{
                createdTokenAddress
                }}</a>
            </div>
        </article>
        <article v-else-if="errorMessage" class="message is-danger">
            <div class="message-body">
                {{ errorMessage }}
            </div>
        </article>
        <div class="field">
            <label class="label">Package</label>
            <div class="control">
                <input class="input" type="text" placeholder="Text input" v-model="package_id">
            </div>
            <p class="help">This is a help text</p>
        </div>
        <div class="field">
            <label class="label">Capability_ID</label>
            <div class="control">
                <input class="input" type="text" placeholder="Text input" v-model="capability">
            </div>
            <p class="help">This is a help text</p>
        </div>
        <div class="field">
            <label class="label">Recipient</label>
            <div class="control">
                <input class="input" type="text" placeholder="Text input" v-model="recipient">
            </div>
            <p class="help">This is a help text</p>
        </div>
        <div class="field">
            <label class="label">Amount</label>
            <div class="control">
                <input class="input" type="number" placeholder="Text input" v-model="amount">
            </div>
            <p class="help">This is a help text</p>
        </div>

        <div class="button_f">
            <button :class="{ 'is-loading': creatingToken }" class="button is-medium is-primary is-outlined"
                @click="createToken">
                Create new token
            </button>
        </div>

    </div>
</template>


<script setup lang="ts">
import { ref } from 'vue';
import { createToken_ } from '../../sui/coin_tx'


const createdTokenAddress = ref("");
const creatingToken = ref(false);
const tokenLink = ref("");
const errorMessage = ref("");

const package_id = ref("")
const capability = ref("")
const recipient = ref("")
const amount = ref(0)

const createToken = async () => {
    try {
        await createToken_(capability.value, amount.value, recipient.value)
        package_id.value = "";
        capability.value = "";
        amount.value = 0
    } catch (error) {
        console.error(error)
    }
}

</script>

<!-- /// Mint and Transfer Coin with signer holding Capability
MintAndTransfer {
    #[clap(long)]
    capability: ObjectID,
    #[clap(long)]
    recipient: Option<SuiAddress>,
    #[clap(long)]
    amount: u64,
}, -->

<style scoped>
.title {
    text-align: center;
}

.button_f {
    display: flex;
    justify-content: center;
}

.button {
    font-weight: 800
}
</style>