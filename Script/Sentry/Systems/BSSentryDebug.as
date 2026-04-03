namespace SentryDebugF
{
	const FConsoleVariable ShowSockets(f"BF.Sentry.ShowSockets", 0);
	const FConsoleVariable ShowAim(f"BF.Sentry.ShowAim", 0);
	const FConsoleVariable LogAim(f"BF.Sentry.LogAim", 0);
	const FConsoleVariable LogAssemblyCVar(f"BF.Sentry.LogAssembly", 0);
	const FConsoleVariable ValidateAssembly(f"BF.Sentry.ValidateAssembly", 0);

	void LogAssembled(ABSSentry Sentry, UBSSentryView Adapter, UBSModularView ModularView)
	{
		if (LogAssemblyCVar.Int == 0)
		{
			return;
		}

		FString BaseMeshName = Sentry.Base != nullptr && Sentry.Base.StaticMesh != nullptr ? Sentry.Base.StaticMesh.GetName().ToString() : "<none>";
		FString Rotator0Name = Adapter.RotatorComponents.Num() > 0 && Adapter.RotatorComponents[0] != nullptr ? Adapter.RotatorComponents[0].GetName().ToString() : "<none>";
		FString Rotator1Name = Adapter.RotatorComponents.Num() > 1 && Adapter.RotatorComponents[1] != nullptr ? Adapter.RotatorComponents[1].GetName().ToString() : "<none>";
		FString MuzzleName = Adapter.MuzzleComponent != nullptr ? Adapter.MuzzleComponent.GetName().ToString() : "<none>";
		int ActiveElementCount = ModularView != nullptr ? ModularView.ActiveModuleElements.Num() : 0;
		LogAssembly(f"Assembly | Rebuild Complete Sentry='{Sentry.GetName()}' BaseMesh='{BaseMeshName}' RotatorCount={Adapter.RotatorComponents.Num()} Rotator0='{Rotator0Name}' Rotator1='{Rotator1Name}' Muzzle='{MuzzleName}' ActiveElements={ActiveElementCount}");
	}
	
	void ValidateNoGarbageComponents(UBSSentryView Adapter, UBSModularView ModularView, ABSSentry Sentry)
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
		bool bHasRotator0 = Sentry.SentryView.RotatorComponents.Num() > 0 && Sentry.SentryView.RotatorComponents[0] != nullptr;
		bool bHasRotator1 = Sentry.SentryView.RotatorComponents.Num() > 1 && Sentry.SentryView.RotatorComponents[1] != nullptr;
		System::DrawDebugString(Sentry.ActorLocation + FVector(0, 0, 70), f"Rotators: {Sentry.SentryView.RotatorComponents.Num()} R0: {bHasRotator0} R1: {bHasRotator1} Muzzle: {Sentry.SentryView.MuzzleComponent != nullptr}", nullptr, FLinearColor::White);

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

	void DrawAim(ABSSentry Sentry, FVector TargetLocation)
	{
		if (Sentry == nullptr || Sentry.SentryView == nullptr)
		{
			return;
		}

		UBSSentryView Adapter = Sentry.SentryView;
		if (Adapter.MuzzleComponent == nullptr || !Adapter.MuzzleComponent.DoesSocketExist(Sentry::MuzzleSocketName))
		{
			return;
		}

		FTransform MuzzleSocketWorld = Adapter.MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
		FVector MuzzleLocation = MuzzleSocketWorld.Location;
		FVector ToTarget = TargetLocation - MuzzleLocation;
		float DistanceToTarget = ToTarget.Size();
		if (DistanceToTarget <= 0.0f)
		{
			return;
		}

		FVector TargetDirection = ToTarget / DistanceToTarget;
		FVector MuzzleForward = MuzzleSocketWorld.Rotation.ForwardVector.GetSafeNormal();
		float AimDot = MuzzleForward.DotProduct(TargetDirection);

		System::DrawDebugLine(MuzzleLocation, TargetLocation, FLinearColor::Yellow, 0, 2);
		System::DrawDebugLine(MuzzleLocation, MuzzleLocation + MuzzleForward * DistanceToTarget, FLinearColor::Blue, 0, 2);
		System::DrawDebugPoint(TargetLocation, 12.0f, FLinearColor::Yellow, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
		System::DrawDebugString(MuzzleLocation + FVector(0, 0, 18), f"dot={AimDot}", nullptr, FLinearColor::White);
	}

	void LogAimState(ABSSentry Sentry, UBSSentryView Adapter, FVector TargetLocation, const FRotator& DesiredRotator0Local, const FRotator& AppliedRotator0Local, const FRotator& DesiredRotator1Local, const FRotator& AppliedRotator1Local)
	{
		if (Sentry == nullptr || Adapter == nullptr)
		{
			return;
		}

		if (LogAim.Int <= 0)
		{
			return;
		}

		if (Adapter.MuzzleComponent == nullptr || !Adapter.MuzzleComponent.DoesSocketExist(Sentry::MuzzleSocketName))
		{
			return;
		}

		FTransform MuzzleSocketWorld = Adapter.MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
		FVector MuzzleLocation = MuzzleSocketWorld.Location;
		FVector ToTarget = TargetLocation - MuzzleLocation;
		float DistanceToTarget = ToTarget.Size();
		if (DistanceToTarget <= 0.0f)
		{
			return;
		}

		FVector TargetDirection = ToTarget / DistanceToTarget;
		FVector MuzzleForward = MuzzleSocketWorld.Rotation.ForwardVector.GetSafeNormal();
		float AimDot = MuzzleForward.DotProduct(TargetDirection);
		FRotator MuzzleError = (TargetDirection.Rotation() - MuzzleForward.Rotation()).GetNormalized();
		FRotator MuzzleLocalRotation = Adapter.MuzzleLocalRotation.Rotator();

		Log(
			f"SentryAim sentry='{Sentry.GetName()}' " +
			f"fastPath={Adapter.bHasYawPitchFastPath} " +
			f"dot={AimDot} dist={DistanceToTarget} " +
			f"muzzleError=(pitch={MuzzleError.Pitch}, yaw={MuzzleError.Yaw}, roll={MuzzleError.Roll}) " +
			f"muzzleOffset=(x={Adapter.MuzzleOffset.X}, y={Adapter.MuzzleOffset.Y}, z={Adapter.MuzzleOffset.Z}) " +
			f"cachedYaw=(forward={Adapter.CachedYawForwardOffset}, lateral={Adapter.CachedYawLateralOffset}) " +
			f"cachedPitch=(forward={Adapter.CachedPitchForwardOffset}, vertical={Adapter.CachedPitchVerticalOffset}) " +
			f"muzzleLocal=(pitch={MuzzleLocalRotation.Pitch}, yaw={MuzzleLocalRotation.Yaw}, roll={MuzzleLocalRotation.Roll}) " +
			f"desiredR0=(pitch={DesiredRotator0Local.Pitch}, yaw={DesiredRotator0Local.Yaw}, roll={DesiredRotator0Local.Roll}) " +
			f"appliedR0=(pitch={AppliedRotator0Local.Pitch}, yaw={AppliedRotator0Local.Yaw}, roll={AppliedRotator0Local.Roll}) " +
			f"desiredR1=(pitch={DesiredRotator1Local.Pitch}, yaw={DesiredRotator1Local.Yaw}, roll={DesiredRotator1Local.Roll}) " +
			f"appliedR1=(pitch={AppliedRotator1Local.Pitch}, yaw={AppliedRotator1Local.Yaw}, roll={AppliedRotator1Local.Roll})"
		);
	}
}
