struct FBSSentryStatics
{
	AActor Actor;
	UBSModularView ModularView;
	UBSChassisDefinition Chassis;
	UBSVisorDefinition Vision;
	UBSTurretDefinition Turret;
}

struct FBSSentryAimCache
{
	USceneComponent Rotator0Component;
	USceneComponent Rotator1Component;
	USceneComponent MuzzleComponent;
	FBSSentryConstraint Rotator0Constraint;
	FBSSentryConstraint Rotator1Constraint;
	
	FVector Rotator0OffsetLocal = FVector::ZeroVector;
	FVector Rotator1OffsetLocal = FVector::ZeroVector;
	FVector MuzzleOffsetLocal = FVector::ZeroVector;
	FQuat MuzzleLocalRotation = FQuat::Identity;
}

struct FBSSentryTargetingRuntime
{
	FVector TargetLocation = FVector::ZeroVector;
	FRotator AppliedRotator0Local = FRotator(0, 0, 0);
	FRotator AppliedRotator1Local = FRotator(0, 0, 0);
	FVector MuzzleWorldLocation = FVector::ZeroVector;
	FRotator MuzzleWorldRotation = FRotator(0, 0, 0);
	float DistanceToTarget = 0.0f;
	FRotator MuzzleError = FRotator(0, 0, 0);
}

struct FBSTargetSnapshot
{
	AActor Actor;
	FVector WorldLocation = FVector::ZeroVector;
	FVector Velocity = FVector::ZeroVector;
	FGameplayTagContainer Tags;
	bool bIsMoving = false;
}

struct FBSSensedContact
{
	AActor Actor;
	FVector WorldLocation = FVector::ZeroVector;
	FVector Velocity = FVector::ZeroVector;
	float Distance = 0.0f;
	bool bHasLineOfSight = false;
	bool bRecognizedHostile = false;
}

struct FBSSentryContactMemory
{
	AActor Actor;
	FVector LastKnownLocation = FVector::ZeroVector;
	FVector LastKnownVelocity = FVector::ZeroVector;
	bool bVisibleThisUpdate = false;
	bool bSelectable = false;
	bool bRecognizedHostile = false;
	float PresenceTime = 0.0f;
	float TimeSinceVisible = 0.0f;
	float TimeSinceSelectable = 0.0f;
	float Distance = 0.0f;
}

enum EBSSentryVisionState
{
	Probing,
	Acquiring,
	Tracking,
	LostHold
}

struct FBSSentryPerceptionRuntime
{
	TArray<FBSSensedContact> Contacts;
	TArray<FBSSentryContactMemory> ContactMemory;
	AActor CurrentTarget;
	FVector CurrentTargetLocation = FVector::ZeroVector;
	float DetectionCooldownRemaining = 0.0f;
	float ProbeDwellRemaining = 0.0f;
	float ProbeYawSpeed = 0.0f;
	float ProbeDirection = 1.0f;
	EBSSentryVisionState VisionState = EBSSentryVisionState::Probing;
}

struct FBSSentryCombatRuntime
{
	float ShotCooldownRemaining = 0.0f;
}
//TODO: Move to generic systems
struct FBSPowerRuntime
{	
	TOptional<int32> TapSource;

	float ChildrenReserve;

	float Reserve;
	float AccumulatedDecrease;
	float AccumulatedTransfer;
	float Insufficency;

	float Output = 100;
	float Capacity = 0;

	bool bSupplied = false;
}

struct FBPowerRuntimeChildren
{
	TArray<FBSPowerRuntime> Batteries;
}

struct FBSSentryStore
{
	// TODO:
	// Actors and Statics.Actor is duplicate
	TArray<AActor> Actors;
	TArray<FGameplayTagContainer> Capabilities;
	TArray<FBSSentryStatics> Statics;
	TArray<FBSSentryAimCache> AimCache;
	TArray<FBSSentryPerceptionRuntime> PerceptionRuntime;
	TArray<FBSSentryTargetingRuntime> TargetingRuntime;
	TArray<FBSSentryCombatRuntime> CombatRuntime;
	TArray<FBSPowerRuntime> PowerRuntime;
	TArray<FBPowerRuntimeChildren> PowerRuntimeChildren;

	int Num() const
	{
		return Actors.Num();
	}

	int CreateRow(AActor Actor)
	{
		int RowIndex = Actors.Num();
		Actors.Add(Actor);
		Capabilities.Add(FGameplayTagContainer());
		Statics.Add(FBSSentryStatics());
		AimCache.Add(FBSSentryAimCache());
		PerceptionRuntime.Add(FBSSentryPerceptionRuntime());
		TargetingRuntime.Add(FBSSentryTargetingRuntime());
		CombatRuntime.Add(FBSSentryCombatRuntime());
		PowerRuntime.Add(FBSPowerRuntime());
		return RowIndex;
	}

	void MoveRow(int TargetRowIndex, int SourceRowIndex)
	{
		Actors[TargetRowIndex] = Actors[SourceRowIndex];
		Capabilities[TargetRowIndex] = Capabilities[SourceRowIndex];
		Statics[TargetRowIndex] = Statics[SourceRowIndex];
		AimCache[TargetRowIndex] = AimCache[SourceRowIndex];
		PerceptionRuntime[TargetRowIndex] = PerceptionRuntime[SourceRowIndex];
		TargetingRuntime[TargetRowIndex] = TargetingRuntime[SourceRowIndex];
		CombatRuntime[TargetRowIndex] = CombatRuntime[SourceRowIndex];
		PowerRuntime[TargetRowIndex] = PowerRuntime[SourceRowIndex];
	}

	void RemoveRowSwap(int RowIndex)
	{
		int LastRowIndex = Actors.Num() - 1;
		if (RowIndex != LastRowIndex)
		{
			MoveRow(RowIndex, LastRowIndex);
		}

		Actors.RemoveAt(LastRowIndex);
		Capabilities.RemoveAt(LastRowIndex);
		Statics.RemoveAt(LastRowIndex);
		AimCache.RemoveAt(LastRowIndex);
		PerceptionRuntime.RemoveAt(LastRowIndex);
		TargetingRuntime.RemoveAt(LastRowIndex);
		CombatRuntime.RemoveAt(LastRowIndex);
		PowerRuntime.RemoveAt(LastRowIndex);
	}

	void Clear()
	{
		Actors.Empty();
		Capabilities.Empty();
		Statics.Empty();
		AimCache.Empty();
		PerceptionRuntime.Empty();
		TargetingRuntime.Empty();
		CombatRuntime.Empty();
		PowerRuntime.Empty();
	}

	TOptional<int> FindRowIndex(AActor Actor) const
	{
		for (int Index = 0; Index < Actors.Num(); Index++)
		{
			if (Actors[Index] == Actor)
			{
				return Index;
			}
		}

		return TOptional<int>();
	}
}
