event void FBSBoolDelegate(bool bIsDragging);

enum EBSDragDistance
{
	KeepOriginal,
	KeepClose,
	KeepSetDistance,
}

enum EBSDragStabilize 
{
	None,
	KeepStraight,
	KeepOriginal
}

enum EBSDragParent
{
	None,
	Yaw,
	Full
}

struct FBSDragParams
{
	UPROPERTY()
	EBSDragDistance DistanceMode = EBSDragDistance::KeepSetDistance;

	UPROPERTY()
	EBSDragStabilize StabilizationMode = EBSDragStabilize::KeepStraight;
	
	UPROPERTY()
	EBSDragParent ParentMode = EBSDragParent::Yaw;

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

	FQuat TargetItemQuat;
	float DragYawOffset = 0.0f;
	float DragDistance = 200;
	EBSDragStabilize StabilizeMode;
	EBSDragParent ParentMode;
	FQuat CameraRotationOnGrab;
	FQuat LastCameraQuat;

	UCameraComponent Camera;

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

	bool IsDragging() const
	{
		return DraggedActor != nullptr;
	}

	void StartDrag(AActor TargetActor, FBSDragParams InDragParams = FBSDragParams())
	{		
		ABSCharacter Character = Cast<ABSCharacter>(Owner);
		if (Character == nullptr)
		{
			return;
		}

		if (TargetActor == nullptr)
		{
			return;
		}

		Character.AddStateTag(GameplayTags::Backyard_Interaction_Pickup);
		Camera = Character.Camera;

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

		StabilizeMode = InDragParams.StabilizationMode;
		ParentMode = InDragParams.ParentMode;

		DraggedActor.SetActorTickEnabled(false);
		RootPrimitive.SetSimulatePhysics(true);
		RootPrimitive.SetCollisionResponseToChannel(ECollisionChannel::ECC_Pawn, ECollisionResponse::ECR_Ignore);

		switch (InDragParams.DistanceMode)
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

		
		if (ParentMode != EBSDragParent::None)
		{
			CameraRotationOnGrab = Character.Camera.WorldRotation.Quaternion();
			LastCameraQuat = CameraRotationOnGrab;
		}

		if (StabilizeMode == EBSDragStabilize::KeepStraight)
		{			
			FRotator TargetItemRotation = FRotator(0, RootPrimitive.WorldRotation.Yaw, 0);
			TargetItemQuat = TargetItemRotation.Quaternion();
			PhysicsCarry.UpdateTargetRotation(TargetItemRotation);
		}
		else
		{
			TargetItemQuat = RootPrimitive.ComponentQuat;
			PhysicsCarry.UpdateTargetRotation(RootPrimitive.WorldRotation);
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
			
			float Sqrt = Math::Sqrt(RootPrimitive.Mass);
			float Sqrt2 = 1 / Math::Sqrt(Sqrt);

			// TODO: Figure out how to automate mass on ABSSentry
			RootPrimitive.SetPhysicsLinearVelocity(RootPrimitive.GetPhysicsLinearVelocity() * Sqrt2);
			auto AngularVelocity = RootPrimitive.GetPhysicsAngularVelocityInRadians();
			RootPrimitive.SetPhysicsAngularVelocityInRadians(AngularVelocity * Sqrt2);
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
		float Delta = AxisValue * RotateSpeed;

		if (StabilizeMode == EBSDragStabilize::None)
		{
			UPrimitiveComponent RootPrimitive = Cast<UPrimitiveComponent>(DraggedActor.RootComponent);
			if (RootPrimitive != nullptr)
			{
				RootPrimitive.AddTorqueInRadians(FVector::UpVector * Delta / Gameplay::GetWorldDeltaSeconds(), NAME_None, true);
			}
		}
		else
		{
			DragYawOffset += Delta * Gameplay::GetWorldDeltaSeconds();
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
	
		FVector TargetLocation = Camera.WorldLocation + Camera.ForwardVector * DragDistance;
		PhysicsCarry.UpdateTarget(TargetLocation);

		SolveConstraints();

	}
	
	private void SolveConstraints()
	{
		FQuat CameraQuat = FQuat::Identity;

		if (ParentMode == EBSDragParent::Full)
		{
			CameraQuat = Camera.WorldRotation.Quaternion() * CameraRotationOnGrab.Inverse();
		}
		else if (ParentMode == EBSDragParent::Yaw)
		{
			float dYaw = -CameraRotationOnGrab.Rotator().Yaw + Camera.WorldRotation.Yaw;
			CameraQuat = FQuat::MakeFromRotator(FRotator(0, dYaw, 0));
		}

		FQuat ManualYaw = FQuat(FVector::UpVector, DragYawOffset);
		FQuat TargetRotation = CameraQuat * ManualYaw * TargetItemQuat;

		if (StabilizeMode == EBSDragStabilize::None)
		{
			FQuat CameraFrameDelta = FQuat::Identity;

			if (ParentMode > EBSDragParent::None)
			{
				FQuat CameraNow = Camera.WorldRotation.Quaternion();
				CameraFrameDelta = CameraNow * LastCameraQuat.Inverse();
				LastCameraQuat = CameraNow;
			}

			TargetItemQuat = CameraFrameDelta * TargetItemQuat;
			PhysicsCarry.UpdateTargetRotation(TargetItemQuat.Rotator());
		}
		else
		{
			PhysicsCarry.UpdateTargetRotation(TargetRotation.Rotator());
		}		
	}

}
