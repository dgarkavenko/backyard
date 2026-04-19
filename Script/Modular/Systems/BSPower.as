namespace Power
{	
	/**
	 * Reads: PowerHot, 	
	 * Writes: PowerHot, PowerChildren child reserves
	 */
	void Tick(FBSRuntimeStore& Store, float DeltaSeconds)
	{
		const float DeltaHour = DeltaSeconds * 0.00028f;

		// TODO: Try merge this two loops
		for (int PowerIndex = 0; PowerIndex < Store.PowerHot.Num(); PowerIndex++)
		{
			float Demand = Store.PowerHot[PowerIndex].Demand;
			if (Demand > 0)
			{
				Store.PowerHot[PowerIndex].ChainInsufficency = DistributeDemand(Store, PowerIndex, Demand);
			}
		}

		for (int PowerIndex = 0; PowerIndex < Store.PowerHot.Num(); PowerIndex++)
		{
			FBSPowerHotRow& PowerRuntime = Store.PowerHot[PowerIndex];
			float AccumulatedDecreasePerHour = PowerRuntime.AccumulatedDecrease * DeltaHour;

			if (AccumulatedDecreasePerHour > 0.0f && PowerRuntime.ChildrenReserve > 0.0f)
			{
				FBSPowerChildrenRow& Children = Store.PowerChildren[PowerIndex];

				float RemainingDemand = 0.0f;
				float CombinedReserve = 0.0f;
				float CombinedChildrenOutput = 0;
				float BaselineDecreasePerBattery = AccumulatedDecreasePerHour / Children.Batteries.Num();

				for (FBSPowerChildRuntime& Child : Children.Batteries)
				{
					RemainingDemand += BaselineDecreasePerBattery;

					float ChildReserveSub = Math::Min(Child.Reserve, RemainingDemand);
					Child.Reserve -= ChildReserveSub;
					RemainingDemand -= ChildReserveSub;
					CombinedReserve += Child.Reserve;
					if (Child.Reserve > 0)
					{
						CombinedChildrenOutput += Child.Output;
					}					
				}

				AccumulatedDecreasePerHour = RemainingDemand;
				PowerRuntime.Insufficency = Math::Max(0.0f, PowerRuntime.AccumulatedTransfer - CombinedChildrenOutput);
				PowerRuntime.ChildrenReserve = CombinedReserve;
			}

			float ReserveSub = Math::Min(PowerRuntime.Reserve, AccumulatedDecreasePerHour);
			PowerRuntime.Reserve -= ReserveSub;
			PowerRuntime.Insufficency = Math::Max(0.0f, PowerRuntime.AccumulatedTransfer - PowerRuntime.Output);
			PowerRuntime.bSupplied = PowerRuntime.Reserve > 0.0f || PowerRuntime.ChildrenReserve > 0.0f;
			PowerRuntime.AccumulatedDecrease = 0.0f;
			PowerRuntime.AccumulatedTransfer = 0.0f;
		}
	}

	/**
	 * Reads: PowerHot
	 * Writes: PowerHot.AccumulatedTransfer, PowerHot.AccumulatedDecrease
	 */
	float DistributeDemand(FBSRuntimeStore& Store, int32 PowerIndex, float Demand)
	{
		FBSPowerHotRow& PowerRuntime = Store.PowerHot[PowerIndex];
		PowerRuntime.AccumulatedTransfer += Demand;

		if (PowerRuntime.TapSourcePowerIndex >= 0)
		{
			FBSPowerHotRow& TapRuntime = Store.PowerHot[PowerRuntime.TapSourcePowerIndex];
			if (TapRuntime.Reserve > 0.0f)
			{
				return Math::Max(PowerRuntime.Insufficency, DistributeDemand(Store, PowerRuntime.TapSourcePowerIndex, Demand));
			}
		}

		PowerRuntime.AccumulatedDecrease += Demand;
		return PowerRuntime.Insufficency;
	}
}
