// Example Leo program for testing parser
program token.aleo {
    // Token record with visibility modifiers
    record Token {
        owner: address,
        public amount: u64
    }

    // Mapping for balances
    mapping balances: address => u64;

    // Constant
    const MAX_SUPPLY: u64 = 1000000u64;

    // Transition function for minting tokens
    async transition mint(receiver: address, amount: u64) -> Token {
        assert(amount <= MAX_SUPPLY);

        return Token {
            owner: receiver,
            amount: amount
        };
    }

    // Function to calculate total
    function calculate_total(a: u64, b: u64) -> u64 {
        let result: u64 = a + b;

        if result > MAX_SUPPLY {
            return MAX_SUPPLY;
        } else {
            return result;
        }
    }

    // Inline function with loops
    inline sum_range(start: u32, end: u32) -> u32 {
        let sum: u32 = 0u32;

        for i in start..end {
            sum += i;
        }

        return sum;
    }
}
