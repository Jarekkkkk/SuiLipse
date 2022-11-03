module sui_lipse::amm{
    use sui::object::{Self,UID, ID};
    use sui::balance::{Self,Supply, Balance};
    use sui::coin::{Self,Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui_lipse::amm_math;
    use sui::vec_set::{Self, VecSet};
    use std::type_name;
    use std::vector;

    // ===== EVENT =====
    /// input amount is zero, including 'pair of assets<X,Y>' and 'LP_TOKEN'
    const ERR_Zero_Amount:u64 = 0;
    /// when one of pair tokens is empty
    const ERR_Reserves_Empty:u64 = 1;
    /// incoreect fee range, [0,100000]
    const ERR_Invalid_Fee:u64 = 2;
    /// when Pool is over MAX_POOL_VALUE
    const ERR_Full_Pool:u64 = 3;
    /// when signer is not included in list
    const ERR_Not_Guardians:u64 = 4;
    /// quoted amount is mismatched with input
    const ERR_Insufficient_A_Amount:u64 = 6;
    const ERR_Insufficient_B_Amount:u64 = 7;
    /// minimum of Liquiditya to prevent math rounding problems
    const MINIMUM_LIQUIDITY:u128 = 10;
    // == TYPE ==
    const ERR_PAIR_CANT_BE_SAME_TYPE: u64 = 11;
    const ERR_WRONG_PAIR_ORDERING: u64 = 12;
    /// safety
    const ERR_POOL_IS_LOCKED: u64 = 111;
    const ERR_ALREADY_EMERGENCY: u64 = 112;
    const ERR_EMERGENCY: u64 = 113;
    /// For fees calculation
    const FEE_SCALING:u64 = 10000;
    /// - Max stored value for both tokens is: U64_MAX / 10_000
    const MAX_POOL_VALUE: u64 = {
        18446744073709551615/*U64_MAX*/ / 10000
    };

    // ===== Object =====
    struct AMM_V2 has drop {}
    //must be `uppercase` to become one-time witness
    struct LP_TOKEN<phantom V, phantom X, phantom Y> has drop {}
    struct Guardians has key{
        id: UID,
        guardians: VecSet<address>//only guardians can create pool
    }
    //only guardians could own PoolCapability
    struct PoolCapability has key, store {
        id: UID,
        //could config further features, ex: individually flexible fee rated
    }
    struct PoolIdsList has key {
        id: UID,
        pool_ids: VecSet<address>
    }
    struct Pool<phantom V, phantom X, phantom Y> has key{
        id: UID,
        reserve_x: Balance<X>,
        reserve_y: Balance<Y>,
        lp_supply: Supply<LP_TOKEN<V, X, Y>>,
        fee_percentage:u64, // 1 equals to 0.01%
        last_block_timestamp: u64,
        last_price_x_cumulative: u128,
        last_price_y_cumulative: u128,
        locked: bool, //for flashlaod usage
        emergency: bool
    }

    // ===== Events =====
    struct PoolCapabilityCreatedEvent has copy, drop{
        pool_capability_id: ID
    }
    struct PoolCreatedEvent has copy, drop{
        pool_id: ID,
        creator: address
    }
    struct LiquidityAddedEvent<phantom V, phantom X, phantom Y> has copy, drop{
        added_amount_0:u64,
        added_amount_1:u64,
        lp_tokens_received: u64
    }
    struct LiquidityRemovedEvent<phantom V, phantom X, phantom Y> has copy, drop{
        returned_amount_0:u64,
        returned_amount_1:u64,
        lp_tokens_removed: u64
    }
    struct SwapEvent<phantom V, phantom X, phantom Y> has copy, drop{
        coin0_in: u64,
        coin1_out: u64,
    }
    struct OracleUpdatedEvent<phantom V, phantom X, phantom Y> has copy, drop {
        last_price_cumulative_0: u128,
        last_price_cumulative_1: u128,
    }

    // ===== Assertion =====
    fun assert_pool_unlocked<V, X, Y>(pool: &Pool<V, X, Y>){
        assert!(!pool.locked, ERR_POOL_IS_LOCKED);
    }
    fun assert_no_emergency<V, X, Y>(pool: &Pool<V, X, Y> ){
        assert!(!pool.emergency, ERR_EMERGENCY);
    }
    fun assert_sorted<X, Y>() {
        let coin_x_name = type_name::into_string(type_name::get<X>());
        let coin_y_name = type_name::into_string(type_name::get<Y>());

        assert!(coin_x_name != coin_y_name, ERR_PAIR_CANT_BE_SAME_TYPE);

        let coin_x_bytes = std::ascii::as_bytes(&coin_x_name);
        let coin_y_bytes = std::ascii::as_bytes(&coin_y_name);

        assert!(vector::length<u8>(coin_x_bytes) <= vector::length<u8>(coin_y_bytes), ERR_WRONG_PAIR_ORDERING);

        if (vector::length<u8>(coin_x_bytes) == vector::length<u8>(coin_y_bytes)) {
            let count = vector::length<u8>(coin_x_bytes);
            let i = 0;
            while (i < count) {
                assert!(*vector::borrow<u8>(coin_x_bytes, i) <= *vector::borrow<u8>(coin_y_bytes, i), ERR_WRONG_PAIR_ORDERING);
            }
        };
    }

    // ===== Utils =====
    fun block_timestamp():u64{
        1
    }

    // ===== Entry Functions =====
    /// for guardians creating type when publishing the module
    entry fun create_capability(guardians: &Guardians, ctx: &mut TxContext){
        let pool = create_capability_(ctx);
        let pool_capability_id = object::id(&pool);
        let sender = tx_context::sender(ctx);

        assert!(vec_set::contains<address>(&guardians.guardians, &sender), ERR_Not_Guardians);

        transfer::transfer(
           pool,
            tx_context::sender(ctx)
        );

        event::emit(
            PoolCapabilityCreatedEvent{
                pool_capability_id
            }
        );
    }
    entry fun change_emergency<V, X, Y>(
        pool: &mut Pool<V, X, Y>,
        _cap: &PoolCapability,
    ){
        assert!(pool.emergency == false, ERR_ALREADY_EMERGENCY);
        pool.emergency = true;
    }
    /// only guardians could create pool by passing the witness type
    entry fun create_pool<V, X, Y>(
        _cap: &PoolCapability,
        pool_list:&mut PoolIdsList,
        token_x: Coin<X>,
        token_y: Coin<Y>,
        fee_percentage: u64,
        ctx: &mut TxContext
    ){
        let pool = create_pool_<V, X, Y>(
                pool_list, token_x, token_y, fee_percentage, ctx
            );
        let pool_id = object::id(&pool);

        transfer::share_object(
            pool
        );

        event::emit(
            PoolCreatedEvent{
                pool_id,
                creator: tx_context::sender(ctx)
            }
        );
    }
    entry fun add_liquidity<V, X, Y>(
        pool: &mut Pool<V, X, Y>,
        token_x: Coin<X>,
        token_y: Coin<Y>,
        amount_x_min:u64,
        amount_y_min:u64,
        ctx:&mut TxContext
    ){
        assert_no_emergency(pool);
        assert_pool_unlocked(pool);

        let (output_lp_coin, amount_a, amount_b, lp_output) = add_liquidity_(pool, token_x, token_y, amount_x_min, amount_y_min, ctx);

        transfer::transfer(
            output_lp_coin,
            tx_context::sender(ctx)
        );

         event::emit(
            LiquidityAddedEvent<V, X, Y>{
                added_amount_0:amount_a,
                added_amount_1:amount_b,
                lp_tokens_received: lp_output
            }
        );
    }
    entry fun remove_liquidity<V, X, Y>(
        pool:&mut Pool<V, X, Y>,
        lp_token:Coin<LP_TOKEN<V, X, Y>>,
        amount_a_min:u64,
        amount_b_min:u64,
        ctx:&mut TxContext
    ){
        assert_no_emergency(pool);
        assert_pool_unlocked(pool);

        let (returned_x, returned_y, lp_value) = remove_liquidity_(pool, lp_token, amount_a_min, amount_b_min, ctx);
        let token_x_output = coin::value(&returned_x);
        let token_y_output = coin::value(&returned_y);

        transfer::transfer(
            returned_x,
            tx_context::sender(ctx)
        );
        transfer::transfer(
            returned_y,
            tx_context::sender(ctx)
        );

        event::emit(
            LiquidityRemovedEvent<V ,X, Y>{
                returned_amount_0:token_x_output,
                returned_amount_1:token_y_output,
                lp_tokens_removed: lp_value
            }
        );
    }
    entry fun swap_token_x<V, X, Y>(
        pool: &mut Pool<V, X, Y>,
        token_x: Coin<X>,
        ctx: &mut TxContext
    ){
        assert_no_emergency(pool);
        assert_pool_unlocked(pool);

        let (coin_x, input_value, output_value) = swap_token_x_(pool, token_x, ctx);

        transfer::transfer(coin_x, tx_context::sender(ctx));

        event::emit(
            SwapEvent<V , X, Y>{
                coin0_in: input_value,
                coin1_out: output_value,
            }
        );
    }
    entry fun swap_token_y<V, X, Y>(
        pool: &mut Pool<V, X, Y>,
        token_y: Coin<Y>,
        ctx: &mut TxContext
    ){
        assert_no_emergency(pool);
        assert_pool_unlocked(pool);

        let (coin_y, coin0_in, coin1_out) = swap_token_y_(pool, token_y, ctx);

        transfer::transfer(
            coin_y,
            tx_context::sender(ctx)
        );

        event::emit(
            SwapEvent<V, X, Y>{
                coin0_in,
                coin1_out
            }
        );
    }

    // ====== MAIN_LOGIC ======
    fun init(ctx:&mut TxContext){
        let guardians = vec_set::empty<address>();
        vec_set::insert(&mut guardians, tx_context::sender(ctx));

        // guardians
        let guardians =  Guardians{
            id: object::new(ctx),
            guardians
        };
        transfer::share_object(
            guardians
        );

        //capability
        transfer::transfer(create_capability_(ctx),tx_context::sender(ctx));

        // pool_list
        let pool_id = object::new(ctx);
        transfer::share_object(
            PoolIdsList{
                id: pool_id,
                pool_ids: vec_set::empty<address>()
            }
        );
    }
    fun create_capability_(ctx: &mut TxContext):PoolCapability{
        PoolCapability{
            id: object::new(ctx)
        }
    }

    public fun create_pool_<V, X, Y>(
        pool_list:&mut PoolIdsList,
        token_x: Coin<X>,
        token_y: Coin<Y>,
        fee_percentage: u64,
        ctx: &mut TxContext
    ):Coin<LP_TOKEN<V, X, Y>>{
        let token_x_value = coin::value(&token_x);
        let token_y_value = coin::value(&token_y);

        assert!(token_x_value > 0 && token_y_value > 0, ERR_Zero_Amount);
        assert!(token_x_value < MAX_POOL_VALUE && token_y_value < MAX_POOL_VALUE, ERR_Full_Pool);
        assert!(fee_percentage > 0 && fee_percentage <= 10000, ERR_Invalid_Fee);

        let lp_shares = amm_math::get_l(token_x_value, token_y_value);
        let lp_supply = balance::create_supply(LP_TOKEN<V, X, Y>{});
        let lp_balance = balance::increase_supply(&mut lp_supply, lp_shares);

        let pool_id = object::new(ctx);
        let pool = Pool{
            id:pool_id,
            reserve_x:coin::into_balance(token_x),
            reserve_y:coin::into_balance(token_y),
            lp_supply,
            fee_percentage,
            last_block_timestamp: block_timestamp(),
            last_price_x_cumulative: 0,
            last_price_y_cumulative: 0,
            locked: false,
            emergency: false
        };
        vec_set::insert(&mut pool_list.pool_ids, object::id_address(&pool));
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
    ):(
        Coin<LP_TOKEN<V, X, Y>>,
        u64,
        u64,
        u64
    ){
        let token_x_value = coin::value(&token_x);
        let token_y_value = coin::value(&token_y);
        assert!(token_x_value > 0 && token_y_value > 0, ERR_Zero_Amount);

        let (token_x_r, token_y_r, lp_supply) = get_reserves(pool);
        //quotget_current_time_secondse

        let (amount_a, amount_b, coin_sui, coin_b) = if (token_x_r == 0 && token_y_r == 0){
            (token_x_value, token_y_value, token_x, token_y)
        }else{
            let opt_b  = amm_math::quote(token_x_r, token_y_r, token_x_value);
            if (opt_b <= token_y_value){
                assert!(opt_b >= amount_y_min, ERR_Insufficient_B_Amount);

                let split_b = coin::take<Y>(coin::balance_mut<Y>(&mut token_y), opt_b, ctx);
                transfer::transfer(token_y, tx_context::sender(ctx));//send back the remained token
                (token_x_value, opt_b,  token_x, split_b)
            }else{
                let opt_a = amm_math::quote(token_y_r, token_x_r, token_y_value);
                assert!(opt_a <= token_x_value && opt_a >= amount_x_min, ERR_Insufficient_A_Amount );

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

        assert!(token_x_pool < MAX_POOL_VALUE ,ERR_Full_Pool);
        assert!(token_y_pool < MAX_POOL_VALUE ,ERR_Full_Pool);

        let output_balance = balance::increase_supply<LP_TOKEN<V, X, Y>>(&mut pool.lp_supply, lp_output);

        return (
            coin::from_balance(output_balance, ctx),
            lp_output,
            amount_a,
            amount_b
        )
    }

    // ===== REMOVE_LIQUIDITY =====

    public fun remove_liquidity_<V, X, Y>(
        pool:&mut Pool<V, X, Y>,
        lp_token:Coin<LP_TOKEN<V, X, Y>>,
        amount_a_min:u64,
        amount_b_min:u64,
        ctx:&mut TxContext
    ):(
        Coin<X>,
        Coin<Y>,
        u64,
    ){
        let lp_value = coin::value(&lp_token);
        assert!(lp_value > 0, ERR_Zero_Amount);

        let (res_x, res_y, lp_s) = get_reserves(pool);
        let (token_x_output, token_y_output) = amm_math::withdraw_liquidity(res_x, res_y, lp_value, lp_s);
        assert!(token_x_output >= amount_a_min, ERR_Insufficient_A_Amount);
        assert!(token_y_output >= amount_b_min, ERR_Insufficient_B_Amount);

        balance::decrease_supply<LP_TOKEN<V, X, Y>>(&mut pool.lp_supply,coin::into_balance(lp_token));

        return (
            coin::take<X>(&mut pool.reserve_x, token_x_output, ctx),
            coin::take<Y>(&mut pool.reserve_y, token_y_output, ctx),
            lp_value
        )
    }

    // ===== SWAP =====

    //TODO: sort the token to optimize and migrate below 2 functinos
    public fun swap_token_x_<V, X, Y>(
        pool: &mut Pool<V, X, Y>,
        token_x: Coin<X>,
        ctx: &mut TxContext
    ):(
        Coin<Y>,
        u64,
        u64
    ){
        let token_x_value = coin::value(&token_x);
        assert!(token_x_value >0, ERR_Zero_Amount);

        let (reserve_x, reserve_y, _) = get_reserves(pool);
        let output_amount = amm_math::get_output(token_x_value, reserve_x, reserve_y, pool.fee_percentage, FEE_SCALING);

        let x_balance = coin::into_balance(token_x);//get the inner ownership


        balance::join<X>(&mut pool.reserve_x, x_balance);// transaction fee goes back to pool

        return(
            coin::take<Y>(&mut pool.reserve_y, output_amount, ctx),
            token_x_value,
            output_amount
        )
    }

    //this could be omited as well
    public fun swap_token_y_<V, X, Y>(
        pool: &mut Pool<V, X, Y>,
        token_y: Coin<Y>,
        ctx: &mut TxContext
    ):(
        Coin<X>,
        u64,
        u64
    ){
        let token_y_value = coin::value(&token_y);
        assert!(token_y_value > 0, ERR_Zero_Amount);

        let (reserve_x, reserve_y, _) = get_reserves(pool);
        assert!(reserve_x > 0 && reserve_y > 0, ERR_Reserves_Empty);

        let output_amount = amm_math::get_output(token_y_value, reserve_y, reserve_x, pool.fee_percentage, FEE_SCALING);
        let token_y_balance = coin::into_balance(token_y);

        balance::join<Y>(&mut pool.reserve_y, token_y_balance);

        return (
            coin::take<X>(&mut pool.reserve_x, output_amount, ctx),
            token_y_value,
            output_amount
        )
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
    use sui::coin::{ Self, mint_for_testing as mint, destroy_for_testing as burn};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui_lipse::amm::{Self, Pool, PoolCapability, PoolIdsList ,LP_TOKEN};
    use sui_lipse::amm_math;
    //use std::debug;

    struct TOKEN_X {} // token_x
    struct TOKEN_Y {} //token_y

    struct AMM_V2 has drop {} //Verifier for pool creator


    // SUI/TOKEN_Y = 1000
    const SUI_AMT: u64 = 1000000; // 10^6
    const TOKEN_X_AMT:u64 = 5000000; // 5 * 10^6
    const TOKEN_Y_AMT: u64 = 1000000000; // 10^9

    const FEE_SCALING: u64 = 10000;
    const FEE: u64 = 3;

    #[test] fun test_init_pool(){
        let scenario = test::begin(@0x1);
        test_init_pool_<AMM_V2, SUI, TOKEN_Y>(SUI_AMT, TOKEN_Y_AMT, &mut scenario);
        test::end(scenario);
    }
    #[test] fun test_init_sui_pool(){
        let scenario = test::begin(@0x2);
        test_init_pool_<AMM_V2, TOKEN_X, TOKEN_Y>(TOKEN_X_AMT, TOKEN_Y_AMT, &mut scenario);
        test::end(scenario);
    }
     #[test] fun test_swap_sui() {
        let scenario = test::begin(@0x1);
        test_swap_sui_<AMM_V2, SUI, TOKEN_Y>(SUI_AMT, TOKEN_Y_AMT, &mut scenario);
        test::end(scenario);
    }
     #[test] fun test_swap_token_y() {
        let scenario = test::begin(@0x1);
        test_swap_token_y_<AMM_V2, SUI, TOKEN_Y>(SUI_AMT, TOKEN_Y_AMT, &mut scenario);
        test::end(scenario);
    }
     #[test] fun test_add_liquidity() {
        let scenario = test::begin(@0x1);
        add_liquidity_<AMM_V2, SUI, TOKEN_Y>(SUI_AMT, TOKEN_Y_AMT, &mut scenario);
        test::end(scenario);
    }
    #[test] fun test_remove_liquidity() {
        let scenario = test::begin(@0x1);
        remove_liquidity_<AMM_V2, SUI, TOKEN_Y>(SUI_AMT, TOKEN_Y_AMT, &mut scenario);
        test::end(scenario);
    }

    fun test_init_pool_<V, X, Y>(token_x_amt: u64, token_y_amt: u64, test:&mut Scenario) {
        let ( lp, _) = people();

        next_tx(test, lp);{
            //init the module
            amm::init_for_testing(ctx(test));
        };

        //create pool
        next_tx(test, lp); {
            let pool_list = test::take_shared<PoolIdsList>(test);
            let cap = test::take_from_sender<PoolCapability>(test);
            let lsp = amm::create_pool_<AMM_V2, X, Y>(
                &mut pool_list,
                mint<X>(token_x_amt, ctx(test)),
                mint<Y>(token_y_amt, ctx(test)),
                FEE,
                ctx(test)
            );

            assert!(burn(lsp) == amm_math::get_l(token_x_amt, token_y_amt), 0);
            test::return_to_sender<PoolCapability>(test, cap);
            test::return_shared(pool_list);
        };

        //shared_pool
        next_tx(test, lp);{
            let pool = test::take_shared<Pool<V, X, Y>>(test);
            //let shared_pool = test::borrow_mut(&mut pool); // shared_obj could only be mutably borrowed
            let (sui_r, token_y_r, lp_s) = amm::get_reserves<V, X, Y>(&mut pool);

            assert!(sui_r == token_x_amt,0);
            assert!(token_y_r == token_y_amt,0);
            assert!(lp_s == amm_math::get_l(token_x_amt, token_y_amt),0);

            test::return_shared(pool);
        };
     }

    fun test_swap_sui_<V, X, Y>(token_x_amt: u64, token_y_amt:u64, test: &mut Scenario){
        let (_, trader) = people();

         test_init_pool_<V, X, Y>(token_x_amt, token_y_amt, test);

        next_tx(test, trader);{
            let pool = test::take_shared<Pool<V, X, Y>>(test);
            //let shared_pool = test::borrow_mut(&mut pool);

            let (token_y, _, _) = amm::swap_token_x_<V, X, Y>(&mut pool, mint<X>(5000, ctx(test)), ctx(test));

            let left = burn(token_y);
            let right = amm_math::get_output(5000, token_x_amt, token_y_amt, FEE, FEE_SCALING);

            assert!( left == right , 0);

            test::return_shared(pool);
        }
    }

    fun test_swap_token_y_<V, X, Y>(token_x_amt: u64, token_y_amt:u64, test: &mut Scenario){
        let (_, trader) = people();

        test_init_pool_<V, X, Y>(token_x_amt, token_y_amt, test);

        next_tx(test, trader);{
            let pool = test::take_shared<Pool<V, X, Y>>(test);
            //let shared_pool = test::borrow_mut(&mut pool);

            let (output_sui, _, _) = amm::swap_token_y_<V, X, Y>(&mut pool, mint<Y>(5000000, ctx(test)), ctx(test));

            assert!(burn(output_sui) == 4973,0);

            test::return_shared(pool);
        }
    }

    fun add_liquidity_<V, X, Y>(token_x_amt: u64, token_y_amt:u64, test: &mut Scenario){
        let (creator, trader) = people();
        next_tx(test, creator);{
            test_init_pool_<V, X, Y>(token_x_amt, token_y_amt, test);
        };

        next_tx(test, trader);{
            let pool = test::take_shared<Pool<V, X, Y>>(test);
            //let shared_pool = test::borrow_mut(&mut pool);

            let (output_lp, _, _, _) = amm::add_liquidity_(&mut pool,  mint<X>(50, ctx(test)), mint<Y>(50000, ctx(test)), 50, 50000, ctx(test));

            assert!(burn(output_lp)==1581, 0);

            test::return_shared(pool);
        }
    }

    fun remove_liquidity_<V, X, Y>(token_x_amt: u64, token_y_amt:u64, test: &mut Scenario){
        let (owner, _) = people();

        test_swap_sui_<V, X, Y>(token_x_amt, token_y_amt, test);//Pool ( SUI_AMT + 5000, 1000000000 - 4973639)

        next_tx(test, owner);{
            let pool = test::take_shared<Pool<V, X, Y>>(test);
            //let shared_pool = test::borrow_mut(&mut pool);
            // (X, Y) = (5000000, 995026361)
            let (x, y, lp) = amm::get_reserves(&mut pool);
            let lp_token = mint<LP_TOKEN<V, X, Y>>(lp, ctx(test));
            //expected

            let (sui_withdraw, token_y_withdraw) = amm_math::withdraw_liquidity(x, y, coin::value(&lp_token),lp);

            let (withdraw_sui, withdraw_token_y, _) = amm::remove_liquidity_(&mut pool, lp_token, sui_withdraw, token_y_withdraw, ctx(test));

            //after withdraw
            let (sui, token_y, lp_supply) = amm::get_reserves(&mut pool);

            assert!(sui == 0,0);
            assert!(token_y== 0, 0);
            assert!(lp_supply == 0, 0);
            assert!(burn(withdraw_sui) == sui_withdraw, 0);
            assert!(burn(withdraw_token_y) == token_y_withdraw, 0);

            test::return_shared(pool);
        }
    }
    //utilities
    fun people(): (address, address) { (@0xABCD, @0x1234 ) }
}