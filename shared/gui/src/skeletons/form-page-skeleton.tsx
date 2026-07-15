import { FormSkeleton } from "@cxado/gui/skeletons/form-skeleton"
import { PageHeaderSkeleton } from "@cxado/gui/skeletons/page-header-skeleton"
import { PageContentShell } from "@cxado/gui/skeletons/primitives"

export function FormPageSkeleton({
  fields = 4,
  singleCard = false,
  showBack = true,
  showActions = true,
}: {
  fields?: number
  singleCard?: boolean
  showBack?: boolean
  showActions?: boolean
}) {
  return (
    <PageContentShell>
      <PageHeaderSkeleton showBack={showBack} />
      <FormSkeleton
        fields={fields}
        singleCard={singleCard}
        showActions={showActions}
      />
    </PageContentShell>
  )
}
