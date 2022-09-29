module sui_lipse::amm_script{
    use sui_lipse::amm::{Self, Pool, LP_TOKEN};
    use sui::coin::{Coin};
    use sui::sui::SUI;
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::string;
    use std::ascii;
    use sui::object::{Self, UID, ID};
    use sui::vec_set::VecSet;


    struct CardCollection has store {
        objects: VecSet<ID>,
        max_capacity: u64, //current capacity is limited, for efficient consideration

    }

    //make this object is untradable, wrapped it to the obj owned by programs
    struct Card has key{
        id: UID,
        name: string::String,
        symbol: ascii::String,
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
            Card{
                id: object::new(ctx),
                name: string::utf8(name),
                symbol: ascii::string(symbol)
            },
            tx_context::sender(ctx)
        )
    }

    entry fun change_card(self: &mut Card, name:vector<u8>, symbol:vector<u8>){
        self.name = string::utf8(name);
        self.symbol = ascii::string(symbol);
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

