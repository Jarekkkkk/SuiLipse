module sui_lipse::sbt{
    use sui::url::{Self, Url};
    use sui::object::UID;
    use sui::tx_context::{TxContext};
    use std::ascii::{Self};
    use std::vector;

    struct SBT has key{
        id: UID,
        url: Url
    }

    public entry fun update_url(sbt: &mut SBT, url: vector<u8>, _:&mut TxContext){
        let url = ascii::string(url);
        url::update(&mut sbt.url, url);
    }

    fun prefix_svg(data: vector<u8>):vector<u8>{
        let prefix = b"data:appl cation/json;base64,";
        vector::append(&mut prefix, data);
        prefix
    }


    #[test]
    fun test_sbt(){
        use sui::tx_context;
        //use std::ascii;
        use sui::url;
        use sui::object;
        use sui::transfer;
        use std::debug;



        let url = b"sdf";

        let ctx = tx_context::dummy();
        let sbt = SBT{
            id: object::new(&mut ctx),
            url: url::new_unsafe_from_bytes(url)
        };
{        debug::print(&sbt);
        update_url(&mut sbt, b"123", &mut ctx);};

        let foo = b"123";
        let res = b"data:appl cation/json;base64,123";

        let foo = prefix_svg(foo);
        debug::print(&foo);

        assert!(foo==res, 1);

        transfer::transfer(sbt, @0x00);
    }


}



