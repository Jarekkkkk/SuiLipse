module sui_lipse::amm_pair{
    use sui::tx_context::TxContext;
    use sui_lipse::amm;

    /// only moduler publisher can create the pool
    /// no type argument required sicnce it could be applied to all kinds of pool

    //verifier, with this struct, wec could add the restriction into this module
    struct SUI_JRK has drop {}


    fun init(ctx: &mut TxContext){
        amm::create_capability(SUI_JRK{}, ctx);
    }
}