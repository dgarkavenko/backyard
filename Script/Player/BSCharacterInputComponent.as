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

		BSInput::BindSimpleAction(InputComp, JumpAction, ETriggerEvent::Started, Character, n"Jump");
		BSInput::BindSimpleAction(InputComp, JumpAction, ETriggerEvent::Completed, Character, n"StopJumping");
		BSInput::BindSimpleAction(InputComp, SprintAction, ETriggerEvent::Started, Character, n"StartSprint");
		BSInput::BindSimpleAction(InputComp, SprintAction, ETriggerEvent::Completed, Character, n"StopSprint");
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
}
