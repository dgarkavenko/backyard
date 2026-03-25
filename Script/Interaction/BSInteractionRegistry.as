class UBSInteractionRegistry : UActorComponent
{
	private TArray<FBFInteraction> Actions;

	TArray<FBFInteraction> GetActions() const
	{
		return Actions;
	}

	// TODO Maybe registe action AND delegate
	void RegisterAction(FBFInteraction Action)
	{
		Actions.Add(Action);
	}

	void UnregisterActionByTag(FGameplayTag ActionTag)
	{
		for (int Index = Actions.Num() - 1; Index >= 0; Index--)
		{
			if (Actions[Index].ActionTag == ActionTag)
			{
				Actions.RemoveAt(Index);
			}
		}
	}

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		UPrimitiveComponent RootPrimitive = Cast<UPrimitiveComponent>(Owner.RootComponent);
		if (RootPrimitive != nullptr)
		{
			RootPrimitive.SetCollisionResponseToChannel(ECollisionChannel::ECC_GameTraceChannel2, ECollisionResponse::ECR_Block);
		}
	}
}
