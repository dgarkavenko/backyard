enum EBSSentryDetectorType
{
	MotionSensor,
	CameraRecognition,
	Lidar
}

class UBSVisorDefinition : UBSModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Detection);
	default Instalation = GameplayTag::MakeGameplayTagQuery_MatchAllTags(GameplayTag::MakeGameplayTagContainerFromTag(GameplayTags::Backyard_Module_Detector));

	UPROPERTY(EditAnywhere, Category = "Detection")
	EBSSentryDetectorType DetectorType = EBSSentryDetectorType::MotionSensor;

	UPROPERTY(EditAnywhere, Category = "Detection", meta = (ClampMin = "0", Units = "cm"))
	float Range = 3000.0f;

	UPROPERTY(EditAnywhere, Category = "Detection", meta = (ClampMin = "1", ClampMax = "360", Units = "Degrees"))
	float HorizontalFovDegrees = 90.0f;

	UPROPERTY(EditAnywhere, Category = "Detection", meta = (ClampMin = "0", Units = "s"))
	float DetectionInterval = 0.2f;

	UPROPERTY(EditAnywhere, Category = "Detection", meta = (ClampMin = "0", Units = "s"))
	float TargetAcquireTime = 0.0f;

	UPROPERTY(EditAnywhere, Category = "Detection", meta = (ClampMin = "0", Units = "s"))
	float ReturnToSweepDelay = 3.5f;

	UPROPERTY(EditAnywhere, Category = "Detection|Probe", meta = (ClampMin = "0", ClampMax = "360", Units = "Degrees"))
	float ProbeArcDegrees = 120.0f;

	UPROPERTY(EditAnywhere, Category = "Detection|Probe", meta = (ClampMin = "0", Units = "s"))
	float ProbeDwellTime = 1.0f;

	UPROPERTY(EditAnywhere, Category = "Detection", meta = (ClampMin = "0"))
	int MaxLosChecksPerUpdate = 8;
}
