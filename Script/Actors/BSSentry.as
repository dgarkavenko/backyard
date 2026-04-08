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

	UPROPERTY()
	TSubclassOf<UFUScreenProjectedWidget> WorldMarkerWidgetClass;

	USceneComponent CurrentMarkerAnchor;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		Base.SetGenerateOverlapEvents(true);
		auto Widget = UI::GetHUD().RegisterWidget(Base, WorldMarkerWidgetClass, FVector::UpVector * 10);			
		UBSSentryMarker SentryMarker = Cast<UBSSentryMarker>(Widget);
		SentryMarker.Model = this;
	
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
