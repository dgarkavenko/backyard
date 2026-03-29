struct FBSPowerState
{
	ABSPowerSource ConnectedSource;
	float AvailableWatts;
	float TotalDemand;
	float SupplyRatio = 1.0f;
	float BatteryRemaining;
	bool bOnBattery = false;
}

namespace PowerBehavior
{
	void Update(UBSPowerSupplyUnitDefinition PSU, UBSBatteryDefinition Battery,
				FBSPowerState& State, ABSSentry Sentry, float DeltaSeconds)
	{
		if (PSU == nullptr)
		{
			State.AvailableWatts = 0.0f;
			State.SupplyRatio = 0.0f;
			return;
		}

		FindSource(PSU, State, Sentry);

		float SourceWatts = 0.0f;
		if (State.ConnectedSource != nullptr)
		{
			SourceWatts = State.ConnectedSource.DrawPower(PSU.MaxDraw, DeltaSeconds);
			SourceWatts *= PSU.Efficiency;
		}

		float BatteryWatts = 0.0f;
		if (Battery != nullptr && State.BatteryRemaining > 0.0f)
		{
			float Shortfall = PSU.MaxDraw * PSU.Efficiency - SourceWatts;
			if (Shortfall > 0.0f)
			{
				float MaxFromBattery = Math::Min(Shortfall, Battery.MaxDischargeRate);
				float EnergyNeeded = MaxFromBattery * DeltaSeconds;
				if (EnergyNeeded > State.BatteryRemaining)
				{
					BatteryWatts = State.BatteryRemaining / DeltaSeconds;
					State.BatteryRemaining = 0.0f;
				}
				else
				{
					BatteryWatts = MaxFromBattery;
					State.BatteryRemaining -= EnergyNeeded;
				}
			}
		}

		State.AvailableWatts = SourceWatts + BatteryWatts;
		State.bOnBattery = (SourceWatts == 0.0f && BatteryWatts > 0.0f);

		if (State.TotalDemand > 0.0f)
		{
			State.SupplyRatio = Math::Clamp(State.AvailableWatts / State.TotalDemand, 0.0f, 1.0f);
		}
		else
		{
			State.SupplyRatio = 1.0f;
		}
	}

	void InitState(FBSPowerState& State, UBSBatteryDefinition Battery)
	{
		State = FBSPowerState();
		if (Battery != nullptr)
		{
			State.BatteryRemaining = Battery.Capacity;
		}
	}

	void FindSource(UBSPowerSupplyUnitDefinition PSU, FBSPowerState& State, ABSSentry Sentry)
	{
		if (State.ConnectedSource != nullptr)
		{
			float DistanceSquared = Sentry.ActorLocation.DistSquared(State.ConnectedSource.ActorLocation);
			if (DistanceSquared > PSU.ConnectionRange * PSU.ConnectionRange || !State.ConnectedSource.HasFuel())
			{
				State.ConnectedSource = nullptr;
			}
			else
			{
				return;
			}
		}

		TArray<ABSPowerSource> FoundSources;
		GetAllActorsOfClass(FoundSources);

		float BestDistanceSquared = PSU.ConnectionRange * PSU.ConnectionRange;
		ABSPowerSource BestSource = nullptr;

		for (ABSPowerSource Source : FoundSources)
		{
			if (Source == nullptr || !Source.HasFuel())
			{
				continue;
			}

			float DistanceSquared = Sentry.ActorLocation.DistSquared(Source.ActorLocation);
			if (DistanceSquared < BestDistanceSquared)
			{
				BestDistanceSquared = DistanceSquared;
				BestSource = Source;
			}
		}

		State.ConnectedSource = BestSource;
	}
}
