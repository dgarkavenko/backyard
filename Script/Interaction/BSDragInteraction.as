class UBSDragInteraction : UActorComponent
{
	UPROPERTY(EditAnywhere, Category = "Drag")
	FBFInteraction Action;

	default Action.ActionTag = GameplayTags::Backyard_Interaction_Pickup;
	default Action.DisplayName = FText::FromString("Drag");

	UPROPERTY()
	FBSDragParams ActionParams;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		Action.Delegate.BindUFunction(this, n"Drag");
		UBSInteractionRegistry::GetOrCreate(Owner).RegisterAction(Action);
	}

	UFUNCTION()
	void Drag(AActor Interactor)
	{
		ABSCharacter Character = Cast<ABSCharacter>(Interactor);
		if (Character != nullptr)
		{
			Character.DragComponent.StartDrag(Owner, ActionParams);		
		}
	}
}
