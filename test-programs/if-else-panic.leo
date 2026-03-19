program if_else_panic.aleo {
    // Test case: if-else with panicking operations in both branches
    // Both branches will be evaluated in ZK circuit context (non-finalize)
    transition check_balance(flag: bool, a: u32, b: u32) -> u32 {
        // Both branches evaluate in ZK circuit
        if (flag) {
            return a - b;  // panics if b > a, even when flag is false
        } else {
            return a / b;  // panics if b == 0, even when flag is true
        }
    }

    // Test case: nested if-else with panicking ops
    transition nested_check(flag: bool, x: u8, y: u8) -> u8 {
        if (flag) {
            if (x > y) {
                return x - y;  // panic-prone
            } else {
                return y - x;  // panic-prone
            }
        } else {
            return x * y;  // panic-prone (overflow)
        }
    }

    // Safe: finalize function with if-else (sequential execution, not circuit)
    finalize safe_finalize(flag: bool, a: u32, b: u32) {
        if (flag) {
            let result: u32 = a - b;  // OK in finalize - branches don't both evaluate
        } else {
            let result: u32 = a / b;
        }
    }

    // Safe: wrapped operations don't panic
    transition safe_wrapped(flag: bool, a: u32, b: u32) -> u32 {
        if (flag) {
            return a.sub_wrapped(b);  // safe
        } else {
            return a.div_wrapped(b);  // safe
        }
    }
}
