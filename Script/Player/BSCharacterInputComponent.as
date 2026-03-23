class UBSCharacterInputComponent : UActorComponent
{
	UPROPERTY(Category = "Input")
	UInputAction MoveAction;

	UPROPERTY(Category = "Input")
	UInputAction LookAction;

	UPROPERTY(Category = "Input")
	UInputAction MouseLookAction;

	UPROPERTY(Category = "Input")
	UInputAction JumpAction;

	UPROPERTY(Category = "Input")
	UInputAction SprintAction;

	UPROPERTY(Category = "Input")
	UInputAction InteractAction;

	ABSCharacter Character;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		Character = Cast<ABSCharacter>(Owner);
		if (Character == nullptr)
		{
			return;
		}

		UEnhancedInputComponent InputComp = UEnhancedInputComponent::Get(Character);

		InputComp.BindAction(MoveAction, ETriggerEvent::Triggered, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Move"));
		InputComp.BindAction(LookAction, ETriggerEvent::Triggered, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Look"));
		InputComp.BindAction(MouseLookAction, ETriggerEvent::Triggered, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Look"));
		InputComp.BindAction(JumpAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_JumpStart"));
		InputComp.BindAction(JumpAction, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_JumpEnd"));
		InputComp.BindAction(SprintAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_SprintStart"));
		InputComp.BindAction(SprintAction, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_SprintEnd"));
		InputComp.BindAction(InteractAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Interact"));
	}

	UFUNCTION()
	void Input_Move(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		FVector2D MoveVector = ActionValue.GetAxis2D();
		Character.AddMovementInput(Character.GetActorRightVector(), MoveVector.X);
		Character.AddMovementInput(Character.GetActorForwardVector(), MoveVector.Y);
	}

	UFUNCTION()
	void Input_Look(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		FVector2D LookVector = ActionValue.GetAxis2D();
		Character.AddControllerYawInput(LookVector.X);
		Character.AddControllerPitchInput(LookVector.Y);
	}

	UFUNCTION()
	void Input_JumpStart(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		Character.Jump();
	}

	UFUNCTION()
	void Input_JumpEnd(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		Character.StopJumping();
	}

	UFUNCTION()
	void Input_SprintStart(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		Character.StartSprint();
	}

	UFUNCTION()
	void Input_SprintEnd(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		Character.StopSprint();
	}

	UFUNCTION()
	void Input_Interact(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		if (Character.FocusedInteractable == nullptr)
		{
			return;
		}

		if (Character.FocusedInteractable.ActionSet == nullptr)
		{
			return;
		}

		if (Character.FocusedInteractable.ActionSet.Actions.Num() == 0)
		{
			return;
		}

		FGameplayTagContainer InteractorTags;
		BSInteraction::ExecuteAction(
			Character.FocusedInteractable,
			Character.FocusedInteractable.ActionSet.Actions[0].ActionTag,
			Character,
			InteractorTags
		);
	}
}
