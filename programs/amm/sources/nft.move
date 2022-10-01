module sui_lipse::nft{
    use sui::url::{Self, Url};
    use std::ascii::{Self, String};
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::vec_set::VecSet;
    use sui_lipse::nft_collection::new_card;

    friend sui_lipse::amm_script;

    const PREFIX:vector<u8> = b"data:image/svg+xml;base64,";

    struct Collection has key {
        id:UID,
        cards: VecSet<ID>,
        max_capacity: u64, //current capacity is limited, for efficient consideration
    }
    // store: capable of being stored
    // key: capable of contain objects with store
    // IMPORTANT !!!: The transferred object's type must be defined in the current module, or must have the 'store' type ability"
    // to be easily transferred off chain by "transfer::transfer"
    struct JarekNFT has key, store{
        id: UID,
        name: String,
        description: String,
        url: Url, //in ascii::string
    }

    #[test]
    public fun test_trasnfer_obj_without_store() {
        use sui::tx_context;

        let ctx = tx_context::dummy();

        let url = b"https://arweave.net/p01LagSqYNVB8eix4UJ3lf1CCYbKKxFgV2XMW4hUMTQ";

        let card = new_card(url::new_unsafe_from_bytes(url), &mut ctx);
        transfer::transfer(card, tx_context::sender(&ctx));

    }

    // ===== Events =====

    struct NFTMinted has copy, drop {
        // The Object ID of the NFT
        object_id: ID,
        // The creator of the NFT
        creator: address,
        // The name of the NFT
        name: String,
    }

    // ===== Public view functions =====

    /// Get the NFT's `name`
    public fun name(nft: &JarekNFT): &String {
        &nft.name
    }

    /// Get the NFT's `description`
    public fun description(nft: &JarekNFT): &String {
        &nft.description
    }

    /// IMOPRTANT!!!, even the attribute of object is differnet, it could still deserialzie, howerver, still not sure whether check owned_obj
    public fun url(nft: &JarekNFT): &Url {
        &nft.url
    }

    fun init(ctx: &mut TxContext){
        transfer::transfer(
            mint_nft_(
                b"Jarek",
                b"This is Jarek's collection",
                b"https://arweave.net/p01LagSqYNVB8eix4UJ3lf1CCYbKKxFgV2XMW4hUMTQ",
                ctx
            ),
            tx_context::sender(ctx)
        )
    }

    // ===== Entrypoints =====

    /// Create a new devnet_nft
    public entry fun mint_nft(
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ) {
        transfer::transfer(
            mint_nft_(name, description, url, ctx),
            tx_context::sender(ctx)
        );
    }
    public(friend) fun mint_nft_(
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ):JarekNFT{
        let nft = JarekNFT {
            id: object::new(ctx),
            name: ascii::string(name),
            description: ascii::string(description),
            url: url::new_unsafe_from_bytes(url)
        };

        event::emit(NFTMinted {
            object_id: object::id(&nft),
            creator: tx_context::sender(ctx),
            name: nft.name,
        });

        nft
    }

    /// Transfer `nft` to `recipient`
    public entry fun transfer(
        nft: JarekNFT, recipient: address, _: &mut TxContext
    ) {
        transfer::transfer(nft, recipient)
    }

    /// Update the `description` of `nft` to `new_description`
    public entry fun update_description(
        nft: &mut JarekNFT,
        new_description: vector<u8>,
        _: &mut TxContext
    ) {
        nft.description = ascii::string(new_description)
    }

    /// Permanently delete `nft`
    public entry fun burn(nft: JarekNFT, _: &mut TxContext) {
        let JarekNFT { id, name: _, description: _, url: _ } = nft;
        object::delete(id)
    }

    public entry fun update_nft(nft:&mut JarekNFT, new_url:vector<u8>){
        let url = &mut nft.url;

        url::update(url, ascii::string(new_url));
    }


    // unworked
    // public entry fun update_svg(nft:&mut JarekNFT, base64_data:vector<u8>){
    //     let prefix = ascii::string(PREFIX);
    //     let prefix = ascii::into_bytes(prefix);
    //     vector::append(&mut prefix, base64_data);

    //     let url = &mut nft.url;
    //     url::update(url, ascii::string(prefix));
    // }

#[test]
public fun test(){
        use sui::test_scenario;
        use std::ascii;
        use sui::url;


        let admin = @0x1111;
        //let buyer = @0x2222;

        let scenario = &mut test_scenario::begin(&admin);

        let name = b"JarekNFT";
        let url =  b"https://arweave.net/p01LagSqYNVB8eix4UJ3lf1CCYbKKxFgV2XMW4hUMTQ";
        let desc = b"Jarek's NFT collections";

        let _decoded = b"amFyZWs=";
        let _res = b"data:image/svg+xml;base64,amFyZWs=";

        {
            mint_nft(name, desc, url, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, &admin);
        {
            let nft = test_scenario::take_owned<JarekNFT>(scenario);

            let foo = name(&nft);
            let bar = description(&nft);
            let baz = url(&nft);

            assert!(foo == &ascii::string(name),1);
            assert!(bar == &ascii::string(desc),1);
            assert!(baz == &url::new_unsafe(ascii::string(url)),1);


            test_scenario::return_owned<JarekNFT>(scenario, nft);
        };



}
}





