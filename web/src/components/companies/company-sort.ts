export const COMPANY_SORTS = [
  'name',
  'domain',
  'created_at',
  'last_activity_at',
  'contacts_count',
] as const
export type CompanySort = (typeof COMPANY_SORTS)[number]
export function companySort(value: unknown) {
  const raw = typeof value === 'string' ? value : 'name'
  return COMPANY_SORTS.includes(raw.replace(/^-/, '') as CompanySort) ? raw : 'name'
}
