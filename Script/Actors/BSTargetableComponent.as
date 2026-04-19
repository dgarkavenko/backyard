class UBSTargetableComponent : UActorComponent
{
	UPROPERTY(EditAnywhere, Category = "Targeting", Meta=(Categories="Backyard"))
	FGameplayTagContainer Tags;

	UPROPERTY(EditAnywhere, Category = "Targeting")
	bool bEnabled = true;

	UPROPERTY(EditAnywhere, Category = "Targeting", meta = (ClampMin = "0", Units = "cm/s"))
	float MovingSpeedThreshold = 10.0f;

	FVector PreviousLocation = FVector::ZeroVector;
	FVector CachedBoundsCenterLocal = FVector::ZeroVector;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		CacheBoundsCenter();
		PreviousLocation = ResolveTargetLocation();

		UBSTargetWorldSubsystem TargetWorldSubsystem = UBSTargetWorldSubsystem::Get();
		if (TargetWorldSubsystem != nullptr)
		{
			TargetWorldSubsystem.RegisterTargetable(this);
		}
	}

	UFUNCTION(BlueprintOverride)
	void EndPlay(EEndPlayReason Reason)
	{
		UBSTargetWorldSubsystem TargetWorldSubsystem = UBSTargetWorldSubsystem::Get();
		if (TargetWorldSubsystem != nullptr)
		{
			TargetWorldSubsystem.UnregisterTargetable(this);
		}
	}

	FBSTargetSnapshot BuildSnapshot(float DeltaSeconds)
	{
		FBSTargetSnapshot Snapshot;
		Snapshot.Actor = Owner;
		Snapshot.WorldLocation = ResolveTargetLocation();
		Snapshot.Velocity = DeltaSeconds > 0.0f
			? (Snapshot.WorldLocation - PreviousLocation) / DeltaSeconds
			: FVector::ZeroVector;
		Snapshot.Tags = Tags;
		Snapshot.bIsMoving = Snapshot.Velocity.SizeSquared() >= MovingSpeedThreshold * MovingSpeedThreshold;

		PreviousLocation = Snapshot.WorldLocation;
		return Snapshot;
	}

	FVector ResolveTargetLocation() const
	{
		if (Owner == nullptr)
		{
			return FVector::ZeroVector;
		}

		return Owner.ActorTransform.TransformPosition(CachedBoundsCenterLocal);
	}

	void CacheBoundsCenter()
	{
		if (Owner == nullptr)
		{
			CachedBoundsCenterLocal = FVector::ZeroVector;
			return;
		}

		FVector BoundsOrigin;
		FVector BoundsExtent;
		Owner.GetActorBounds(true, BoundsOrigin, BoundsExtent, false);
		CachedBoundsCenterLocal = Owner.ActorTransform.InverseTransformPosition(BoundsOrigin);
	}
}
