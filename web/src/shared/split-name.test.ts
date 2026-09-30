import { expect, test } from 'vitest'

import { splitName } from './split-name'

// Os exemplos do JSDoc do @chatwoot/utils
test.each([
  ['Mary Jane Smith', { firstName: 'Mary Jane', lastName: 'Smith' }],
  ['Alice', { firstName: 'Alice', lastName: '' }],
  ['John Doe', { firstName: 'John', lastName: 'Doe' }],
  ['', { firstName: '', lastName: '' }],
  ['  Ana   Maria  ', { firstName: 'Ana', lastName: 'Maria' }],
])('%j', (name, expected) => expect(splitName(name)).toEqual(expected))
