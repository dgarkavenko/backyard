class UBSModularView : UActorComponent
{
	UPROPERTY(EditAnywhere, Category = "Modular")
	UMaterialInterface MaterialOverride;

	TArray<UStaticMeshComponent> ModuleElementPool;
	TArray<UStaticMeshComponent> ActiveModuleElements;

	TArray<int> ModuleElementGenerations;
	int Generation = 0;

	TMap<FName, USceneComponent> SocketOwnerCache;
	FBSModularBuildResult LastBuildResult;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		UBSModularComponent ModularComponent = UBSModularComponent::Get(Owner);
		if (ModularComponent != nullptr)
		{
			ModularComponent.OnCompositionChanged.AddUFunction(this, n"Build");
			Build(ModularComponent);
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
	void Build(UBSModularComponent ModularComponent)
	{
		LastBuildResult = ModularAssembly::Build(this, Cast<AActor>(Owner), ModularComponent);
		ModularComponent.OnViewBuilt.Broadcast(ModularComponent, this);
	}
}
