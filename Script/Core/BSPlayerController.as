struct FSBInteractionState
{
	EBSInteractStage Stage = EBSInteractStage::Pending;
	UBSInteractionRegistry Target;
	FBSResolvedAction InstantAction;
	FBSResolvedAction HoldAction;
	float HoldProgress = 0.0f;
}

class ABSPlayerController : ABFPlayerController
{
	UPROPERTY()
	TSubclassOf<UCommonActivatableWidget> DebugScreen;

	UPROPERTY()
	TSubclassOf<UCommonActivatableWidget> HUDRoot;

	UPROPERTY(Category = "Input")
	UInputAction ShowDebugAction;

	UPROPERTY(Category = "Input")
	UInputAction PrimaryAction;

	UPROPERTY(Category = "Input")
	UInputAction InteractAction_Down;

	UPROPERTY(Category = "Input")
	UInputAction InteractAction_Tap;

	FBSInteractionPromptInfo CurrentPromptInfo;
	FSBInteractionState InteractionState;

	UBSItemData CachedHeldItemData;
	bool bCachedDragging = false;
	bool bCachedPlacementActive = false;
	bool bPromptDirty = true;

	UEnhancedInputComponent EnhancedInputComponent;

	UBSInteractionTraceComponent InteractorComponent;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		PushWidgetToPrimaryLayout(GameplayTags::ForgeryUI_Layer_Game, HUDRoot);
	}

	UFUNCTION(BlueprintOverride)
	void ReceivePossess(APawn PossessedPawn)
	{
		InteractorComponent = UBSInteractionTraceComponent::Get(PossessedPawn);
		if (InteractorComponent != nullptr)
		{
			InteractorComponent.OnFocusedInteractableChanged.AddUFunction(this, n"OnFocusedInteractableChanged");
		}
	}

	UFUNCTION(BlueprintOverride)
	void ReceiveUnPossess(APawn UnpossessedPawn)
	{
		if (InteractorComponent != nullptr)
		{
			InteractorComponent.OnFocusedInteractableChanged.Clear();
			InteractorComponent = nullptr;
		}
	}
	
	UFUNCTION()
	void OnFocusedInteractableChanged(UBSInteractionRegistry Previous, UBSInteractionRegistry Current)
	{
		bPromptDirty = true;
		
		InteractionState = FSBInteractionState();

		if (Current != nullptr)
		{
			InteractionState.Stage = EBSInteractStage::Pending;
			InteractionState.Target = Current;
			FGameplayTagContainer InteractorTags = GetBSCharacter().GetCombinedInteractorTags();
			InteractionState.InstantAction = BSInteraction::ResolveInstantAction(Current, InteractorTags);
			InteractionState.HoldAction = BSInteraction::ResolveHoldAction(Current, InteractorTags);
		}
	}

	UFUNCTION(BlueprintOverride)
	void SetupInputComponent()
	{
		EnhancedInputComponent = UEnhancedInputComponent::Get(this);

		EnhancedInputComponent.BindAction(InteractAction_Tap, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"InteractionTap_Started"));
		EnhancedInputComponent.BindAction(InteractAction_Tap, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(this, n"InteractionTap"));
		EnhancedInputComponent.BindAction(InteractAction_Down, ETriggerEvent::Triggered, FEnhancedInputActionHandlerDynamicSignature(this, n"InteractionDown"));
		EnhancedInputComponent.BindAction(InteractAction_Down, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(this, n"InteractionDownReleased"));
		
		EnhancedInputComponent.BindAction(PrimaryAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Primary"));
		EnhancedInputComponent.BindAction(ShowDebugAction, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_ShowDebug"));
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
	}

	UFUNCTION()
	void InteractionDownReleased(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		InteractionState.Stage = EBSInteractStage::Pending;
	}

	/** ElapsedTime = with .2s tap time; TriggeredTime = clean time */  
	UFUNCTION()
	void InteractionDown(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		if (InteractionState.Stage == EBSInteractStage::Completed)
		{
			return;
		}

		if (InteractionState.HoldAction.bValid)
		{
			InteractionState.Stage = EBSInteractStage::Holding;
			InteractionState.HoldProgress = TriggeredTime / InteractionState.HoldAction.Action.HoldDuration;

			if (TriggeredTime > InteractionState.HoldAction.Action.HoldDuration)
			{				
				ExecuteResolvedAction(InteractionState.HoldAction, GetBSCharacter());
				InteractionState.Stage = EBSInteractStage::Completed;
			}
		}
	}

	bool bConsumeNextTap = false;

	/** InteractionTap fires on release. In some cases we can use press event, but we have to consume it to not trigger twice*/
	UFUNCTION()
	void InteractionTap_Started(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		bConsumeNextTap = false;

		ABSCharacter Character = GetBSCharacter();
		if (Character != nullptr && Character.TryResolveCharacterAction())
		{
			bPromptDirty = true;
			bConsumeNextTap = true;
			return;
		}

		if (!InteractionState.HoldAction.bValid && InteractionState.InstantAction.bValid)
		{

			ExecuteResolvedAction(InteractionState.InstantAction, GetBSCharacter());
			InteractionState.Stage = EBSInteractStage::Completed;
			bConsumeNextTap = true;

		}
	}

	UFUNCTION()
	void InteractionTap(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		if (bConsumeNextTap)
		{
			return;
		}

		if (InteractionState.InstantAction.bValid && InteractionState.Stage != EBSInteractStage::Completed)
		{
			ExecuteResolvedAction(InteractionState.InstantAction, GetBSCharacter());
		}
		else
		{
			ABSCharacter Character = GetBSCharacter();
			if (Character != nullptr && Character.TryResolveCharacterAction())
			{
				bPromptDirty = true;
			}
		}

		InteractionState.Stage = EBSInteractStage::Pending;
	}

	UFUNCTION()
	void Input_Primary(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		ABSCharacter Character = GetBSCharacter();
		if (Character == nullptr)
		{
			return;
		}

		SpawnPrimaryProjectile(Character.Camera.WorldLocation + Character.Camera.ForwardVector * 100.0f, Character.Camera.ForwardVector, Character);

		// UBSInteractionRegistry Focused = InteractorComponent.FocusedInteractable;
		// if (Focused != nullptr)
		// {
		// 	FGameplayTagContainer InteractorTags = Character.GetCombinedInteractorTags();
		// 	FBSResolvedAction ToolAction = BSInteraction::ResolveToolAction(Focused, InteractorTags);

		// 	if (ToolAction.bValid)
		// 	{
		// 		ExecuteResolvedAction(ToolAction, Character);
		// 		return;
		// 	}
		// }
	}

	UFUNCTION()
	void Input_Cancel(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		ABSCharacter Character = GetBSCharacter();
		if (Character == nullptr)
		{
			return;
		}	
	}

	UFUNCTION()
	void Input_ShowDebug(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		PushWidgetToPrimaryLayout(GameplayTags::ForgeryUI_Layer_GameMenu, DebugScreen);
	}

	void ExecuteResolvedAction(FBSResolvedAction Resolved, AActor Interactor)
	{
		Print(f"ExecuteResolvedAction {Resolved.Action.DisplayName}");
		if (Resolved.bValid)
		{
			Resolved.Action.Delegate.ExecuteIfBound(Interactor);
			bPromptDirty = true;
		}
	}

	void UpdateDirtyState(ABSCharacter Character)
	{
		bool bCurrentDragging = Character.DragComponent.IsDragging();

		if (bCurrentDragging != bCachedDragging)
		{
			bCachedDragging = bCurrentDragging;
			bPromptDirty = true;
		}
	}

	void RecomputePrompt(ABSCharacter Character)
	{
		UBSInteractionRegistry Focused = InteractorComponent.FocusedInteractable;
		if (Focused != nullptr)
		{
			FGameplayTagContainer InteractorTags = Character.GetCombinedInteractorTags();
			bool bIsDragging = Character.DragComponent.IsDragging();
			CurrentPromptInfo = BSInteraction::BuildPromptInfo(Focused, InteractorTags, bIsDragging);
		}
		else if (Character.DragComponent.IsDragging())
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

	void SpawnPrimaryProjectile(FVector Origin, FVector Direction, AActor Causer)
	{
		if (Causer == nullptr)
		{
			return;
		}

		FBFProjectileSpawnParams Projectile;

		Projectile.DragType = EBFProjectileDrag::VeryLow;
		Projectile.Instigator = this;
		Projectile.Causer = Causer;
		Projectile.Lifetime = 10;
		Projectile.Position = Origin;
		Projectile.Velocity = Direction.GetSafeNormal() * 730 * 10;

		auto BFProjectileSubsystem = UBFProjectileSubsystem::Get();
		if (BFProjectileSubsystem != nullptr)
		{
			BFProjectileSubsystem.SpawnProjectile(Projectile);
		}
	}
}
