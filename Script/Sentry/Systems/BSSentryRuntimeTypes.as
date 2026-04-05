struct FBSSentryStatics
{
	ABSSentry Sentry;
	UBSChassisDefinition Chassis;
	UBSVisorDefinition Vision;
	UBSTurretDefinition Turret;
	UBSPowerSupplyUnitDefinition PowerSupply;
	UBSBatteryDefinition Battery;
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

struct FBSSentryPowerRuntime
{
	float Watt;
}
