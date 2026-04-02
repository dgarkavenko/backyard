class UBSSentryWorldSubsystem : UScriptWorldSubsystem
{
	TArray<int> RowHandles;
	TArray<int> FreeList;

	TArray<ABSSentry> Sentry;
	TArray<UBSSentryVisualAdapter> VisualAdapter;
	TArray<UBSChassisDefinition> Chassis;
	TArray<UBSTurretDefinition> Turret;
	TArray<UBSPowerSupplyUnitDefinition> PSUConfig;
	TArray<UBSBatteryDefinition> BatteryConfig;
	TArray<FBSPowerState> PowerState;	
	TArray<float> ShotCooldownRemaining;

	TArray<FVector> TargetLocation;

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

		for (int Index = 0; Index < RowHandles.Num(); Index++)
		{
			if (RowHandles[Index] >= 0)
			{
				check(VisualAdapter[Index] != nullptr);
				check(Chassis[Index] != nullptr);
			}
		}

		//Acquire Target
		for (int Index = 0; Index < RowHandles.Num(); Index++)
		{
			if (RowHandles[Index] >= 0)
			{
				TargetLocation[Index] = PlayerLocation;
			}
			
		}

		//Aim at target
		for (int Index = 0; Index < RowHandles.Num(); Index++)
		{
			if (RowHandles[Index] >= 0)
			{
				SentryAim::Update(Sentry[Index], VisualAdapter[Index], TargetLocation[Index], DeltaSeconds);
				if (SentryDebugF::ShowAim.Int > 0)
				{
					SentryDebugF::DrawAim(Sentry[Index], TargetLocation[Index]);
				}
			}			
		}

		for (int Index = 0; Index < RowHandles.Num(); Index++)
		{
			ShotCooldownRemaining[Index] -= DeltaSeconds;
		}

		for (int Index = 0; Index < RowHandles.Num(); Index++)
		{
			if (RowHandles[Index] >= 0 && Turret[Index] != nullptr)
			{
				if (ShotCooldownRemaining[Index] < 0)
				{
					SentryShoot::Update(Sentry[Index], VisualAdapter[Index], Turret[Index], TargetLocation[Index], ShotCooldownRemaining[Index]);
				}				
			}
		}
	}

	void SyncFromModularRuntime(int Handle, UBSModularComponent ModularComponent)
	{
		TArray<int> ActiveHandles;

		AActor Owner = ModularComponent.Owner;
		ABSSentry SyncedSentry = Cast<ABSSentry>(Owner);
		if (ModularComponent == nullptr || SyncedSentry == nullptr || SyncedSentry.VisualAdapter == nullptr)
		{
			return;
		}

		UBSChassisDefinition ChassisDefinition = nullptr;
		UBSPowerSupplyUnitDefinition PowerSupply = nullptr;
		UBSBatteryDefinition Battery = nullptr;
		UBSTurretDefinition TurretDefinition = nullptr;

		for (UBFModuleDefinition Module : ModularComponent.InstalledModules)
		{	
			check(Module != nullptr, "Module is nullptr");

			if (ChassisDefinition == nullptr)
			{
				ChassisDefinition = Cast<UBSChassisDefinition>(Module);
			}
			if (PowerSupply == nullptr)
			{
				PowerSupply = Cast<UBSPowerSupplyUnitDefinition>(Module);
			}
			if (TurretDefinition == nullptr)
			{
				TurretDefinition = Cast<UBSTurretDefinition>(Module);
			}
			if (Battery == nullptr)
			{
				Battery = Cast<UBSBatteryDefinition>(Module);
			}
		}

		if (ChassisDefinition == nullptr)
		{
			return;
		}

		ActiveHandles.Add(Handle);

		int32 RowIndex = EnsureHandleRow(Handle);

		Sentry[RowIndex] = SyncedSentry;
		VisualAdapter[RowIndex] = SyncedSentry.VisualAdapter;
		Chassis[RowIndex] = ChassisDefinition;
		Turret[RowIndex] = TurretDefinition;
		PSUConfig[RowIndex] = PowerSupply;
		BatteryConfig[RowIndex] = Battery;

		// for (int RowIndex = 0; RowIndex < SourceHandles.Num(); RowIndex++)
		// {
		// 	if (SourceHandles[RowIndex] >= 0 && !ActiveHandles.Contains(SourceHandles[RowIndex]))
		// 	{
		// 		ReleaseRow(RowIndex);
		// 	}
		// }
	}

	int32 EnsureHandleRow(int32 Handle)
	{
		TOptional<int32> RowIndex = FindRowForHandle(Handle);
		if (RowIndex.IsSet())
		{
			return RowIndex.Value;
		}
		
		int32 NewRow = AcquireRow();
		RowHandles[NewRow] = Handle;

		return NewRow;
	}

	private TOptional<int> FindRowForHandle(int Handle) const
	{
		for (int RowIndex = 0; RowIndex < RowHandles.Num(); RowIndex++)
		{
			if (RowHandles[RowIndex] == Handle)
			{
				return RowIndex;
			}
		}

		return TOptional<int>();
	}

	private int AcquireRow()
	{
		if (FreeList.Num() > 0)
		{
			int RowIndex = FreeList.Last();
			FreeList.RemoveAt(FreeList.Num() - 1);
			return RowIndex;
		}

		int RowIndex = RowHandles.Num();
		RowHandles.Add(-1);
		Sentry.Add(nullptr);
		VisualAdapter.Add(nullptr);
		Chassis.Add(nullptr);
		Turret.Add(nullptr);
		PSUConfig.Add(nullptr);
		BatteryConfig.Add(nullptr);
		TargetLocation.Add(FVector::ZeroVector);
		PowerState.Add(FBSPowerState());
		ShotCooldownRemaining.Add(0.0f);
		return RowIndex;
	}

	private void ReleaseRow(int RowIndex)
	{
		RowHandles[RowIndex] = -1;
		Sentry[RowIndex] = nullptr;
		VisualAdapter[RowIndex] = nullptr;
		Chassis[RowIndex] = nullptr;
		Turret[RowIndex] = nullptr;
		PSUConfig[RowIndex] = nullptr;
		BatteryConfig[RowIndex] = nullptr;
		PowerState[RowIndex] = FBSPowerState();
		ShotCooldownRemaining[RowIndex] = 0.0f;

		if (!FreeList.Contains(RowIndex))
		{
			FreeList.Add(RowIndex);
		}
	}

	private void ClearAllRows()
	{
		for (int RowIndex = 0; RowIndex < RowHandles.Num(); RowIndex++)
		{
			ReleaseRow(RowIndex);
		}
	}
}
