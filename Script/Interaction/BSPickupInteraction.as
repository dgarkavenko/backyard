enum EBSPickupMode
{
	Hold,
	Drag
}

class UBSPickupInteraction : UActorComponent
{
	UPROPERTY(EditAnywhere, Category = "Pickup")
	FBFInteraction Action;

	UPROPERTY(EditAnywhere, Category = "Pickup")
	EBSPickupMode Mode = EBSPickupMode::Hold;

	UPROPERTY(EditAnywhere, Category = "Pickup")
	UBSItemData ItemData;

	default Action.ActionTag = GameplayTags::Backyard_Interaction_Pickup;
	default Action.DisplayName = FText::FromString("Pick up");

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		Action.Delegate.BindUFunction(this, n"OnPickup");
		UBSInteractionRegistry::GetOrCreate(Owner).RegisterAction(Action);
	}

	UFUNCTION()
	void OnPickup(AActor Interactor)
	{
		ABSCharacter Character = Cast<ABSCharacter>(Interactor);
		if (Character == nullptr)
		{
			return;
		}

		if (Mode == EBSPickupMode::Hold)
		{
			if (ItemData == nullptr)
			{
				return;
			}
			Character.HeldItemComponent.Pickup(Owner, ItemData);
		}
		else
		{
			Character.DragComponent.StartDrag(Owner);
		}
	}
}
