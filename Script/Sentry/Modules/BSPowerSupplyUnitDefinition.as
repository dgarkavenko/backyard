class UBSPowerSupplyUnitDefinition : UBSModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Module_PSU);
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Power);

	default Instalation = GameplayTag::MakeGameplayTagQuery_MatchAllTags(GameplayTag::MakeGameplayTagContainerFromTag(GameplayTags::Backyard_Module_PSU));

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "W"))
	float MaxDraw = 100.0f;

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", ClampMax = "1"))
	float Efficiency = 0.9f;

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "cm"))
	float ConnectionRange = 500.0f;
}
