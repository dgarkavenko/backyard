struct FBSPowerState
{
	ABSPowerSource ConnectedSource;
	float AvailableWatts;
	float TotalDemand;
	float SupplyRatio = 1.0f;
	float BatteryRemaining;
	bool bOnBattery = false;
}

struct FBSSentryStatics
{
	ABSSentry Sentry;
	UBSSentryView SentryView;
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
	FTransform BaseWorldTransform = FTransform();
	FQuat BaseWorldRotation = FQuat::Identity;
	FVector Rotator0OffsetLocal = FVector::ZeroVector;
	FVector Rotator1OffsetLocal = FVector::ZeroVector;
	FVector MuzzleOffsetLocal = FVector::ZeroVector;
	FQuat MuzzleLocalRotation = FQuat::Identity;
	float CachedYawLateralOffset = 0.0f;
	float CachedYawForwardOffset = 0.0f;
	float CachedPitchVerticalOffset = 0.0f;
	float CachedPitchForwardOffset = 0.0f;
}

struct FBSSentryTargetingRuntime
{
	FVector TargetLocation = FVector::ZeroVector;
	FRotator DesiredRotator0Local = FRotator(0, 0, 0);
	FRotator DesiredRotator1Local = FRotator(0, 0, 0);
	FRotator AppliedRotator0Local = FRotator(0, 0, 0);
	FRotator AppliedRotator1Local = FRotator(0, 0, 0);
	FVector MuzzleWorldLocation = FVector::ZeroVector;
	FRotator MuzzleWorldRotation = FRotator(0, 0, 0);
	FRotator MuzzleError = FRotator(0, 0, 0);
	float DistanceToTarget = 0.0f;
	float AimDot = 0.0f;
	bool bHasAimSolution = false;
	bool bHasMuzzleState = false;
	bool bApplyAim = false;
}

struct FBSSentryCombatRuntime
{
	float ShotCooldownRemaining = 0.0f;
}

struct FBSSentryPowerRuntime
{
	FBSPowerState State;
}
