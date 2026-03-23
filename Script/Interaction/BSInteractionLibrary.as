struct FBSFilteredAction
{
	FBSInteractionAction Action;
	bool bAvailable = false;
}

struct FBSResolvedAction
{
	FBSInteractionAction Action;
	bool bValid = false;
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

	// ── Resolution Functions ──

	FBSResolvedAction ResolveInstantAction(UBSInteractable Interactable, FGameplayTagContainer InteractorTags)
	{
		FBSResolvedAction Result;

		if (Interactable == nullptr || Interactable.ActionSet == nullptr)
		{
			return Result;
		}

		for (FBSInteractionAction Action : Interactable.ActionSet.Actions)
		{
			if (Action.HoldDuration > 0.0f)
			{
				continue;
			}

			bool bAvailable = Action.RequiredTags.IsEmpty() || InteractorTags.HasAll(Action.RequiredTags);
			if (bAvailable)
			{
				Result.Action = Action;
				Result.bValid = true;
				return Result;
			}
		}

		return Result;
	}

	FBSResolvedAction ResolveHoldAction(UBSInteractable Interactable, FGameplayTagContainer InteractorTags)
	{
		FBSResolvedAction Result;

		if (Interactable == nullptr || Interactable.ActionSet == nullptr)
		{
			return Result;
		}

		for (FBSInteractionAction Action : Interactable.ActionSet.Actions)
		{
			if (Action.HoldDuration <= 0.0f)
			{
				continue;
			}

			bool bAvailable = Action.RequiredTags.IsEmpty() || InteractorTags.HasAll(Action.RequiredTags);
			if (bAvailable)
			{
				Result.Action = Action;
				Result.bValid = true;
				return Result;
			}
		}

		return Result;
	}

	FBSResolvedAction ResolveToolAction(UBSInteractable Interactable, FGameplayTagContainer InteractorTags)
	{
		FBSResolvedAction Result;

		if (Interactable == nullptr || Interactable.ActionSet == nullptr)
		{
			return Result;
		}

		for (FBSInteractionAction Action : Interactable.ActionSet.Actions)
		{
			if (Action.RequiredTags.IsEmpty())
			{
				continue;
			}

			if (InteractorTags.HasAll(Action.RequiredTags))
			{
				Result.Action = Action;
				Result.bValid = true;
				return Result;
			}
		}

		return Result;
	}

	FBSInteractionPromptInfo BuildPromptInfo(UBSInteractable Interactable, FGameplayTagContainer InteractorTags, bool bIsHolding)
	{
		FBSInteractionPromptInfo Info;

		if (Interactable == nullptr || Interactable.ActionSet == nullptr)
		{
			return Info;
		}

		FBSResolvedAction InstantAction = ResolveInstantAction(Interactable, InteractorTags);
		FBSResolvedAction HoldAction = ResolveHoldAction(Interactable, InteractorTags);

		if (InstantAction.bValid)
		{
			Info.bAvailable = true;

			if (bIsHolding && InstantAction.Action.Outcome == EBSActionOutcome::PickupTarget)
			{
				Info.DisplayName = FText::FromString("[E] Swap");
				Info.Icon = EBSInteractionIcon::Pickup;
			}
			else if (InstantAction.Action.Outcome == EBSActionOutcome::PickupTarget)
			{
				Info.DisplayName = FText::FromString("[E] " + InstantAction.Action.DisplayName.ToString());
				Info.Icon = EBSInteractionIcon::Pickup;
			}
			else
			{
				Info.DisplayName = FText::FromString("[E] " + InstantAction.Action.DisplayName.ToString());
				Info.Icon = EBSInteractionIcon::Interact;
			}
		}

		if (HoldAction.bValid)
		{
			Info.bAvailable = true;
			Info.bShowHoldProgress = true;
			Info.HoldDuration = HoldAction.Action.HoldDuration;

			if (!InstantAction.bValid)
			{
				Info.DisplayName = FText::FromString("[Hold E] " + HoldAction.Action.DisplayName.ToString());
				Info.Icon = HoldAction.Action.Outcome == EBSActionOutcome::PickupTarget
					? EBSInteractionIcon::Pickup
					: EBSInteractionIcon::Interact;
			}
		}

		FBSResolvedAction ToolAction = ResolveToolAction(Interactable, InteractorTags);
		if (ToolAction.bValid && !InstantAction.bValid && !HoldAction.bValid)
		{
			Info.bAvailable = true;
			Info.DisplayName = FText::FromString("[LMB] " + ToolAction.Action.DisplayName.ToString());
			Info.Icon = EBSInteractionIcon::Tool;
		}

		return Info;
	}
}
