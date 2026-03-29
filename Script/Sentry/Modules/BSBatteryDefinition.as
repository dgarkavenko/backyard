class UBSBatteryDefinition : UBSModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Module_Battery);
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Power);

	default Instalation = GameplayTag::MakeGameplayTagQuery_MatchAllTags(GameplayTag::MakeGameplayTagContainerFromTag(GameplayTags::Backyard_Module_Battery));

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "J"))
	float Capacity = 1000.0f;

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "W"))
	float MaxDischargeRate = 50.0f;
}
