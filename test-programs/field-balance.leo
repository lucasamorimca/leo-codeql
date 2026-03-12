// VULNERABLE: Uses field type for balance values
// This should trigger the FieldTypeForBalance detector
program field_balance.aleo {
    // VULNERABILITY: Using field type for amount instead of u64/u128
    // field type can represent negative values and has no overflow protection
    record Token {
        owner: address,
        amount: field,
    }

    // VULNERABILITY: field used for balance storage
    mapping balances: address => field;

    // VULNERABILITY: field used for total_supply
    mapping total_supply: field => field;

    // Mint function using field arithmetic
    async transition mint(
        public receiver: address,
        public amount: field
    ) -> (Token, Future) {
        let token: Token = Token {
            owner: receiver,
            amount: amount,
        };

        return (token, finalize_mint(receiver, amount));
    }

    finalize finalize_mint(receiver: address, amount: field) {
        // BUG: field arithmetic has no overflow checks
        let current: field = Mapping::get_or_use(balances, receiver, 0field);
        Mapping::set(balances, receiver, current + amount);

        let supply: field = Mapping::get_or_use(total_supply, 0field, 0field);
        Mapping::set(total_supply, 0field, supply + amount);
    }

    // Transfer with field subtraction (no underflow protection)
    transition transfer(
        token: Token,
        public to: address,
        public amount: field
    ) -> (Token, Token) {
        // BUG: No protection against negative balances
        let remaining: Token = Token {
            owner: token.owner,
            amount: token.amount - amount,
        };

        let transferred: Token = Token {
            owner: to,
            amount: amount,
        };

        return (remaining, transferred);
    }

    // Function calculating with field type
    function calculate_total(a: field, b: field, c: field) -> field {
        // VULNERABILITY: field arithmetic in financial calculations
        let total: field = a + b + c;
        return total;
    }
}
