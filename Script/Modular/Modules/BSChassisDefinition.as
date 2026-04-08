class UBSChassisDefinition : UBSModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Aim);

	UPROPERTY(EditAnywhere, Category = "Motion", meta = (ClampMin = "0", ClampMax = "720", Units = "Degrees"))
	float RotationSpeed = 90.0f;

	UPROPERTY(EditAnywhere, Category = "Motion", meta = (ClampMin = "0", ClampMax = "720", Units = "Degrees"))
	float SweepSpeed = 45.0f;

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "W"))
	float AimPowerDrawWatts = 15.0f;

	UPROPERTY(EditAnywhere, Category = "Assembly", meta = (ForceInlineRow, TitleProperty = "{ElementId} : {bPitch} | {bYaw} | {bRoll}"))
	TArray<FBSChassisRotatorSpec> Rotators;
}
