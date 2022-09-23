module sui_lipse::amm{
    use sui::object::{Self,UID};
    use sui::balance::{Self,Supply, Balance};
    use sui::coin::{Self,Coin};
    use sui::sui::SUI;
    use sui::tx_context::TxContext;
    use sui::transfer;

    use sui_lipse::math::{Self};

    const EZEROAMOUNT:u64 = 0;
    const EINVALIDFEE:u64 = 1;
    const EFULLPOOL:u64 = 2;

    const FEE_SCALING:u64 = 10000;
    const MAX_POOL_VALUE: u64 = {
        18446744073709551615/*U64_MAX*/ / 10000
    };


    //<P>: pool provider verifier
    //<T>: one of pair of tokens
    //LSP: pool token
    struct LP_TOKEN<phantom V, phantom Y> has drop {}

    //Initially, pool should all be exchanged 'in SUI based'
    struct Pool<phantom V, phantom Y> has key{
        id:UID,
        reserve_sui:Balance<SUI>,
        reserve_y:Balance<Y>,
        lp_supply:Supply<LP_TOKEN<V,Y>>,
        fee_percentage:u64 //[1,10000] --> [0.01%, 100%]
    }


    fun init(_ctx:&mut TxContext){}

    //transfer `shared_obj: pool` to tx_sender
    public fun create_pool<V:drop,Y>(
        _verifier:V,
        token_sui:Coin<SUI>,
        token_y:Coin<Y>,
        fee_percentage:u64,
        ctx:&mut TxContext
    ):Coin<LP_TOKEN<V,Y>> {
        let sui_value = coin::value(&token_sui);
        let token_y_value = coin::value(&token_y);

        assert!(sui_value > 0 && token_y_value > 0, EZEROAMOUNT);
        assert!(sui_value < MAX_POOL_VALUE && token_y_value < MAX_POOL_VALUE, EFULLPOOL);
        assert!(fee_percentage > 0 && fee_percentage <= 10000, EINVALIDFEE);


        let lp_shares = math::sqrt(sui_value) * math::sqrt(token_y_value);
        let lp_supply = balance::create_supply(LP_TOKEN<V,Y>{});
        let lp_balance = balance::increase_supply(&mut lp_supply, lp_shares);

        transfer::share_object(Pool{
            id:object::new(ctx),
            reserve_sui:coin::into_balance(token_sui),
            reserve_y:coin::into_balance(token_y),
            lp_supply,
            fee_percentage
        });

        coin::from_balance(lp_balance, ctx)
    }

    fun add_liquidity(){}

    fun remove_liquidity(){}


    //helper
    //( sui_reserve, token_y_reserve, lp_token_supply)
     public fun get_amounts<V, Y>(pool: &Pool<V, Y>): (u64, u64, u64) {
        (
            balance::value(&pool.reserve_sui),
            balance::value(&pool.reserve_y),
            balance::supply_value(&pool.lp_supply)
        )
    }



    #[test]
    fun test(){
    }

    //glue calling for init the module
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }
}


#[test_only]
module sui_lipse::amm_test{
    use sui::sui::SUI;
    use sui::coin::{mint_for_testing as mint, destroy_for_testing as burn};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui_lipse::amm::{Self, Pool};

    struct TOKEN_Y {}

    struct JAREK has drop {}/*Verifier for pool creator*/

    // SUI/TOKEN_Y = 1000
    const SUI_AMT: u64 = 1000000;
    const TOKEN_Y_AMT: u64 = 1000000000;

    //tests
    #[test] fun test_init_pool() {
        let scenario = test::begin(&@0x1);
        test_init_pool_(&mut scenario);
    }


    fun test_init_pool_(test:&mut Scenario){
        let ( lp, _) = people();

        //init the module
        next_tx(test, &lp);{
            amm::init_for_testing(ctx(test));
        };

        //create pool
        next_tx(test, &lp); {
            let lsp = amm::create_pool(
                JAREK {},
                mint<SUI>(SUI_AMT, ctx(test)),
                mint<TOKEN_Y>(TOKEN_Y_AMT, ctx(test)),
                3,
                ctx(test)
            );

            assert!(burn(lsp) == 31622000, 0);
        };

        //validate
        next_tx(test, &lp);
        {
            let pool = test::take_shared<Pool<JAREK, TOKEN_Y>>(test);
            let shared_pool = test::borrow_mut(&mut pool); // shared_obj could only be borrowed mutably
            let (sui_r, token_y_r, lp_s) = amm::get_amounts<JAREK, TOKEN_Y>(shared_pool);

            assert!(sui_r == SUI_AMT,0);
            assert!(token_y_r == TOKEN_Y_AMT,0);
            assert!(lp_s == 31622000,0);

            test::return_shared(test, pool);
        }
     }

    //utilities
    fun people(): (address, address) { (@0xABCD, @0x1234 ) }
}