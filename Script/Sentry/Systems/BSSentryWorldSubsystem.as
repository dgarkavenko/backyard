class UBSSentryWorldSubsystem : UScriptWorldSubsystem
{
	TArray<ABSSentry> RowSentries;

	TArray<FBSSentryStatics> Statics;

	TArray<FBSSentryAimCache> AimCache;

	TArray<FBSSentryTargetingRuntime> TargetingRuntime;
	TArray<FBSSentryCombatRuntime> CombatRuntime;
	TArray<FBSSentryPowerRuntime> PowerRuntime;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		ACharacter PlayerCharacter = Gameplay::GetPlayerCharacter(0);
		ABSPlayerController PlayerController = Cast<ABSPlayerController>(Gameplay::GetPlayerController(0));
		if (PlayerCharacter == nullptr || PlayerController == nullptr)
		{
			return;
		}

		FVector PlayerLocation = PlayerCharacter.ActorLocation;

		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			check(Statics[Index].Sentry != nullptr);
			check(Statics[Index].SentryView != nullptr);
			check(Statics[Index].Chassis != nullptr);
		}

		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			TargetingRuntime[Index].TargetLocation = PlayerLocation;
		}

		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			SentryAim::Solve(AimCache[Index], TargetingRuntime[Index], DeltaSeconds);
		}

		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			CombatRuntime[Index].ShotCooldownRemaining -= DeltaSeconds;
		}

		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			SentryAim::Apply(AimCache[Index], TargetingRuntime[Index]);
		}

		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			if (Statics[Index].Turret != nullptr && CombatRuntime[Index].ShotCooldownRemaining < 0.0f)
			{
				SentryShoot::Update(Statics[Index], AimCache[Index], TargetingRuntime[Index], CombatRuntime[Index]);
			}
		}

		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			if (SentryDebugF::ShowAim.Int > 0)
			{
				SentryDebugF::DrawAim(Statics[Index].Sentry, TargetingRuntime[Index]);
			}

			SentryDebugF::LogAimState(Statics[Index].Sentry, AimCache[Index], TargetingRuntime[Index]);
		}
	}

	void SyncSentry(ABSSentry Sentry)
	{
		if (Sentry == nullptr || Sentry.ModularComponent == nullptr || Sentry.ModularView == nullptr)
		{
			RemoveSentry(Sentry);
			return;
		}

		TOptional<int> ExistingRowIndex = FindRowIndex(Sentry);
		bool bRowCreated = !ExistingRowIndex.IsSet();
		int RowIndex = bRowCreated ? CreateRow(Sentry) : ExistingRowIndex.Value;

		FBSSentryStatics ResolvedStatics;
		if (!ResolveStatics(Sentry, ResolvedStatics))
		{
			RemoveSentry(Sentry);
			return;
		}

		ApplyStatics(RowIndex, ResolvedStatics, bRowCreated);
		SentryAssembly::Build(this, RowIndex, Sentry, Sentry.ModularComponent, Sentry.ModularView);
		SentryAim::SeedRuntime(AimCache[RowIndex], TargetingRuntime[RowIndex]);
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

	private bool ResolveStatics(ABSSentry Sentry, FBSSentryStatics& OutStatics) const
	{
		if (Sentry == nullptr || Sentry.SentryView == nullptr || Sentry.ModularComponent == nullptr)
		{
			return false;
		}

		UBSModularComponent ModularComponent = Sentry.ModularComponent;
		OutStatics.Sentry = Sentry;
		OutStatics.SentryView = Sentry.SentryView;

		for (UBSModuleDefinition Module : ModularComponent.InstalledModules)
		{
			check(Module != nullptr, "Module is nullptr");

			if (OutStatics.Chassis == nullptr)
			{
				OutStatics.Chassis = Cast<UBSChassisDefinition>(Module);
			}
			if (OutStatics.PowerSupply == nullptr)
			{
				OutStatics.PowerSupply = Cast<UBSPowerSupplyUnitDefinition>(Module);
			}
			if (OutStatics.Turret == nullptr)
			{
				OutStatics.Turret = Cast<UBSTurretDefinition>(Module);
			}
			if (OutStatics.Battery == nullptr)
			{
				OutStatics.Battery = Cast<UBSBatteryDefinition>(Module);
			}
		}

		return OutStatics.Chassis != nullptr;
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

	private void ApplyStatics(int RowIndex, const FBSSentryStatics& ResolveStatics, bool bRowCreated)
	{
		bool bTurretChanged = bRowCreated || Statics[RowIndex].Turret != ResolveStatics.Turret;
		bool bBatteryChanged = bRowCreated || Statics[RowIndex].Battery != ResolveStatics.Battery;

		Statics[RowIndex] = ResolveStatics;
		AimCache[RowIndex] = FBSSentryAimCache();
		SentryAim::ResetRuntime(TargetingRuntime[RowIndex]);

		if (bTurretChanged)
		{
			CombatRuntime[RowIndex].ShotCooldownRemaining = 0.0f;
		}

		if (bBatteryChanged)
		{
			PowerBehavior::InitState(Statics[RowIndex], PowerRuntime[RowIndex]);
		}
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
}
