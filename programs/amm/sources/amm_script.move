module sui_lipse::amm_script{
    use sui_lipse::amm::{Self, Pool, LP_TOKEN};
    use sui::coin::{Coin};
    use sui::sui::SUI;
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::object::{ ID};
    use sui::vec_set::VecSet;
    use sui_lipse::nft::{Self, JarekNFT};


    struct CardCollection has store {
        objects: VecSet<ID>,
        max_capacity: u64, //current capacity is limited, for efficient consideration
    }

    //make this object is untradable, wrapped it to the obj owned by programs


    entry fun change_card(self: &mut JarekNFT, new_url:vector<u8>){
        nft::update_nft(self, new_url);
    }

    public entry fun create_pool<V: drop, Y>(
    verifier:V,
    token_sui:Coin<SUI>,
    token_y:Coin<Y>,
    fee_percentage:u64,
    name:vector<u8>,
    symbol:vector<u8>,
    ctx:&mut TxContext
    ){
        transfer::transfer(
            amm::create_pool(
                verifier, token_sui, token_y, fee_percentage, name, symbol, ctx
            ),
            tx_context::sender(ctx)
        );
        transfer::transfer(
            // introduce inner function of other module by being being declared as 'friend'
            nft::mint_nft_(
                b"Jarek_AMM",
                b"This is Jarek's collection, but from pool creation",
                b"https://arweave.net/p01LagSqYNVB8eix4UJ3lf1CCYbKKxFgV2XMW4hUMTQ",
                ctx
            ),
            tx_context::sender(ctx)
        )
    }


    //it is required to input desired amounts, since sometimes the amount won't be that precise
    entry fun add_liquidity<V, Y>(
    pool:&mut Pool<V, Y>,  sui: Coin<SUI>, token_y: Coin<Y>,
    amount_a_min:u64, amount_b_min:u64, ctx:&mut TxContext
    ){
        transfer::transfer(
            amm::add_liquidity(pool, sui, token_y, amount_a_min, amount_b_min, ctx),
            tx_context::sender(ctx)
        );
    }

    entry fun remove_liquidity<V, Y>(
    pool:&mut Pool<V, Y>, lp_token:Coin<LP_TOKEN<V, Y>>,
    amount_a_min:u64, amount_b_min:u64, ctx:&mut TxContext
    ){
        let (sui, token_y) = amm::remove_liquidity(pool, lp_token, amount_a_min, amount_b_min, ctx);
        transfer::transfer(
            sui,
            tx_context::sender(ctx)
        );
        transfer::transfer(
            token_y,
            tx_context::sender(ctx)
        );
    }

    entry fun swap_sui<V,Y>(
    pool:&mut Pool<V,Y>, sui:Coin<SUI>, ctx:&mut TxContext
    ){
        transfer::transfer(
           amm::swap_sui(pool, sui, ctx),
            tx_context::sender(ctx)
        );
    }

    public fun  swap_token_y<V,Y>(
    pool: &mut Pool<V,Y>, token_y:Coin<Y>, ctx: &mut TxContext
    ){
        transfer::transfer(
           amm::swap_token_y(pool, token_y, ctx),
            tx_context::sender(ctx)
        );
    }
}

