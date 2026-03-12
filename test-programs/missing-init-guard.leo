// VULNERABLE: Missing access control on initialization function
// This should trigger the MissingInitAccessControl detector
program missing_init_guard.aleo {
    // Configuration settings stored on-chain
    mapping settings: field => u64;
    mapping admin: field => address;

    // VULNERABILITY: No access control check in initialize function
    // Anyone can call this and overwrite critical settings
    async transition initialize(
        public max_supply: u64,
        public fee_rate: u64,
        public admin_addr: address
    ) -> Future {
        return finalize_init(max_supply, fee_rate, admin_addr);
    }

    finalize finalize_init(max_supply: u64, fee_rate: u64, admin_addr: address) {
        // BUG: No assert checking caller is authorized
        // Should have: assert(caller == ADMIN_ADDRESS);
        Mapping::set(settings, 1field, max_supply);
        Mapping::set(settings, 2field, fee_rate);
        Mapping::set(admin, 0field, admin_addr);
    }

    // Another vulnerable init-like function
    async transition setup_config(
        public treasury: address,
        public min_deposit: u64
    ) -> Future {
        return finalize_setup(treasury, min_deposit);
    }

    finalize finalize_setup(treasury: address, min_deposit: u64) {
        // BUG: No access control - anyone can change treasury address
        Mapping::set(admin, 1field, treasury);
        Mapping::set(settings, 3field, min_deposit);
    }

    // Normal operation function (not an init function)
    async transition deposit(public amount: u64) -> Future {
        return finalize_deposit(self.caller, amount);
    }

    finalize finalize_deposit(caller: address, amount: u64) {
        let current: u64 = Mapping::get_or_use(settings, 4field, 0u64);
        Mapping::set(settings, 4field, current + amount);
    }
}
