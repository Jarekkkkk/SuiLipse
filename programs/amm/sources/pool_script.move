module sui_lipse::amm_script{
    use sui_lipse::amm::{Self, Pool};
    use sui::coin::Coin;
    use sui::sui::SUI;
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    //probably should added as (friend modules)
    public entry fun create_pool(){}

    //it is required to input desired amounts, since sometimes the amount won't be that precise
    entry fun add_liquidity<V, Y>(
    pool:&mut Pool<V, Y>, sui:Coin<SUI>, token_y:Coin<Y>,
    amount_a_min:u64, amount_b_min:u64, ctx:&mut TxContext
    ){
        transfer::transfer(
            amm::add_liquidity(pool, sui, token_y, amount_a_min, amount_b_min, ctx),
            tx_context::sender(ctx)
        );
    }
    public entry fun remove_liquidity(){}
    public entry fun swap_sui(){}
    public entry fun swap_token_y(){}
}

