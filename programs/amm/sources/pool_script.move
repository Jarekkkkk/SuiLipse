module sui_lipse::amm_script{
    use sui_lipse::amm::{Self, Pool, LP_TOKEN};
    use sui::coin::{Coin};
    use sui::sui::SUI;
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    const EInsufficientAmount:u64 = 6;
    const EInsufficientBAmount:u64 = 7;

    //probably should added as (friend modules)
    public entry fun create_pool(){}

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

