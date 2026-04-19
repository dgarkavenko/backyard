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

struct FBSDetectionHotRow
{
	int32 OwnerBaseIndex = -1;
	FBSDetectionLinks Links;
	TArray<FBSSensedContact> Contacts;
	TArray<FBSSentryContactMemory> ContactMemory;
	AActor CurrentTarget;
	FVector CurrentTargetLocation = FVector::ZeroVector;
	float DetectionCooldownRemaining = 0.0f;
	float ProbeDwellRemaining = 0.0f;
	float ProbeDirection = 1.0f;
	float ProbeTargetYaw = 0.0f;
	EBSSentryVisionState VisionState = EBSSentryVisionState::Probing;

	// static
	EBSSentryDetectorType DetectorType = EBSSentryDetectorType::MotionSensor;
	float Range = 3000.0f;
	float HorizontalFovDegrees = 90.0f;
	float DetectionInterval = 0.2f;
	float TargetAcquireTime = 0.0f;
	float ReturnToSweepDelay = 3.5f;
	float ProbeArcDegrees = 120.0f;
	float ProbeDwellTime = 1.0f;
	int32 MaxLosChecksPerUpdate = 8;
	float DetectionPowerDrawWatts = 10.0f;
	float ProbeYawSpeed = 0.0f;
}

struct FBSDetectionColdRow
{
	UBSVisorDefinition Detector;
	USceneComponent SensorComponent;
}
