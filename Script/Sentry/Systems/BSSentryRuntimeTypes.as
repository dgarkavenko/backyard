struct FBSPowerState
{
	ABSPowerSource ConnectedSource;
	float AvailableWatts;
	float TotalDemand;
	float SupplyRatio = 1.0f;
	float BatteryRemaining;
	bool bOnBattery = false;
}

struct FBSSentryBindings
{
	ABSSentry Sentry;
	UBSSentryView SentryView;
	UBSChassisDefinition Chassis;
	UBSTurretDefinition Turret;
	UBSPowerSupplyUnitDefinition PowerSupply;
	UBSBatteryDefinition Battery;
}

struct FBSSentryTargetingRuntime
{
	FVector TargetLocation = FVector::ZeroVector;
}

struct FBSSentryCombatRuntime
{
	float ShotCooldownRemaining = 0.0f;
}

struct FBSSentryPowerRuntime
{
	FBSPowerState State;
}
