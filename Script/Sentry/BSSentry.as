class ABSSentry : AActor
{
	UPROPERTY(DefaultComponent)
	UBSInteractionRegistry InteractionRegistry;

	UPROPERTY(DefaultComponent)
	UBSTerminalInteraction TerminalInteraction;

	UPROPERTY(DefaultComponent)
	UBSDragInteraction DragInteraction;

	default DragInteraction.Action.HoldDuration = 1.0f;
	default DragInteraction.ActionParams.StabilizationMode = EBSDragStabilize::KeepStraight;
	default DragInteraction.ActionParams.ParentMode = EBSDragParent::Yaw;

	UPROPERTY(DefaultComponent)
	UBSModularComponent ModularComponent;

	UPROPERTY(DefaultComponent)
	UBSModularView ModularView;
	default ModularView.MaterialOverride = Material;

	UPROPERTY(DefaultComponent, RootComponent)
	UStaticMeshComponent Base;

	UPROPERTY(EditAnywhere, Category = "Sentry")
	UMaterialInterface Material;


	TOptional<int> SystemHandle;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		Base.SetGenerateOverlapEvents(true);
		ModularComponent.OnViewBuilt.AddUFunction(this, n"OnViewBuilt");

	}

	void DisableTerminalInteraction()
	{
		InteractionRegistry.UnregisterActionByTag(GameplayTags::Backyard_Interaction_Terminal);
	}

	void EnableTerminalInteraction()
	{
		InteractionRegistry.RegisterAction(TerminalInteraction.TerminalInteraction);
	}

	UFUNCTION()
	void OnViewBuilt(UBSModularComponent BuiltModularComponent, UBSModularView BuiltModularView)
	{
		check(BuiltModularComponent != nullptr);
		check(BuiltModularView != nullptr);
		
		UBSSentryWorldSubsystem SentrySubsystem = UBSSentryWorldSubsystem::Get();
		if (SentrySubsystem != nullptr)
		{
			SystemHandle = SentrySubsystem.SyncSentry(this);
		}
	}

	UFUNCTION(BlueprintOverride)
	void EndPlay(EEndPlayReason EndPlayReason)
	{
		SystemHandle.Reset();
		UBSSentryWorldSubsystem SentrySubsystem = UBSSentryWorldSubsystem::Get();
		if (SentrySubsystem != nullptr)
		{
			SentrySubsystem.RemoveSentry(this);
		}
	}
}
