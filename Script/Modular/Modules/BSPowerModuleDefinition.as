class UBSPowerSupplyUnitDefinition : UBSModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Power_Storage);
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Power_Tap);

	default Instalation = GameplayTag::MakeGameplayTagQuery_MatchAllTags(GameplayTag::MakeGameplayTagContainerFromTag(GameplayTags::Backyard_Module_PSU));

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "Wh"))
	float Capacity = 0.0f;

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "W"))
	float MaxOutputWatts = 0.0f;

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "W"))
	float ChargingSpeed = 0.0f;
}

class UBSBatteryDefinition : UBSModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Power_Storage);

	default Instalation = GameplayTag::MakeGameplayTagQuery_MatchAllTags(GameplayTag::MakeGameplayTagContainerFromTag(GameplayTags::Backyard_Module_Battery));

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "Wh"))
	float Capacity = 0.0f;

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "W"))
	float MaxOutputWatts = 0.0f;
	
	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "W"))
	float ChargingSpeed = 0.0f;
}