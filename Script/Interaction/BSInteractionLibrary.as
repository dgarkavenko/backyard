enum EBSInteractStage
{
	Pending,
	Holding,
	Completed
}

struct FBSFilteredAction
{
	FBFInteraction Action;
	bool bAvailable = false;
}

struct FBSResolvedAction
{
	FBFInteraction Action;
	bool bValid = false;
}

namespace BSInteraction
{
	UBSInteractionRegistry CheckHitForInteractable(FHitResult HitResult)
	{
		AActor HitActor = HitResult.GetActor();
		if (HitActor == nullptr)
		{
			return nullptr;
		}
		return UBSInteractionRegistry::Get(HitActor);
	}

	TArray<FBSFilteredAction> GetFilteredActions(UBSInteractionRegistry Interactable, FGameplayTagContainer InteractorTags)
	{
		TArray<FBSFilteredAction> FilteredActions;

		if (Interactable == nullptr)
		{
			return FilteredActions;
		}

		TArray<FBFInteraction> Actions = Interactable.GetActions();
		for (FBFInteraction Action : Actions)
		{
			FBSFilteredAction Filtered;
			Filtered.Action = Action;
			Filtered.bAvailable = Action.RequiredTags.IsEmpty() || InteractorTags.HasAll(Action.RequiredTags);
			FilteredActions.Add(Filtered);
		}

		return FilteredActions;
	}

	FBSResolvedAction ResolveInstantAction(UBSInteractionRegistry Interactable, FGameplayTagContainer InteractorTags)
	{
		FBSResolvedAction Result;

		if (Interactable == nullptr)
		{
			return Result;
		}

		TArray<FBFInteraction> Actions = Interactable.GetActions();
		for (FBFInteraction Action : Actions)
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

	FBSResolvedAction ResolveHoldAction(UBSInteractionRegistry Interactable, FGameplayTagContainer InteractorTags)
	{
		FBSResolvedAction Result;

		if (Interactable == nullptr)
		{
			return Result;
		}

		TArray<FBFInteraction> Actions = Interactable.GetActions();
		for (FBFInteraction Action : Actions)
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

	FBSResolvedAction ResolveToolAction(UBSInteractionRegistry Interactable, FGameplayTagContainer InteractorTags)
	{
		FBSResolvedAction Result;

		if (Interactable == nullptr)
		{
			return Result;
		}

		TArray<FBFInteraction> Actions = Interactable.GetActions();
		for (FBFInteraction Action : Actions)
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

	FBSInteractionPromptInfo BuildPromptInfo(UBSInteractionRegistry Interactable, FGameplayTagContainer InteractorTags, bool bIsDragging)
	{
		FBSInteractionPromptInfo Info;

		if (Interactable == nullptr)
		{
			return Info;
		}

		FBSResolvedAction InstantAction = ResolveInstantAction(Interactable, InteractorTags);
		FBSResolvedAction HoldAction = ResolveHoldAction(Interactable, InteractorTags);

		bool bIsPickup = UBSDragInteraction::Get(Interactable.Owner) != nullptr;

		if (InstantAction.bValid)
		{
			Info.bAvailable = true;

			bool bWouldSwap = bIsPickup && (bIsDragging);

			if (bWouldSwap)
			{
				Info.DisplayName = FText::FromString("[E] Swap");
				Info.Icon = EBSInteractionIcon::Pickup;
			}
			else if (bIsPickup)
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
				Info.Icon = bIsPickup ? EBSInteractionIcon::Pickup : EBSInteractionIcon::Interact;
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
