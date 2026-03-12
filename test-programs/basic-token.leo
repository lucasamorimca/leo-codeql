// A basic token program demonstrating core Leo features
program basic_token.aleo {
    // Token record with private balance
    record Token {
        owner: address,
        amount: u64,
    }

    // Public mapping for total balances
    mapping balances: address => u64;

    // Mint new tokens to a recipient
    transition mint(public receiver: address, public amount: u64) -> Token {
        let token: Token = Token {
            owner: receiver,
            amount: amount,
        };
        return token then finalize(receiver, amount);
    }

    finalize mint(receiver: address, amount: u64) {
        let current: u64 = Mapping::get_or_use(balances, receiver, 0u64);
        Mapping::set(balances, receiver, current + amount);
    }

    // Transfer tokens between addresses
    async transition transfer(
        token: Token,
        public to: address,
        public amount: u64
    ) -> (Token, Token, Future) {
        // Calculate fee for the transfer
        let fee: u64 = calculate_fee(amount);
        let total: u64 = amount + fee;

        // Ensure sender has enough balance
        assert(token.amount >= total);

        // Create new tokens
        let remaining: Token = Token {
            owner: token.owner,
            amount: token.amount - total,
        };

        let transferred: Token = Token {
            owner: to,
            amount: amount,
        };

        return (remaining, transferred, finalize_transfer(to, amount));
    }

    finalize finalize_transfer(to: address, amount: u64) {
        let current: u64 = Mapping::get_or_use(balances, to, 0u64);
        Mapping::set(balances, to, current + amount);
    }

    // Calculate transfer fee (1% of amount)
    function calculate_fee(amount: u64) -> u64 {
        let fee: u64 = amount / 100u64;
        return fee;
    }
}
