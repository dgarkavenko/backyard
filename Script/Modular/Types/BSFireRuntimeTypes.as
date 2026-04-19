struct FBSFireHotRow
{
	int32 OwnerBaseIndex = -1;
	FBSFireLinks Links;
	float ShotCooldownRemaining = 0.0f;

	// static
	int32 RPM = 0;
	float MaxDistance = 0.0f;
	float MaxAngleDegrees = 0.0f;
	float FiringPowerDrawWatts = 0.0f;
}

struct FBSFireColdRow
{
	UBSTurretDefinition Turret;
}
