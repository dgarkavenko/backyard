class UBSSentryWorldSubsystem : UScriptWorldSubsystem
{
	TArray<ABSSentry> RowSentries;
	TArray<FGameplayTagContainer> Capabilities;
	TArray<FBSSentryStatics> Statics;
	TArray<FBSSentryAimCache> AimCache;
	TArray<FBSSentryPerceptionRuntime> PerceptionRuntime;
	TArray<FBSSentryTargetingRuntime> TargetingRuntime;
	TArray<FBSSentryCombatRuntime> CombatRuntime;
	TArray<FBSSentryPowerRuntime> PowerRuntime;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			check(Statics[Index].Sentry != nullptr);
			const FGameplayTagContainer& RowCapabilities = Capabilities[Index];
			bool bHasDetection = RowCapabilities.HasTag(GameplayTags::Backyard_Capability_Detection);
			bool bHasAim = RowCapabilities.HasTag(GameplayTags::Backyard_Capability_Aim);
			bool bHasFire = RowCapabilities.HasTag(GameplayTags::Backyard_Capability_Fire);

			if (bHasDetection)
			{
				SentryVision::Update(RowCapabilities, Statics[Index], AimCache[Index], PerceptionRuntime[Index], DeltaSeconds);
				SentryVision::ApplyVisorLightColor(Statics[Index], PerceptionRuntime[Index]);
			}

			if (!bHasAim)
			{
				continue;
			}

			check(Statics[Index].Chassis != nullptr, "Aim capability requires cached chassis data");
			bool bTrackAimState = PerceptionRuntime[Index].VisionState == EBSSentryVisionState::Tracking
				|| PerceptionRuntime[Index].VisionState == EBSSentryVisionState::LostHold;
			if (bTrackAimState)
			{
				TargetingRuntime[Index].TargetLocation = PerceptionRuntime[Index].CurrentTargetLocation;
				SentryAim::SeedFromComponents(AimCache[Index], TargetingRuntime[Index]);
				SentryAim::Solve(Statics[Index], AimCache[Index], TargetingRuntime[Index], DeltaSeconds);
				SentryAim::Apply(AimCache[Index], TargetingRuntime[Index]);
				SentryAim::ReadMuzzle(AimCache[Index], TargetingRuntime[Index]);

				if (bHasFire && PerceptionRuntime[Index].VisionState == EBSSentryVisionState::Tracking)
				{
					CombatRuntime[Index].ShotCooldownRemaining -= DeltaSeconds;
					if (CanFire(Statics[Index], TargetingRuntime[Index], CombatRuntime[Index]))
					{
						SentryFiring::Shot(Statics[Index], AimCache[Index], TargetingRuntime[Index]);
						CombatRuntime[Index].ShotCooldownRemaining = 60.0f / float(Statics[Index].Turret.RPM);
					}
				}
			}
			else if (bHasDetection)
			{
				SentryVision::ApplyProbing(Statics[Index], AimCache[Index], TargetingRuntime[Index], PerceptionRuntime[Index], DeltaSeconds);
			}

			if (SentryDebugF::ShowAim.Int > 0)
			{
				SentryDebugF::DrawAim(TargetingRuntime[Index]);
			}

			if (SentryDebugF::ShowVision.Int > 0 && bHasDetection)
			{
				SentryDebugF::DrawVision(Statics[Index], AimCache[Index], PerceptionRuntime[Index]);
			}
		}
	}

	TOptional<int> SyncSentry(ABSSentry Sentry)
	{
		TOptional<int> ExistingRowIndex = FindRowIndex(Sentry);
		int RowIndex = !ExistingRowIndex.IsSet() ? CreateRow(Sentry) : ExistingRowIndex.Value;

		SentryAssembly::Build(Sentry,
							  Statics[RowIndex],
							  AimCache[RowIndex],
							  TargetingRuntime[RowIndex],
							  PerceptionRuntime[RowIndex],
							  CombatRuntime[RowIndex],
							  PowerRuntime[RowIndex],
							  Capabilities[RowIndex]);

		return RowIndex;
	}

	void RemoveSentry(ABSSentry Sentry)
	{
		TOptional<int> ExistingRowIndex = FindRowIndex(Sentry);
		if (!ExistingRowIndex.IsSet())
		{
			return;
		}

		int RowIndex = ExistingRowIndex.Value;
		int LastRowIndex = RowSentries.Num() - 1;

		if (RowIndex != LastRowIndex)
		{
			MoveRow(RowIndex, LastRowIndex);
		}

		RowSentries.RemoveAt(LastRowIndex);
		Capabilities.RemoveAt(LastRowIndex);
		Statics.RemoveAt(LastRowIndex);
		AimCache.RemoveAt(LastRowIndex);
		PerceptionRuntime.RemoveAt(LastRowIndex);
		TargetingRuntime.RemoveAt(LastRowIndex);
		CombatRuntime.RemoveAt(LastRowIndex);
		PowerRuntime.RemoveAt(LastRowIndex);
	}

	private int CreateRow(ABSSentry Sentry)
	{
		int RowIndex = RowSentries.Num();
		RowSentries.Add(Sentry);
		Capabilities.Add(FGameplayTagContainer());
		Statics.Add(FBSSentryStatics());
		AimCache.Add(FBSSentryAimCache());
		PerceptionRuntime.Add(FBSSentryPerceptionRuntime());
		TargetingRuntime.Add(FBSSentryTargetingRuntime());
		CombatRuntime.Add(FBSSentryCombatRuntime());
		PowerRuntime.Add(FBSSentryPowerRuntime());
		return RowIndex;
	}

	private void MoveRow(int TargetRowIndex, int SourceRowIndex)
	{
		RowSentries[TargetRowIndex] = RowSentries[SourceRowIndex];
		Capabilities[TargetRowIndex] = Capabilities[SourceRowIndex];
		Statics[TargetRowIndex] = Statics[SourceRowIndex];
		AimCache[TargetRowIndex] = AimCache[SourceRowIndex];
		PerceptionRuntime[TargetRowIndex] = PerceptionRuntime[SourceRowIndex];
		TargetingRuntime[TargetRowIndex] = TargetingRuntime[SourceRowIndex];
		CombatRuntime[TargetRowIndex] = CombatRuntime[SourceRowIndex];
		PowerRuntime[TargetRowIndex] = PowerRuntime[SourceRowIndex];
	}

	TOptional<int> FindRowIndex(ABSSentry Sentry) const
	{
		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			if (RowSentries[Index] == Sentry)
			{
				return Index;
			}
		}

		return TOptional<int>();
	}

	private void ClearAllRows()
	{
		RowSentries.Empty();
		Capabilities.Empty();
		Statics.Empty();
		AimCache.Empty();
		PerceptionRuntime.Empty();
		TargetingRuntime.Empty();
		CombatRuntime.Empty();
		PowerRuntime.Empty();
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
