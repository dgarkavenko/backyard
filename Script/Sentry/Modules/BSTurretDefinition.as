struct FBSSentryShootingRules
{
	UPROPERTY(EditAnywhere, meta = (ClampMin = "0", Units = "cm"))
	float MaxDistance = 5000.0f;

	UPROPERTY(EditAnywhere, meta = (ClampMin = "0", ClampMax = "180", Units = "Degrees"))
	float MaxAngleDegrees = 5.0f;
}

class UBSTurretDefinition : UBSModuleDefinition
{
	default Capabilities.AddTag(GameplayTags::Backyard_Capability_Fire);

	UPROPERTY(EditAnywhere, Category = "Fire", meta = (ClampMin = "1"))
	int RPM = 300;

	UPROPERTY(EditAnywhere, Category = "Fire")
	FBSSentryShootingRules ShootingRules;

	UPROPERTY()
	TSoftObjectPtr<UNiagaraSystem> ShotEffect_NS;

	UPROPERTY()
	TSoftObjectPtr<UNiagaraDataChannelAsset> ShotEffect_NDC;
}
