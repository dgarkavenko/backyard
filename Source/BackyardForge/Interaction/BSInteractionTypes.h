#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "BSInteractionTypes.generated.h"

DECLARE_DYNAMIC_DELEGATE_OneParam(FBFInteractionDelegate, AActor*, Interactor);

USTRUCT(BlueprintType)
struct FBFInteraction
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadWrite, EditAnywhere)
	FGameplayTag ActionTag;

	UPROPERTY(BlueprintReadWrite,EditAnywhere)
	FText DisplayName;

	UPROPERTY(BlueprintReadWrite, EditAnywhere)
	FGameplayTagContainer RequiredTags;

	UPROPERTY(BlueprintReadWrite, EditAnywhere, meta = (ClampMin = "0", ClampMax = "15", Units = "s"))
	float HoldDuration = 0.0f;

	UPROPERTY(BlueprintReadWrite)
	FBFInteractionDelegate Delegate;
};
