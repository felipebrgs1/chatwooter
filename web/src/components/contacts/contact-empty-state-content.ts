// Os 5 primeiros de components-next/Contacts/EmptyState/contactEmptyStateContent.js, com as chaves da API.
import type { ContactCardData } from './contacts-card'

export const sampleContacts: ContactCardData[] = [
  {
    id: 22,
    name: 'Candice Matherson',
    email: 'candice.matherson@lumora.com',
    phone_number: '+14155552671',
    additional_attributes: {
      city: 'Los Angeles',
      country: 'United States',
      country_code: 'US',
      company_name: 'Lumora',
    },
  },
  {
    id: 21,
    name: 'Ophelia Folkard',
    email: 'ophelia.folkard@designify.com',
    phone_number: '+14155552672',
    additional_attributes: {
      city: 'San Francisco',
      country: 'United States',
      country_code: 'US',
      company_name: 'Designify',
    },
  },
  {
    id: 20,
    name: 'Willy Castelot',
    email: 'willy.castelot@codehub.io',
    phone_number: '+14155552673',
    additional_attributes: {
      city: 'Austin',
      country: 'United States',
      country_code: 'US',
      company_name: 'CodeHub',
    },
  },
  {
    id: 19,
    name: 'Elisabeth Derington',
    email: 'elisabeth.derington@innova.com',
    phone_number: '+14155552674',
    additional_attributes: {
      city: 'Seattle',
      country: 'United States',
      country_code: 'US',
      company_name: 'InnovaTech',
    },
  },
  {
    id: 18,
    name: 'Olia Olenchenko',
    email: 'olia.olenchenko@contently.com',
    phone_number: '+14155552675',
    additional_attributes: {
      city: 'Chicago',
      country: 'United States',
      country_code: 'US',
      company_name: 'Contently',
    },
  },
]
