/**
 * @name Test Leo Library
 * @description Basic test query to validate Leo QL library compilation
 * @kind problem
 * @id leo/test/library-compilation
 */

import codeql.leo.Leo

from Program p
select p, "Found program: " + p.getName()
