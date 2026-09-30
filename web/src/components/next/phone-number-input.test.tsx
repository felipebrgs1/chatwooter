import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { expect, test, vi } from 'vitest'

import { renderWithI18n } from '../../test/i18n'
import { PhoneNumberInput } from './phone-number-input'

function Controlled({ initial, onChange }: { initial: string; onChange: (v: string) => void }) {
  const [value, setValue] = useState(initial)
  return (
    <PhoneNumberInput
      value={value}
      placeholder="Enter the phone number"
      onChange={(next) => {
        setValue(next)
        onChange(next)
      }}
    />
  )
}

test('separa o DDI do número guardado', async () => {
  await renderWithI18n(<Controlled initial="+5511999990000" onChange={() => {}} />)
  expect(screen.getByText('+55')).toBeInTheDocument()
  expect(screen.getByPlaceholderText('Enter the phone number')).toHaveValue('11999990000')
})

test('digitar emite o número completo com o DDI', async () => {
  const onChange = vi.fn()
  await renderWithI18n(<Controlled initial="+5511999990000" onChange={onChange} />)
  const input = screen.getByPlaceholderText('Enter the phone number')
  await userEvent.clear(input)
  await userEvent.type(input, '2130000000')
  expect(onChange).toHaveBeenLastCalledWith('+552130000000')
})

test('trocar o país troca o DDI', async () => {
  const onChange = vi.fn()
  await renderWithI18n(<Controlled initial="+5511999990000" onChange={onChange} />)
  await userEvent.click(screen.getByRole('button', { name: /🇧🇷/ }))
  await userEvent.type(screen.getByPlaceholderText('Search country'), 'Portugal')
  await userEvent.click(screen.getByRole('button', { name: /Portugal/ }))
  expect(screen.getByText('+351')).toBeInTheDocument()
  expect(onChange).toHaveBeenLastCalledWith('+35111999990000')
})

test('letras mostram o erro do Chatwoot e não emitem', async () => {
  const onChange = vi.fn()
  await renderWithI18n(<Controlled initial="+5511999990000" onChange={onChange} />)
  await userEvent.type(screen.getByPlaceholderText('Enter the phone number'), 'x')
  expect(screen.getByText('Phone number should be empty or in E.164 format')).toBeInTheDocument()
  expect(onChange).not.toHaveBeenCalled()
})
