class UBSSentryWorldSubsystem : UScriptWorldSubsystem
{
	TArray<ABSSentry> RowSentries;
	TArray<FGameplayTagContainer> Capabilities;


	TArray<FBSSentryStatics> Statics;
	TArray<FBSSentryAimCache> AimCache;
	TArray<FBSSentryTargetingRuntime> TargetingRuntime;
	TArray<FBSSentryCombatRuntime> CombatRuntime;
	TArray<FBSSentryPowerRuntime> PowerRuntime;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		ACharacter PlayerCharacter = Gameplay::GetPlayerCharacter(0);
		if (PlayerCharacter == nullptr)
		{
			return;
		}

		FVector PlayerLocation = PlayerCharacter.ActorLocation;
		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			check(Statics[Index].Sentry != nullptr);
			check(Statics[Index].Chassis != nullptr);

			if (!AimCache[Index].bHasAimCache)
			{
				continue;
			}

			TargetingRuntime[Index].TargetLocation = PlayerLocation;
			SentryAim::SeedFromComponents(AimCache[Index], TargetingRuntime[Index]);
			if (!SentryAim::Solve(Statics[Index], AimCache[Index], TargetingRuntime[Index], DeltaSeconds))
			{
				continue;
			}

			if (!SentryAim::Apply(AimCache[Index], TargetingRuntime[Index]))
			{
				continue;
			}

			if (!SentryAim::ReadMuzzle(AimCache[Index], TargetingRuntime[Index]))
			{
				continue;
			}

			CombatRuntime[Index].ShotCooldownRemaining -= DeltaSeconds;
			if (CanFire(Statics[Index], TargetingRuntime[Index], CombatRuntime[Index]))
			{
				SentryFiring::Shot(Statics[Index], AimCache[Index], TargetingRuntime[Index]);
				CombatRuntime[Index].ShotCooldownRemaining = 60.0f / float(Statics[Index].Turret.RPM);
			}

			if (SentryDebugF::ShowAim.Int > 0)
			{
				SentryDebugF::DrawAim(TargetingRuntime[Index]);
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
		Statics.RemoveAt(LastRowIndex);
		AimCache.RemoveAt(LastRowIndex);
		TargetingRuntime.RemoveAt(LastRowIndex);
		CombatRuntime.RemoveAt(LastRowIndex);
		PowerRuntime.RemoveAt(LastRowIndex);
	}

	private int CreateRow(ABSSentry Sentry)
	{
		int RowIndex = RowSentries.Num();
		RowSentries.Add(Sentry);
		Statics.Add(FBSSentryStatics());
		AimCache.Add(FBSSentryAimCache());
		TargetingRuntime.Add(FBSSentryTargetingRuntime());
		CombatRuntime.Add(FBSSentryCombatRuntime());
		PowerRuntime.Add(FBSSentryPowerRuntime());
		return RowIndex;
	}

	private void MoveRow(int TargetRowIndex, int SourceRowIndex)
	{
		RowSentries[TargetRowIndex] = RowSentries[SourceRowIndex];
		Statics[TargetRowIndex] = Statics[SourceRowIndex];
		AimCache[TargetRowIndex] = AimCache[SourceRowIndex];
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
		Statics.Empty();
		AimCache.Empty();
		TargetingRuntime.Empty();
		CombatRuntime.Empty();
		PowerRuntime.Empty();
	}

	private bool CanFire(const FBSSentryStatics& RowStatics, const FBSSentryTargetingRuntime& RowTargetingRuntime, const FBSSentryCombatRuntime& RowCombatRuntime) const
	{
		UBSTurretDefinition Turret = RowStatics.Turret;
		if (Turret == nullptr || Turret.RPM <= 0 || RowCombatRuntime.ShotCooldownRemaining > 0.0f)
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
