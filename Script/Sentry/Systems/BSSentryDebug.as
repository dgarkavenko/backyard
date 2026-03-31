namespace SentryDebugF
{
	const FConsoleVariable ShowSockets(f"BF.Sentry.ShowSockets", 0);
	const FConsoleVariable LogAssemblyCVar(f"BF.Sentry.LogAssembly", 0);
	const FConsoleVariable ValidateAssembly(f"BF.Sentry.ValidateAssembly", 0);

	void LogAssembled(ABSSentry Sentry, UBSSentryVisualAdapter Adapter)
	{
		if (LogAssemblyCVar.Int == 0)
		{
			return;
		}

		FString BaseMeshName = Sentry.Base != nullptr && Sentry.Base.StaticMesh != nullptr ? Sentry.Base.StaticMesh.GetName().ToString() : "<none>";
		FString Rotator0Name = Adapter.RotatorComponents.Num() > 0 && Adapter.RotatorComponents[0] != nullptr ? Adapter.RotatorComponents[0].GetName().ToString() : "<none>";
		FString Rotator1Name = Adapter.RotatorComponents.Num() > 1 && Adapter.RotatorComponents[1] != nullptr ? Adapter.RotatorComponents[1].GetName().ToString() : "<none>";
		FString MuzzleName = Adapter.MuzzleComponent != nullptr ? Adapter.MuzzleComponent.GetName().ToString() : "<none>";
		LogAssembly(f"Assembly | Rebuild Complete Sentry='{Sentry.GetName()}' BaseMesh='{BaseMeshName}' RotatorCount={Adapter.RotatorComponents.Num()} Rotator0='{Rotator0Name}' Rotator1='{Rotator1Name}' Muzzle='{MuzzleName}' ActiveElements={Adapter.ActiveModuleElements.Num()}");
	}
	
	void ValidateNoGarbageComponents(UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		ValidatePoolState(Adapter.ModuleElementPool, Adapter.ActiveModuleElements);

		TArray<USceneComponent> AttachedComponents;
		Sentry.Base.GetChildrenComponents(true, AttachedComponents);

		for (USceneComponent Child : AttachedComponents)
		{
			UStaticMeshComponent MeshComponent = Cast<UStaticMeshComponent>(Child);
			if (MeshComponent == nullptr)
			{
				continue;
			}

			if (!IsManagedDynamicComponent(Adapter, MeshComponent))
			{
				FString Name = MeshComponent.GetName().ToString();
				if (Name.Contains("ModulePool_"))
				{
					Warning(f"Sentry rebuild garbage assert: unmanaged pooled component '{Name}' attached to {Sentry.GetName()}");
				}
			}
		}
	}	

	bool IsManagedDynamicComponent(UBSSentryVisualAdapter Adapter, UStaticMeshComponent Component)
	{
		return Adapter.ModuleElementPool.Contains(Component);
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
		if (Sentry == nullptr || Sentry.ModularComponent == nullptr || Sentry.VisualAdapter == nullptr)
		{
			return;
		}

		int SlotCount = Sentry.ModularComponent.Slots.Num();
		FString BaseMeshName = Sentry.Base != nullptr && Sentry.Base.StaticMesh != nullptr ? Sentry.Base.StaticMesh.GetName().ToString() : "None";
		FString Header = f"Slots: {SlotCount} Modules: {Sentry.ModularComponent.InstalledModules.Num()} Base: {BaseMeshName}";
		System::DrawDebugString(Sentry.ActorLocation + FVector(0, 0, 50), Header, nullptr, FLinearColor::White);
		bool bHasRotator0 = Sentry.VisualAdapter.RotatorComponents.Num() > 0 && Sentry.VisualAdapter.RotatorComponents[0] != nullptr;
		bool bHasRotator1 = Sentry.VisualAdapter.RotatorComponents.Num() > 1 && Sentry.VisualAdapter.RotatorComponents[1] != nullptr;
		System::DrawDebugString(Sentry.ActorLocation + FVector(0, 0, 70), f"Rotators: {Sentry.VisualAdapter.RotatorComponents.Num()} R0: {bHasRotator0} R1: {bHasRotator1} Muzzle: {Sentry.VisualAdapter.MuzzleComponent != nullptr}", nullptr, FLinearColor::White);

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
