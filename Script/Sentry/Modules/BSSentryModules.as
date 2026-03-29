class UBSChassisDefinition : UBFModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Module_Chassis);
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Aim);

	UPROPERTY(EditAnywhere, Category = "Meshes")
	UStaticMesh BaseMesh;

	UPROPERTY(EditAnywhere, Category = "Meshes")
	UStaticMesh PlatformMesh;

	UPROPERTY(EditAnywhere, Category = "Rotator01")
	UStaticMesh Rotator01Mesh;

	UPROPERTY(EditAnywhere, Category = "Rotator01")
	FBSSentryConstraint Rotator01Constraint;

	UPROPERTY(EditAnywhere, Category = "Rotator02")
	UStaticMesh Rotator02Mesh;

	UPROPERTY(EditAnywhere, Category = "Rotator02")
	FBSSentryConstraint Rotator02Constraint;
}

class UBSGenericModule : UBFModuleDefinition
{
	UPROPERTY(EditAnywhere, Category = "Meshes")
	UStaticMesh BaseMesh;
}

class UBSTurretDefinition : UBFModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Module_Turret);

	UPROPERTY(EditAnywhere, meta = (ForceInlineRow, TitleProperty = "{ParentIndex}-{Socket}"))
	TArray<FBSLoadoutElement> Elements;
}

class UBSDetectorDefinition : UBFModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Module_Detector);
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Detection);
}

class UBSWeaponDefinition : UBFModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Module_Weapon);
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Fire);
}

class UBSPowerSupplyUnitDefinition : UBFModuleDefinition
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

class UBSBatteryDefinition : UBFModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Module_Battery);
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Power);
	
	default Instalation = GameplayTag::MakeGameplayTagQuery_MatchAllTags(GameplayTag::MakeGameplayTagContainerFromTag(GameplayTags::Backyard_Module_Battery));

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "J"))
	float Capacity = 1000.0f;

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "W"))
	float MaxDischargeRate = 50.0f;
}

class UBSShieldDefinition : UBFModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Module_Shield);
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Shield);
}

class UBSMagazineDefinition : UBFModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Module_Magazine);
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Ammo);
}
