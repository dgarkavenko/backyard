class UBSSentryView : UActorComponent
{
	TArray<UStaticMeshComponent> ModuleElementPool;
	TArray<int> ModuleElementGenerations;
	TArray<UStaticMeshComponent> ActiveModuleElements;
	int RebuildGeneration = 0;

	TMap<FName, USceneComponent> SocketOwnerCache;

	TArray<USceneComponent> RotatorComponents;
	TArray<FBSSentryConstraint> RotatorConstraints;
	TArray<FVector> RotatorOffsets;
	USceneComponent MuzzleComponent;

	bool bHasYawPitchFastPath = false;
	FVector Rotator1OffsetLocal;
	FVector MuzzleOffsetLocal;
	FVector MuzzleOffset;
	FQuat MuzzleLocalRotation;
	float CachedYawLateralOffset = 0.0f;
	float CachedYawForwardOffset = 0.0f;
	float CachedPitchVerticalOffset = 0.0f;
	float CachedPitchForwardOffset = 0.0f;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		UBSModularComponent ModularComponent = UBSModularComponent::Get(Owner);
		if (ModularComponent != nullptr)
		{
			ModularComponent.OnCompositionChanged.AddUFunction(this, n"OnCompositionChanged");
		}

		RebuildFromCurrentModules();
	}

	UFUNCTION(BlueprintOverride)
	void EndPlay(EEndPlayReason Reason)
	{
		UBSModularComponent ModularComponent = UBSModularComponent::Get(Owner);
		if (ModularComponent != nullptr)
		{
			ModularComponent.OnCompositionChanged.UnbindObject(this);
		}

		ABSSentry Sentry = Cast<ABSSentry>(Owner);
		if (Sentry == nullptr)
		{
			return;
		}

		UBSSentryWorldSubsystem SentrySubsystem = UBSSentryWorldSubsystem::Get();
		if (SentrySubsystem != nullptr)
		{
			SentrySubsystem.RemoveSentry(Sentry);
		}
	}

	UFUNCTION()
	void OnCompositionChanged(UBSModularComponent ModularComponent)
	{
		RebuildFromCurrentModules();
	}

	void RebuildFromCurrentModules()
	{
		ABSSentry Sentry = Cast<ABSSentry>(Owner);
		UBSModularComponent ModularComponent = UBSModularComponent::Get(Owner);
		if (Sentry == nullptr || ModularComponent == nullptr)
		{
			return;
		}

		SentryAssembly::Rebuild(this, Sentry, ModularComponent, Sentry.Material);
	}

	bool HasAimRig() const
	{
		return RotatorComponents.Num() >= 2
			&& RotatorComponents[0] != nullptr
			&& RotatorComponents[1] != nullptr;
	}

	USceneComponent GetDefaultAttachParent(ABSSentry Sentry) const
	{
		if (RotatorComponents.Num() > 0)
		{
			return RotatorComponents.Last();
		}

		return Sentry.Base;
	}
}
