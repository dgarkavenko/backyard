#include "BFNativeModuleTaxonomy.h"

#include "BackyardForge.h"
#include "Engine/AssetManager.h"
#include "BFModuleDefinition.h"

void UBFNativeModuleTaxonomy::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);

	UAssetManager& AssetManager = UAssetManager::Get();

	PendingModuleIds.Reset();
	AssetManager.GetPrimaryAssetIdList(FPrimaryAssetType(MODULE_ASSET_TYPE), PendingModuleIds);

	if (PendingModuleIds.Num() > 0)
	{
		const TArray<FName> Bundles;
		const auto Delegate = FStreamableDelegate::CreateUObject(this, &UBFNativeModuleTaxonomy::OnModulesLoaded);
		AssetManager.LoadPrimaryAssets(PendingModuleIds, Bundles, Delegate);
	}
}

void UBFNativeModuleTaxonomy::OnModulesLoaded()
{
	const UAssetManager& AssetManager = UAssetManager::Get();

	for (const FPrimaryAssetId& Id : PendingModuleIds)
	{
		UObject* Asset = AssetManager.GetPrimaryAssetObject(Id);
		UBFModuleDefinition* Module = Cast<UBFModuleDefinition>(Asset);

		if (Module == nullptr)
		{
			UE_LOG(LogBackyardForge, Error, TEXT("Failed to load module: %s"), *Id.ToString());
			continue;
		}

		Modules.Add(Id, Module);
	}

	UE_LOG(LogBackyardForge, Log, TEXT("ModuleTaxonomy: loaded %d modules"), Modules.Num());
}
