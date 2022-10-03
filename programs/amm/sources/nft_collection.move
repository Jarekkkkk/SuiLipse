module sui_lipse::nft_collection{
    use sui::url::{Self, Url};
    use std::ascii::{Self, String};
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::vec_set::{Self, VecSet};



    const DEFAULT_CAPACITY:u64  = 100;

    const EMaxCapacityExceeded:u64 = 1;

    struct CardCollection<phantom Card> has key {
        id:UID,
        cards: VecSet<ID>, // purpose of stroing ID
        max_capacity: u64, //current capacity is limited, for efficient consideration
    }
    //dashboard
    struct Card has key{
        id: UID,
        name: String,
        description: String,
        url: Url, //in ascii::string
    }
    //test the minimum requirement of nft standard
    struct CopyCard has key{
        id: UID,
        name: String,
        url :Url
    }

    ///for testing purpose
    public fun new_card(url: Url, ctx: &mut TxContext):CopyCard{
        CopyCard{
            id: object::new(ctx),
            name: ascii::string(b"Test minimum requirement"),
            url
        }
    }

    // ===== Events =====
    struct CollectionCreated has copy, drop{
        object_id: ID,
        creator: address,

    }

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
    public fun name(nft: &Card): &String {
        &nft.name
    }

    /// Get the NFT's `description`
    public fun description(nft: &Card): &String {
        &nft.description
    }

    /// Get the NFT's `url`
    public fun url(nft: &Card): &Url {
        &nft.url
    }

    //mock up the nft that doesn't betray the front end fetching
    fun init(ctx: &mut TxContext){
        let name = b"Crypto Jarek #-1";
        let description = b"Test NFT collection with locking features";
        let url = b"https://arweave.net/Ys5-KyxJYjywCNeEwj0n0Q3ZxF4mgoAGcmawO76qbuM";
        let creator = tx_context::sender(ctx);
         let c = CardCollection<Card>{
            id: object::new(ctx),
            cards: vec_set::empty(),
            max_capacity: DEFAULT_CAPACITY
        };

        let copy_card = CopyCard{id: object::new(ctx), name: ascii::string(b"test limiilted requirement"),url: url::new_unsafe_from_bytes(url)};

        //create collection and transfer child obj to collection
        add_(&mut c, name, description, url, object::new(ctx), creator);
        // transfer copy one to test url
        transfer::transfer(copy_card, creator);
        // send the collection to
        transfer::transfer(c, creator);
    }

    // add the cards into collection with ID
    public fun add_(
        c: &mut CardCollection<Card>,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        id: UID,
        creator: address
    ){
        let size = vec_set::size<ID>(&c.cards);
        assert!(size + 1 <= c.max_capacity, EMaxCapacityExceeded);

        //copy ID
        vec_set::insert(&mut c.cards, object::uid_to_inner(&id));
        //create NFT with UID
        let card = mint_nft_(name, description, url, id, creator);
        //let card_id = typed_id::new(&card); // return TypedID<T>

        //lock the card by transerring to collection
        transfer::transfer_to_object(card, c);
        //card_id
    }



    // ===== Entrypoints =====

    public entry fun mint_nft(
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let id = object::new(ctx);
        let creator = tx_context::sender(ctx);
        transfer::transfer(
            mint_nft_(name, description, url, id, creator),
            tx_context::sender(ctx)
        );
    }

    // create card && emit event, require UID
    public(friend) fun mint_nft_(
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        id: UID,
        creator:address
    ):Card{
        let nft = Card {
            id,
            name: ascii::string(name),
            description: ascii::string(description),
            url: url::new_unsafe_from_bytes(url)
        };

        event::emit(NFTMinted {
            object_id: object::id(&nft),
            creator,
            name: nft.name,
        });

        nft
    }

    /// Transfer `nft` to `recipient`
    public entry fun transfer(
        nft: Card, recipient: address, _: &mut TxContext
    ) {
        transfer::transfer(nft, recipient)
    }

    /// Update the `description` of `nft` to `new_description`
    public entry fun update_description(
        nft: &mut Card,
        new_description: vector<u8>,
        _: &mut TxContext
    ) {
        nft.description = ascii::string(new_description)
    }

    /// Permanently delete `nft`
    public entry fun burn(nft: Card, _: &mut TxContext) {
        let Card { id, name: _, description: _, url: _ } = nft;
        object::delete(id)
    }

    public entry fun update_nft(nft:&mut Card, new_url:vector<u8>){
        let url = &mut nft.url;

        url::update(url, ascii::string(new_url));
    }


#[test]
public fun test(){
        use sui::test_scenario;
        use std::ascii;
        use sui::url;


        let admin = @0x1111;
        //let buyer = @0x2222;

        let scenario = &mut test_scenario::begin(&admin);

        let name = b"Card";
        let url =  b"https://arweave.net/p01LagSqYNVB8eix4UJ3lf1CCYbKKxFgV2XMW4hUMTQ";
        let desc = b"Jarek's NFT collections";

        let _decoded = b"amFyZWs=";
        let _res = b"data:image/svg+xml;base64,amFyZWs=";

        {
            mint_nft(name, desc, url, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, &admin);
        {
            let nft = test_scenario::take_owned<Card>(scenario);

            let foo = name(&nft);
            let bar = description(&nft);
            let baz = url(&nft);

            assert!(foo == &ascii::string(name),1);
            assert!(bar == &ascii::string(desc),1);
            assert!(baz == &url::new_unsafe(ascii::string(url)),1);


            test_scenario::return_owned<Card>(scenario, nft);
        };
}
}





