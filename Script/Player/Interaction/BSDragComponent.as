event void FBSBoolDelegate(bool bIsDragging);

class UBSDragComponent : UActorComponent
{
	default PrimaryComponentTick.bStartWithTickEnabled = false;

	UPROPERTY(EditAnywhere, Category = "Drag|Input")
	UInputMappingContext IMC_Drag;

	UPROPERTY(EditAnywhere, Category = "Drag|Input")
	UInputAction DragRotateAction;

	UPROPERTY(EditAnywhere, Category = "Drag|Input", meta = (ClampMin = "0", ClampMax = "720", Units = "Rad"))
	float RotateSpeed = Math::DegreesToRadians(180.0f);

	UPROPERTY(EditAnywhere, Category = "Drag|Physics", meta = (ClampMin = "50", ClampMax = "500", Units = "cm"))
	float DragDistance = 200.0f;

	UPROPERTY(EditAnywhere, Category = "Drag|Physics")
	float GrabLinearStiffness = 350.0f;

	UPROPERTY(EditAnywhere, Category = "Drag|Physics")
	float GrabLinearDamping = 100.0f;

	UBFPhysicsCarryComponent PhysicsCarry;
	AActor DraggedActor;

	float DragYawOffset = 0.0f;
	FQuat RotationOnStart;

	bool bStabilize = true;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		PhysicsCarry = UBFPhysicsCarryComponent::Get(Owner);

		UEnhancedInputComponent InputComponent = UEnhancedInputComponent::Get(Owner);
		if (InputComponent != nullptr && DragRotateAction != nullptr)
		{
			InputComponent.BindAction(DragRotateAction, ETriggerEvent::Triggered,
				FEnhancedInputActionHandlerDynamicSignature(this, n"Rotate"));
		}
	}

	bool IsDragging() const
	{
		return DraggedActor != nullptr;
	}

	void StartDrag(AActor TargetActor)
	{
		if (TargetActor == nullptr)
		{
			return;
		}

		if (IsDragging())
		{
			Warning("StartDrag while IsDragging() == true");
			return;
		}

		SetComponentTickEnabled(true);

		DraggedActor = TargetActor;

		UPrimitiveComponent RootPrimitive = Cast<UPrimitiveComponent>(DraggedActor.RootComponent);
		if (RootPrimitive == nullptr)
		{
			return;
		}

		DragYawOffset = 0;

		DraggedActor.SetActorTickEnabled(false);
		RootPrimitive.SetSimulatePhysics(true);
		RootPrimitive.SetCollisionResponseToChannel(ECollisionChannel::ECC_Pawn, ECollisionResponse::ECR_Ignore);

		PhysicsCarry.CarryDistance = DragDistance;
		PhysicsCarry.LinearStiffness = GrabLinearStiffness;
		PhysicsCarry.LinearDamping = GrabLinearDamping;
		PhysicsCarry.AngularStiffness = 450.0f;
		PhysicsCarry.AngularDamping = 100.0f;
		PhysicsCarry.Grab(RootPrimitive);

		if (bStabilize)
		{
			FRotator UpwardsRotation = RootPrimitive.WorldRotation;
			UpwardsRotation.Pitch = UpwardsRotation.Roll = 0;
			RotationOnStart = UpwardsRotation.Quaternion();
			PhysicsCarry.UpdateTargetRotation(UpwardsRotation);

		}					
		else
		{
			RotationOnStart = RootPrimitive.ComponentQuat;
		}

		ABSCharacter Character = Cast<ABSCharacter>(Owner);
		if (Character != nullptr)
		{
			Character.AddStateTag(GameplayTags::Backyard_Interaction_Pickup);
		}

		AddDragMappingContext();
	}

	void StopDrag()
	{
		if (!IsDragging())
		{
			return;
		}

		SetComponentTickEnabled(false);		

		RemoveDragMappingContext();
		PhysicsCarry.Release();

		UPrimitiveComponent RootPrimitive = Cast<UPrimitiveComponent>(DraggedActor.RootComponent);
		if (RootPrimitive != nullptr)
		{
			RootPrimitive.SetCollisionResponseToChannel(ECollisionChannel::ECC_Pawn, ECollisionResponse::ECR_Block);
		}

		DraggedActor = nullptr;

		ABSCharacter Character = Cast<ABSCharacter>(Owner);
		if (Character != nullptr)
		{
			Character.RemoveStateTag(GameplayTags::Backyard_Interaction_Pickup);
		}
	}

	UFUNCTION()
	void Rotate(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
		if (DraggedActor != nullptr)
		{
			float AxisValue = ActionValue.GetAxis1D();
			DragYawOffset += AxisValue * RotateSpeed * Gameplay::GetWorldDeltaSeconds();
			FQuat DeltaRotation = FQuat(FVector::UpVector, DragYawOffset);
			PhysicsCarry.UpdateTargetRotation((DeltaRotation * RotationOnStart).Rotator());			
		}		
	}

	private void AddDragMappingContext()
	{
		APawn OwnerPawn = Cast<APawn>(Owner);
		if (OwnerPawn == nullptr)
		{
			return;
		}

		APlayerController PlayerController = Cast<APlayerController>(OwnerPawn.Controller);
		if (PlayerController == nullptr)
		{
			return;
		}

		UEnhancedInputLocalPlayerSubsystem Subsystem = UEnhancedInputLocalPlayerSubsystem::Get(PlayerController);
		if (Subsystem != nullptr)
		{
			Subsystem.AddMappingContext(IMC_Drag, 1, FModifyContextOptions());
		}
	}

	private void RemoveDragMappingContext()
	{
		APawn OwnerPawn = Cast<APawn>(Owner);
		if (OwnerPawn == nullptr)
		{
			return;
		}

		APlayerController PlayerController = Cast<APlayerController>(OwnerPawn.Controller);
		if (PlayerController == nullptr)
		{
			return;
		}

		UEnhancedInputLocalPlayerSubsystem Subsystem = UEnhancedInputLocalPlayerSubsystem::Get(PlayerController);
		if (Subsystem != nullptr)
		{
			Subsystem.RemoveMappingContext(IMC_Drag, FModifyContextOptions());
		}
	}

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		APawn OwnerPawn = Cast<APawn>(Owner);
		if (OwnerPawn == nullptr)
		{
			return;
		}

		UCameraComponent Camera = UCameraComponent::Get(OwnerPawn);
		if (Camera == nullptr)
		{
			return;
		}

		FVector TargetLocation = Camera.WorldLocation + Camera.ForwardVector * DragDistance;
		PhysicsCarry.UpdateTarget(TargetLocation);


	}
}
