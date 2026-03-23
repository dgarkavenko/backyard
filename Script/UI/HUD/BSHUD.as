class UBSHUDRoot : UFUActivatableWidget
{
	UPROPERTY(BindWidget)
	UFUProgressBar Reticle;

	UPROPERTY(BindWidget, meta = (BindWidgetOptional))
	UTextBlock InteractionPromptText;

	UPROPERTY(EditAnywhere, Category = "Reticle")
	float ReticleNormalScale = 1.0f;

	UPROPERTY(EditAnywhere, Category = "Reticle")
	float ReticleFocusedScale = 1.5f;

	UPROPERTY(EditAnywhere, Category = "Reticle")
	float ReticleInterpSpeed = 10.0f;

	ABSPlayerController OwningController;
	float CurrentReticleScale = 1.0f;
	bool bLastPromptAvailable = false;

	UFUNCTION(BlueprintOverride)
	void Construct()
	{
		OwningController = Cast<ABSPlayerController>(GetOwningPlayer());
	}

	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float DeltaTime)
	{
		if (OwningController == nullptr)
		{
			return;
		}

		FBSInteractionPromptInfo PromptInfo = OwningController.CurrentPromptInfo;

		UpdateReticle(PromptInfo, DeltaTime);
		UpdatePromptWidgets(PromptInfo);
		PrintDebugState(PromptInfo);
	}

	private void UpdateReticle(FBSInteractionPromptInfo PromptInfo, float DeltaTime)
	{
		float TargetScale = PromptInfo.bAvailable ? ReticleFocusedScale : ReticleNormalScale;
		CurrentReticleScale = Math::FInterpTo(CurrentReticleScale, TargetScale, DeltaTime, ReticleInterpSpeed);
		Reticle.SetRenderScale(FVector2D(CurrentReticleScale, CurrentReticleScale));
	}

	private void UpdatePromptWidgets(FBSInteractionPromptInfo PromptInfo)
	{
		if (InteractionPromptText != nullptr)
		{
			if (PromptInfo.bAvailable)
			{
				InteractionPromptText.SetText(PromptInfo.DisplayName);
				InteractionPromptText.SetVisibility(ESlateVisibility::HitTestInvisible);
			}
			else
			{
				InteractionPromptText.SetVisibility(ESlateVisibility::Collapsed);
			}
		}

		if (Reticle != nullptr)
		{
			if (PromptInfo.bShowHoldProgress && OwningController.bInteractHeld)
			{
				float Progress = OwningController.InteractHoldTimer / PromptInfo.HoldDuration;
				Reticle.SetValue(Math::Clamp(Progress, 0.0f, 1.0f));
				Reticle.SetVisibility(ESlateVisibility::HitTestInvisible);
			}
		}
	}

	private void PrintDebugState(FBSInteractionPromptInfo PromptInfo)
	{
		if (PromptInfo.bAvailable == bLastPromptAvailable && !OwningController.bPromptDirty)
		{
			if (OwningController.bInteractHeld)
			{
				float Progress = OwningController.InteractHoldTimer / PromptInfo.HoldDuration;
				Print(f"[Hold] {Math::RoundToInt(Progress * 100)}%", 0);
			}
			return;
		}

		bLastPromptAvailable = PromptInfo.bAvailable;

		ABSCharacter Character = OwningController.GetBSCharacter();
		if (Character == nullptr)
		{
			return;
		}

		FString FocusedName = Character.FocusedInteractable != nullptr
			? Character.FocusedInteractable.Owner.GetName().ToString()
			: "none";

		FString PromptText = PromptInfo.bAvailable
			? PromptInfo.DisplayName.ToString()
			: "---";

		FString HeldName = Character.HeldItemComponent.IsHolding()
			? Character.HeldItemComponent.HeldItemData.GetName().ToString()
			: "none";

		FString HoldModeStr = Character.HeldItemComponent.IsHolding()
			? (Character.HeldItemComponent.GetHoldMode() == EBSHoldMode::Tool ? "Tool" : "Carry")
			: "---";

		FString PlacementStr = Character.PlacementComponent.bActive ? "ACTIVE" : "off";

		Print(f"[Interaction] Focus: {FocusedName} | Prompt: {PromptText} | Held: {HeldName} ({HoldModeStr}) | Placement: {PlacementStr} }", 0);
	}
}
