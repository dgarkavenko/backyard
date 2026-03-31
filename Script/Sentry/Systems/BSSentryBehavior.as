
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
	TArray<int> EntityHandle;

	TArray<ABSSentry> Sentry;
	TArray<UBSSentryVisualAdapter> VisualAdapter;
	TArray<UBSChassisDefinition> ChassisConfig;
	TArray<UBSPowerSupplyUnitDefinition> PSUConfig;
	TArray<UBSBatteryDefinition> BatteryConfig;
	TArray<FBSPowerState> PowerState;

	TArray<FVector> TargetLocation;

	TArray<int> FreeList;


	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		ACharacter PlayerCharacter = Gameplay::GetPlayerCharacter(0);
		if (PlayerCharacter == nullptr)
		{
			return;
		}

		FVector PlayerLocation = PlayerCharacter.ActorLocation;

		for (int Index = 0; Index < EntityHandle.Num(); Index++)
		{
			//check(EntityHandle[Index] >= 0);
			check(VisualAdapter[Index] != nullptr);
			check(ChassisConfig[Index] != nullptr);
		}

		//Acquire Target
		for (int Index = 0; Index < EntityHandle.Num(); Index++)
		{
			if (EntityHandle[Index] >= 0)
			{
				TargetLocation[Index] = PlayerLocation;
			}
			
		}

		//Aim at target
		for (int Index = 0; Index < EntityHandle.Num(); Index++)
		{
			if (EntityHandle[Index] >= 0)
			{
				SentryAim::Update(Sentry[Index], VisualAdapter[Index], TargetLocation[Index], DeltaSeconds);			
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
		UBSTurretDefinition Turret = nullptr;

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
			if (Turret == nullptr)
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
		ChassisConfig[RowIndex] = ChassisDefinition;
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
		EntityHandle[NewRow] = Handle;

		return NewRow;
	}

	private TOptional<int> FindRowForHandle(int Handle) const
	{
		for (int RowIndex = 0; RowIndex < EntityHandle.Num(); RowIndex++)
		{
			if (EntityHandle[RowIndex] == Handle)
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

		int RowIndex = EntityHandle.Num();
		EntityHandle.Add(-1);
		Sentry.Add(nullptr);
		VisualAdapter.Add(nullptr);
		ChassisConfig.Add(nullptr);
		PSUConfig.Add(nullptr);
		BatteryConfig.Add(nullptr);
		TargetLocation.Add(FVector::ZeroVector);
		PowerState.Add(FBSPowerState());
		return RowIndex;
	}

	private void ReleaseRow(int RowIndex)
	{
		EntityHandle[RowIndex] = -1;
		Sentry[RowIndex] = nullptr;
		VisualAdapter[RowIndex] = nullptr;
		ChassisConfig[RowIndex] = nullptr;
		PSUConfig[RowIndex] = nullptr;
		BatteryConfig[RowIndex] = nullptr;
		PowerState[RowIndex] = FBSPowerState();

		if (!FreeList.Contains(RowIndex))
		{
			FreeList.Add(RowIndex);
		}
	}

	private void ClearAllRows()
	{
		for (int RowIndex = 0; RowIndex < EntityHandle.Num(); RowIndex++)
		{
			ReleaseRow(RowIndex);
		}
	}
}
