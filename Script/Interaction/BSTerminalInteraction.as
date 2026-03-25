class UBSTerminalInteraction : UActorComponent
{
	FBFInteraction TerminalInteraction;

	default PrimaryComponentTick.bStartWithTickEnabled = false;

	default TerminalInteraction.ActionTag = GameplayTags::Backyard_Interaction_Terminal;
	default TerminalInteraction.DisplayName = FText::FromString("Open Terminal");
	default TerminalInteraction.HoldDuration = 0.0f;

	UPROPERTY()
	TSubclassOf<UFUActivatableWidget> WidgetClass;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		UBSInteractionRegistry Registry = UBSInteractionRegistry::GetOrCreate(Owner);

		TerminalInteraction.Delegate.BindUFunction(this, n"ShowScreen");
		Registry.RegisterAction(TerminalInteraction);
	}
	
	UFUNCTION()
	void ShowScreen(AActor Interactor)
	{
		ABFPlayerController PlayerController = Cast<ABFPlayerController>(Interactor.GetOwner());
		PlayerController.PushWidgetToPrimaryLayout(GameplayTags::ForgeryUI_Layer_GameMenu, WidgetClass);
	}
}