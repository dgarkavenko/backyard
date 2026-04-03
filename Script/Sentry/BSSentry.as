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

	UPROPERTY(DefaultComponent)
	UBSSentryView SentryView;

	UPROPERTY(DefaultComponent, RootComponent)
	UStaticMeshComponent Base;

	UPROPERTY(EditAnywhere, Category = "Sentry")
	UMaterialInterface Material;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		Base.SetGenerateOverlapEvents(true);
	}

	void DisableTerminalInteraction()
	{
		InteractionRegistry.UnregisterActionByTag(GameplayTags::Backyard_Interaction_Terminal);
	}

	void EnableTerminalInteraction()
	{
		InteractionRegistry.RegisterAction(TerminalInteraction.TerminalInteraction);
	}
}
