struct FBSFilteredAction
{
	FBSInteractionAction Action;
	bool bAvailable = false;
}

namespace BSInteraction
{
	UBSInteractable CheckHitForInteractable(FHitResult HitResult)
	{
		AActor HitActor = HitResult.GetActor();
		if (HitActor == nullptr)
		{
			return nullptr;
		}
		return UBSInteractable::Get(HitActor);
	}

	UBSInteractable TraceForInteractable(APlayerController PlayerController, float MaxDistance = 500.0f)
	{
		APawn ControlledPawn = PlayerController.GetControlledPawn();
		if (ControlledPawn == nullptr)
		{
			return nullptr;
		}

		UCameraComponent Camera = UCameraComponent::Get(ControlledPawn);
		if (Camera == nullptr)
		{
			return nullptr;
		}

		FVector Start = Camera.GetWorldLocation();
		FVector End = Start + Camera.GetForwardVector() * MaxDistance;

		TArray<AActor> IgnoredActors;
		IgnoredActors.Add(ControlledPawn);

		FHitResult HitResult;
		bool bHit = System::LineTraceSingle(
			Start,
			End,
			ETraceTypeQuery::TraceTypeQuery2,
			false,
			IgnoredActors,
			EDrawDebugTrace::None,
			HitResult,
			true
		);

		if (!bHit)
		{
			return nullptr;
		}

		return UBSInteractable::Get(HitResult.GetActor());
	}

	TArray<FBSFilteredAction> GetFilteredActions(UBSInteractable Interactable, FGameplayTagContainer InteractorTags)
	{
		TArray<FBSFilteredAction> FilteredActions;

		if (Interactable == nullptr || Interactable.ActionSet == nullptr)
		{
			return FilteredActions;
		}

		for (FBSInteractionAction Action : Interactable.ActionSet.Actions)
		{
			FBSFilteredAction Filtered;
			Filtered.Action = Action;
			Filtered.bAvailable = Action.RequiredTags.IsEmpty() || InteractorTags.HasAll(Action.RequiredTags);
			FilteredActions.Add(Filtered);
		}

		return FilteredActions;
	}

	bool ExecuteAction(UBSInteractable Interactable, FGameplayTag ActionTag, AActor Interactor, FGameplayTagContainer InteractorTags)
	{
		if (Interactable == nullptr || Interactable.ActionSet == nullptr)
		{
			return false;
		}

		for (FBSInteractionAction Action : Interactable.ActionSet.Actions)
		{
			if (Action.ActionTag != ActionTag)
			{
				continue;
			}

			bool bAvailable = Action.RequiredTags.IsEmpty() || InteractorTags.HasAll(Action.RequiredTags);
			if (!bAvailable)
			{
				return false;
			}

			Interactable.OnActionExecuted.Broadcast(ActionTag, Interactor);
			return true;
		}

		return false;
	}
}
