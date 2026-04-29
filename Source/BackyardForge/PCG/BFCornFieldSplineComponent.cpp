#include "PCG/BFCornFieldSplineComponent.h"

#include "PCG/BFCornField.h"

#if WITH_EDITOR
void UBFCornFieldSplineComponent::PostEditChangeChainProperty(FPropertyChangedChainEvent& PropertyChangedEvent)
{
	Super::PostEditChangeChainProperty(PropertyChangedEvent);
	NotifyCornFieldOwner();
}

void UBFCornFieldSplineComponent::PostEditComponentMove(bool bFinished)
{
	Super::PostEditComponentMove(bFinished);

	if (bFinished)
	{
		NotifyCornFieldOwner();
	}
}
#endif

void UBFCornFieldSplineComponent::NotifyCornFieldOwner()
{
	if (ABFCornField* CornField = Cast<ABFCornField>(GetOwner()))
	{
		CornField->HandleSplineEdited();
	}
}
