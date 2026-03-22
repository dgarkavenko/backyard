event void FSUpdateSprintMeterDelegate(float Percentage);
event void FSSprintStateChangedDelegate(bool bIsSprinting);

class ABSCharacter : ACharacter
{
	UPROPERTY(DefaultComponent, Attach = CharacterMesh0)
	USkeletalMeshComponent FirstPersonMesh;

	UPROPERTY(DefaultComponent, Attach = FirstPersonMesh, AttachSocket = head)
	UCameraComponent Camera;

	UPROPERTY(DefaultComponent, Attach = Camera)
	USpotLightComponent SpotLight;

	UPROPERTY(DefaultComponent)
	USphereComponent InteractionSphere;

	UPROPERTY(DefaultComponent)
	UBSPlacementComponent PlacementComponent;

	UPROPERTY(EditAnywhere, Category = "Interaction", meta = (ClampMin = "50", ClampMax = "1000", Units = "cm"))
	float InteractionAwarenessRadius = 300.0f;

	UPROPERTY(EditAnywhere, Category = "Interaction", meta = (ClampMin = "100", ClampMax = "5000", Units = "cm"))
	float CameraTraceDistance = 1000.0f;

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
	UInputAction PlacementToggleAction;

	UPROPERTY(Category = "Input")
	UInputAction PlacementConfirmAction;

	UPROPERTY(Category = "Input")
	UInputAction Inventory1Action;

	UPROPERTY(Category = "Input")
	UInputAction Inventory2Action;

	UPROPERTY(Category = "Input")
	UInputAction Inventory3Action;

	UPROPERTY(EditAnywhere, Category = "Walk")
	float WalkSpeed = 250.0f;

	UPROPERTY(EditAnywhere, Category = "Sprint", meta = (ClampMin = "0", ClampMax = "1"))
	float SprintFixedTickTime = 0.03333f;

	UPROPERTY(EditAnywhere, Category = "Sprint", meta = (ClampMin = "0", ClampMax = "10"))
	float SprintTime = 3.0f;

	UPROPERTY(EditAnywhere, Category = "Sprint", meta = (ClampMin = "0"))
	float SprintSpeed = 600.0f;

	UPROPERTY(EditAnywhere, Category = "Recovery", meta = (ClampMin = "0"))
	float RecoveringWalkSpeed = 150.0f;

	UPROPERTY(EditAnywhere, Category = "Recovery", meta = (ClampMin = "0", ClampMax = "10"))
	float RecoveryTime = 0.0f;

	UPROPERTY(Category = "Delegates")
	FSUpdateSprintMeterDelegate OnSprintMeterUpdated;

	UPROPERTY(Category = "Delegates")
	FSSprintStateChangedDelegate OnSprintStateChanged;

	bool bSprinting = false;
	bool bRecovering = false;
	float SprintMeter = 0.0f;
	FTimerHandle SprintTimer;
	UEnhancedInputComponent InputComp;
	TArray<UBSInteractable> NearbyInteractables;
	FHitResult CameraTraceResult;
	bool bCameraTraceHit = false;
	UBSInteractable FocusedInteractable;

	default Camera.RelativeLocation = FVector(-2.8f, 5.89f, 0.0f);
	default Camera.RelativeRotation = FRotator(0.0f, 90.0f, -90.0f);
	default Camera.bUsePawnControlRotation = true;

	default SpotLight.RelativeLocation = FVector(30.0f, 17.5f, -5.0f);
	default SpotLight.RelativeRotation = FRotator(-18.6f, -1.3f, 5.26f);
	default SpotLight.SetIntensity(0.5f);
	default SpotLight.AttenuationRadius = 1050.0f;
	default SpotLight.InnerConeAngle = 18.7f;
	default SpotLight.OuterConeAngle = 45.24f;

	default CapsuleComponent.CapsuleRadius = 34.0f;
	default CapsuleComponent.CapsuleHalfHeight = 96.0f;

	default CharacterMovement.BrakingDecelerationFalling = 1500.0f;
	default CharacterMovement.AirControl = 0.5f;

	default Mesh.VisibilityBasedAnimTickOption = EVisibilityBasedAnimTickOption::AlwaysTickPoseAndRefreshBones;
	default Mesh.SetOwnerNoSee(true);

	default FirstPersonMesh.bOnlyOwnerSee = true;
	default FirstPersonMesh.SetCollisionProfileName(n"NoCollision");

	default InteractionSphere.SetCollisionEnabled(ECollisionEnabled::QueryOnly);
	default InteractionSphere.SetGenerateOverlapEvents(true);

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		Mesh.FirstPersonPrimitiveType = EFirstPersonPrimitiveType::WorldSpaceRepresentation;		
		FirstPersonMesh.FirstPersonPrimitiveType = EFirstPersonPrimitiveType::FirstPerson;

		UBSCopyPoseAnimInstance CopyPoseAnimInstance = Cast<UBSCopyPoseAnimInstance>(FirstPersonMesh.AnimInstance);
		if (CopyPoseAnimInstance != nullptr)
		{
			CopyPoseAnimInstance.DonorSMC = Mesh;
		}
		
		Camera.bEnableFirstPersonFieldOfView = true;
		Camera.bEnableFirstPersonScale = true;
		Camera.FirstPersonFieldOfView = 70.0f;
		Camera.FieldOfView = 90.0f;
		Camera.FirstPersonScale = 0.6f;

		SpotLight.SetIntensityUnits(ELightUnits::Lumens);

		InteractionSphere.SetSphereRadius(InteractionAwarenessRadius);
		InteractionSphere.OnComponentBeginOverlap.AddUFunction(this, n"OnInteractionSphereBeginOverlap");
		InteractionSphere.OnComponentEndOverlap.AddUFunction(this, n"OnInteractionSphereEndOverlap");

		SprintMeter = SprintTime;
		CharacterMovement.MaxWalkSpeed = WalkSpeed;

		SprintTimer = System::SetTimer(this, n"SprintFixedTick", SprintFixedTickTime, bLooping = true);

		InputComp = UEnhancedInputComponent::Get(this);
		
		InputComp.BindAction(MoveAction, ETriggerEvent::Triggered, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Move"));
		InputComp.BindAction(LookAction, ETriggerEvent::Triggered, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Look"));
		InputComp.BindAction(MouseLookAction, ETriggerEvent::Triggered, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Look"));
		InputComp.BindAction(JumpAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_JumpStart"));
		InputComp.BindAction(JumpAction, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_JumpEnd"));
		InputComp.BindAction(SprintAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_SprintStart"));
		InputComp.BindAction(SprintAction, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_SprintEnd"));

		InputComp.BindAction(PlacementToggleAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_PlacementToggle"));
		InputComp.BindAction(PlacementConfirmAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_PlacementConfirm"));
		InputComp.BindAction(Inventory1Action, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Inventory1"));
		InputComp.BindAction(Inventory2Action, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Inventory2"));
		InputComp.BindAction(Inventory3Action, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Inventory3"));
	}

	UFUNCTION(BlueprintOverride)
	void EndPlay(EEndPlayReason EndPlayReason)
	{
		System::ClearAndInvalidateTimerHandle(SprintTimer);
	}

	UFUNCTION()
	void Input_Move(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		FVector2D MoveVector = ActionValue.GetAxis2D();
		AddMovementInput(GetActorRightVector(), MoveVector.X);
		AddMovementInput(GetActorForwardVector(), MoveVector.Y);
	}

	UFUNCTION()
	void Input_Look(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		FVector2D LookVector = ActionValue.GetAxis2D();
		AddControllerYawInput(LookVector.X);
		AddControllerPitchInput(LookVector.Y);
	}

	UFUNCTION()
	void Input_JumpStart(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		Jump();
	}

	UFUNCTION()
	void Input_JumpEnd(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		StopJumping();
	}

	UFUNCTION()
	void Input_SprintStart(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		bSprinting = true;

		if (!bRecovering)
		{
			CharacterMovement.MaxWalkSpeed = SprintSpeed;
			OnSprintStateChanged.Broadcast(true);
		}
	}

	UFUNCTION()
	void Input_SprintEnd(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		bSprinting = false;

		if (!bRecovering)
		{
			CharacterMovement.MaxWalkSpeed = WalkSpeed;
			OnSprintStateChanged.Broadcast(false);
		}
	}

	// ── Camera Trace ──

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		FVector Start = Camera.GetWorldLocation();
		FVector End = Start + Camera.GetForwardVector() * CameraTraceDistance;

		TArray<AActor> IgnoredActors;
		IgnoredActors.Add(this);

		bCameraTraceHit = System::LineTraceSingle(
			Start,
			End,
			ETraceTypeQuery::Visibility,
			false,
			IgnoredActors,
			EDrawDebugTrace::None,
			CameraTraceResult,
			true
		);

		if (PlacementComponent.bActive)
		{
			if (bCameraTraceHit)
			{
				PlacementComponent.UpdatePreview(CameraTraceResult);
			}
			FocusedInteractable = nullptr;
		}
		else
		{
			FocusedInteractable = bCameraTraceHit ? BSInteraction::CheckHitForInteractable(CameraTraceResult) : nullptr;
		}
	}

	// ── Placement Input ──

	UFUNCTION()
	void Input_PlacementToggle(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		PlacementComponent.Toggle();
	}

	UFUNCTION()
	void Input_PlacementConfirm(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		if (PlacementComponent.bActive)
		{
			PlacementComponent.ConfirmPlacement();
		}
	}

	UFUNCTION()
	void Input_Inventory1(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		PlacementComponent.SelectSlot(0);
	}

	UFUNCTION()
	void Input_Inventory2(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		PlacementComponent.SelectSlot(1);
	}

	UFUNCTION()
	void Input_Inventory3(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		PlacementComponent.SelectSlot(2);
	}

	// ── Interaction Awareness ──

	UFUNCTION()
	void OnInteractionSphereBeginOverlap(
		UPrimitiveComponent OverlappedComponent, AActor OtherActor,
		UPrimitiveComponent OtherComponent, int OtherBodyIndex,
		bool bFromSweep, const FHitResult&in Hit)
	{
		UBSInteractable Interactable = UBSInteractable::Get(OtherActor);
		if (Interactable != nullptr && !NearbyInteractables.Contains(Interactable))
		{
			NearbyInteractables.Add(Interactable);
		}
	}

	UFUNCTION()
	void OnInteractionSphereEndOverlap(
		UPrimitiveComponent OverlappedComponent, AActor OtherActor,
		UPrimitiveComponent OtherComponent, int OtherBodyIndex)
	{
		UBSInteractable Interactable = UBSInteractable::Get(OtherActor);
		if (Interactable != nullptr)
		{
			NearbyInteractables.Remove(Interactable);
		}
	}

	// ── Stamina System ──

	UFUNCTION()
	void SprintFixedTick()
	{
		// Drain stamina while sprinting, moving, and not recovering
		if (bSprinting && !bRecovering && GetVelocity().Size() > WalkSpeed)
		{
			if (SprintMeter > 0.0f)
			{
				SprintMeter = Math::Max(SprintMeter - SprintFixedTickTime, 0.0f);

				// Ran out of stamina — enter recovery mode
				if (SprintMeter <= 0.0f)
				{
					bRecovering = true;
					CharacterMovement.MaxWalkSpeed = RecoveringWalkSpeed;
				}
			}
		}
		else
		{
			// Recover stamina
			SprintMeter = Math::Min(SprintMeter + SprintFixedTickTime, SprintTime);

			// Fully recovered — exit recovery mode
			if (SprintMeter >= SprintTime)
			{
				bRecovering = false;
				CharacterMovement.MaxWalkSpeed = bSprinting ? SprintSpeed : WalkSpeed;
				OnSprintStateChanged.Broadcast(bSprinting);
			}
		}

		// Always broadcast the current meter percentage
		OnSprintMeterUpdated.Broadcast(SprintMeter / SprintTime);
	}
}
