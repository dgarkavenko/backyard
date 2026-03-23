event void FBSHeldItemChangedDelegate(UBSItemData ItemData, bool bIsHolding);

class UBSHeldItemComponent : UActorComponent
{
	UPROPERTY(EditAnywhere, Category = "Held Item", meta = (ClampMin = "50", ClampMax = "300", Units = "cm"))
	float DropForwardOffset = 100.0f;

	UPROPERTY(Category = "Delegates")
	FBSHeldItemChangedDelegate OnHeldItemChanged;

	UPROPERTY(DefaultComponent)
	UBFPhysicsCarryComponent PhysicsCarry;

	AActor HeldActor;
	UBSItemData HeldItemData;
	EBSHoldMode ActiveHoldMode;
	UStaticMeshComponent DisplayMesh;
	FGameplayTagContainer GrantedTags;

	bool IsHolding() const
	{
		return HeldActor != nullptr;
	}

	FGameplayTagContainer GetGrantedTags() const
	{
		return GrantedTags;
	}

	EBSHoldMode GetHoldMode() const
	{
		return ActiveHoldMode;
	}

	void Pickup(AActor TargetActor, UBSItemData ItemData)
	{
		if (TargetActor == nullptr || ItemData == nullptr)
		{
			return;
		}

		if (IsHolding())
		{
			Drop();
		}

		HeldActor = TargetActor;
		HeldItemData = ItemData;
		ActiveHoldMode = ItemData.HoldMode;
		GrantedTags = ItemData.GrantedTags;

		if (ActiveHoldMode == EBSHoldMode::Tool)
		{
			PickupTool();
		}
		else
		{
			PickupCarry();
		}

		OnHeldItemChanged.Broadcast(HeldItemData, true);
	}

	void Drop()
	{
		if (!IsHolding())
		{
			return;
		}

		if (ActiveHoldMode == EBSHoldMode::Tool)
		{
			DropTool();
		}
		else
		{
			DropCarry();
		}

		UBSItemData PreviousItemData = HeldItemData;
		HeldActor = nullptr;
		HeldItemData = nullptr;
		GrantedTags = FGameplayTagContainer();

		OnHeldItemChanged.Broadcast(PreviousItemData, false);
	}

	void PlaceAt(FVector Location, FRotator Rotation)
	{
		if (!IsHolding())
		{
			return;
		}

		if (ActiveHoldMode == EBSHoldMode::Carry)
		{
			PhysicsCarry.Release();
			UPrimitiveComponent RootPrimitive = Cast<UPrimitiveComponent>(HeldActor.RootComponent);
			if (RootPrimitive != nullptr)
			{
				RootPrimitive.SetSimulatePhysics(false);
			}
		}

		HeldActor.SetActorLocationAndRotation(Location, Rotation);
		HeldActor.SetActorHiddenInGame(false);
		HeldActor.SetActorEnableCollision(true);
		HeldActor.SetActorTickEnabled(true);

		DestroyDisplayMesh();

		UBSItemData PreviousItemData = HeldItemData;
		HeldActor = nullptr;
		HeldItemData = nullptr;
		GrantedTags = FGameplayTagContainer();

		OnHeldItemChanged.Broadcast(PreviousItemData, false);
	}

	

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		if (!IsHolding() || ActiveHoldMode != EBSHoldMode::Carry)
		{
			return;
		}

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

		FVector TargetLocation = Camera.WorldLocation + Camera.ForwardVector * PhysicsCarry.CarryDistance;
		PhysicsCarry.UpdateTarget(TargetLocation);
	}

	// ── Tool Mode ──

	private void PickupTool()
	{
		HeldActor.SetActorHiddenInGame(true);
		HeldActor.SetActorEnableCollision(false);
		HeldActor.SetActorTickEnabled(false);

		CreateDisplayMesh();
	}

	private void DropTool()
	{
		FVector DropLocation = CalculateDropLocation();
		HeldActor.SetActorLocation(DropLocation);
		HeldActor.SetActorHiddenInGame(false);
		HeldActor.SetActorEnableCollision(true);
		HeldActor.SetActorTickEnabled(true);

		DestroyDisplayMesh();
	}

	// ── Carry Mode ──

	private void PickupCarry()
	{
		UPrimitiveComponent RootPrimitive = Cast<UPrimitiveComponent>(HeldActor.RootComponent);
		if (RootPrimitive == nullptr)
		{
			return;
		}

		HeldActor.SetActorTickEnabled(false);
		RootPrimitive.SetSimulatePhysics(true);
		RootPrimitive.SetCollisionResponseToChannel(ECollisionChannel::ECC_Pawn, ECollisionResponse::ECR_Ignore);

		PhysicsCarry.Grab(RootPrimitive);
	}

	private void DropCarry()
	{
		PhysicsCarry.Release();

		UPrimitiveComponent RootPrimitive = Cast<UPrimitiveComponent>(HeldActor.RootComponent);
		if (RootPrimitive != nullptr)
		{
			RootPrimitive.SetCollisionResponseToChannel(ECollisionChannel::ECC_Pawn, ECollisionResponse::ECR_Block);
		}
	}

	// ── Display Mesh (Tool mode) ──

	void CreateDisplayMesh()
	{
		if (HeldItemData == nullptr || HeldItemData.DisplayMesh == nullptr)
		{
			return;
		}

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

		DisplayMesh = UStaticMeshComponent::Create(Owner, n"HeldItemDisplay");
		DisplayMesh.SetStaticMesh(HeldItemData.DisplayMesh);
		DisplayMesh.AttachTo(Camera);
		DisplayMesh.RelativeTransform = HeldItemData.DisplayMeshOffset;
		DisplayMesh.SetCollisionEnabled(ECollisionEnabled::NoCollision);
		DisplayMesh.FirstPersonPrimitiveType = EFirstPersonPrimitiveType::FirstPerson;
	}

	void DestroyDisplayMesh()
	{
		if (DisplayMesh != nullptr)
		{
			DisplayMesh.DestroyComponent(Owner);
			DisplayMesh = nullptr;
		}
	}

	// ── Utilities ──

	private FVector CalculateDropLocation()
	{
		APawn OwnerPawn = Cast<APawn>(Owner);
		if (OwnerPawn == nullptr)
		{
			return Owner.ActorLocation;
		}

		UCameraComponent Camera = UCameraComponent::Get(OwnerPawn);
		if (Camera == nullptr)
		{
			return Owner.ActorLocation;
		}

		FVector Forward = Camera.ForwardVector;
		Forward.Z = 0.0f;
		Forward = Forward.GetSafeNormal();

		FVector DropStart = Owner.ActorLocation + Forward * DropForwardOffset;

		TArray<AActor> IgnoredActors;
		IgnoredActors.Add(Owner);
		if (HeldActor != nullptr)
		{
			IgnoredActors.Add(HeldActor);
		}

		FHitResult HitResult;
		bool bHit = System::LineTraceSingle(
			DropStart,
			DropStart - FVector(0.0f, 0.0f, 500.0f),
			ETraceTypeQuery::Visibility,
			false,
			IgnoredActors,
			EDrawDebugTrace::None,
			HitResult,
			true
		);

		if (bHit)
		{
			return HitResult.ImpactPoint;
		}

		return DropStart;
	}
}
