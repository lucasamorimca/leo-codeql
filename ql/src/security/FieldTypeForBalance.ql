/**
 * @name Field type used for balance or amount
 * @description Using field type for balances/amounts is dangerous because field elements wrap around silently at the field prime. Use integer types (u64, u128) instead
 * @kind problem
 * @problem.severity warning
 * @id leo/security/field-type-for-balance
 */

import codeql.leo.Leo

/**
 * Holds if the name suggests a monetary/balance value.
 * Excludes common non-monetary suffixes to reduce false positives.
 */
bindingset[name]
predicate isBalanceLikeName(string name) {
  exists(string lower | lower = name.toLowerCase() |
    (
      lower.matches("%balance%") or
      lower.matches("%amount%") or
      lower.matches("%supply%") or
      lower.matches("%price%") or
      lower.matches("%credit%") or
      lower.matches("%quantity%") or
      lower.matches("%token_value%") or
      lower.matches("%total_supply%") or
      lower.matches("%fee%") or
      lower.matches("%reward%") or
      lower.matches("%stake%") or
      lower.matches("%collateral%") or
      lower.matches("%deposit%") or
      lower.matches("%withdrawal%") or
      lower.matches("%cost%") or
      lower.matches("%payment%") or
      lower.matches("%fund%") or
      lower.matches("%debt%") or
      lower.matches("%principal%") or
      lower.matches("%allowance%")
    ) and
    // Exclude non-monetary suffixes
    not lower.matches("%_id") and
    not lower.matches("%_name") and
    not lower.matches("%_type") and
    not lower.matches("%_count") and
    not lower.matches("%_index") and
    not lower.matches("%_hash") and
    not lower.matches("%_key") and
    not lower.matches("%_flag") and
    not lower.matches("%_status") and
    not lower.matches("%_enabled") and
    not lower.matches("%_active") and
    not lower.matches("%_limit") and
    not lower.matches("%_threshold") and
    // Keep token but exclude non-monetary token compounds
    not (lower.matches("%token%") and (
      lower.matches("%_id") or
      lower.matches("%_name") or
      lower.matches("%_type") or
      lower.matches("%_hash") or
      lower.matches("%_key") or
      lower.matches("%auth%") or
      lower.matches("%access%")
    )) and
    // Keep interest but exclude interest_rate_type style names
    not (lower.matches("%interest%") and lower.matches("%_rate_%"))
  )
}

from AstNode node, string name
where
  (
    // Struct/record fields
    exists(StructField field |
      field = node and
      name = field.getName() and
      isBalanceLikeName(name) and
      (field.getType().isField() or field.getType().isScalar())
    )
    or
    // Function parameters
    exists(Parameter param |
      param = node and
      name = param.getName() and
      isBalanceLikeName(name) and
      (param.getType().isField() or param.getType().isScalar())
    )
    or
    // Let statements
    exists(LetStmt letStmt |
      letStmt = node and
      name = letStmt.getVariableName() and
      isBalanceLikeName(name) and
      (letStmt.getVariableType().isField() or letStmt.getVariableType().isScalar())
    )
    or
    // Mapping declarations with balance-like names or field-typed values
    exists(MappingDeclaration mapping |
      mapping = node and
      name = mapping.getName() and
      isBalanceLikeName(name) and
      (mapping.getValueType().isField() or mapping.getValueType().isScalar())
    )
  )
select node,
  "Variable '" + name +
    "' uses field/scalar type for balance/amount. " +
    "Field and scalar elements wrap around silently - use u64 or u128 instead for safe arithmetic"
