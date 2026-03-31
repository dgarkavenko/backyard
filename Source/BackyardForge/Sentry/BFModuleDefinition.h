#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "GameplayTagContainer.h"
#include "BFModuleDefinition.generated.h"

const FName MODULE_ASSET_TYPE = TEXT("BFModuleDefinition");

USTRUCT(BlueprintType)
struct FBFModuleSlot
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadWrite, EditAnywhere)
	FGameplayTagContainer Tags;

	UPROPERTY(BlueprintReadWrite, EditAnywhere)
	FName Socket;
};

UCLASS()
class BACKYARDFORGE_API UBFModuleDefinition : public UPrimaryDataAsset
{
	GENERATED_BODY()

public:
	virtual FPrimaryAssetId GetPrimaryAssetId() const override
	{
		return FPrimaryAssetId(MODULE_ASSET_TYPE, GetFName());
	}

	UPROPERTY(BlueprintReadWrite, EditAnywhere)
	FGameplayTagQuery Instalation;

	UPROPERTY(BlueprintReadWrite, EditAnywhere)
	FGameplayTagContainer Capabilities;

	UPROPERTY(BlueprintReadWrite, EditAnywhere, meta=(TitleProperty="{Tags} {Socket}"))
	TArray<FBFModuleSlot> ProvidedSlots;
};
