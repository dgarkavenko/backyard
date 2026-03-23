class ABSPlayerController : ABFPlayerController
{
	UPROPERTY()
	TSubclassOf<UCommonActivatableWidget> DebugScreen;

	UPROPERTY()
	TSubclassOf<UCommonActivatableWidget> HUDRoot;

	// ── Input Actions ──

	UPROPERTY(Category = "Input")
	UInputAction ShowDebugAction;

	UPROPERTY(Category = "Input")
	UInputAction InteractAction;

	UPROPERTY(Category = "Input")
	UInputAction PrimaryAction;

	UPROPERTY(Category = "Input")
	UInputAction CancelAction;

	UPROPERTY(EditAnywhere, Category = "Input")
	UInputMappingContext IMC_Movement;

	UPROPERTY(EditAnywhere, Category = "Input")
	UInputMappingContext IMC_Player;

	// ── Prompt State ──

	FBSInteractionPromptInfo CurrentPromptInfo;

	// ── Hold-E State ──

	bool bInteractHeld = false;
	float InteractHoldTimer = 0.0f;
	UBSInteractable InteractHoldTarget;
	FBSResolvedAction InteractHoldAction;

	// ── Dirty Tracking ──

	UBSInteractable CachedFocusedInteractable;
	UBSItemData CachedHeldItemData;
	bool bCachedPlacementActive = false;
	bool bPromptDirty = true;

	UEnhancedInputComponent InputComp;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		PushWidgetToPrimaryLayout(GameplayTags::ForgeryUI_Layer_Game, HUDRoot);
	}

	UFUNCTION(BlueprintOverride)
	void SetupInputComponent()
	{
		InputComp = UEnhancedInputComponent::Get(this);

		InputComp.BindAction(InteractAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_InteractStarted"));
		InputComp.BindAction(InteractAction, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_InteractReleased"));
		InputComp.BindAction(PrimaryAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Primary"));
		InputComp.BindAction(CancelAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Cancel"));
		InputComp.BindAction(ShowDebugAction, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_ShowDebug"));
	}

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		ABSCharacter Character = GetBSCharacter();
		if (Character == nullptr)
		{
			return;
		}

		UpdateDirtyState(Character);

		if (bPromptDirty)
		{
			RecomputePrompt(Character);
			bPromptDirty = false;
		}

		if (bInteractHeld)
		{
			UpdateHoldTimer(Character, DeltaSeconds);
		}

		if (Character.PlacementComponent.bActive && Character.bCameraTraceHit)
		{
			Character.PlacementComponent.UpdatePreview(Character.CameraTraceResult);
		}
	}

	// ── Input Handlers ──

	UFUNCTION()
	void Input_InteractStarted(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		ABSCharacter Character = GetBSCharacter();
		if (Character == nullptr)
		{
			return;
		}

		if (Character.PlacementComponent.bActive)
		{
			Character.PlacementComponent.CancelPlacement(Character.HeldItemComponent);
			bPromptDirty = true;
			return;
		}

		UBSInteractable Focused = Character.FocusedInteractable;

		if (Focused != nullptr)
		{
			FGameplayTagContainer InteractorTags = Character.HeldItemComponent.GetGrantedTags();
			FBSResolvedAction HoldAction = BSInteraction::ResolveHoldAction(Focused, InteractorTags);

			if (HoldAction.bValid)
			{
				Print(f"[Hold] Started: {HoldAction.Action.DisplayName} ({HoldAction.Action.HoldDuration:.1f}s)");
				bInteractHeld = true;
				InteractHoldTimer = 0.0f;
				InteractHoldTarget = Focused;
				InteractHoldAction = HoldAction;
				return;
			}

			FBSResolvedAction InstantAction = BSInteraction::ResolveInstantAction(Focused, InteractorTags);
			if (InstantAction.bValid)
			{
				Print(f"[Interact] {InstantAction.Action.DisplayName}");
				ExecuteResolvedAction(Character, InstantAction, Focused);
				return;
			}
		}

		if (Character.HeldItemComponent.IsHolding())
		{
			Print("[Interact] Drop");
			Character.HeldItemComponent.Drop();
			bPromptDirty = true;
		}
	}

	UFUNCTION()
	void Input_InteractReleased(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		ABSCharacter Character = GetBSCharacter();
		if (Character == nullptr)
		{
			return;
		}

		bool bWasHolding = bInteractHeld;
		ResetHoldState();

		UBSInteractable Focused = Character.FocusedInteractable;

		if (Focused != nullptr)
		{
			FGameplayTagContainer InteractorTags = Character.HeldItemComponent.GetGrantedTags();
			FBSResolvedAction InstantAction = BSInteraction::ResolveInstantAction(Focused, InteractorTags);

			if (InstantAction.bValid)
			{
				ExecuteResolvedAction(Character, InstantAction, Focused);
				return;
			}
		}

		if (Focused == nullptr && Character.HeldItemComponent.IsHolding())
		{
			Character.HeldItemComponent.Drop();
			bPromptDirty = true;
		}
	}

	UFUNCTION()
	void Input_Primary(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		ABSCharacter Character = GetBSCharacter();
		if (Character == nullptr)
		{
			return;
		}

		if (Character.PlacementComponent.bActive)
		{
			Character.PlacementComponent.ConfirmPlacement(Character.HeldItemComponent);
			bPromptDirty = true;
			return;
		}

		if (!Character.HeldItemComponent.IsHolding())
		{
			return;
		}

		UBSItemData HeldData = Character.HeldItemComponent.HeldItemData;

		if (HeldData != nullptr && HeldData.bPlaceable)
		{
			Character.PlacementComponent.ActivatePlacement(Character.HeldItemComponent);
			bPromptDirty = true;
			return;
		}

		UBSInteractable Focused = Character.FocusedInteractable;
		if (Focused != nullptr)
		{
			FGameplayTagContainer InteractorTags = Character.HeldItemComponent.GetGrantedTags();
			FBSResolvedAction ToolAction = BSInteraction::ResolveToolAction(Focused, InteractorTags);

			if (ToolAction.bValid)
			{
				ExecuteResolvedAction(Character, ToolAction, Focused);
			}
		}
	}

	UFUNCTION()
	void Input_Cancel(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		ABSCharacter Character = GetBSCharacter();
		if (Character == nullptr)
		{
			return;
		}

		if (Character.PlacementComponent.bActive)
		{
			Character.PlacementComponent.CancelPlacement(Character.HeldItemComponent);
			bPromptDirty = true;
		}
	}

	UFUNCTION()
	void Input_ShowDebug(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		PushWidgetToPrimaryLayout(GameplayTags::ForgeryUI_Layer_GameMenu, DebugScreen);
	}

	// ── Action Execution Pipeline ──

	void ExecuteResolvedAction(ABSCharacter Character, FBSResolvedAction Resolved, UBSInteractable Target)
	{
		if (!Resolved.bValid)
		{
			return;
		}

		FGameplayTagContainer InteractorTags = Character.HeldItemComponent.GetGrantedTags();
		BSInteraction::ExecuteAction(Target, Resolved.Action.ActionTag, Character, InteractorTags);

		switch (Resolved.Action.Outcome)
		{
			case EBSActionOutcome::PickupTarget:
			{
				if (Target.ItemData != nullptr)
				{
					Character.HeldItemComponent.Pickup(Target.Owner, Target.ItemData);
				}
				break;
			}
			case EBSActionOutcome::None:
			default:
			{
				break;
			}
		}

		bPromptDirty = true;
	}

	// ── Hold Timer ──

	void UpdateHoldTimer(ABSCharacter Character, float DeltaSeconds)
	{
		if (InteractHoldTarget != Character.FocusedInteractable)
		{
			FString OldName = InteractHoldTarget != nullptr ? InteractHoldTarget.Owner.GetName().ToString() : "null";
			FString NewName = Character.FocusedInteractable != nullptr ? Character.FocusedInteractable.Owner.GetName().ToString() : "null";
			Print(f"[Hold] Target changed: {OldName} -> {NewName}, cancelling");
			ResetHoldState();
			return;
		}

		InteractHoldTimer += DeltaSeconds;
		Print(f"[Hold] {InteractHoldTimer:.2f} / {InteractHoldAction.Action.HoldDuration:.2f}", Duration = 0.0f);

		if (InteractHoldTimer >= InteractHoldAction.Action.HoldDuration)
		{
			FBSResolvedAction CompletedAction = InteractHoldAction;
			UBSInteractable CompletedTarget = InteractHoldTarget;
			ResetHoldState();

			ExecuteResolvedAction(Character, CompletedAction, CompletedTarget);
		}
	}

	void ResetHoldState()
	{
		bInteractHeld = false;
		InteractHoldTimer = 0.0f;
		InteractHoldTarget = nullptr;
		InteractHoldAction = FBSResolvedAction();
	}

	// ── Dirty Tracking / Prompt Cache ──

	void UpdateDirtyState(ABSCharacter Character)
	{
		UBSInteractable CurrentFocused = Character.FocusedInteractable;
		UBSItemData CurrentHeldData = Character.HeldItemComponent.HeldItemData;
		bool bCurrentPlacement = Character.PlacementComponent.bActive;

		if (CurrentFocused != CachedFocusedInteractable
			|| CurrentHeldData != CachedHeldItemData
			|| bCurrentPlacement != bCachedPlacementActive)
		{
			CachedFocusedInteractable = CurrentFocused;
			CachedHeldItemData = CurrentHeldData;
			bCachedPlacementActive = bCurrentPlacement;
			bPromptDirty = true;
		}
	}

	void RecomputePrompt(ABSCharacter Character)
	{
		if (Character.PlacementComponent.bActive)
		{
			CurrentPromptInfo = FBSInteractionPromptInfo();
			CurrentPromptInfo.bAvailable = true;
			CurrentPromptInfo.DisplayName = FText::FromString("[LMB] Place  [RMB] Cancel");
			CurrentPromptInfo.Icon = EBSInteractionIcon::Interact;
			return;
		}

		UBSInteractable Focused = Character.FocusedInteractable;
		if (Focused != nullptr)
		{
			FGameplayTagContainer InteractorTags = Character.HeldItemComponent.GetGrantedTags();
			bool bIsHolding = Character.HeldItemComponent.IsHolding();
			CurrentPromptInfo = BSInteraction::BuildPromptInfo(Focused, InteractorTags, bIsHolding);
		}
		else if (Character.HeldItemComponent.IsHolding())
		{
			CurrentPromptInfo = FBSInteractionPromptInfo();
			CurrentPromptInfo.bAvailable = true;
			CurrentPromptInfo.DisplayName = FText::FromString("[E] Drop");
			CurrentPromptInfo.Icon = EBSInteractionIcon::Pickup;
		}
		else
		{
			CurrentPromptInfo = FBSInteractionPromptInfo();
		}
	}

	ABSCharacter GetBSCharacter()
	{
		return Cast<ABSCharacter>(GetControlledPawn());
	}
}
