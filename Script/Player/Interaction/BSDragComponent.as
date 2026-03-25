event void FBSBoolDelegate(bool bIsDragging);

enum EBSDragDistance
{
	KeepOriginal,
	KeepClose,
	KeepSetDistance,
}

enum EBSDragStabilize
{
	Free,
	FreeWithCameraRelatedYaw,
	KeepGlobalUpVector,
	KeepGlobalUpVectorWithCameraRelatedYaw,
	KeepRotationRelatedToCamera,
	KeepGlobalRotationWithCameraRelatedYaw,
	KeepGlobalRotation,
}

struct FBSDragParams
{
	UPROPERTY()
	EBSDragDistance DragDistanceMode = EBSDragDistance::KeepSetDistance;

	UPROPERTY()
	EBSDragStabilize DragStabilizeMode = EBSDragStabilize::KeepGlobalRotation;

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
	float DragYawOffset = 0.0f;
	float DragDistance = 200;
	EBSDragStabilize StabilizeMode;
	FQuat CameraRotationOnGrab;
	float LastCameraYaw;

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

	private bool IsFreeMode() const
	{
		return StabilizeMode == EBSDragStabilize::Free
			|| StabilizeMode == EBSDragStabilize::FreeWithCameraRelatedYaw;
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
		StabilizeMode = InDragParams.DragStabilizeMode;

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

		if (IsFreeMode())
		{
			PhysicsCarry.AngularStiffness = 0;
			PhysicsCarry.AngularDamping = 10;
		}
		else
		{
			PhysicsCarry.AngularStiffness = InDragParams.AngularStiffness;
			PhysicsCarry.AngularDamping = InDragParams.AngularDamping;
		}

		PhysicsCarry.Grab(RootPrimitive);

		APawn OwnerPawn = Cast<APawn>(Owner);
		UCameraComponent Camera = UCameraComponent::Get(OwnerPawn);
		if (Camera != nullptr)
		{
			CameraRotationOnGrab = Camera.WorldRotation.Quaternion();
			LastCameraYaw = Camera.WorldRotation.Yaw;
		}

		if (StabilizeMode == EBSDragStabilize::KeepGlobalUpVector
			|| StabilizeMode == EBSDragStabilize::KeepGlobalUpVectorWithCameraRelatedYaw)
		{
			FRotator UpwardsRotation = RootPrimitive.WorldRotation;
			UpwardsRotation.Pitch = UpwardsRotation.Roll = 0;
			RotationOnStart = UpwardsRotation.Quaternion();
			PhysicsCarry.UpdateTargetRotation(UpwardsRotation);
		}
		else if (!IsFreeMode())
		{
			RotationOnStart = RootPrimitive.ComponentQuat;
			PhysicsCarry.UpdateTargetRotation(RootPrimitive.WorldRotation);
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
		if (DraggedActor == nullptr)
		{
			return;
		}

		float AxisValue = ActionValue.GetAxis1D();
		float Delta = AxisValue * RotateSpeed * Gameplay::GetWorldDeltaSeconds();

		if (IsFreeMode())
		{
			UPrimitiveComponent RootPrimitive = Cast<UPrimitiveComponent>(DraggedActor.RootComponent);
			if (RootPrimitive != nullptr)
			{
				RootPrimitive.AddTorqueInRadians(FVector::UpVector * Delta * 50.0f, NAME_None, true);
			}
		}
		else
		{
			DragYawOffset += Delta;
			while (DragYawOffset > PI) { DragYawOffset -= PI * 2.0f; }
			while (DragYawOffset < -PI) { DragYawOffset += PI * 2.0f; }
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

		if (IsFreeMode())
		{
			TickFreeMode(Camera, DeltaSeconds);
		}
		else
		{
			TickConstrainedMode(Camera);
		}
	}

	private void TickFreeMode(UCameraComponent Camera, float DeltaSeconds)
	{
		if (StabilizeMode != EBSDragStabilize::FreeWithCameraRelatedYaw)
		{
			return;
		}

		UPrimitiveComponent RootPrimitive = Cast<UPrimitiveComponent>(DraggedActor.RootComponent);
		if (RootPrimitive == nullptr)
		{
			return;
		}

		float CameraYawNow = Camera.WorldRotation.Yaw;
		float CameraYawDelta = CameraYawNow - LastCameraYaw;
		while (CameraYawDelta > 180.0f) { CameraYawDelta -= 360.0f; }
		while (CameraYawDelta < -180.0f) { CameraYawDelta += 360.0f; }
		LastCameraYaw = CameraYawNow;

		FVector AngularVelocity = RootPrimitive.GetPhysicsAngularVelocityInRadians();
		AngularVelocity.Z = Math::DegreesToRadians(CameraYawDelta) / DeltaSeconds;
		RootPrimitive.SetPhysicsAngularVelocityInRadians(AngularVelocity);
	}

	private void TickConstrainedMode(UCameraComponent Camera)
	{
		FQuat CameraQuat = FQuat::Identity;

		if (StabilizeMode == EBSDragStabilize::KeepRotationRelatedToCamera)
		{
			CameraQuat = Camera.WorldRotation.Quaternion() * CameraRotationOnGrab.Inverse();
		}
		else if (StabilizeMode == EBSDragStabilize::KeepGlobalUpVectorWithCameraRelatedYaw
			|| StabilizeMode == EBSDragStabilize::KeepGlobalRotationWithCameraRelatedYaw)
		{
			float CameraYawDelta = Camera.WorldRotation.Yaw - CameraRotationOnGrab.Rotator().Yaw;
			CameraQuat = FQuat(FVector::UpVector, Math::DegreesToRadians(CameraYawDelta));
		}

		FQuat ManualYaw = FQuat(FVector::UpVector, DragYawOffset);
		FQuat TargetRotation = CameraQuat * ManualYaw * RotationOnStart;
		PhysicsCarry.UpdateTargetRotation(TargetRotation.Rotator());
	}
}
