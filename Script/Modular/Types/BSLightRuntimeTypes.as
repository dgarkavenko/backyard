struct FBSLightHotRow
{
	int32 OwnerBaseIndex = -1;
	FBSLightLinks Links;
	float DesiredIntensity = 0.0f;
	FLinearColor DesiredColor = FLinearColor(1.00f, 0.31f, 0.07f);

	// static
	float NominalIntensity = 400.0f;
	float FlickerLowIntensity = 10.0f;
	float FlickerHighIntensity = 150.0f;
	float LightPowerDrawWatts = 400.0f;
	FLinearColor SweepColor = FLinearColor(1.00f, 0.31f, 0.07f);
	FLinearColor ActiveColor = FLinearColor(1.0f, 0.0f, 0.0f);
}

struct FBSLightColdRow
{
	USpotLightComponent LightComponent;
}
