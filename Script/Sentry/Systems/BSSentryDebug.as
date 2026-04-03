namespace SentryDebugF
{
	const FConsoleVariable ShowSockets(f"BF.Sentry.ShowSockets", 0);
	const FConsoleVariable ShowAim(f"BF.Sentry.ShowAim", 0);
	const FConsoleVariable LogAim(f"BF.Sentry.LogAim", 0);
	const FConsoleVariable LogAssemblyCVar(f"BF.Sentry.LogAssembly", 0);
	const FConsoleVariable ValidateAssembly(f"BF.Sentry.ValidateAssembly", 0);

	void LogAssembled(ABSSentry Sentry, const FBSSentryAimCache& AimCache, UBSModularView ModularView)
	{
		if (LogAssemblyCVar.Int == 0)
		{
			return;
		}

		FString BaseMeshName = Sentry.Base != nullptr && Sentry.Base.StaticMesh != nullptr ? Sentry.Base.StaticMesh.GetName().ToString() : "<none>";
		FString Rotator0Name = AimCache.Rotator0Component != nullptr ? AimCache.Rotator0Component.GetName().ToString() : "<none>";
		FString Rotator1Name = AimCache.Rotator1Component != nullptr ? AimCache.Rotator1Component.GetName().ToString() : "<none>";
		FString MuzzleName = AimCache.MuzzleComponent != nullptr ? AimCache.MuzzleComponent.GetName().ToString() : "<none>";
		int RotatorCount = 0;
		if (AimCache.Rotator0Component != nullptr)
		{
			RotatorCount++;
		}
		if (AimCache.Rotator1Component != nullptr)
		{
			RotatorCount++;
		}
		int ActiveElementCount = ModularView != nullptr ? ModularView.ActiveModuleElements.Num() : 0;
		LogAssembly(f"Assembly | Rebuild Complete Sentry='{Sentry.GetName()}' BaseMesh='{BaseMeshName}' RotatorCount={RotatorCount} Rotator0='{Rotator0Name}' Rotator1='{Rotator1Name}' Muzzle='{MuzzleName}' ActiveElements={ActiveElementCount}");
	}
	
	void ValidateNoGarbageComponents(UBSModularView ModularView, ABSSentry Sentry)
	{
		if (ModularView == nullptr)
		{
			return;
		}

		ValidatePoolState(ModularView.ModuleElementPool, ModularView.ActiveModuleElements);

		TArray<USceneComponent> AttachedComponents;
		Sentry.Base.GetChildrenComponents(true, AttachedComponents);

		for (USceneComponent Child : AttachedComponents)
		{
			UStaticMeshComponent MeshComponent = Cast<UStaticMeshComponent>(Child);
			if (MeshComponent == nullptr)
			{
				continue;
			}

			if (!IsManagedDynamicComponent(ModularView, MeshComponent))
			{
				FString Name = MeshComponent.GetName().ToString();
				if (Name.Contains("ModulePool_"))
				{
					Warning(f"Sentry rebuild garbage assert: unmanaged pooled component '{Name}' attached to {Sentry.GetName()}");
				}
			}
		}
	}	

	bool IsManagedDynamicComponent(UBSModularView ModularView, UStaticMeshComponent Component)
	{
		return ModularView != nullptr && ModularView.ModuleElementPool.Contains(Component);
	}

	void ValidatePoolState(const TArray<UStaticMeshComponent>& Pool, const TArray<UStaticMeshComponent>& ActivePool)
	{
		for (UStaticMeshComponent Component : Pool)
		{
			if (Component == nullptr)
			{
				continue;
			}

			bool bIsActive = ActivePool.Contains(Component);
			if (bIsActive && Component.StaticMesh == nullptr)
			{
				Warning(f"Sentry rebuild garbage assert: active module component '{Component.GetName()}' has no mesh");
			}

			if (!bIsActive && Component.StaticMesh != nullptr)
			{
				Warning(f"Sentry rebuild garbage assert: stale module component '{Component.GetName()}' still has mesh '{Component.StaticMesh.GetName()}'");
			}
		}
	}

	void LogAssembly(FString Message)
	{
		if (LogAssemblyCVar.Int > 0)
		{
			Log(Message);
		}
	}

	void DrawSockets(ABSSentry Sentry)
	{
		if (Sentry == nullptr || Sentry.ModularComponent == nullptr || Sentry.ModularView == nullptr || Sentry.SentryView == nullptr)
		{
			return;
		}

		int SlotCount = Sentry.ModularComponent.Slots.Num();
		FString BaseMeshName = Sentry.Base != nullptr && Sentry.Base.StaticMesh != nullptr ? Sentry.Base.StaticMesh.GetName().ToString() : "None";
		FString Header = f"Slots: {SlotCount} Modules: {Sentry.ModularComponent.InstalledModules.Num()} Base: {BaseMeshName}";
		System::DrawDebugString(Sentry.ActorLocation + FVector(0, 0, 50), Header, nullptr, FLinearColor::White);
		UBSSentryWorldSubsystem SentrySubsystem = UBSSentryWorldSubsystem::Get();
		bool bHasRotator0 = false;
		bool bHasRotator1 = false;
		bool bHasMuzzle = false;
		int RotatorCount = 0;
		if (SentrySubsystem != nullptr)
		{
			TOptional<int> RowIndex = SentrySubsystem.FindRowIndex(Sentry);
			if (RowIndex.IsSet())
			{
				bHasRotator0 = SentrySubsystem.AimCache[RowIndex.Value].Rotator0Component != nullptr;
				bHasRotator1 = SentrySubsystem.AimCache[RowIndex.Value].Rotator1Component != nullptr;
				bHasMuzzle = SentrySubsystem.AimCache[RowIndex.Value].MuzzleComponent != nullptr;
				RotatorCount = (bHasRotator0 ? 1 : 0) + (bHasRotator1 ? 1 : 0);
			}
		}
		System::DrawDebugString(Sentry.ActorLocation + FVector(0, 0, 70), f"Rotators: {RotatorCount} R0: {bHasRotator0} R1: {bHasRotator1} Muzzle: {bHasMuzzle}", nullptr, FLinearColor::White);

		for (int SlotIndex = 0; SlotIndex < SlotCount; SlotIndex++)
		{
			const FBFModuleSlot& ModuleSlot = Sentry.ModularComponent.Slots[SlotIndex].SlotData;
			FLinearColor PointColor = Sentry.ModularComponent.Slots[SlotIndex].Content.IsSet() ? FLinearColor::Yellow : FLinearColor::Green;
			FString Label = ModuleSlot.Socket.ToString();

			if (ModuleSlot.Socket == NAME_None)
			{
				FVector FallbackLocation = Sentry.ActorLocation + FVector(0, 0, 30 + SlotIndex * 15);
				System::DrawDebugPoint(FallbackLocation, 8.0f, FLinearColor::Red, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
				System::DrawDebugString(FallbackLocation, f"[{SlotIndex}] NO SOCKET", nullptr, FLinearColor::Red);
				continue;
			}
		}
	}

	void DrawAim(ABSSentry Sentry, const FBSSentryTargetingRuntime& TargetingRuntime)
	{
		if (Sentry == nullptr || !TargetingRuntime.bHasMuzzleState)
		{
			return;
		}

		FVector MuzzleLocation = TargetingRuntime.MuzzleWorldLocation;
		float DistanceToTarget = TargetingRuntime.DistanceToTarget;
		if (DistanceToTarget <= 0.0f)
		{
			return;
		}

		FVector MuzzleForward = TargetingRuntime.MuzzleWorldRotation.ForwardVector.GetSafeNormal();

		System::DrawDebugLine(MuzzleLocation, TargetingRuntime.TargetLocation, FLinearColor::Yellow, 0, 2);
		System::DrawDebugLine(MuzzleLocation, MuzzleLocation + MuzzleForward * DistanceToTarget, FLinearColor::Blue, 0, 2);
		System::DrawDebugPoint(TargetingRuntime.TargetLocation, 12.0f, FLinearColor::Yellow, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
		System::DrawDebugString(MuzzleLocation + FVector(0, 0, 18), f"dot={TargetingRuntime.AimDot}", nullptr, FLinearColor::White);
	}

	void LogAimState(ABSSentry Sentry, const FBSSentryAimCache& AimCache, const FBSSentryTargetingRuntime& TargetingRuntime)
	{
		if (Sentry == nullptr || !AimCache.bHasAimCache || !TargetingRuntime.bHasMuzzleState)
		{
			return;
		}

		if (LogAim.Int <= 0)
		{
			return;
		}

		float DistanceToTarget = TargetingRuntime.DistanceToTarget;
		if (DistanceToTarget <= 0.0f)
		{
			return;
		}

		FRotator MuzzleLocalRotation = AimCache.MuzzleLocalRotation.Rotator();

		Log(
			f"SentryAim sentry='{Sentry.GetName()}' " +
			f"fastPath={AimCache.bHasAimCache} " +
			f"dot={TargetingRuntime.AimDot} dist={DistanceToTarget} " +
			f"muzzleError=(pitch={TargetingRuntime.MuzzleError.Pitch}, yaw={TargetingRuntime.MuzzleError.Yaw}, roll={TargetingRuntime.MuzzleError.Roll}) " +
			f"muzzleOffset=(x={AimCache.MuzzleOffsetLocal.X}, y={AimCache.MuzzleOffsetLocal.Y}, z={AimCache.MuzzleOffsetLocal.Z}) " +
			f"cachedYaw=(forward={AimCache.CachedYawForwardOffset}, lateral={AimCache.CachedYawLateralOffset}) " +
			f"cachedPitch=(forward={AimCache.CachedPitchForwardOffset}, vertical={AimCache.CachedPitchVerticalOffset}) " +
			f"muzzleLocal=(pitch={MuzzleLocalRotation.Pitch}, yaw={MuzzleLocalRotation.Yaw}, roll={MuzzleLocalRotation.Roll}) " +
			f"desiredR0=(pitch={TargetingRuntime.DesiredRotator0Local.Pitch}, yaw={TargetingRuntime.DesiredRotator0Local.Yaw}, roll={TargetingRuntime.DesiredRotator0Local.Roll}) " +
			f"appliedR0=(pitch={TargetingRuntime.AppliedRotator0Local.Pitch}, yaw={TargetingRuntime.AppliedRotator0Local.Yaw}, roll={TargetingRuntime.AppliedRotator0Local.Roll}) " +
			f"desiredR1=(pitch={TargetingRuntime.DesiredRotator1Local.Pitch}, yaw={TargetingRuntime.DesiredRotator1Local.Yaw}, roll={TargetingRuntime.DesiredRotator1Local.Roll}) " +
			f"appliedR1=(pitch={TargetingRuntime.AppliedRotator1Local.Pitch}, yaw={TargetingRuntime.AppliedRotator1Local.Yaw}, roll={TargetingRuntime.AppliedRotator1Local.Roll})"
		);
	}
}
