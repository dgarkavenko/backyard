class UBSChassisDefinition : UBSModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Module_Chassis);
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Aim);

	UPROPERTY(EditAnywhere, Category = "Assembly", meta = (ForceInlineRow, TitleProperty = "{ElementId} : {bPitch} | {bYaw} | {bRoll}"))
	TArray<FBSChassisRotatorSpec> Rotators;
}
