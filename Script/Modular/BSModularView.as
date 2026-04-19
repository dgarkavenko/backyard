class UBSModularView : UActorComponent
{
	UPROPERTY(EditAnywhere, Category = "Modular")
	UMaterialInterface MaterialOverride;

	int32 RuntimeBaseIndex = -1;
	int32 RuntimePowerIndex = -1;
	int32 RuntimeDetectionIndex = -1;
	int32 RuntimeAimIndex = -1;
	int32 RuntimeFireIndex = -1;
	int32 RuntimeLightIndex = -1;

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

		UBSRuntimeSubsystem Runtime = UBSRuntimeSubsystem::Get();
		if (Runtime != nullptr && Owner != nullptr)
		{
			Runtime.RemoveActor(Owner);
		}

		ClearRuntimeFeatureIndices();
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

	void ClearRuntimeFeatureIndices()
	{
		RuntimeBaseIndex = -1;
		RuntimePowerIndex = -1;
		RuntimeDetectionIndex = -1;
		RuntimeAimIndex = -1;
		RuntimeFireIndex = -1;
		RuntimeLightIndex = -1;
	}

	void SetRuntimeFeatureIndices(const FBSBaseRuntimeRow& RuntimeRow, int32 BaseIndex)
	{
		RuntimeBaseIndex = BaseIndex;
		RuntimePowerIndex = RuntimeRow.PowerIndex;
		RuntimeDetectionIndex = RuntimeRow.DetectionIndex;
		RuntimeAimIndex = RuntimeRow.AimIndex;
		RuntimeFireIndex = RuntimeRow.FireIndex;
		RuntimeLightIndex = RuntimeRow.LightIndex;
	}
}
