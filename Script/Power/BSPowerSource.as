class ABSPowerSource : AActor
{
	UPROPERTY(DefaultComponent, RootComponent)
	UStaticMeshComponent Mesh;

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0", Units = "W"))
	float MaxOutput = 100.0f;

	UPROPERTY(EditAnywhere, Category = "Power")
	float FuelRemaining = -1.0f;

	UPROPERTY(EditAnywhere, Category = "Power", meta = (ClampMin = "0"))
	float FuelPerWatt = 0.01f;

	bool IsInfinite() const
	{
		return FuelRemaining < 0.0f;
	}

	bool HasFuel() const
	{
		return IsInfinite() || FuelRemaining > 0.0f;
	}

	float DrawPower(float RequestedWatts, float DeltaSeconds)
	{
		if (!HasFuel())
		{
			return 0.0f;
		}

		float ClampedWatts = Math::Min(RequestedWatts, MaxOutput);

		if (!IsInfinite())
		{
			float FuelNeeded = ClampedWatts * FuelPerWatt * DeltaSeconds;
			if (FuelNeeded > FuelRemaining)
			{
				ClampedWatts = FuelRemaining / (FuelPerWatt * DeltaSeconds);
				FuelRemaining = 0.0f;
			}
			else
			{
				FuelRemaining -= FuelNeeded;
			}
		}

		return ClampedWatts;
	}
}
