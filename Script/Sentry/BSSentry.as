class ABSSentry : AActor
{
	UPROPERTY(DefaultComponent)
	UBSInteractionRegistry InteractionRegistry;

	UPROPERTY(DefaultComponent)
	UBSTerminalInteraction TerminalInteraction;

	UPROPERTY(DefaultComponent)
	UBSDragInteraction DragInteraction;

	default DragInteraction.Action.HoldDuration = 1.0f;
	default DragInteraction.ActionParams.StabilizationMode = EBSDragStabilize::KeepStraight;
	default DragInteraction.ActionParams.ParentMode = EBSDragParent::Yaw;

	UPROPERTY(DefaultComponent, RootComponent)
	UStaticMeshComponent Base;

	UPROPERTY(DefaultComponent, Attach = Base, AttachSocket = s_child_01)
	UStaticMeshComponent Rotator01;

	UPROPERTY(DefaultComponent, Attach = Rotator01, AttachSocket = s_child_01)
	UStaticMeshComponent Rotator02;

	TArray<UStaticMeshComponent> LoadoutElements;
	TArray<UStaticMeshComponent> ChassisElements;
	int ElementCounter = 0;

	UPROPERTY(EditAnywhere, Category = "Sentry")
	UMaterialInterface Material;

	// Cached geometry — written by SentryAssembly::CacheGeometry
	FVector Rotator01PivotOffset;
	FVector Rotator02PivotOffset;
	UStaticMeshComponent MuzzleComponent;
	FVector MuzzleOffset;
	FRotator MuzzleForwardRotation;

	// Module system
	TArray<FBFModuleSlot> Slots;
	TArray<int> SlotModuleIndices;
	TArray<UBFModuleDefinition> InstalledModules;
	FGameplayTagContainer Capabilities;
	TMap<FName, USceneComponent> SocketOwnerCache;

	// Subsystem registration
	UBSChassisDefinition ChassisDefinition;
	int SubsystemSlot = -1;

	bool CanAddModule(UBFModuleDefinition NewModule) const
	{
		if (NewModule == nullptr)
		{
			return false;
		}

		if (NewModule.Instalation.IsEmpty())
		{
			return true;
		}

		for (const FBFModuleSlot& Slot : Slots)
		{
			if (!Slot.bOccupied && NewModule.Instalation.Matches(Slot.Tags))
			{
				return true;
			}
		}

		return false;
	}

	void AddModule(UBFModuleDefinition NewModule)
	{
		if (NewModule == nullptr)
		{
			return;
		}

		int ModuleIndex = InstalledModules.Num();
		InstalledModules.Add(NewModule);
		Capabilities.AppendTags(NewModule.Capabilities);

		// Occupy matching slot
		FName OccupiedSocket = NAME_None;
		if (!NewModule.Instalation.IsEmpty())
		{
			for (int i = 0; i < Slots.Num(); i++)
			{
				if (!Slots[i].bOccupied && NewModule.Instalation.Matches(Slots[i].Tags))
				{
					Slots[i].bOccupied = true;
					SlotModuleIndices[i] = ModuleIndex;
					OccupiedSocket = Slots[i].Socket;
					break;
				}
			}
		}

		// Add slots this module provides
		for (const FBFModuleSlot& ProvidedSlot : NewModule.ProvidedSlots)
		{
			Slots.Add(ProvidedSlot);
			SlotModuleIndices.Add(-1);
		}

		// Dispatch build
		DispatchModuleBuild(NewModule, OccupiedSocket);

		// Validate provided sockets exist on mesh hierarchy
		for (const FBFModuleSlot& ProvidedSlot : NewModule.ProvidedSlots)
		{
			if (ProvidedSlot.Socket != NAME_None)
			{
				USceneComponent SocketOwner = SentryAssembly::FindSocketOwner(this, ProvidedSlot.Socket);
				if (SocketOwner == nullptr)
				{
					Print(f"Warning: Socket '{ProvidedSlot.Socket}' from {NewModule.GetName()} not found on any mesh (virtual)");
				}
			}
		}
	}

	void ClearModules()
	{
		SentryAssembly::ClearMeshes(this);
		Slots.Empty();
		SlotModuleIndices.Empty();
		InstalledModules.Empty();
		Capabilities = FGameplayTagContainer();
		SocketOwnerCache.Empty();
		ChassisDefinition = nullptr;

		UpdateSubsystemRegistration();
	}

	void RebuildFromModules()
	{
		TArray<UBFModuleDefinition> ModuleCopy = InstalledModules;
		Slots.Empty();
		SlotModuleIndices.Empty();
		InstalledModules.Empty();
		Capabilities = FGameplayTagContainer();
		SocketOwnerCache.Empty();
		ChassisDefinition = nullptr;

		SentryAssembly::ClearMeshes(this);

		for (UBFModuleDefinition Module : ModuleCopy)
		{
			AddModule(Module);
		}
	}

	private void DispatchModuleBuild(UBFModuleDefinition Definition, FName Socket)
	{
		auto ChassisDef = Cast<UBSChassisDefinition>(Definition);
		if (ChassisDef != nullptr)
		{
			ChassisDefinition = ChassisDef;
			SentryAssembly::BuildChassis(ChassisDef, this, Material);
			SentryAssembly::CacheGeometry(this);
			UpdateSubsystemRegistration();
			return;
		}

		auto TurretDef = Cast<UBSTurretDefinition>(Definition);
		if (TurretDef != nullptr)
		{
			SentryAssembly::BuildLoadout(TurretDef.Elements, this, Material);
			return;
		}

		auto PSUDef = Cast<UBSPowerSupplyUnitDefinition>(Definition);
		if (PSUDef != nullptr && SubsystemSlot >= 0)
		{
			UBSSentriesSystem Subsystem = UBSSentriesSystem::Get();
			if (Subsystem != nullptr)
			{
				Subsystem.SetPSU(SubsystemSlot, PSUDef);
			}
		}

		auto BatteryDef = Cast<UBSBatteryDefinition>(Definition);
		if (BatteryDef != nullptr && SubsystemSlot >= 0)
		{
			UBSSentriesSystem Subsystem = UBSSentriesSystem::Get();
			if (Subsystem != nullptr)
			{
				Subsystem.SetBattery(SubsystemSlot, BatteryDef);
			}
		}

		// Generic fallback: attach mesh at socket
		auto GenericDef = Cast<UBSGenericModule>(Definition);
		if (GenericDef != nullptr && GenericDef.BaseMesh != nullptr)
		{
			SentryAssembly::AttachModuleMesh(GenericDef.BaseMesh, Socket, this, Material);
			return;
		}
	}

	private void UpdateSubsystemRegistration()
	{
		UBSSentriesSystem Subsystem = UBSSentriesSystem::Get();
		if (Subsystem == nullptr)
		{
			return;
		}

		if (SubsystemSlot >= 0)
		{
			Subsystem.Unregister(SubsystemSlot);
			SubsystemSlot = -1;
		}

		if (ChassisDefinition != nullptr)
		{
			SubsystemSlot = Subsystem.Register(this, ChassisDefinition);
		}
	}

	UFUNCTION(BlueprintOverride)
	void ConstructionScript()
	{
	}

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		Base.SetGenerateOverlapEvents(true);
	}

	UFUNCTION(BlueprintOverride)
	void EndPlay(EEndPlayReason Reason)
	{
		if (SubsystemSlot >= 0)
		{
			UBSSentriesSystem Subsystem = UBSSentriesSystem::Get();
			if (Subsystem != nullptr)
			{
				Subsystem.Unregister(SubsystemSlot);
			}
			SubsystemSlot = -1;
		}
	}

	void DisableTerminalInteraction()
	{
		InteractionRegistry.UnregisterActionByTag(GameplayTags::Backyard_Interaction_Terminal);
	}

	void EnableTerminalInteraction()
	{
		InteractionRegistry.RegisterAction(TerminalInteraction.TerminalInteraction);
	}
}
