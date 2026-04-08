class UBSModularView : UActorComponent
{
	UPROPERTY(EditAnywhere, Category = "Modular")
	UMaterialInterface MaterialOverride;

	TArray<UStaticMeshComponent> ModuleElementPool;
	TArray<UStaticMeshComponent> ActiveModuleElements;

	TArray<int> ModuleElementGenerations;
	int Generation = 0;

	TMap<FName, USceneComponent> SocketOwnerCache;
	TArray<FBSBuiltModuleView> Build;

	UPROPERTY()
	USpotLightComponent CachedVisorSpotLight;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		UBSModularComponent ModularComponent = UBSModularComponent::Get(Owner);
		if (ModularComponent != nullptr)
		{
			ModularComponent.OnCompositionChanged.AddUFunction(this, n"SyncActor");
			SyncActor(ModularComponent);
		}
	}

	UFUNCTION(BlueprintOverride)
	void EndPlay(EEndPlayReason Reason)
	{
		UBSModularComponent ModularComponent = UBSModularComponent::Get(Owner);
		if (ModularComponent != nullptr)
		{
			ModularComponent.OnCompositionChanged.UnbindObject(this);
		}
	}

	UFUNCTION()
	void SyncActor(UBSModularComponent ModularComponent)
	{
		UBSRuntimeSubsystem Runtime = UBSRuntimeSubsystem::Get();
		if (Runtime != nullptr)
		{
			Runtime.SyncActor(ModularComponent, this);
		}
	}
}
