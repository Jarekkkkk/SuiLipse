module sui_lipse::amm{
    use sui::object::{Self,UID, ID};
    use sui::balance::{Self,Supply, Balance};
    use sui::coin::{Self,Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use std::string::{Self, String};
    use sui_lipse::amm_math;


    // ===== EVENT =====
    /// input amount is zero, including 'pair of assets<X,Y>' and 'LP_TOKEN'
    const EZeroAmount:u64 = 0;
     /// when one of pair tokens is empty
    const EReservesEmpty:u64 = 1;
    /// incoreect fee range, [0,100000]
    const EInvalidFee:u64 = 2;
    /// when Pool is over MAX_POOL_VALUE
    const EFullPool:u64 = 3;


    const EInsufficientAAmount:u64 = 6;
    const EInsufficientBAmount:u64 = 7;

    /// minimum of Liquiditya to prevent math rounding problems
    const MINIMUM_LIQUIDITY:u128 = 10;

    /// For fees calculation
    const FEE_SCALING:u64 = 10000;

    /// - Max stored value for both tokens is: U64_MAX / 10_000
    const MAX_POOL_VALUE: u64 = {
        18446744073709551615/*U64_MAX*/ / 10000
    };

    // ===== Object =====
    /// only moduler publisher can create the pool
    /// no type argument required sicnce it could be applied to all kinds of pool
    struct PoolCapability has key, store {
        id: UID,
    }

    //must be `uppercase` to become one-time witness
    struct LP_TOKEN<phantom V, phantom X, phantom Y> has drop {}

    struct Pool<phantom V, phantom X, phantom Y> has key{
        id: UID,
        name: String,
        symbol: String,
        reserve_x: Balance<X>,
        reserve_y: Balance<Y>,
        lp_supply: Supply<LP_TOKEN<V, X, Y>>,
        fee_percentage:u64 //[1,10000] --> [0.01%, 100%]
        //TODO: Epoch duration in Sui
    }

    // ===== Events =====
    struct PoolCreated has copy, drop{
        pool: ID,
        name: String,
        symbol: String,
        fee_percentage: u64
        //Quesiton: can i declare type ?
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
        lp_token:u64,
        amount0:u64,
        amount1:u64,
    }
    struct Swap has copy, drop{
        sender: address,
        amountIn:u64,
        amountOut:u64,
    }

    fun init(ctx:&mut TxContext){
         transfer::transfer(
             PoolCapability{id: object::new(ctx)},
             tx_context::sender(ctx)
         )
    }

    // ===== CREATE_POOL =====
    /// onlt module publisher could create pool by passing the witess type
    entry fun create_pool<V: drop, X, Y>(
       verifier: V,
        cap: &PoolCapability,
        token_x: Coin<X>,
        token_y: Coin<Y>,
        fee_percentage: u64,
        name: vector<u8>,
        symbol: vector<u8>,
        ctx: &mut TxContext
    ){
        transfer::transfer(
            create_pool_(
                verifier, cap, token_x, token_y, fee_percentage, name, symbol, ctx
            ),
            tx_context::sender(ctx)
        );
    }

    public fun create_pool_<V:drop, X, Y>(
        _verifier: V,
        _capability: &PoolCapability,
        token_x: Coin<X>,
        token_y: Coin<Y>,
        fee_percentage: u64,
        name: vector<u8>,
        symbol: vector<u8>,
        ctx: &mut TxContext
    ):Coin<LP_TOKEN<V, X, Y>>{
        let token_x_value = coin::value(&token_x);
        let token_y_value = coin::value(&token_y);

        assert!(token_x_value > 0 && token_y_value > 0, EZeroAmount);
        assert!(token_x_value < MAX_POOL_VALUE && token_y_value < MAX_POOL_VALUE, EFullPool);
        assert!(fee_percentage > 0 && fee_percentage <= 10000, EInvalidFee);

        let lp_shares = amm_math::get_l(token_x_value, token_y_value);
        let lp_supply = balance::create_supply(LP_TOKEN<V, X, Y>{});
        let lp_balance = balance::increase_supply(&mut lp_supply, lp_shares);

        let pool = Pool{
            id:object::new(ctx),
            reserve_x:coin::into_balance(token_x),
            reserve_y:coin::into_balance(token_y),
            lp_supply,
            fee_percentage,
            name:string::utf8(name),
            symbol:string::utf8(symbol),
        };
         event::emit(
            PoolCreated{
                pool:object::id(&pool),
                name: string::utf8(name),
                symbol: string::utf8(symbol),
                fee_percentage
            }
        );
        transfer::share_object(pool);
        coin::from_balance(lp_balance, ctx)
    }


    // ===== ADD_LIQUIDITY =====

    public fun add_liquidity_<V, X, Y>(
        pool: &mut Pool<V, X, Y>,
        token_x: Coin<X>,
        token_y: Coin<Y>,
        amount_x_min:u64,
        amount_y_min:u64,
        ctx:&mut TxContext
    ):Coin<LP_TOKEN<V, X, Y>>{
        let token_x_value = coin::value(&token_x);
        let token_y_value = coin::value(&token_y);
        assert!(token_x_value > 0 && token_y_value > 0, EZeroAmount);

        let (token_x_r, token_y_r, lp_supply) = get_reserves(pool);
        //quote
        let (amount_a, amount_b, coin_sui, coin_b) = if (token_x_r == 0 && token_y_r == 0){
            (token_x_value, token_y_value, token_x, token_y)
        }else{
            let opt_b  = amm_math::quote(token_x_r, token_y_r, token_x_value);
            if (opt_b <= token_y_value){
                assert!(opt_b >= amount_y_min, EInsufficientBAmount);

                let split_b = coin::take<Y>(coin::balance_mut<Y>(&mut token_y), opt_b, ctx);
                transfer::transfer(token_y, tx_context::sender(ctx));//send back the remained token
                (token_x_value, opt_b,  token_x, split_b)
            }else{
                let opt_a = amm_math::quote(token_y_r, token_x_r, token_y_value);
                assert!(opt_a <= token_x_value && opt_a >= amount_x_min, EInsufficientAAmount );

                let split_a = coin::take<X>(coin::balance_mut<X>(&mut token_x), opt_b, ctx);
                transfer::transfer(token_x, tx_context::sender(ctx));
                (opt_a, token_y_value,  split_a, token_y)
            }
        };
        let lp_output = amm_math::min(
            (amount_a * lp_supply / token_x_r),
            (amount_b * lp_supply / token_y_r)
        );
        // deposit
        let token_x_pool = balance::join<X>(&mut pool.reserve_x, coin::into_balance(coin_sui));
        let token_y_pool = balance::join<Y>(&mut pool.reserve_y,  coin::into_balance(coin_b));

        assert!(token_x_pool < MAX_POOL_VALUE ,EFullPool);
        assert!(token_y_pool < MAX_POOL_VALUE ,EFullPool);

        let output_balance = balance::increase_supply<LP_TOKEN<V, X, Y>>(&mut pool.lp_supply, lp_output);
        event::emit(
            Mint{
                sender: tx_context::sender(ctx),
                amount0: amount_a,
                amount1: amount_b
            }
        );
        coin::from_balance(output_balance, ctx)
    }

    // ===== REMOVE_LIQUIDITY =====

    public fun remove_liquidity_<V, X, Y>(
    pool:&mut Pool<V, X, Y>,
    lp_token:Coin<LP_TOKEN<V, X, Y>>,
    amount_a_min:u64,
    amount_b_min:u64,
    ctx:&mut TxContext
    ):(Coin<X>, Coin<Y>){
        let lp_value = coin::value(&lp_token);
        assert!(lp_value > 0, EZeroAmount);

        let (res_x, res_y, lp_s) = get_reserves(pool);
        let (token_x_output, token_y_output) = amm_math::withdraw_liquidity(res_x, res_y, lp_value, lp_s);
        assert!(token_x_output >= amount_a_min, EInsufficientAAmount);
        assert!(token_y_output >= amount_b_min, EInsufficientBAmount);

        balance::decrease_supply<LP_TOKEN<V, X, Y>>(&mut pool.lp_supply,coin::into_balance(lp_token));

        event::emit(
            Burn{
                sender: tx_context::sender(ctx),
                lp_token: lp_value,
                amount0: token_x_output,
                amount1: token_y_output
            }
        );
        (
            coin::take<X>(&mut pool.reserve_x, token_x_output, ctx),
            coin::take<Y>(&mut pool.reserve_y, token_y_output, ctx)
        )
    }

    // ===== SWAP =====

    //TODO: sort the token to optimize and migrate below 2 functinos
    public fun swap_token_x<V, X, Y>(
    pool: &mut Pool<V, X, Y>,
    token_x: Coin<X>,
    ctx: &mut TxContext
    ):Coin<Y>{
        let token_x_value = coin::value(&token_x);
        assert!(token_x_value >0, EZeroAmount);

        let (reserve_x, reserve_y, _) = get_reserves(pool);
        let output_amount = amm_math::get_dy(token_x_value, reserve_x, reserve_y, pool.fee_percentage, FEE_SCALING);

        let x_balance = coin::into_balance(token_x);//get the inner ownership

        event::emit(
            Swap{
                sender: tx_context::sender(ctx),
                amountIn: token_x_value,
                amountOut: output_amount
            }
        );
        balance::join<X>(&mut pool.reserve_x, x_balance);// transaction fee goes back to pool
        coin::take<Y>(&mut pool.reserve_y, output_amount, ctx)
    }

    //this could be omited as well
    public fun swap_token_y<V, X, Y>(
    pool: &mut Pool<V, X, Y>,
    token_y: Coin<Y>,
    ctx: &mut TxContext
    ):Coin<X>{
        let token_y_value = coin::value(&token_y);
        assert!(token_y_value > 0, EZeroAmount);

        let (reserve_x, reserve_y, _) = get_reserves(pool);
        assert!(reserve_x > 0 && reserve_y > 0, EReservesEmpty);

        let output_amount = amm_math::get_dy(token_y_value, reserve_y, reserve_x, pool.fee_percentage, FEE_SCALING);
        let token_y_balance = coin::into_balance(token_y);

         event::emit(
            Swap{
                sender: tx_context::sender(ctx),
                amountIn: token_y_value,
                amountOut: output_amount
            }
        );
        balance::join<Y>(&mut pool.reserve_y, token_y_balance);
        coin::take<X>(&mut pool.reserve_x, output_amount, ctx)
    }

    // ------ helper script functions -------

    /// for fetch pool info
    ///( sui_reserve, token_y_reserve, lp_token_supply)
    public fun get_reserves<V, X, Y>(pool: &Pool<V, X, Y>): (u64, u64, u64) {
        (
            balance::value(&pool.reserve_x),
            balance::value(&pool.reserve_y),
            balance::supply_value(&pool.lp_supply)
        )
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
    use sui_lipse::amm::{Self, Pool, LP_TOKEN, PoolCapability};
    use sui_lipse::amm_math;

    use std::debug;

    struct TOKEN_X {} // token_x
    struct TOKEN_Y {} //token_y

    struct JAREK has drop {}/*Verifier for pool creator*/

    // SUI/TOKEN_Y = 1000
    const SUI_AMT: u64 = 1000000; // 10^6
    const TOKEN_X_AMT:u64 = 5000000; // 5 * 10^6
    const TOKEN_Y_AMT: u64 = 1000000000; // 10^9

    const FEE_SCALING: u64 = 10000;
    const FEE: u64 = 3;

    #[test] fun test_init_pool(){
        let scenario = test::begin(&@0x1);
        test_init_pool_<JAREK, SUI, TOKEN_Y>(SUI_AMT, TOKEN_Y_AMT, &mut scenario);
    }
    #[test] fun test_init_sui_pool(){
        let scenario = test::begin(&@0x2);
        test_init_pool_<JAREK, TOKEN_X, TOKEN_Y>(TOKEN_X_AMT, TOKEN_Y_AMT, &mut scenario);
    }
     #[test] fun test_swap_sui() {
        let scenario = test::begin(&@0x1);
        test_swap_sui_<JAREK, SUI, TOKEN_Y>(SUI_AMT, TOKEN_Y_AMT, &mut scenario);
    }
     #[test] fun test_swap_token_y() {
        let scenario = test::begin(&@0x1);
        test_swap_token_y_<JAREK, SUI, TOKEN_Y>(SUI_AMT, TOKEN_Y_AMT, &mut scenario);
    }
     #[test] fun test_add_liquidity() {
        let scenario = test::begin(&@0x1);
        add_liquidity_<JAREK, SUI, TOKEN_Y>(SUI_AMT, TOKEN_Y_AMT, &mut scenario);
    }
    #[test] fun test_remove_liquidity() {
        let scenario = test::begin(&@0x1);
        remove_liquidity_<JAREK, SUI, TOKEN_Y>(SUI_AMT, TOKEN_Y_AMT, &mut scenario);
    }

    fun test_init_pool_<V, X, Y>(token_x_amt: u64, token_y_amt: u64, test:&mut Scenario) {
        let ( lp, _) = people();

        //init the module
        next_tx(test, &lp);{
            amm::init_for_testing(ctx(test));
        };

        //create pool
        next_tx(test, &lp); {
            let cap = test::take_owned<PoolCapability>(test);
            let lsp = amm::create_pool_(
                JAREK {},
                &cap,
                mint<X>(token_x_amt, ctx(test)),
                mint<Y>(token_y_amt, ctx(test)),
                FEE,
                b"SUI v1 pool",
                b"SUI-JRK",
                ctx(test)
            );

            assert!(burn(lsp) == amm_math::get_l(token_x_amt, token_y_amt), 0);
            test::return_owned<PoolCapability>(test, cap);
        };

        //shared_pool
        next_tx(test, &lp);{
            let pool = test::take_shared<Pool<V, X, Y>>(test);
            let shared_pool = test::borrow_mut(&mut pool); // shared_obj could only be mutably borrowed
            let (sui_r, token_y_r, lp_s) = amm::get_reserves<V, X, Y>(shared_pool);

            assert!(sui_r == token_x_amt,0);
            assert!(token_y_r == token_y_amt,0);
            assert!(lp_s == amm_math::get_l(token_x_amt, token_y_amt),0);

            test::return_shared(test, pool);
        };
     }

    fun test_swap_sui_<V, X, Y>(token_x_amt: u64, token_y_amt:u64, test: &mut Scenario){
        let (_, trader) = people();

         test_init_pool_<V, X, Y>(token_x_amt, token_y_amt, test);

        next_tx(test, &trader);{
            let pool = test::take_shared<Pool<V, X, Y>>(test);
            let shared_pool = test::borrow_mut(&mut pool);

            let token_y = amm::swap_token_x<V, X, Y>(shared_pool, mint<X>(5000, ctx(test)), ctx(test));

            let left = burn(token_y);
            let right = amm_math::get_dy(5000, token_x_amt, token_y_amt, FEE, FEE_SCALING);
            debug::print(&left);
            debug::print(&right);

            assert!( left == right , 0);

            test::return_shared(test, pool);
        }
    }

    fun test_swap_token_y_<V, X, Y>(token_x_amt: u64, token_y_amt:u64, test: &mut Scenario){
        let (_, trader) = people();

         test_init_pool_<V, X, Y>(token_x_amt, token_y_amt, test);

        next_tx(test, &trader);{
            let pool = test::take_shared<Pool<V, X, Y>>(test);
            let shared_pool = test::borrow_mut(&mut pool);

            let output_sui = amm::swap_token_y<V, X, Y>(shared_pool, mint<Y>(5000000, ctx(test)), ctx(test));

            assert!(burn(output_sui) == 4973,0);

            test::return_shared(test, pool);
        }
    }

    fun add_liquidity_<V, X, Y>(token_x_amt: u64, token_y_amt:u64, test: &mut Scenario){
        let (_, trader) = people();

        test_init_pool_<V, X, Y>(token_x_amt, token_y_amt, test);

        next_tx(test, &trader);{
            let pool = test::take_shared<Pool<V, X, Y>>(test);
            let shared_pool = test::borrow_mut(&mut pool);

            let output_lp = amm::add_liquidity_(shared_pool,  mint<X>(50, ctx(test)), mint<Y>(50000, ctx(test)), 50, 50000, ctx(test));

            assert!(burn(output_lp)==1581, 0);

            test::return_shared(test, pool);
        }
    }

    fun remove_liquidity_<V, X, Y>(token_x_amt: u64, token_y_amt:u64, test: &mut Scenario){
        let (owner, _) = people();

        test_swap_sui_<V, X, Y>(token_x_amt, token_y_amt, test);//Pool ( SUI_AMT + 5000, 1000000000 - 4973639)

        next_tx(test, &owner);{
            let pool = test::take_shared<Pool<V, X, Y>>(test);
            let shared_pool = test::borrow_mut(&mut pool);
            // (X, Y) = (5000000, 995026361)
            let (x, y, lp) = amm::get_reserves(shared_pool);
            let lp_token = mint<LP_TOKEN<V, X, Y>>(lp, ctx(test));
            //expected

            let (sui_withdraw, token_y_withdraw) = amm_math::withdraw_liquidity(x, y, coin::value(&lp_token),lp);

            let (withdraw_sui, withdraw_token_y) = amm::remove_liquidity_(shared_pool, lp_token, sui_withdraw, token_y_withdraw, ctx(test));

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