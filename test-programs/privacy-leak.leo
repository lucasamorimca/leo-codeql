// VULNERABLE: Leaks private data to finalize function
// This should trigger the PrivacyLeakToFinalize detector
program privacy_leak.aleo {
    // Token with private balance field
    record Token {
        owner: address,
        amount: u64,
    }

    mapping public_balances: address => u64;

    // VULNERABILITY: Passes private token.amount directly to finalize
    // Private record fields should never be exposed to public finalize functions
    async transition leak_private_balance(
        token: Token,
        public recipient: address
    ) -> (Token, Future) {
        let new_token: Token = Token {
            owner: recipient,
            amount: token.amount,
        };

        // BUG: token.amount is private but passed to public async function
        let f: Future = finalize_leak(recipient, token.amount);
        return (new_token, f);
    }

    async function finalize_leak(recipient: address, amount: u64) {
        // This async function receives private data, creating a privacy leak
        Mapping::set(public_balances, recipient, amount);
    }

    // Another example: leaking private field in calculation
    async transition leak_in_expression(
        token: Token
    ) -> Future {
        // VULNERABILITY: Using private token.amount in public async function call
        let doubled: u64 = token.amount * 2u64;
        let f: Future = finalize_doubled(token.owner, doubled);
        return f;
    }

    async function finalize_doubled(owner: address, amount: u64) {
        Mapping::set(public_balances, owner, amount);
    }
}
