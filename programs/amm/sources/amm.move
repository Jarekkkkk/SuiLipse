module sui_lipse::amm{
    use sui::object::{Self,UID, ID};
    use sui::balance::{Self,Supply, Balance};
    use sui::coin::{Self,Coin};
    use sui::sui::SUI;
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use std::string::{Self, String};

    use sui_lipse::amm_math;

    const EZeroAmount:u64 = 0;
    const EInvalidFee:u64 = 1;
    const EFullPool:u64 = 2;
    const ENotEnoughCoin:u64 = 3;
    const EReservesEmpty:u64 = 4;
    const EInsufficientLiquidty:u64 = 5;
    const EInsufficientAAmount:u64 = 6;
    const EInsufficientBAmount:u64 = 7;

    const MINIMUM_LIQUIDITY:u128 = 10; // minimum of Liquiditya to prevent math rounding problems
    const FEE_SCALING:u64 = 10000;
    const MAX_POOL_VALUE: u64 = {
        18446744073709551615/*U64_MAX*/ / 10000
    };

    friend sui_lipse::amm_script;


    //<V>: pool provider verifier
    //<Y>: one of pair of tokens
    //LP_TOKEN: pool token
    //must be `uppercase` to become one-time witness
    struct LP_TOKEN<phantom V, phantom Y> has drop {}

    //Initially, pool should all be exchanged 'in SUI based'
    struct Pool<phantom V, phantom Y> has key{
        id:UID,
        name:String,
        symbol:String,
        reserve_sui:Balance<SUI>,
        reserve_y:Balance<Y>,
        lp_supply:Supply<LP_TOKEN<V,Y>>,
        fee_percentage:u64 //[1,10000] --> [0.01%, 100%]
    }

    // ===== Events =====
    struct PoolCreated has copy, drop{
        pool:ID,
        //token_a: TYPE_A
        //token_b: TYPE_B
    }
    struct Mint has copy, drop{
        sender: address,
        amount0:u64,
        amount1:u64
    }
    struct Burn has copy, drop{
        sender: address,
        amount0:u64,
        amount1:u64
    }
    struct Swap has copy, drop{
        sender: address,
        amount0In:u64,
        amount1In:u64,
        amount0Out:u64,
        amount1Out:u64,
        to:address
    }

    fun init(_ctx:&mut TxContext){}

    public fun create_pool<V:drop,Y>(
        _verifier:V,
        token_sui:Coin<SUI>,
        token_y:Coin<Y>,
        fee_percentage:u64,
        name:vector<u8>,
        symbol:vector<u8>,
        ctx:&mut TxContext
    ):Coin<LP_TOKEN<V,Y>> {
        let sui_value = coin::value(&token_sui);
        let token_y_value = coin::value(&token_y);

        assert!(sui_value > 0 && token_y_value > 0, EZeroAmount);
        assert!(sui_value < MAX_POOL_VALUE && token_y_value < MAX_POOL_VALUE, EFullPool);
        assert!(fee_percentage > 0 && fee_percentage <= 10000, EInvalidFee);


        let lp_shares = amm_math::sqrt(sui_value) * amm_math::sqrt(token_y_value);
        let lp_supply = balance::create_supply(LP_TOKEN<V,Y>{});
        let lp_balance = balance::increase_supply(&mut lp_supply, lp_shares);

        let pool = Pool{
            id:object::new(ctx),
            reserve_sui:coin::into_balance(token_sui),
            reserve_y:coin::into_balance(token_y),
            lp_supply,
            fee_percentage,
            name:string::utf8(name),
            symbol:string::utf8(symbol),
        };
         event::emit(
            PoolCreated{pool:object::id(&pool)}
        );
        transfer::share_object(pool);
        coin::from_balance(lp_balance, ctx)
    }

    // ===== ADD_LIQUIDITY =====

    public fun add_liquidity_generic(){}
    public fun add_liquidity<V, Y>(
    pool:&mut Pool<V, Y>,  sui: Coin<SUI>, token_y: Coin<Y>,
    amount_a_min:u64, amount_b_min:u64, ctx:&mut TxContext
    ):Coin<LP_TOKEN<V, Y>>{
        let sui_value = coin::value(&sui);
        let token_y_value = coin::value(&token_y);
        assert!(sui_value > 0 && token_y_value > 0, ENotEnoughCoin);

        let (sui_r, token_y_r, lp_supply) = get_reserves(pool);
        //quote
         let (amount_a, amount_b, coin_sui, coin_b) = if (sui_r == 0 && token_y_r == 0){
            (sui_value, token_y_value, sui, token_y)
        }else{
            let opt_b  = quote(sui_r, token_y_r, sui_value);
            if (opt_b <= token_y_value){
                assert!(opt_b >= amount_b_min, EInsufficientBAmount);

                let split_b = coin::take<Y>(coin::balance_mut<Y>( &mut token_y), opt_b, ctx);
                transfer::transfer(token_y, tx_context::sender(ctx));
                (sui_value, opt_b,  sui, split_b)
            }else{
                 let opt_a = quote(token_y_r, sui_r, token_y_value);
                assert!(opt_a <= sui_value && opt_a >= amount_a_min, EInsufficientAAmount );

                let split_a = coin::take<SUI>(coin::balance_mut<SUI>(&mut sui), opt_b, ctx);
                transfer::transfer(sui, tx_context::sender(ctx));
                (opt_a, token_y_value,  split_a, token_y)
            }
        };

         let lp_output = amm_math::min(
            (amount_a * lp_supply / sui_r),
            (amount_b * lp_supply / token_y_r)
        );
        let sui_pool = balance::join<SUI>(&mut pool.reserve_sui, coin::into_balance(coin_sui));
        let token_y_pool = balance::join<Y>(&mut pool.reserve_y,  coin::into_balance(coin_b));

        assert!(sui_pool < MAX_POOL_VALUE ,EFullPool);
        assert!(token_y_pool < MAX_POOL_VALUE ,EFullPool);

        let output_balance = balance::increase_supply<LP_TOKEN<V, Y>>(&mut pool.lp_supply, lp_output);
        coin::from_balance(output_balance, ctx)
    }

    // ===== REMOVE_LIQUIDITY =====

    public fun remove_liquidity<V, Y>(
    pool:&mut Pool<V, Y>, lp_token:Coin<LP_TOKEN<V, Y>>,
    amount_a_min:u64, amount_b_min:u64, ctx:&mut TxContext
    ):(Coin<SUI>, Coin<Y>){
        let lp_value = coin::value(&lp_token);
        assert!(lp_value > 0, ENotEnoughCoin);
        assert!(balance::supply_value(&pool.lp_supply) > 0, EReservesEmpty);

        let (sui_output, token_y_output) = withdraw_liquidity(pool, lp_value);

        assert!(sui_output >= amount_a_min, EInsufficientAAmount);
        assert!(token_y_output >= amount_b_min, EInsufficientBAmount);

        balance::decrease_supply<LP_TOKEN<V,Y>>(&mut pool.lp_supply,coin::into_balance(lp_token));
        (
            coin::take<SUI>(&mut pool.reserve_sui, sui_output, ctx),
            coin::take<Y>(&mut pool.reserve_y, token_y_output, ctx)
        )
    }

    // ===== SWAP =====

    public fun swap_sui<V,Y>(
    pool:&mut Pool<V,Y>, sui:Coin<SUI>, ctx:&mut TxContext
    ):Coin<Y>{
        let sui_value = coin::value(&sui);

        assert!(sui_value >0, ENotEnoughCoin);

        let (reserve_sui, reserve_y, _) = get_reserves(pool);
        let output_amount = get_input(sui_value, reserve_sui, reserve_y, pool.fee_percentage);

        let sui_balance = coin::into_balance(sui);//get the inner ownership

        balance::join<SUI>(&mut pool.reserve_sui, sui_balance);// transaction fee goes back to pool
        coin::take<Y>(&mut pool.reserve_y, output_amount, ctx)
    }

    public fun  swap_token_y<V,Y>(
    pool: &mut Pool<V,Y>, token_y:Coin<Y>, ctx: &mut TxContext
    ):Coin<SUI>{
        let token_y_value = coin::value(&token_y);
        assert!(token_y_value > 0, ENotEnoughCoin);

        let (reserve_sui, reserve_y, _) = get_reserves(pool);
        assert!(reserve_sui > 0 && reserve_y > 0, EReservesEmpty);

        let output_amount = get_input(token_y_value, reserve_y, reserve_sui, pool.fee_percentage);
        let token_y_balance = coin::into_balance(token_y);

        balance::join<Y>(&mut pool.reserve_y, token_y_balance);
        coin::take<SUI>(&mut pool.reserve_sui, output_amount, ctx)
    }

    // ------ helper script functions -------

    public fun get_sui_price<V, Y>(pool:&Pool<V, Y>):u64{
        let sui_value = balance::value(&pool.reserve_sui);
        let token_y_value = balance::value(&pool.reserve_y);

        token_y_value / sui_value
    }

    public fun get_token_y_price<V, Y>(pool: &Pool<V, Y>):u64{
        let sui_value = balance::value(&pool.reserve_sui);
        let token_y_value = balance::value(&pool.reserve_y);

        sui_value/ token_y_value
    }

    //( sui_reserve, token_y_reserve, lp_token_supply)
     public fun get_reserves<V, Y>(pool: &Pool<V, Y>): (u64, u64, u64) {
        (
            balance::value(&pool.reserve_sui),
            balance::value(&pool.reserve_y),
            balance::supply_value(&pool.lp_supply)
        )
    }

    // ------ utils -------
    // b' (optimzied_) = (Y/X) * a, subjected to Y/X = b/a
    public fun quote(reserve_a:u64, reserve_b:u64, input_a:u64):u64{
        assert!(reserve_a > 0 && reserve_b > 0, EInsufficientLiquidty);
        assert!(input_a > 0, EInsufficientAAmount);

        (reserve_b/ reserve_a) * input_a
    }

    //dy = (dx*y) / (dx + x), at dx' = dx(1 - fee)
    public fun get_input(dx:u64, x:u64, y:u64, f:u64
    ):u64{
        let dx_fee_deduction = (FEE_SCALING - f) * dx;
        let numerator = dx_fee_deduction * y;
        let denominator = FEE_SCALING * x + dx_fee_deduction;

        (numerator / denominator)
    }

    // (dx, dy) = ((lp_input/ LP_supply) * reserve_x ,(lp_input/ LP_supply) * reserve_y)
    public fun withdraw_liquidity<V, Y>(pool:&Pool<V, Y>, lp_value:u64):(u64, u64){
        let (sui_r, token_y_r, lp_supply) = get_reserves(pool);
        assert!(sui_r > 0 && token_y_r > 0, EInsufficientLiquidty);
        assert!(lp_value > 0, EInsufficientAAmount);

        ((sui_r * lp_value / lp_supply), (token_y_r * lp_value / lp_supply))
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
    use sui::coin::{Self, mint_for_testing as mint, destroy_for_testing as burn};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui_lipse::amm::{Self, Pool, LP_TOKEN};


    struct TOKEN_Y {} //token_y

    struct JAREK has drop {}/*Verifier for pool creator*/

    // SUI/TOKEN_Y = 1000
    const SUI_AMT: u64 = 1000000;
    const TOKEN_Y_AMT: u64 = 1000000000;

    //tests
    #[test] fun test_init_pool() {
        let scenario = test::begin(&@0x1);
        test_init_pool_(&mut scenario);
    }
     #[test] fun test_swap_sui() {
        let scenario = test::begin(&@0x1);
        test_swap_sui_(&mut scenario);
    }
     #[test] fun test_swap_token_y() {
        let scenario = test::begin(&@0x1);
        test_swap_token_y_(&mut scenario);
    }
     #[test] fun test_add_liquidity() {
        let scenario = test::begin(&@0x1);
        add_liquidity_(&mut scenario);
    }
    #[test] fun test_remove_liquidity() {
        let scenario = test::begin(&@0x1);
        remove_liquidity_(&mut scenario);
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
                b"jarek's pool",
                b"SUI-JRK",
                ctx(test)
            );

            assert!(burn(lsp) == 31622000, 0);
        };

        //shared_pool
        next_tx(test, &lp);
        {
            let pool = test::take_shared<Pool<JAREK, TOKEN_Y>>(test);
            let shared_pool = test::borrow_mut(&mut pool); // shared_obj could only be borrowed mutably
            let (sui_r, token_y_r, lp_s) = amm::get_reserves<JAREK, TOKEN_Y>(shared_pool);
            let sui_price = amm::get_sui_price<JAREK, TOKEN_Y>(shared_pool);

            assert!(sui_r == SUI_AMT,0);
            assert!(token_y_r == TOKEN_Y_AMT,0);
            assert!(lp_s == 31622000,0);
            assert!(sui_price == 1000,0);

            test::return_shared(test, pool);
        }
     }

     fun test_swap_sui_(test: &mut Scenario){
        let (_, trader) = people();

        test_init_pool_(test);

        next_tx(test, &trader);{
            let pool = test::take_shared<Pool<JAREK, TOKEN_Y>>(test);
            let shared_pool = test::borrow_mut(&mut pool);

            let token_y = amm::swap_sui<JAREK, TOKEN_Y>(shared_pool, mint<SUI>(5000, ctx(test)), ctx(test));

            assert!(burn(token_y) == 4973639, 0);

            test::return_shared(test, pool);
        }
    }

    fun test_swap_token_y_(test: &mut Scenario){
        let (_, trader) = people();

        test_init_pool_(test);

        next_tx(test, &trader);{
            let pool = test::take_shared<Pool<JAREK, TOKEN_Y>>(test);
            let shared_pool = test::borrow_mut(&mut pool);

            let output_sui = amm::swap_token_y<JAREK, TOKEN_Y>(shared_pool, mint<TOKEN_Y>(5000000, ctx(test)), ctx(test));

            assert!(burn(output_sui) == 4973,0);

            test::return_shared(test, pool);
        }
    }

    fun add_liquidity_(test: &mut Scenario){
        let (_, trader) = people();

        test_init_pool_(test);

        next_tx(test, &trader);{
            let pool = test::take_shared<Pool<JAREK, TOKEN_Y>>(test);
            let shared_pool = test::borrow_mut(&mut pool);

            let output_lp = amm::add_liquidity(shared_pool,  mint<SUI>(50, ctx(test)), mint<TOKEN_Y>(50000, ctx(test)), 50, 50000, ctx(test));

            assert!(burn(output_lp)==1581, 0);

            test::return_shared(test, pool);
        }
    }

    fun remove_liquidity_(test: &mut Scenario){
        let (owner, _) = people();

        test_swap_sui_(test);//Pool ( SUI_AMT + 5000, 1000000000 - 4973639)

        next_tx(test, &owner);{
            let pool = test::take_shared<Pool<JAREK, TOKEN_Y>>(test);
            let shared_pool = test::borrow_mut(&mut pool);
            // (X, Y) = (5000000, 995026361)
            let (_, _, lp) = amm::get_reserves(shared_pool);
            let lp_token = mint<LP_TOKEN<JAREK, TOKEN_Y>>(lp, ctx(test));
            //expected
            let (sui_withdraw, token_y_withdraw) = amm::withdraw_liquidity(shared_pool, coin::value<LP_TOKEN<JAREK, TOKEN_Y>>(&lp_token));

            let (withdraw_sui, withdraw_token_y) = amm::remove_liquidity(shared_pool, lp_token, sui_withdraw, token_y_withdraw, ctx(test));

            //after withdraw
            let (sui, token_y, lp_supply) = amm::get_reserves(shared_pool);

            assert!(sui == 0,0);
            assert!(token_y== 0, 0);
            assert!(lp_supply == 0, 0);
            assert!(burn(withdraw_sui) == sui_withdraw, 0);
            assert!(burn(withdraw_token_y) == token_y_withdraw, 0);

            test::return_shared(test, pool);
        }
    }
    //utilities
    fun people(): (address, address) { (@0xABCD, @0x1234 ) }
}