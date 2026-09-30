import { createFileRoute, useRouter } from '@tanstack/react-router'

import { CompanyDetail } from '../../../../components/companies/company-detail'

export const Route = createFileRoute('/app/_authenticated/companies/$companyId')({
  component: CompanyPage,
})
function CompanyPage() {
  const { companyId } = Route.useParams()
  const router = useRouter()
  const navigate = Route.useNavigate()
  return (
    <CompanyDetail
      key={companyId}
      companyId={Number(companyId)}
      onBack={() => {
        if (window.history.length > 1) router.history.back()
        else void navigate({ to: '/app/companies' })
      }}
    />
  )
}
