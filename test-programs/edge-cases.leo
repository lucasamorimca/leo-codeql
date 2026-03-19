// Edge cases test program for Leo extractor
// Tests: for loops, arrays, tuples, nested ternary, casts
program edge_cases.aleo {
    record State {
        owner: address,
        value: u64,
    }

    // Test for loops with arrays
    transition process_array(public data: [u32; 5]) -> u32 {
        let sum: u32 = 0u32;
        for i: u8 in 0u8..5u8 {
            sum += data[i];
        }
        return sum;
    }

    // Test tuples and destructuring
    transition swap_values(public a: u64, public b: u64) -> (u64, u64) {
        let pair: (u64, u64) = (b, a);
        return pair;
    }

    // Test nested ternary expressions
    transition nested_conditional(
        public x: u32,
        public y: u32,
        public flag1: bool,
        public flag2: bool
    ) -> u32 {
        let result: u32 = flag1
            ? (flag2 ? x : y)
            : (flag2 ? y : x);
        return result;
    }

    // Test type casts
    transition cast_values(public small: u8) -> u64 {
        let medium: u32 = small as u32;
        let large: u64 = medium as u64;
        return large;
    }

    // Test array with cast and loop
    function compute_checksum(data: [u8; 4]) -> u32 {
        let checksum: u32 = 0u32;
        for i: u8 in 0u8..4u8 {
            checksum += data[i] as u32;
        }
        return checksum;
    }
}
