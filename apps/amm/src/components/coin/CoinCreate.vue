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
                <input class="input" type="text" placeholder="Text input">
            </div>
            <p class="help">This is a help text</p>
        </div>
        <div class="field">
            <label class="label">Capability_ID</label>
            <div class="control">
                <input class="input" type="text" placeholder="Text input">
            </div>
            <p class="help">This is a help text</p>
        </div>
        <div class="field">
            <label class="label">Recipient</label>
            <div class="control">
                <input class="input" type="text" placeholder="Text input">
            </div>
            <p class="help">This is a help text</p>
        </div>
        <div class="field">
            <label class="label">Amount</label>
            <div class="control">
                <input class="input" type="number" placeholder="Text input">
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


<script setup lang="ts">import { reactive, ref } from 'vue';
const createdTokenAddress = ref("");
const creatingToken = ref(false);
const tokenLink = ref("");
const errorMessage = ref("");

const form = reactive(
    {
        capability: "",
        recipient: "",
        amount: 0
    }
)

const submit = () => {
    console.log('submit the coin create form');
}

const createToken = () => { console.log("create token "); }
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
    margin-top: 3rem;
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