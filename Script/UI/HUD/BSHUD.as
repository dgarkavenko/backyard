class UBSHUDRoot : UFUActivatableWidget
{
	UPROPERTY(BindWidget)
	UFUProgressBar Reticle;

	UPROPERTY(BindWidget, meta = (BindWidget))
	UFUProjectedWidgetHost WorldMarkerHost;

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

		UpdateReticle(OwningController.InteractionState.Target != nullptr, DeltaTime);
		UpdatePromptWidgets(PromptInfo);
	}

	UFUScreenProjectedWidget RegisterWidget(
		USceneComponent Anchor,
		TSubclassOf<UFUScreenProjectedWidget> WidgetClass,
		FVector AnchorLocalOffset = FVector::ZeroVector,
		FVector2D ScreenOffset = FVector2D::ZeroVector,
		int ZOrder = 0)
	{
		if (WorldMarkerHost != nullptr)
		{
			return WorldMarkerHost.RegisterWidget(Anchor, WidgetClass, AnchorLocalOffset, ScreenOffset, ZOrder);
		}

		return nullptr;
	}

	void UnregisterWidget(USceneComponent Anchor)
	{
		if (WorldMarkerHost != nullptr)
		{
			WorldMarkerHost.UnregisterWidget(Anchor);
		}
	}

	private void UpdateReticle(bool bHasInteractionTarget, float DeltaTime)
	{
		float TargetScale = bHasInteractionTarget ? ReticleFocusedScale : ReticleNormalScale;
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
			if (OwningController.InteractionState.Stage == EBSInteractStage::Holding)
			{
				Reticle.SetValue(OwningController.InteractionState.HoldProgress);
			}

			if (Reticle.Value != 0 && OwningController.InteractionState.Stage == EBSInteractStage::Pending)
			{
				Reticle.SetValue(0);
			}
		}
	}
}
