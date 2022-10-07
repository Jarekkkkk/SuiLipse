module sui_lipse::amm_pair{
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;

    use sui_lipse::amm;

    /// only moduler publisher can create the pool
    /// no type argument required sicnce it could be applied to all kinds of pool
    struct PoolCapability<phantom V> has key, store {
        id: UID,
    }

    //verifier, with this struct, wec could add the restriction into this module
    struct SUI_JRK has drop {}


    fun init<V: drop>(ctx: &mut TxContext){
        let cap = PoolCapability<SUI_JRK>{
            id: object::new(ctx)
        };

        transfer::transfer(
            cap,
            tx_context::sender(ctx)
        );
    }
}