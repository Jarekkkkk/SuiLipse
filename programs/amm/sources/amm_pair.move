module sui_lipse::amm_pair{


    /// only moduler publisher can create the pool
    /// no type argument required sicnce it could be applied to all kinds of pool

    //verifier, with this struct, wec could add the restriction into this module
    struct AMM_V2 has drop {}
    struct AMM_V3 has drop {}
    struct StableCurve has drop {}
    struct ConstantCurve has drop {}
}