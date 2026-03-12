// SAFE: Well-written contract following best practices
// This should NOT trigger any detectors
program safe_contract.aleo {
    // Properly typed token with u64 for amounts
    record Token {
        owner: address,
        amount: u64,
    }

    // Public balance tracking with proper types
    mapping balances: address => u64;
    mapping admin: field => address;

    // Constant for admin address
    const ADMIN_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    // Safe initialization with access control
    async transition initialize(public initial_admin: address) -> Future {
        return finalize_init(self.caller, initial_admin);
    }

    finalize finalize_init(caller: address, initial_admin: address) {
        // SAFE: Access control check before initialization
        assert_eq(caller, ADMIN_ADDRESS);
        Mapping::set(admin, 0field, initial_admin);
    }

    // Safe mint function with proper types
    async transition mint(
        public receiver: address,
        public amount: u64
    ) -> (Token, Future) {
        let token: Token = Token {
            owner: receiver,
            amount: amount,
        };

        // SAFE: Only public parameters passed to finalize
        return (token, finalize_mint(receiver, amount));
    }

    finalize finalize_mint(receiver: address, amount: u64) {
        let current: u64 = Mapping::get_or_use(balances, receiver, 0u64);
        Mapping::set(balances, receiver, current + amount);
    }

    // Safe transfer with explicit checks instead of risky ternary
    transition transfer(
        token: Token,
        public to: address,
        public amount: u64
    ) -> (Token, Token) {
        // SAFE: Explicit assertion instead of ternary with subtraction
        assert(token.amount >= amount);

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

    // Safe conditional logic without dangerous ternary
    function calculate_amount(base: u64, bonus: u64, apply_bonus: bool) -> u64 {
        // SAFE: Using if-else instead of ternary with arithmetic
        if apply_bonus {
            return base + bonus;
        } else {
            return base;
        }
    }

    // Safe helper function with proper types
    function calculate_fee(amount: u64, fee_rate: u64) -> u64 {
        // SAFE: Simple arithmetic with proper integer types
        let fee: u64 = amount * fee_rate / 10000u64;
        return fee;
    }

    // Admin function with proper access control
    async transition update_admin(public new_admin: address) -> Future {
        return finalize_update_admin(self.caller, new_admin);
    }

    finalize finalize_update_admin(caller: address, new_admin: address) {
        // SAFE: Verify caller is current admin
        let current_admin: address = Mapping::get(admin, 0field);
        assert_eq(caller, current_admin);
        Mapping::set(admin, 0field, new_admin);
    }
}
