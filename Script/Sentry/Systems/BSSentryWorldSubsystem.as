class UBSSentryWorldSubsystem : UScriptWorldSubsystem
{
	TArray<ABSSentry> RowSentries;

	TArray<FBSSentryBindings> Bindings;
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
			check(Bindings[Index].Sentry != nullptr);
			check(Bindings[Index].SentryView != nullptr);
			check(Bindings[Index].Chassis != nullptr);
		}

		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			TargetingRuntime[Index].TargetLocation = PlayerLocation;
		}

		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			SentryAim::Update(Bindings[Index], TargetingRuntime[Index], DeltaSeconds);
			if (SentryDebugF::ShowAim.Int > 0)
			{
				SentryDebugF::DrawAim(Bindings[Index].Sentry, TargetingRuntime[Index].TargetLocation);
			}
		}

		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			CombatRuntime[Index].ShotCooldownRemaining -= DeltaSeconds;
		}

		for (int Index = 0; Index < RowSentries.Num(); Index++)
		{
			if (Bindings[Index].Turret != nullptr && CombatRuntime[Index].ShotCooldownRemaining < 0.0f)
			{
				SentryShoot::Update(Bindings[Index], TargetingRuntime[Index], CombatRuntime[Index]);
			}
		}
	}

	void SyncSentry(ABSSentry Sentry)
	{
		FBSSentryBindings ResolvedBindings;
		if (!ResolveBindings(Sentry, ResolvedBindings))
		{
			RemoveSentry(Sentry);
			return;
		}

		TOptional<int> ExistingRowIndex = FindRowIndex(Sentry);
		bool bRowCreated = !ExistingRowIndex.IsSet();
		int RowIndex = bRowCreated ? CreateRow(Sentry) : ExistingRowIndex.Value;
		ApplyBindings(RowIndex, ResolvedBindings, bRowCreated);
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
		Bindings.RemoveAt(LastRowIndex);
		TargetingRuntime.RemoveAt(LastRowIndex);
		CombatRuntime.RemoveAt(LastRowIndex);
		PowerRuntime.RemoveAt(LastRowIndex);
	}

	private bool ResolveBindings(ABSSentry Sentry, FBSSentryBindings& OutBindings) const
	{
		if (Sentry == nullptr || Sentry.SentryView == nullptr || Sentry.ModularComponent == nullptr)
		{
			return false;
		}

		UBSModularComponent ModularComponent = Sentry.ModularComponent;
		OutBindings.Sentry = Sentry;
		OutBindings.SentryView = Sentry.SentryView;

		for (UBSModuleDefinition Module : ModularComponent.InstalledModules)
		{
			check(Module != nullptr, "Module is nullptr");

			if (OutBindings.Chassis == nullptr)
			{
				OutBindings.Chassis = Cast<UBSChassisDefinition>(Module);
			}
			if (OutBindings.PowerSupply == nullptr)
			{
				OutBindings.PowerSupply = Cast<UBSPowerSupplyUnitDefinition>(Module);
			}
			if (OutBindings.Turret == nullptr)
			{
				OutBindings.Turret = Cast<UBSTurretDefinition>(Module);
			}
			if (OutBindings.Battery == nullptr)
			{
				OutBindings.Battery = Cast<UBSBatteryDefinition>(Module);
			}
		}

		return OutBindings.Chassis != nullptr;
	}

	private int CreateRow(ABSSentry Sentry)
	{
		int RowIndex = RowSentries.Num();
		RowSentries.Add(Sentry);
		Bindings.Add(FBSSentryBindings());
		TargetingRuntime.Add(FBSSentryTargetingRuntime());
		CombatRuntime.Add(FBSSentryCombatRuntime());
		PowerRuntime.Add(FBSSentryPowerRuntime());
		return RowIndex;
	}

	private void ApplyBindings(int RowIndex, const FBSSentryBindings& ResolvedBindings, bool bRowCreated)
	{
		bool bTurretChanged = bRowCreated || Bindings[RowIndex].Turret != ResolvedBindings.Turret;
		bool bBatteryChanged = bRowCreated || Bindings[RowIndex].Battery != ResolvedBindings.Battery;

		Bindings[RowIndex] = ResolvedBindings;

		if (bTurretChanged)
		{
			CombatRuntime[RowIndex].ShotCooldownRemaining = 0.0f;
		}

		if (bBatteryChanged)
		{
			PowerBehavior::InitState(Bindings[RowIndex], PowerRuntime[RowIndex]);
		}
	}

	private void MoveRow(int TargetRowIndex, int SourceRowIndex)
	{
		RowSentries[TargetRowIndex] = RowSentries[SourceRowIndex];
		Bindings[TargetRowIndex] = Bindings[SourceRowIndex];
		TargetingRuntime[TargetRowIndex] = TargetingRuntime[SourceRowIndex];
		CombatRuntime[TargetRowIndex] = CombatRuntime[SourceRowIndex];
		PowerRuntime[TargetRowIndex] = PowerRuntime[SourceRowIndex];
	}

	private TOptional<int> FindRowIndex(ABSSentry Sentry) const
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
		Bindings.Empty();
		TargetingRuntime.Empty();
		CombatRuntime.Empty();
		PowerRuntime.Empty();
	}
}
