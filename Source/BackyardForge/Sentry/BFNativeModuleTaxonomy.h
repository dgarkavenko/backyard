#pragma once

#include "CoreMinimal.h"
#include "BFNativeModuleTaxonomy.generated.h"

class UBFModuleDefinition;

UCLASS(Abstract)
class BACKYARDFORGE_API UBFNativeModuleTaxonomy : public UGameInstanceSubsystem
{
	GENERATED_BODY()

	virtual void Initialize(FSubsystemCollectionBase& Collection) override;

	UFUNCTION(BlueprintCallable)
	void OnModulesLoaded();

public:
	UPROPERTY(BlueprintReadOnly)
	TMap<FPrimaryAssetId, TObjectPtr<UBFModuleDefinition>> Modules;

private:
	TArray<FPrimaryAssetId> PendingModuleIds;
};
