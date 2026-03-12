// VULNERABLE: Dangerous ternary with potential underflow
// This should trigger the TernaryPanicTrap detector
program ternary_underflow.aleo {
    record Balance {
        owner: address,
        amount: u32,
    }

    mapping balances: address => u32;

    // VULNERABILITY: Ternary expression with subtraction that could underflow
    // In ZK circuits, both branches are evaluated, so a - b could panic
    transition risky_withdraw(
        balance: Balance,
        public withdraw_amount: u32,
        public use_alternative: bool
    ) -> Balance {
        let safe_amount: u32 = 100u32;

        // BUG: If use_alternative is false and balance.amount < withdraw_amount,
        // the subtraction will underflow and panic even though the true branch is taken
        let final_amount: u32 = use_alternative
            ? safe_amount
            : balance.amount - withdraw_amount;

        let new_balance: Balance = Balance {
            owner: balance.owner,
            amount: final_amount,
        };

        return new_balance;
    }

    // Another example with arithmetic operations
    transition calculate_fee(
        public base_amount: u32,
        public discount: u32,
        public apply_discount: bool
    ) -> u32 {
        // VULNERABILITY: Subtraction in ternary could underflow
        // Both branches are computed in ZK, so if discount > base_amount, panic occurs
        let fee: u32 = apply_discount
            ? base_amount - discount
            : base_amount;

        return fee;
    }

    // Example with nested ternary
    transition complex_calculation(
        public a: u32,
        public b: u32,
        public c: u32,
        public flag1: bool,
        public flag2: bool
    ) -> u32 {
        // VULNERABILITY: Multiple potential underflows in nested ternary
        let result: u32 = flag1
            ? (flag2 ? a - b : a - c)
            : b - c;

        return result;
    }
}
