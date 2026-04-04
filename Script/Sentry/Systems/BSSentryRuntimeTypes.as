struct FBSSentryStatics
{
	ABSSentry Sentry;
	UBSChassisDefinition Chassis;
	UBSTurretDefinition Turret;
	UBSPowerSupplyUnitDefinition PowerSupply;
	UBSBatteryDefinition Battery;
}

struct FBSSentryAimCache
{
	bool bHasAimCache = false;
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


struct FBSSentryCombatRuntime
{
	float ShotCooldownRemaining = 0.0f;
}

struct FBSSentryPowerRuntime
{
	float Watt;
}
