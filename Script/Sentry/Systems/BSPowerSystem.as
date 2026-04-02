namespace PowerBehavior
{
	void Update(const FBSSentryBindings& Bindings, FBSSentryPowerRuntime& PowerRuntime, float DeltaSeconds)
	{
		if (Bindings.PowerSupply == nullptr)
		{
			PowerRuntime.State.AvailableWatts = 0.0f;
			PowerRuntime.State.SupplyRatio = 0.0f;
			return;
		}

		FindSource(Bindings, PowerRuntime.State);

		float SourceWatts = 0.0f;
		if (PowerRuntime.State.ConnectedSource != nullptr)
		{
			SourceWatts = PowerRuntime.State.ConnectedSource.DrawPower(Bindings.PowerSupply.MaxDraw, DeltaSeconds);
			SourceWatts *= Bindings.PowerSupply.Efficiency;
		}

		float BatteryWatts = 0.0f;
		if (Bindings.Battery != nullptr && PowerRuntime.State.BatteryRemaining > 0.0f)
		{
			float Shortfall = Bindings.PowerSupply.MaxDraw * Bindings.PowerSupply.Efficiency - SourceWatts;
			if (Shortfall > 0.0f)
			{
				float MaxFromBattery = Math::Min(Shortfall, Bindings.Battery.MaxDischargeRate);
				float EnergyNeeded = MaxFromBattery * DeltaSeconds;
				if (EnergyNeeded > PowerRuntime.State.BatteryRemaining)
				{
					BatteryWatts = PowerRuntime.State.BatteryRemaining / DeltaSeconds;
					PowerRuntime.State.BatteryRemaining = 0.0f;
				}
				else
				{
					BatteryWatts = MaxFromBattery;
					PowerRuntime.State.BatteryRemaining -= EnergyNeeded;
				}
			}
		}

		PowerRuntime.State.AvailableWatts = SourceWatts + BatteryWatts;
		PowerRuntime.State.bOnBattery = (SourceWatts == 0.0f && BatteryWatts > 0.0f);

		if (PowerRuntime.State.TotalDemand > 0.0f)
		{
			PowerRuntime.State.SupplyRatio = Math::Clamp(PowerRuntime.State.AvailableWatts / PowerRuntime.State.TotalDemand, 0.0f, 1.0f);
		}
		else
		{
			PowerRuntime.State.SupplyRatio = 1.0f;
		}
	}

	void InitState(const FBSSentryBindings& Bindings, FBSSentryPowerRuntime& PowerRuntime)
	{
		PowerRuntime.State = FBSPowerState();
		if (Bindings.Battery != nullptr)
		{
			PowerRuntime.State.BatteryRemaining = Bindings.Battery.Capacity;
		}
	}

	void FindSource(const FBSSentryBindings& Bindings, FBSPowerState& State)
	{
		if (State.ConnectedSource != nullptr)
		{
			float DistanceSquared = Bindings.Sentry.ActorLocation.DistSquared(State.ConnectedSource.ActorLocation);
			if (DistanceSquared > Bindings.PowerSupply.ConnectionRange * Bindings.PowerSupply.ConnectionRange || !State.ConnectedSource.HasFuel())
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

		float BestDistanceSquared = Bindings.PowerSupply.ConnectionRange * Bindings.PowerSupply.ConnectionRange;
		ABSPowerSource BestSource = nullptr;

		for (ABSPowerSource Source : FoundSources)
		{
			if (Source == nullptr || !Source.HasFuel())
			{
				continue;
			}

			float DistanceSquared = Bindings.Sentry.ActorLocation.DistSquared(Source.ActorLocation);
			if (DistanceSquared < BestDistanceSquared)
			{
				BestDistanceSquared = DistanceSquared;
				BestSource = Source;
			}
		}

		State.ConnectedSource = BestSource;
	}
}
