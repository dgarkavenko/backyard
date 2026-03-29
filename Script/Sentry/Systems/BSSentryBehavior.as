namespace SentryDebug
{
	const FConsoleVariable ShowSockets(f"BF.Sentry.ShowSockets", 0);
	const FConsoleVariable LogAssemblyCVar(f"BF.Sentry.LogAssembly", 0);

	void LogAssembly(FString Message)
	{
		if (LogAssemblyCVar.Int > 0)
		{
			Log(Message);
		}
	}

	void DrawSockets(ABSSentry Sentry)
	{
		if (Sentry == nullptr || Sentry.ModularComponent == nullptr || Sentry.VisualAdapter == nullptr)
		{
			return;
		}

		int SlotCount = Sentry.ModularComponent.Slots.Num();
		FString BaseMeshName = Sentry.Base != nullptr && Sentry.Base.StaticMesh != nullptr ? Sentry.Base.StaticMesh.GetName().ToString() : "None";
		FString Header = f"Slots: {SlotCount} Modules: {Sentry.ModularComponent.InstalledModules.Num()} Base: {BaseMeshName}";
		System::DrawDebugString(Sentry.ActorLocation + FVector(0, 0, 50), Header, nullptr, FLinearColor::White);
		System::DrawDebugString(Sentry.ActorLocation + FVector(0, 0, 70), f"Yaw: {Sentry.VisualAdapter.YawPivot != nullptr} Pitch: {Sentry.VisualAdapter.PitchPivot != nullptr} Muzzle: {Sentry.VisualAdapter.MuzzleComponent != nullptr}", nullptr, FLinearColor::White);

		for (int SlotIndex = 0; SlotIndex < SlotCount; SlotIndex++)
		{
			const FBFModuleSlot& ModuleSlot = Sentry.ModularComponent.Slots[SlotIndex];
			FLinearColor PointColor = ModuleSlot.bOccupied ? FLinearColor::Yellow : FLinearColor::Green;
			FString Label = ModuleSlot.Socket.ToString();

			if (ModuleSlot.Socket == NAME_None)
			{
				FVector FallbackLocation = Sentry.ActorLocation + FVector(0, 0, 30 + SlotIndex * 15);
				System::DrawDebugPoint(FallbackLocation, 8.0f, FLinearColor::Red, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
				System::DrawDebugString(FallbackLocation, f"[{SlotIndex}] NO SOCKET", nullptr, FLinearColor::Red);
				continue;
			}

			USceneComponent SocketOwner = SentryAssembly::FindSocketOwner(Sentry.VisualAdapter, Sentry, ModuleSlot.Socket);
			if (SocketOwner == nullptr)
			{
				USceneComponent DefaultAttachParent = Sentry.VisualAdapter.GetDefaultAttachParent(Sentry);
				FVector VirtualLocation = DefaultAttachParent != nullptr
					? DefaultAttachParent.WorldLocation + FVector(0, 0, 10 + SlotIndex * 10)
					: Sentry.ActorLocation + FVector(0, 0, 10 + SlotIndex * 10);
				FLinearColor CyanColor = FLinearColor(0.0f, 0.8f, 0.8f);
				System::DrawDebugPoint(VirtualLocation, 8.0f, CyanColor, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
				System::DrawDebugString(VirtualLocation, f"[{SlotIndex}] {Label} (virtual)", nullptr, CyanColor);
				continue;
			}

			FVector SocketLocation = SocketOwner.GetSocketLocation(ModuleSlot.Socket);
			System::DrawDebugPoint(SocketLocation, 12.0f, PointColor, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
			System::DrawDebugString(SocketLocation, f"[{SlotIndex}] {Label}", nullptr, PointColor);
		}
	}
}

namespace SentryAim
{
	void Update(ABSSentry Sentry, UBSSentryVisualAdapter Adapter, FVector TargetLocation, float DeltaSeconds)
	{
		if (Adapter == nullptr || !Adapter.HasAimRig())
		{
			return;
		}

		FVector YawPivotWorld = Adapter.YawPivot != nullptr
			? Adapter.YawPivot.WorldTransform.TransformPosition(Adapter.YawPivotOffset)
			: FVector::ZeroVector;
		FVector DirectionToTarget = (TargetLocation - YawPivotWorld).GetSafeNormal();
		FVector LocalDirection = Sentry.Base.WorldTransform.InverseTransformVector(DirectionToTarget);
		FRotator Constrained = Sentry::ConstrainRotation(
			Adapter.YawPivot.RelativeRotation,
			LocalDirection.Rotation(),
			Adapter.YawConstraint,
			DeltaSeconds
		);
		Adapter.YawPivot.SetRelativeRotation(Constrained);

		if (Adapter.MuzzleComponent != nullptr)
		{
			FVector MuzzleWorld = Adapter.PitchPivot.WorldTransform.TransformPosition(Adapter.MuzzleOffset);
			DirectionToTarget = (TargetLocation - MuzzleWorld).GetSafeNormal();
			LocalDirection = Adapter.YawPivot.WorldTransform.InverseTransformVector(DirectionToTarget);
			FRotator DesiredRotation = LocalDirection.Rotation() - Adapter.MuzzleForwardRotation;
			Constrained = Sentry::ConstrainRotation(
				Adapter.PitchPivot.RelativeRotation,
				DesiredRotation,
				Adapter.PitchConstraint,
				DeltaSeconds
			);
		}
		else
		{
			FVector PitchPivotWorld = Adapter.YawPivot.WorldTransform.TransformPosition(Adapter.PitchPivotOffset);
			DirectionToTarget = (TargetLocation - PitchPivotWorld).GetSafeNormal();
			LocalDirection = Adapter.YawPivot.WorldTransform.InverseTransformVector(DirectionToTarget);
			Constrained = Sentry::ConstrainRotation(
				Adapter.PitchPivot.RelativeRotation,
				LocalDirection.Rotation(),
				Adapter.PitchConstraint,
				DeltaSeconds
			);
		}

		Adapter.PitchPivot.SetRelativeRotation(Constrained);
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
