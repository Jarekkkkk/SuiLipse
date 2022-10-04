module sui_lipse::amm_script{
    use sui_lipse::amm::{Self, Pool, LP_TOKEN};
    use sui::coin::{Coin};
    use sui::sui::SUI;
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui_lipse::nft_collection;


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
            amm::create_pool_(
                verifier, token_sui, token_y, fee_percentage, name, symbol, ctx
            ),
            tx_context::sender(ctx)
        );
        // to trasnfer NFT with only 'key' abiility, it has to be called in the module where define
        // introduce inner function of other module by being being declared as 'friend'
         nft_collection::mint_nft(
                name,
                symbol, // passed as description
                b"https://arweave.net/p01LagSqYNVB8eix4UJ3lf1CCYbKKxFgV2XMW4hUMTQ",
                ctx
            );
    }


    //it is required to input desired amounts, since sometimes the amount won't be that precise
    entry fun add_liquidity<V, X, Y>(
    pool:&mut Pool<V, X, Y>,  sui: Coin<X>, token_y: Coin<Y>,
    amount_a_min:u64, amount_b_min:u64, ctx:&mut TxContext
    ){
        transfer::transfer(
            amm::add_liquidity_(pool, sui, token_y, amount_a_min, amount_b_min, ctx),
            tx_context::sender(ctx)
        );
    }

    entry fun remove_liquidity<V, X, Y>(
    pool:&mut Pool<V, X, Y>, lp_token:Coin<LP_TOKEN<V, X, Y>>,
    amount_a_min:u64, amount_b_min:u64, ctx:&mut TxContext
    ){
        let (token_x, token_y) = amm::remove_liquidity_(pool, lp_token, amount_a_min, amount_b_min, ctx);
        transfer::transfer(
            token_x,
            tx_context::sender(ctx)
        );
        transfer::transfer(
            token_y,
            tx_context::sender(ctx)
        );
    }

    entry fun swap_sui<V,Y>(
    pool:&mut Pool<V, SUI, Y>, sui:Coin<SUI>, ctx:&mut TxContext
    ){
        transfer::transfer(
           amm::swap_token_x(pool, sui, ctx),
            tx_context::sender(ctx)
        );
    }

    public fun  swap_token_y<V, X, Y>(
    pool: &mut Pool<V, X, Y>, token_y:Coin<Y>, ctx: &mut TxContext
    ){
        transfer::transfer(
           amm::swap_token_y(pool, token_y, ctx),
            tx_context::sender(ctx)
        );
    }
}

