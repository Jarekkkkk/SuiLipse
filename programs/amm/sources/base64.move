module sui_lipse::base64{
    public fun foo ():u8{
        5
    }


}
#[test_only]
module sui_lipse::test{
    //use sui_lipse::base64;
    use std::debug::print;
    use std::vector;

    const ELAYERZERO_INVALID_LENGTH: u64 = 0;
    const ELAYERZERO_INVALID_CHARACTER: u64 = 1;


    const BASE16_CHARS: vector<u8> = b"0123456789abcdef";
    const BASE64_CHARS: vector<u8> = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const PADDING: u8 = 0x3d;
    const DECODE_LUT: vector<u8> = vector<u8>[
     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0, 1, 2,  3, 4, 5,
     6, 7,  8, 9, 255, 255, 255, 255, 255, 255, 255, 10, 11, 12, 13, 14, 15, 255,
     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
     255, 255, 255, 255, 255, 255, 255, 10, 11, 12, 13, 14, 15, 255, 255, 255, 255, 255,
     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
     255, 255, 255, 255
     ];

     public fun encode(bytes: vector<u8>): vector<u8> {
         let retval = vector::empty<u8>();
         let n = vector::length(&bytes);
         let i = 0u64;
         while (i < n) {
             let v = vector::borrow(&bytes, i);
             let c1 = vector::borrow(&BASE16_CHARS, ((*v >> 4) as u64));
             let c2 = vector::borrow(&BASE16_CHARS, ((*v & 0x0f) as u64));
             vector::push_back(&mut retval, *c1);
             vector::push_back(&mut retval, *c2);
             i = i + 1;
         };
         return retval
     }
    public fun encode_64(bytes: vector<u8>): vector<u8>{
        if (vector::length(&bytes) == 0){
            return b""
        };
        let retval = vector::empty<u8>();
        let n = vector::length(&bytes);
        let i = 0u64;
        while(i + 3 <= n){
            let v1 = vector::borrow(&bytes, i);
            let v2 = vector::borrow(&bytes, i+1);
            let v3 = vector::borrow(&bytes, i+2);
            let c1 = vector::borrow(&BASE64_CHARS, ((*v1 >> 2) as u64));
            let c2 = vector::borrow(&BASE64_CHARS, ((((*v1 & 0x03) << 4) | (*v2 >> 4)) as u64));
            let c3 = vector::borrow(&BASE64_CHARS, ((((*v2 & 0x0f) << 2) | ((*v3 & 0xc0) >> 6 )) as u64));
            let c4 = vector::borrow(&BASE64_CHARS, ((*v3 & 0x3f) as u64));
            vector::push_back(&mut retval, *c1);
            vector::push_back(&mut retval, *c2);
            vector::push_back(&mut retval, *c3);
            vector::push_back(&mut retval, *c4);
            i = i + 3;
        };

        let mod = n % 3;
        if (mod == 1){
            let v1 = vector::borrow(&bytes, i);
            let c1 = vector::borrow(&BASE64_CHARS, ((*v1 >> 2) as u64));
            let c2 = vector::borrow(&BASE64_CHARS, (((*v1 & 0x03) << 4 ) as u64));
            vector::push_back(&mut retval, *c1);
            vector::push_back(&mut retval, *c2);
            vector::push_back(&mut retval, PADDING);
            vector::push_back(&mut retval, PADDING);
        }else if(mod == 2){
            let v1 = vector::borrow(&bytes, i);
            let v2 = vector::borrow(&bytes, i + 1);
            let c1 = vector::borrow(&BASE64_CHARS, ((*v1 >> 2) as u64));
            let c2 = vector::borrow(&BASE64_CHARS, ((((*v1 & 0x03) << 4) | (*v2 >> 4)) as u64));
            let c3 = vector::borrow(&BASE64_CHARS, (((*v2 & 0x0f) << 2 ) as u64));
            vector::push_back(&mut retval, *c1);
            vector::push_back(&mut retval, *c2);
            vector::push_back(&mut retval, *c3);
            vector::push_back(&mut retval, PADDING);
        };
        return retval
    }

    public fun decode_64(bytes: vector<u8>):vector<u8>{
         if (vector::length(&bytes) == 0){
            return b""
        };
         let retval = vector::empty<u8>();
         let n = vector::length(&bytes);
         assert!(n % 4 == 0, ELAYERZERO_INVALID_LENGTH);

         if(vector::borrow(&bytes, n - 1) == &PADDING){
            n = n - 1;
            if(vector::borrow(&bytes, n - 1) == &PADDING){
                n = n - 1;
            }
         };
        let i = 0u64;
        while(i + 4 <= n){
            let s1 = vector::borrow(&bytes, i);
            let s2 = vector::borrow(&bytes, i + 1);
            let s3 = vector::borrow(&bytes, i + 2);
            let s4 = vector::borrow(&bytes, i + 3);
            let r1 = vector::borrow(&BASE64_CHARS, ((*s1) as u64));
            let r2 = vector::borrow(&BASE64_CHARS, ((*s2) as u64));
            let r3 = vector::borrow(&BASE64_CHARS, ((*s3) as u64));
            let r4 = vector::borrow(&BASE64_CHARS, ((*s4) as u64));

            print(r1);
            print(r2);
            print(r3);
            print(r4);

            i = i + 4;
        };

        return retval
    }

     public fun decode(bytes: vector<u8>): vector<u8> {
         let retval = vector::empty<u8>();
         let n = vector::length(&bytes);
         assert!(n & 1 == 0, ELAYERZERO_INVALID_LENGTH);
         let i = 0u64;
         while (i < n) {
             let s0 = vector::borrow(&bytes, i);
             let s1 = vector::borrow(&bytes, i + 1);
             let r0 = vector::borrow(&DECODE_LUT, ((*s0) as u64));
             let r1 = vector::borrow(&DECODE_LUT, ((*s1) as u64));
             assert!((*r0 | *r1) < 128u8, ELAYERZERO_INVALID_CHARACTER);
             let v = (((*r0 << 4) | *r1) as u8);
             vector::push_back(&mut retval, v);
             i = i + 2;
         };
         return retval
     }

    #[test] fun test_64(){
        let hex = b"abcde";// [48, 48, 48, 48]
        let e = encode_64(hex);
        print(&e);
        decode_64(e);
    }

    #[test] fun test_foo(){
        //convert hex to bianry
        let retval = vector::empty<u8>();
        let foo = x"a0"; //[160] Question: How to input as hex value ?
        let v = vector::borrow(&foo,0);// 160
        let c1 = vector::borrow(&BASE16_CHARS, ((*v >> 4)/*10*/ as u64));// 97 (get the first 4)
        let c2 = vector::borrow(&BASE16_CHARS, ((*v & 0x0f)/*0*/ as u64));// 48 (get the last 4)

        vector::push_back(&mut retval, *c1);
        vector::push_back(&mut retval, *c2);
    }
}