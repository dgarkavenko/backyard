class ABSPlayerController : ABFPlayerController
{
	UPROPERTY()
	TSubclassOf<UCommonActivatableWidget> DebugScreen;

	UPROPERTY()
	TSubclassOf<UCommonActivatableWidget> HUDRoot;

	UPROPERTY(Category = "Input")
	UInputAction ShowDebugAction;

	UPROPERTY(Category = "Input")
	UInputAction PlacementToggleAction;

	UPROPERTY(Category = "Input")
	UInputAction PlacementConfirmAction;

	UPROPERTY(Category = "Input")
	UInputAction Inventory1Action;

	UPROPERTY(Category = "Input")
	UInputAction Inventory2Action;

	UPROPERTY(Category = "Input")
	UInputAction Inventory3Action;

	UPROPERTY(EditAnywhere, Category = "Input")
	UInputMappingContext IMC_Movement;

	UPROPERTY(EditAnywhere, Category = "Input")
	UInputMappingContext IMC_Player;

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
		InputComp.BindAction(ShowDebugAction, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_ShowDebug"));
		InputComp.BindAction(PlacementToggleAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_PlacementToggle"));
		InputComp.BindAction(PlacementConfirmAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_PlacementConfirm"));
		InputComp.BindAction(Inventory1Action, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Inventory1"));
		InputComp.BindAction(Inventory2Action, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Inventory2"));
		InputComp.BindAction(Inventory3Action, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Inventory3"));
	}

	// ── Placement Input ──

	UFUNCTION()
	void Input_PlacementToggle(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		ABSCharacter Character = Cast<ABSCharacter>(GetControlledPawn());
		if (Character != nullptr)
		{
			Character.PlacementComponent.Toggle();
		}
	}

	UFUNCTION()
	void Input_PlacementConfirm(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		ABSCharacter Character = Cast<ABSCharacter>(GetControlledPawn());
		if (Character != nullptr && Character.PlacementComponent.bActive)
		{
			Character.PlacementComponent.ConfirmPlacement();
		}
	}

	UFUNCTION()
	void Input_Inventory1(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		ABSCharacter Character = Cast<ABSCharacter>(GetControlledPawn());
		if (Character != nullptr)
		{
			Character.PlacementComponent.SelectSlot(0);
		}
	}

	UFUNCTION()
	void Input_Inventory2(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		ABSCharacter Character = Cast<ABSCharacter>(GetControlledPawn());
		if (Character != nullptr)
		{
			Character.PlacementComponent.SelectSlot(1);
		}
	}

	UFUNCTION()
	void Input_Inventory3(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		ABSCharacter Character = Cast<ABSCharacter>(GetControlledPawn());
		if (Character != nullptr)
		{
			Character.PlacementComponent.SelectSlot(2);
		}
	}

	// ── Debug ──

	UFUNCTION()
	void Input_ShowDebug(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		PushWidgetToPrimaryLayout(GameplayTags::ForgeryUI_Layer_GameMenu, DebugScreen);
	}

	void EnterWorkbenchInputMode()
	{

		UEnhancedInputLocalPlayerSubsystem Subsystem = UEnhancedInputLocalPlayerSubsystem::Get(GetLocalPlayer());
		if (Subsystem != nullptr)
		{
			FModifyContextOptions Options;

			Subsystem.RemoveMappingContext(IMC_Movement, Options);
			Subsystem.RemoveMappingContext(IMC_Player, Options);
		}
	}

	void ExitWorkbenchInputMode()
	{
		UEnhancedInputLocalPlayerSubsystem Subsystem = UEnhancedInputLocalPlayerSubsystem::Get(GetLocalPlayer());
		if (Subsystem != nullptr)
		{
			FModifyContextOptions Options;

			Subsystem.AddMappingContext(IMC_Movement, 0, Options);
			Subsystem.AddMappingContext(IMC_Player, 0, Options);
		}
	}
}
