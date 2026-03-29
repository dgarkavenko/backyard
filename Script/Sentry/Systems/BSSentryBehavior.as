
namespace SentryAim
{
	void Update(ABSSentry Sentry, UBSSentryVisualAdapter Adapter, FVector TargetLocation, float DeltaSeconds)
	{
		if (Adapter == nullptr || !Adapter.HasAimRig())
		{
			return;
		}

		USceneComponent Rotator0 = Adapter.RotatorComponents[0];
		USceneComponent Rotator1 = Adapter.RotatorComponents[1];
		FBSSentryConstraint Rotator0Constraint = Adapter.RotatorConstraints.Num() > 0 ? Adapter.RotatorConstraints[0] : FBSSentryConstraint();
		FBSSentryConstraint Rotator1Constraint = Adapter.RotatorConstraints.Num() > 1 ? Adapter.RotatorConstraints[1] : FBSSentryConstraint();
		FVector Rotator0Offset = Adapter.RotatorOffsets.Num() > 0 ? Adapter.RotatorOffsets[0] : FVector::ZeroVector;
		FVector Rotator1Offset = Adapter.RotatorOffsets.Num() > 1 ? Adapter.RotatorOffsets[1] : FVector::ZeroVector;

		FVector Rotator0World = Rotator0.WorldTransform.TransformPosition(Rotator0Offset);
		FVector DirectionToTarget = (TargetLocation - Rotator0World).GetSafeNormal();
		FVector LocalDirection = Sentry.Base.WorldTransform.InverseTransformVector(DirectionToTarget);
		FRotator Constrained = Sentry::ConstrainRotation(
			Rotator0.RelativeRotation,
			LocalDirection.Rotation(),
			Rotator0Constraint,
			DeltaSeconds
		);
		Rotator0.SetRelativeRotation(Constrained);

		if (Adapter.MuzzleComponent != nullptr)
		{
			FVector MuzzleWorld = Rotator1.WorldTransform.TransformPosition(Adapter.MuzzleOffset);
			DirectionToTarget = (TargetLocation - MuzzleWorld).GetSafeNormal();
			LocalDirection = Rotator0.WorldTransform.InverseTransformVector(DirectionToTarget);
			FRotator DesiredRotation = LocalDirection.Rotation() - Adapter.MuzzleForwardRotation;
			Constrained = Sentry::ConstrainRotation(
				Rotator1.RelativeRotation,
				DesiredRotation,
				Rotator1Constraint,
				DeltaSeconds
			);
		}
		else
		{
			FVector Rotator1World = Rotator0.WorldTransform.TransformPosition(Rotator1Offset);
			DirectionToTarget = (TargetLocation - Rotator1World).GetSafeNormal();
			LocalDirection = Rotator0.WorldTransform.InverseTransformVector(DirectionToTarget);
			Constrained = Sentry::ConstrainRotation(
				Rotator1.RelativeRotation,
				LocalDirection.Rotation(),
				Rotator1Constraint,
				DeltaSeconds
			);
		}

		Rotator1.SetRelativeRotation(Constrained);
	}
}

class UBSSentriesSystem : UScriptWorldSubsystem
{
	TArray<int> SourceHandles;
	TArray<int> SourceVersions;
	TArray<ABSSentry> Sentries;
	TArray<UBSSentryVisualAdapter> VisualAdapters;
	TArray<UBSChassisDefinition> ChassisConfigs;
	TArray<UBSPowerSupplyUnitDefinition> PSUConfigs;
	TArray<UBSBatteryDefinition> BatteryConfigs;
	TArray<FBSPowerState> PowerStates;
	TArray<int> FreeList;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		SyncFromModularRuntime();

		ACharacter PlayerCharacter = Gameplay::GetPlayerCharacter(0);
		if (PlayerCharacter == nullptr)
		{
			return;
		}

		FVector TargetLocation = PlayerCharacter.ActorLocation;

		for (int Index = 0; Index < SourceHandles.Num(); Index++)
		{
			if (SourceHandles[Index] < 0 || VisualAdapters[Index] == nullptr || ChassisConfigs[Index] == nullptr)
			{
				continue;
			}

			if (PSUConfigs[Index] != nullptr)
			{
				PowerBehavior::Update(PSUConfigs[Index], BatteryConfigs[Index], PowerStates[Index], Sentries[Index], DeltaSeconds);
			}

			if (PSUConfigs[Index] == nullptr || PowerStates[Index].SupplyRatio > 0.0f)
			{
				SentryAim::Update(Sentries[Index], VisualAdapters[Index], TargetLocation, DeltaSeconds);
			}
		}
	}

	private void SyncFromModularRuntime()
	{
		UBSModularEntitiesSystem ModularSystem = UBSModularEntitiesSystem::Get();
		if (ModularSystem == nullptr)
		{
			ClearAllRows();
			return;
		}

		TArray<int> ActiveHandles;

		for (int Handle = 0; Handle < ModularSystem.Components.Num(); Handle++)
		{
			UBSModularComponent ModularComponent = ModularSystem.Components[Handle];
			AActor Owner = ModularSystem.Owners[Handle];
			ABSSentry Sentry = Cast<ABSSentry>(Owner);
			if (ModularComponent == nullptr || Sentry == nullptr || Sentry.VisualAdapter == nullptr)
			{
				continue;
			}

			UBSChassisDefinition ChassisDefinition = nullptr;
			UBSPowerSupplyUnitDefinition PowerSupply = nullptr;
			UBSBatteryDefinition Battery = nullptr;

			for (UBFModuleDefinition Module : ModularComponent.InstalledModules)
			{
				if (Module == nullptr)
				{
					continue;
				}

				if (ChassisDefinition == nullptr)
				{
					ChassisDefinition = Cast<UBSChassisDefinition>(Module);
				}
				if (PowerSupply == nullptr)
				{
					PowerSupply = Cast<UBSPowerSupplyUnitDefinition>(Module);
				}
				if (Battery == nullptr)
				{
					Battery = Cast<UBSBatteryDefinition>(Module);
				}
			}

			if (ChassisDefinition == nullptr)
			{
				continue;
			}

			ActiveHandles.Add(Handle);

			int RowIndex = FindRowForHandle(Handle);
			if (RowIndex < 0)
			{
				RowIndex = AcquireRow();
				SourceHandles[RowIndex] = Handle;
				SourceVersions[RowIndex] = -1;
			}

			if (SourceVersions[RowIndex] != ModularComponent.CompositionVersion)
			{
				bool bBatteryChanged = BatteryConfigs[RowIndex] != Battery;

				Sentries[RowIndex] = Sentry;
				VisualAdapters[RowIndex] = Sentry.VisualAdapter;
				ChassisConfigs[RowIndex] = ChassisDefinition;
				PSUConfigs[RowIndex] = PowerSupply;
				BatteryConfigs[RowIndex] = Battery;
				SourceVersions[RowIndex] = ModularComponent.CompositionVersion;

				if (bBatteryChanged)
				{
					PowerBehavior::InitState(PowerStates[RowIndex], Battery);
				}
			}
		}

		for (int RowIndex = 0; RowIndex < SourceHandles.Num(); RowIndex++)
		{
			if (SourceHandles[RowIndex] >= 0 && !ActiveHandles.Contains(SourceHandles[RowIndex]))
			{
				ReleaseRow(RowIndex);
			}
		}
	}

	private int FindRowForHandle(int Handle) const
	{
		for (int RowIndex = 0; RowIndex < SourceHandles.Num(); RowIndex++)
		{
			if (SourceHandles[RowIndex] == Handle)
			{
				return RowIndex;
			}
		}

		return -1;
	}

	private int AcquireRow()
	{
		if (FreeList.Num() > 0)
		{
			int RowIndex = FreeList.Last();
			FreeList.RemoveAt(FreeList.Num() - 1);
			return RowIndex;
		}

		int RowIndex = SourceHandles.Num();
		SourceHandles.Add(-1);
		SourceVersions.Add(-1);
		Sentries.Add(nullptr);
		VisualAdapters.Add(nullptr);
		ChassisConfigs.Add(nullptr);
		PSUConfigs.Add(nullptr);
		BatteryConfigs.Add(nullptr);
		PowerStates.Add(FBSPowerState());
		return RowIndex;
	}

	private void ReleaseRow(int RowIndex)
	{
		SourceHandles[RowIndex] = -1;
		SourceVersions[RowIndex] = -1;
		Sentries[RowIndex] = nullptr;
		VisualAdapters[RowIndex] = nullptr;
		ChassisConfigs[RowIndex] = nullptr;
		PSUConfigs[RowIndex] = nullptr;
		BatteryConfigs[RowIndex] = nullptr;
		PowerStates[RowIndex] = FBSPowerState();

		if (!FreeList.Contains(RowIndex))
		{
			FreeList.Add(RowIndex);
		}
	}

	private void ClearAllRows()
	{
		for (int RowIndex = 0; RowIndex < SourceHandles.Num(); RowIndex++)
		{
			ReleaseRow(RowIndex);
		}
	}
}
