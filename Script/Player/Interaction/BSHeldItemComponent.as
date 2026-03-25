event void FBSHeldItemChangedDelegate(UBSItemData ItemData, bool bIsHolding);

class UBSHeldItemComponent : UActorComponent
{
	UPROPERTY(EditAnywhere, Category = "Held Item", meta = (ClampMin = "50", ClampMax = "300", Units = "cm"))
	float DropForwardOffset = 100.0f;

	UPROPERTY(Category = "Delegates")
	FBSHeldItemChangedDelegate OnHeldItemChanged;

	AActor HeldActor;
	UBSItemData HeldItemData;
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
		GrantedTags = ItemData.GrantedTags;

		HeldActor.SetActorHiddenInGame(true);
		HeldActor.SetActorEnableCollision(false);
		HeldActor.SetActorTickEnabled(false);

		CreateDisplayMesh();

		OnHeldItemChanged.Broadcast(HeldItemData, true);
	}

	void Drop()
	{
		if (!IsHolding())
		{
			return;
		}

		FVector DropLocation = CalculateDropLocation();
		HeldActor.SetActorLocation(DropLocation);
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

	void PlaceAt(FVector Location, FRotator Rotation)
	{
		if (!IsHolding())
		{
			return;
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

	void HideForPlacement()
	{
		DestroyDisplayMesh();
	}

	void RestoreFromPlacement()
	{
		CreateDisplayMesh();
	}

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
