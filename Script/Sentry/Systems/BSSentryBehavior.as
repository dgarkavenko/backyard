namespace SentryDebug
{
	const FConsoleVariable ShowSockets(f"BF.Sentry.ShowSockets", 0);

	void DrawSockets(ABSSentry Sentry)
	{
		int SlotCount = Sentry.Slots.Num();
		System::DrawDebugString(Sentry.ActorLocation + FVector(0, 0, 50), f"Slots: {SlotCount}", nullptr, FLinearColor::White);

		for (int SlotIndex = 0; SlotIndex < SlotCount; SlotIndex++)
		{
			const FBFModuleSlot& ModuleSlot = Sentry.Slots[SlotIndex];
			FLinearColor PointColor = ModuleSlot.bOccupied ? FLinearColor::Yellow : FLinearColor::Green;
			FString Label = ModuleSlot.Socket.ToString();

			if (ModuleSlot.Socket == NAME_None)
			{
				FVector FallbackLocation = Sentry.ActorLocation + FVector(0, 0, 30 + SlotIndex * 15);
				System::DrawDebugPoint(FallbackLocation, 8.0f, FLinearColor::Red, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
				System::DrawDebugString(FallbackLocation, f"[{SlotIndex}] NO SOCKET", nullptr, FLinearColor::Red);
				continue;
			}

			USceneComponent SocketOwner = SentryAssembly::FindSocketOwner(Sentry, ModuleSlot.Socket);
			if (SocketOwner == nullptr)
			{
				FVector VirtualLocation = Sentry.Rotator02.WorldLocation + FVector(0, 0, 10 + SlotIndex * 10);
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
	void Update(ABSSentry Sentry, UBSChassisDefinition ChassisDef, FVector TargetLocation, float DeltaSeconds)
	{
		if (ChassisDef == nullptr)
		{
			return;
		}

		FVector Rotator01PivotWorld = Sentry.Base.WorldTransform.TransformPosition(Sentry.Rotator01PivotOffset);
		FVector DirectionToTarget = (TargetLocation - Rotator01PivotWorld).GetSafeNormal();
		FVector LocalDirection = Sentry.Base.WorldTransform.InverseTransformVector(DirectionToTarget);
		FRotator Constrained = Sentry::ConstrainRotation(
			Sentry.Rotator01.RelativeRotation, LocalDirection.Rotation(),
			ChassisDef.Rotator01Constraint, DeltaSeconds
		);
		Sentry.Rotator01.SetRelativeRotation(Constrained);

		if (Sentry.MuzzleComponent != nullptr)
		{
			FVector MuzzleWorld = Sentry.Rotator02.WorldTransform.TransformPosition(Sentry.MuzzleOffset);
			DirectionToTarget = (TargetLocation - MuzzleWorld).GetSafeNormal();
			LocalDirection = Sentry.Rotator01.WorldTransform.InverseTransformVector(DirectionToTarget);
			FRotator DesiredRotation = LocalDirection.Rotation() - Sentry.MuzzleForwardRotation;
			Constrained = Sentry::ConstrainRotation(
				Sentry.Rotator02.RelativeRotation, DesiredRotation,
				ChassisDef.Rotator02Constraint, DeltaSeconds
			);
		}
		else
		{
			FVector Rotator02PivotWorld = Sentry.Rotator01.WorldTransform.TransformPosition(Sentry.Rotator02PivotOffset);
			DirectionToTarget = (TargetLocation - Rotator02PivotWorld).GetSafeNormal();
			LocalDirection = Sentry.Rotator01.WorldTransform.InverseTransformVector(DirectionToTarget);
			Constrained = Sentry::ConstrainRotation(
				Sentry.Rotator02.RelativeRotation, LocalDirection.Rotation(),
				ChassisDef.Rotator02Constraint, DeltaSeconds
			);
		}
		Sentry.Rotator02.SetRelativeRotation(Constrained);
	}
}

class UBSSentriesSystem : UScriptWorldSubsystem
{
	TArray<ABSSentry> Sentries;
	TArray<UBSChassisDefinition> ChassisConfigs;
	TArray<UBSPowerSupplyUnitDefinition> PSUConfigs;
	TArray<UBSBatteryDefinition> BatteryConfigs;
	TArray<FBSPowerState> PowerStates;
	TArray<int> FreeList;

	int Register(ABSSentry Sentry, UBSChassisDefinition ChassisDef)
	{
		int SlotIndex = -1;

		if (FreeList.Num() > 0)
		{
			SlotIndex = FreeList.Last();
			FreeList.RemoveAt(FreeList.Num() - 1);
			Sentries[SlotIndex] = Sentry;
			ChassisConfigs[SlotIndex] = ChassisDef;
			PSUConfigs[SlotIndex] = nullptr;
			BatteryConfigs[SlotIndex] = nullptr;
			PowerStates[SlotIndex] = FBSPowerState();
		}
		else
		{
			SlotIndex = Sentries.Num();
			Sentries.Add(Sentry);
			ChassisConfigs.Add(ChassisDef);
			PSUConfigs.Add(nullptr);
			BatteryConfigs.Add(nullptr);
			PowerStates.Add(FBSPowerState());
		}

		return SlotIndex;
	}

	void Unregister(int SlotIndex)
	{
		if (SlotIndex < 0 || SlotIndex >= Sentries.Num())
		{
			return;
		}

		Sentries[SlotIndex] = nullptr;
		ChassisConfigs[SlotIndex] = nullptr;
		PSUConfigs[SlotIndex] = nullptr;
		BatteryConfigs[SlotIndex] = nullptr;
		PowerStates[SlotIndex] = FBSPowerState();
		FreeList.Add(SlotIndex);
	}

	void SetPSU(int SlotIndex, UBSPowerSupplyUnitDefinition PSU)
	{
		if (SlotIndex < 0 || SlotIndex >= Sentries.Num())
		{
			return;
		}
		PSUConfigs[SlotIndex] = PSU;
	}

	void SetBattery(int SlotIndex, UBSBatteryDefinition Battery)
	{
		if (SlotIndex < 0 || SlotIndex >= Sentries.Num())
		{
			return;
		}
		BatteryConfigs[SlotIndex] = Battery;
		PowerBehavior::InitState(PowerStates[SlotIndex], Battery);
	}

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		ACharacter PlayerCharacter = Gameplay::GetPlayerCharacter(0);
		if (PlayerCharacter == nullptr)
		{
			return;
		}

		FVector TargetLocation = PlayerCharacter.ActorLocation;

		for (int i = 0; i < Sentries.Num(); i++)
		{
			if (Sentries[i] == nullptr)
			{
				continue;
			}

			if (PSUConfigs[i] != nullptr)
			{
				PowerBehavior::Update(PSUConfigs[i], BatteryConfigs[i], PowerStates[i], Sentries[i], DeltaSeconds);
			}

			if (PSUConfigs[i] == nullptr || PowerStates[i].SupplyRatio > 0.0f)
			{
				SentryAim::Update(Sentries[i], ChassisConfigs[i], TargetLocation, DeltaSeconds);
			}

		}
	}
}
