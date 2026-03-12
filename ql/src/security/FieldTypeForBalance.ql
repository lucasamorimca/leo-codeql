/**
 * @name Field type used for balance or amount
 * @description Using field type for balances/amounts is dangerous because field elements wrap around silently at the field prime. Use integer types (u64, u128) instead
 * @kind problem
 * @problem.severity warning
 * @id leo/security/field-type-for-balance
 */

import codeql.leo.Leo

from AstNode node, string name
where
  (
    // Struct/record fields
    exists(StructField field, LeoType typ, string fieldName |
      field = node and
      fieldName = field.getName() and
      name = fieldName and
      typ = field.getType() and
      (
        fieldName.toLowerCase().matches("%balance%") or
        fieldName.toLowerCase().matches("%amount%") or
        fieldName.toLowerCase().matches("%supply%") or
        fieldName.toLowerCase().matches("%total%") or
        fieldName.toLowerCase().matches("%value%") or
        fieldName.toLowerCase().matches("%quantity%") or
        fieldName.toLowerCase().matches("%price%")
      ) and
      typ.isField()
    )
    or
    // Function parameters
    exists(Parameter param, LeoType typ, string paramName |
      param = node and
      paramName = param.getName() and
      name = paramName and
      typ = param.getType() and
      (
        paramName.toLowerCase().matches("%balance%") or
        paramName.toLowerCase().matches("%amount%") or
        paramName.toLowerCase().matches("%supply%") or
        paramName.toLowerCase().matches("%total%") or
        paramName.toLowerCase().matches("%value%") or
        paramName.toLowerCase().matches("%quantity%") or
        paramName.toLowerCase().matches("%price%")
      ) and
      typ.isField()
    )
    or
    // Let statements
    exists(LetStmt letStmt, LeoType typ, string varName |
      letStmt = node and
      varName = letStmt.getVariableName() and
      name = varName and
      typ = letStmt.getVariableType() and
      (
        varName.toLowerCase().matches("%balance%") or
        varName.toLowerCase().matches("%amount%") or
        varName.toLowerCase().matches("%supply%") or
        varName.toLowerCase().matches("%total%") or
        varName.toLowerCase().matches("%value%") or
        varName.toLowerCase().matches("%quantity%") or
        varName.toLowerCase().matches("%price%")
      ) and
      typ.isField()
    )
  )
select node, "Variable '" + name + "' uses field type for balance/amount. Field elements wrap around silently - use u64 or u128 instead for safe arithmetic"
