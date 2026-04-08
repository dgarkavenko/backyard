class UBSRuntimeSubsystem : UScriptWorldSubsystem
{
	float SetConsumption(int32 RowIndex, float Consumption)
	{
		FBSPowerRuntime& PowerRuntime = Store.PowerRuntime[RowIndex];
		PowerRuntime.AccumulatedTransfer += Consumption;

		if (PowerRuntime.TapSource.IsSet() && Store.PowerRuntime[PowerRuntime.TapSource.Value].Reserve > 0)
		{
			FBSPowerRuntime& Tap = Store.PowerRuntime[PowerRuntime.TapSource.Value];
			if (Tap.Reserve > 0)
			{
				return Math::Max(PowerRuntime.Insufficency, SetConsumption(PowerRuntime.TapSource.Value, Consumption));
			}
		}

		PowerRuntime.AccumulatedDecrease += Consumption;
		return PowerRuntime.Insufficency;
	}

	FBSSentryStore Store;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		float DeltaHour = DeltaSeconds * 0.00028f;

		for (int RowIndex = 0; RowIndex < Store.Num(); RowIndex++)
		{
			FBSPowerRuntime& PowerRuntime = Store.PowerRuntime[RowIndex];
			float AccumulatedDecreasePerHour = PowerRuntime.AccumulatedDecrease * DeltaHour;

			if (AccumulatedDecreasePerHour > 0 && PowerRuntime.ChildrenReserve > 0)
			{
				FBPowerRuntimeChildren& Children = Store.PowerRuntimeChildren[RowIndex];

				float RemainingDemand = 0;
				float CombinedChildrenOutput = 0;
				float CombinedReserve = 0;
				float BaselineDecreasePerBattery = AccumulatedDecreasePerHour / Children.Batteries.Num();

				// TODO store child reserve
				for (FBSPowerRuntime& Child : Children.Batteries)
				{
					RemainingDemand += BaselineDecreasePerBattery;
					
					float ChildReserveSub = Math::Min(Child.Reserve, RemainingDemand);
					Child.Reserve -= ChildReserveSub;
					RemainingDemand -= ChildReserveSub;
					CombinedChildrenOutput += Child.Output;
					CombinedReserve += Child.Reserve;
				}

				AccumulatedDecreasePerHour = RemainingDemand;
				PowerRuntime.Insufficency = Math::Max(0, PowerRuntime.AccumulatedTransfer - AccumulatedDecreasePerHour);
				PowerRuntime.ChildrenReserve = CombinedReserve;
			}

			float ReserveSub = Math::Min(PowerRuntime.Reserve, AccumulatedDecreasePerHour);
			PowerRuntime.Reserve -= ReserveSub;
			PowerRuntime.Insufficency = Math::Max(0, PowerRuntime.AccumulatedTransfer - PowerRuntime.Output);
			PowerRuntime.bSupplied = PowerRuntime.Reserve > 0 || PowerRuntime.ChildrenReserve > 0;
		
			PowerRuntime.AccumulatedDecrease = 0;
			PowerRuntime.AccumulatedTransfer = 0;		
		}

		for (int RowIndex = 0; RowIndex < Store.Num(); RowIndex++)
		{
			FBSSentryStatics& RowStatics = Store.Statics[RowIndex];
			
			bool bSupplied = Store.PowerRuntime[RowIndex].bSupplied;


			float ChainInsuficency = SetConsumption(RowIndex, 400);
						
			USpotLightComponent VisorSpotLight = RowStatics.ModularView.CachedVisorSpotLight;
			if (VisorSpotLight != nullptr)
			{
				if (bSupplied)
				{
					if (ChainInsuficency > 0)
					{	
						float T = Gameplay::TimeSeconds + RowIndex;
						float I = Math::Min(1, Math::Abs(2 * Math::Sin(0.3 * T) + Math::Cos(T * 6)));
						VisorSpotLight.SetIntensity(Math::Lerp(10, 150, I));
					}
					else
					{
						VisorSpotLight.SetIntensity(400.0f);
					}
				}
				else
				{
					VisorSpotLight.SetIntensity(0.0f);
					continue;
				}
			}			

			check(RowStatics.Actor != nullptr);
			FBSSentryAimCache& RowAimCache = Store.AimCache[RowIndex];
			FBSSentryPerceptionRuntime& RowPerceptionRuntime = Store.PerceptionRuntime[RowIndex];
			FBSSentryTargetingRuntime& RowTargetingRuntime = Store.TargetingRuntime[RowIndex];
			FBSSentryCombatRuntime& RowCombatRuntime = Store.CombatRuntime[RowIndex];
			const FGameplayTagContainer& Capabilities = Store.Capabilities[RowIndex];
			bool bHasDetection = Capabilities.HasTag(GameplayTags::Backyard_Capability_Detection);
			bool bHasAim = Capabilities.HasTag(GameplayTags::Backyard_Capability_Aim);
			bool bHasFire = Capabilities.HasTag(GameplayTags::Backyard_Capability_Fire);

			if (!bHasAim)
			{
				continue;
			}

			if (bHasDetection)
			{
				SentryVision::Update(Capabilities, RowStatics, RowAimCache, RowPerceptionRuntime, DeltaSeconds);
				SentryVision::ApplyVisorLightColor(RowStatics, RowPerceptionRuntime);
			}

			check(RowStatics.Chassis != nullptr, "Aim capability requires cached chassis data");

			bool bTrackAimState = RowPerceptionRuntime.VisionState == EBSSentryVisionState::Tracking
				|| RowPerceptionRuntime.VisionState == EBSSentryVisionState::LostHold;

			if (bTrackAimState)
			{
				RowTargetingRuntime.TargetLocation = RowPerceptionRuntime.CurrentTargetLocation;
				SentryAim::SeedFromComponents(RowAimCache, RowTargetingRuntime);
				SentryAim::Solve(RowStatics, RowAimCache, RowTargetingRuntime, DeltaSeconds);
				SentryAim::Apply(RowAimCache, RowTargetingRuntime);
				SentryAim::ReadMuzzle(RowAimCache, RowTargetingRuntime);

				if (bHasFire && RowPerceptionRuntime.VisionState == EBSSentryVisionState::Tracking)
				{
					RowCombatRuntime.ShotCooldownRemaining -= DeltaSeconds;
					if (CanFire(RowStatics, RowTargetingRuntime, RowCombatRuntime))
					{
						SentryFiring::Shot(RowStatics, RowAimCache, RowTargetingRuntime);
						RowCombatRuntime.ShotCooldownRemaining = 60.0f / float(RowStatics.Turret.RPM);
					}
				}
			}
			else if (bHasDetection)
			{
				SentryVision::ApplyProbing(RowStatics, RowAimCache, RowTargetingRuntime, RowPerceptionRuntime, DeltaSeconds);
			}
		}

		SentryDebugF::Tick(Store);
	}

	TOptional<int> SyncActor(UBSModularComponent ModularComponent, UBSModularView View)
	{
		AActor Actor = ModularComponent.Owner;
		TOptional<int> ExistingRowIndex = Store.FindRowIndex(Actor);
		int RowIndex = !ExistingRowIndex.IsSet() ? Store.CreateRow(Actor) : ExistingRowIndex.Value;
		
		Store.Capabilities[RowIndex] = FGameplayTagContainer();
		ModularComponent.GetAllCapabilities(Store.Capabilities[RowIndex]);
		ModularAssembly::AssembleView(View, Actor, ModularComponent);

		Store.Statics[RowIndex] = FBSSentryStatics();
		Store.Statics[RowIndex].ModularView = View;
		Store.Statics[RowIndex].Actor = Actor;

		PowerAssembly::BuildRow(Store, RowIndex, ModularComponent);
		SentryAssembly::BuildRow(Store, RowIndex, Actor);

		return RowIndex;
	}

	void RemoveActor(AActor Actor)
	{
		TOptional<int> ExistingRowIndex = Store.FindRowIndex(Actor);
		if (!ExistingRowIndex.IsSet())
		{
			return;
		}

		Store.RemoveRowSwap(ExistingRowIndex.Value);
	}

	TOptional<int> GetRowIndex(ABSSentry Sentry) const
	{
		return Store.FindRowIndex(Sentry);
	}

	int GetRowCount() const
	{
		return Store.Num();
	}

	AActor GetSentryAtRow(int RowIndex) const
	{
		return Store.Actors[RowIndex];
	}

	const FBSSentryStatics& GetStatics(int RowIndex) const
	{
		return Store.Statics[RowIndex];
	}

	const FBSSentryPerceptionRuntime& GetPerceptionRuntime(int RowIndex) const
	{
		return Store.PerceptionRuntime[RowIndex];
	}

	const FBSSentryTargetingRuntime& GetTargetingRuntime(int RowIndex) const
	{
		return Store.TargetingRuntime[RowIndex];
	}

	const FBSSentryCombatRuntime& GetCombatRuntime(int RowIndex) const
	{
		return Store.CombatRuntime[RowIndex];
	}

	const FBSPowerRuntime& GetPowerRuntime(int RowIndex) const
	{
		return Store.PowerRuntime[RowIndex];
	}

	private bool CanFire(const FBSSentryStatics& RowStatics, const FBSSentryTargetingRuntime& RowTargetingRuntime, const FBSSentryCombatRuntime& RowCombatRuntime) const
	{
		UBSTurretDefinition Turret = RowStatics.Turret;
		check(Turret != nullptr, "Fire capability requires a turret module");
		if (Turret.RPM <= 0 || RowCombatRuntime.ShotCooldownRemaining > 0.0f)
		{
			return false;
		}

		if (RowTargetingRuntime.DistanceToTarget <= 0.0f || RowTargetingRuntime.DistanceToTarget > Turret.ShootingRules.MaxDistance)
		{
			return false;
		}

		return Math::Abs(RowTargetingRuntime.MuzzleError.Yaw) <= Turret.ShootingRules.MaxAngleDegrees
			&& Math::Abs(RowTargetingRuntime.MuzzleError.Pitch) <= Turret.ShootingRules.MaxAngleDegrees;
	}
}
