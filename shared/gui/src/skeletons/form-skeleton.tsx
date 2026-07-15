import { Skeleton } from "@cxado/gui/ui/skeleton"
import { Card, CardContent, CardHeader } from "@cxado/gui/ui/card"
import { Field, FieldGroup } from "@cxado/gui/ui/field"
import { FormCardGrid, FormCardLayout } from "@cxado/gui/layout/form-card-grid"
import { FormActionsSkeleton } from "@cxado/gui/skeletons/primitives"

function CardSkeleton({ fields }: { fields: number }) {
  return (
    <Card>
      <CardHeader>
        <Skeleton className="h-5 w-32 max-w-full" />
        <Skeleton className="h-4 w-48 max-w-full" />
      </CardHeader>
      <CardContent>
        <FieldGroup>
          {Array.from({ length: fields }).map((_, i) => (
            <Field key={i}>
              <Skeleton className="mb-2 h-4 w-24" />
              <Skeleton className="h-9 w-full" />
            </Field>
          ))}
        </FieldGroup>
      </CardContent>
    </Card>
  )
}

export function FormSkeleton({
  fields = 4,
  singleCard = false,
  showActions = true,
}: {
  fields?: number
  singleCard?: boolean
  showActions?: boolean
}) {
  const cardFields = Math.max(1, fields)

  return (
    <FormCardLayout
      singleCard={singleCard}
      actions={showActions ? <FormActionsSkeleton /> : undefined}
    >
      <FormCardGrid singleCard={singleCard}>
        <CardSkeleton fields={cardFields} />
        {!singleCard ? <CardSkeleton fields={Math.max(1, cardFields - 1)} /> : null}
      </FormCardGrid>
    </FormCardLayout>
  )
}

