struct FBSAimHotRow
{
	int32 OwnerBaseIndex = -1;
	bool bHasAimTarget = false;
	bool bUseProbe = false;
	bool bHasConfirmation = false;

	FVector AimTargetLocation = FVector::ZeroVector;
	float ProbeYawTarget = 0.0f;
	FRotator AppliedRotator0Local = FRotator(0, 0, 0);
	FRotator AppliedRotator1Local = FRotator(0, 0, 0);
	FVector MuzzleWorldLocation = FVector::ZeroVector;
	FRotator MuzzleWorldRotation = FRotator(0, 0, 0);
	float DistanceToTarget = 0.0f;
	FRotator MuzzleError = FRotator(0, 0, 0);

	// static
	FBSSentryConstraint Rotator0Constraint;
	FBSSentryConstraint Rotator1Constraint;
}

struct FBSAimColdRow
{
	UBSChassisDefinition Chassis;
	USceneComponent Rotator0Component;
	USceneComponent Rotator1Component;
	USceneComponent MuzzleComponent;
	FVector Rotator0OffsetLocal = FVector::ZeroVector;
	FVector Rotator1OffsetLocal = FVector::ZeroVector;
	FVector MuzzleOffsetLocal = FVector::ZeroVector;
	FQuat MuzzleLocalRotation = FQuat::Identity;
}
