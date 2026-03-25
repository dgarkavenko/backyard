event void FBSBoolDelegate(bool bIsDragging);

enum EBSDragDistance
{
	KeepOriginal,
	KeepClose,
	KeepSetDistance,	
}

enum EBSDragStabilize
{
	KeepOriginal,
	KeepUpwards,
	Free
}

struct FBSDragParams
{
	UPROPERTY()
	EBSDragDistance DragDistanceMode = EBSDragDistance::KeepSetDistance;

	UPROPERTY()
	EBSDragStabilize DragStabilizeMode = EBSDragStabilize::KeepOriginal;

	UPROPERTY()
	float DragDistance = 200.0f;

	UPROPERTY()	
	float LinearStiffness = 350.0f;

	UPROPERTY()	
	float LinearDamping = 100.0f;

	UPROPERTY()	
	float AngularStiffness = 450.0f;

	UPROPERTY()
	float AngularDamping = 100.0f;

	UPROPERTY()
	FVector CameraRotationInfluence = FVector(0, 0, 0);
}

class UBSDragComponent : UActorComponent
{
	default PrimaryComponentTick.bStartWithTickEnabled = false;

	UPROPERTY(EditAnywhere, Category = "Drag|Input")
	UInputMappingContext IMC_Drag;

	UPROPERTY(EditAnywhere, Category = "Drag|Input")
	UInputAction DragRotateAction;

	UPROPERTY(EditAnywhere, Category = "Drag|Input", meta = (ClampMin = "0", ClampMax = "30", Units = "Rad"))
	float RotateSpeed = Math::DegreesToRadians(180.0f);

	UBFPhysicsCarryComponent PhysicsCarry;
	AActor DraggedActor;

	FQuat RotationOnStart;
	FQuat FreeRotation;
	float DragYawOffset = 0.0f;
	
	float DragDistance = 200;
	EBSDragStabilize StabilizeMode;
	FVector CameraRotationInfluence;
	FQuat CameraRotationOnGrab;
	
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

	void StartDrag(AActor TargetActor, FBSDragParams InDragParams = FBSDragParams())
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

		switch (InDragParams.DragDistanceMode)
		{
			case EBSDragDistance::KeepSetDistance:
				DragDistance = InDragParams.DragDistance;
				break;
			case EBSDragDistance::KeepOriginal:
				DragDistance = InDragParams.DragDistance;
				break;
			case EBSDragDistance::KeepClose:
			{
				FVector ActorOrigin;
				FVector ActorExtent;				
				TargetActor.GetActorBounds(true, ActorOrigin, ActorExtent);
				DragDistance = ActorExtent.Size();			
				break;
			}

		}

		PhysicsCarry.LinearStiffness = InDragParams.LinearStiffness;
		PhysicsCarry.LinearDamping = InDragParams.LinearDamping;
		PhysicsCarry.AngularStiffness = InDragParams.AngularStiffness;
		PhysicsCarry.AngularDamping = InDragParams.AngularDamping;
		PhysicsCarry.Grab(RootPrimitive);

		StabilizeMode = InDragParams.DragStabilizeMode;
		CameraRotationInfluence = InDragParams.CameraRotationInfluence;

		APawn OwnerPawn = Cast<APawn>(Owner);
		UCameraComponent Camera = UCameraComponent::Get(OwnerPawn);
		if (Camera != nullptr)
		{
			CameraRotationOnGrab = Camera.WorldRotation.Quaternion();
		}

		if (StabilizeMode == EBSDragStabilize::KeepUpwards)
		{
			FRotator UpwardsRotation = RootPrimitive.WorldRotation;
			UpwardsRotation.Pitch = UpwardsRotation.Roll = 0;
			RotationOnStart = UpwardsRotation.Quaternion();
			PhysicsCarry.UpdateTargetRotation(UpwardsRotation);
		}
		else
		{
			RotationOnStart = RootPrimitive.ComponentQuat;
			FreeRotation = RotationOnStart;
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
			float Delta = AxisValue * RotateSpeed * Gameplay::GetWorldDeltaSeconds();

			if (StabilizeMode == EBSDragStabilize::Free)
			{
				FQuat DeltaRotation = FQuat(FVector::UpVector, Delta);
				FreeRotation = DeltaRotation * FreeRotation;
			}
			else
			{
				DragYawOffset += Delta;
				while (DragYawOffset > PI) { DragYawOffset -= PI * 2.0f; }
				while (DragYawOffset < -PI) { DragYawOffset += PI * 2.0f; }
			}			
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

		FQuat CameraNow = Camera.WorldRotation.Quaternion();
		FQuat CameraDelta = CameraNow * CameraRotationOnGrab.Inverse();
		FRotator CameraDeltaEuler = CameraDelta.Rotator();
		FRotator ScaledCameraDelta = FRotator(
			CameraDeltaEuler.Pitch * CameraRotationInfluence.X,
			CameraDeltaEuler.Yaw * CameraRotationInfluence.Y,
			CameraDeltaEuler.Roll * CameraRotationInfluence.Z
		);
		FQuat CameraInfluenceQuat = ScaledCameraDelta.Quaternion();

		if (StabilizeMode == EBSDragStabilize::Free)
		{
			FreeRotation = FQuat::FastLerp(FreeRotation, DraggedActor.ActorQuat, DeltaSeconds * 2);
			FQuat TargetRotation = CameraInfluenceQuat * FreeRotation;
			PhysicsCarry.UpdateTargetRotation(TargetRotation.Rotator());
		}
		else
		{
			FQuat ManualYaw = FQuat(FVector::UpVector, DragYawOffset);
			FQuat TargetRotation = CameraInfluenceQuat * ManualYaw * RotationOnStart;
			PhysicsCarry.UpdateTargetRotation(TargetRotation.Rotator());
		}
	}
}
