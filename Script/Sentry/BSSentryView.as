class UBSSentryView : UActorComponent
{
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
			ModularComponent.OnViewBuilt.AddUFunction(this, n"OnViewBuilt");
		}
	}

	UFUNCTION(BlueprintOverride)
	void EndPlay(EEndPlayReason Reason)
	{
		UBSModularComponent ModularComponent = UBSModularComponent::Get(Owner);
		if (ModularComponent != nullptr)
		{
			ModularComponent.OnViewBuilt.UnbindObject(this);
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
	void OnViewBuilt(UBSModularComponent ModularComponent, UBSModularView ModularView)
	{
		ABSSentry Sentry = Cast<ABSSentry>(Owner);
		check(Sentry != nullptr);
		check(ModularComponent != nullptr);
		check(ModularView != nullptr);

		SentryAssembly::Build(this, Sentry, ModularComponent, ModularView);
	}

	bool HasAimRig() const
	{
		return RotatorComponents.Num() >= 2
			&& RotatorComponents[0] != nullptr
			&& RotatorComponents[1] != nullptr;
	}
}
