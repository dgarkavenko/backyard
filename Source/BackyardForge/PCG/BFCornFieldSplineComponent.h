#pragma once

#include "CoreMinimal.h"
#include "Components/SplineComponent.h"

#include "BFCornFieldSplineComponent.generated.h"

UCLASS(ClassGroup = Utility, meta = (BlueprintSpawnableComponent))
class BACKYARDFORGE_API UBFCornFieldSplineComponent : public USplineComponent
{
	GENERATED_BODY()

public:
#if WITH_EDITOR
	virtual void PostEditChangeChainProperty(FPropertyChangedChainEvent& PropertyChangedEvent) override;
	virtual void PostEditComponentMove(bool bFinished) override;
#endif

private:
	void NotifyCornFieldOwner();
};
