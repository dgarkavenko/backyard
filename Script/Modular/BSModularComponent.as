event void FBSModularCompositionChangedDelegate(UBSModularComponent ModularComponent);

class UBSModularComponent : UActorComponent
{
	TArray<FBFModuleSlot> Slots;
	TArray<int> SlotModuleIndices;
	TArray<int> SlotProviderModuleIndices;
	TArray<UBFModuleDefinition> InstalledModules;
	TArray<int> ModuleOccupiedSlotIndices;
	FGameplayTagContainer Capabilities;

	int RuntimeHandle = -1;
	int CompositionVersion = 0;

	UPROPERTY(Category = "Delegates")
	FBSModularCompositionChangedDelegate OnCompositionChanged;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		RegisterRuntime();
		UpdateRuntimeRecord();
	}

	UFUNCTION(BlueprintOverride)
	void EndPlay(EEndPlayReason Reason)
	{
		UBSModularEntitiesSystem Subsystem = UBSModularEntitiesSystem::Get();
		if (Subsystem != nullptr && RuntimeHandle >= 0)
		{
			Subsystem.Unregister(RuntimeHandle);
			RuntimeHandle = -1;
		}
	}

	bool CanAddModule(UBFModuleDefinition NewModule) const
	{
		if (NewModule == nullptr)
		{
			return false;
		}

		bool bIsChassis = Cast<UBSChassisDefinition>(NewModule) != nullptr;
		bool bHasChassis = HasInstalledChassis();
		if (bIsChassis)
		{
			return !bHasChassis;
		}

		if (NewModule.Instalation.IsEmpty())
		{
			return bHasChassis;
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

	bool AddModule(UBFModuleDefinition NewModule)
	{
		if (!CanAddModule(NewModule))
		{
			FString ModuleName = NewModule != nullptr ? NewModule.GetName().ToString() : "<null-module>";
			SentryDebug::LogAssembly(f"Modular: rejected install '{ModuleName}' owner='{GetOwnerName()}'");
			return false;
		}

		AppendModule(NewModule, -1);
		FString ModuleName = NewModule != nullptr ? NewModule.GetName().ToString() : "<null-module>";
		SentryDebug::LogAssembly(f"Modular: installed '{ModuleName}' owner='{GetOwnerName()}'");
		NotifyCompositionChanged();
		return true;
	}

	bool CanAddModuleToSlot(UBFModuleDefinition NewModule, int SlotIndex) const
	{
		if (NewModule == nullptr || SlotIndex < 0 || SlotIndex >= Slots.Num())
		{
			return false;
		}

		if (Slots[SlotIndex].bOccupied)
		{
			return false;
		}

		bool bIsChassis = Cast<UBSChassisDefinition>(NewModule) != nullptr;
		bool bHasChassis = HasInstalledChassis();
		if (bIsChassis)
		{
			return false;
		}

		if (NewModule.Instalation.IsEmpty())
		{
			return bHasChassis;
		}

		return NewModule.Instalation.Matches(Slots[SlotIndex].Tags);
	}

	bool AddModuleToSlot(UBFModuleDefinition NewModule, int SlotIndex)
	{
		if (!CanAddModuleToSlot(NewModule, SlotIndex))
		{
			FString ModuleName = NewModule != nullptr ? NewModule.GetName().ToString() : "<null-module>";
			SentryDebug::LogAssembly(f"Modular: rejected slot install '{ModuleName}' owner='{GetOwnerName()}' slot={SlotIndex}");
			return false;
		}

		AppendModule(NewModule, SlotIndex);
		FString ModuleName = NewModule != nullptr ? NewModule.GetName().ToString() : "<null-module>";
		SentryDebug::LogAssembly(f"Modular: installed '{ModuleName}' owner='{GetOwnerName()}' slot={SlotIndex}");
		NotifyCompositionChanged();
		return true;
	}

	void ClearModules()
	{
		ResetResolvedState();
		NotifyCompositionChanged();
	}

	void RebuildComposition()
	{
		TArray<UBFModuleDefinition> ModuleCopy = InstalledModules;
		SetModules(ModuleCopy);
	}

	void SetModules(const TArray<UBFModuleDefinition>& Modules)
	{
		ResetResolvedState();

		for (UBFModuleDefinition Module : Modules)
		{
			if (CanAddModule(Module))
			{
				AppendModule(Module, -1);
			}
		}

		NotifyCompositionChanged();
	}

	UBFModuleDefinition GetModuleForSlot(int SlotIndex) const
	{
		if (SlotIndex < 0 || SlotIndex >= SlotModuleIndices.Num())
		{
			return nullptr;
		}

		int ModuleIndex = SlotModuleIndices[SlotIndex];
		if (ModuleIndex < 0 || ModuleIndex >= InstalledModules.Num())
		{
			return nullptr;
		}

		return InstalledModules[ModuleIndex];
	}

	int GetInstalledModuleIndex(UBFModuleDefinition Module) const
	{
		for (int ModuleIndex = 0; ModuleIndex < InstalledModules.Num(); ModuleIndex++)
		{
			if (InstalledModules[ModuleIndex] == Module)
			{
				return ModuleIndex;
			}
		}

		return -1;
	}

	int GetOccupiedSlotIndexForModuleIndex(int ModuleIndex) const
	{
		if (ModuleIndex < 0 || ModuleIndex >= ModuleOccupiedSlotIndices.Num())
		{
			return -1;
		}

		return ModuleOccupiedSlotIndices[ModuleIndex];
	}

	int GetSlotProviderModuleIndex(int SlotIndex) const
	{
		if (SlotIndex < 0 || SlotIndex >= SlotProviderModuleIndices.Num())
		{
			return -1;
		}

		return SlotProviderModuleIndices[SlotIndex];
	}

	bool HasInstalledChassis() const
	{
		for (UBFModuleDefinition Module : InstalledModules)
		{
			if (Cast<UBSChassisDefinition>(Module) != nullptr)
			{
				return true;
			}
		}

		return false;
	}

	private void AppendModule(UBFModuleDefinition NewModule, int PreferredSlotIndex)
	{
		int ModuleIndex = InstalledModules.Num();
		InstalledModules.Add(NewModule);
		ModuleOccupiedSlotIndices.Add(-1);
		Capabilities.AppendTags(NewModule.Capabilities);

		if (!NewModule.Instalation.IsEmpty())
		{
			if (PreferredSlotIndex >= 0
				&& PreferredSlotIndex < Slots.Num()
				&& !Slots[PreferredSlotIndex].bOccupied
				&& NewModule.Instalation.Matches(Slots[PreferredSlotIndex].Tags))
			{
				Slots[PreferredSlotIndex].bOccupied = true;
				SlotModuleIndices[PreferredSlotIndex] = ModuleIndex;
				ModuleOccupiedSlotIndices[ModuleIndex] = PreferredSlotIndex;
			}
			else
			{
				for (int SlotIndex = 0; SlotIndex < Slots.Num(); SlotIndex++)
				{
					if (!Slots[SlotIndex].bOccupied && NewModule.Instalation.Matches(Slots[SlotIndex].Tags))
					{
						Slots[SlotIndex].bOccupied = true;
						SlotModuleIndices[SlotIndex] = ModuleIndex;
						ModuleOccupiedSlotIndices[ModuleIndex] = SlotIndex;
						break;
					}
				}
			}
		}
		else if (PreferredSlotIndex >= 0 && PreferredSlotIndex < Slots.Num() && !Slots[PreferredSlotIndex].bOccupied)
		{
			Slots[PreferredSlotIndex].bOccupied = true;
			SlotModuleIndices[PreferredSlotIndex] = ModuleIndex;
			ModuleOccupiedSlotIndices[ModuleIndex] = PreferredSlotIndex;
		}

		for (const FBFModuleSlot& ProvidedSlot : NewModule.ProvidedSlots)
		{
			Slots.Add(ProvidedSlot);
			SlotModuleIndices.Add(-1);
			SlotProviderModuleIndices.Add(ModuleIndex);
		}
	}

	private void ResetResolvedState()
	{
		Slots.Empty();
		SlotModuleIndices.Empty();
		SlotProviderModuleIndices.Empty();
		InstalledModules.Empty();
		ModuleOccupiedSlotIndices.Empty();
		Capabilities = FGameplayTagContainer();
	}

	private void RegisterRuntime()
	{
		if (RuntimeHandle >= 0)
		{
			return;
		}

		UBSModularEntitiesSystem Subsystem = UBSModularEntitiesSystem::Get();
		if (Subsystem != nullptr)
		{
			RuntimeHandle = Subsystem.Register(this);
		}
	}

	private void UpdateRuntimeRecord()
	{
		UBSModularEntitiesSystem Subsystem = UBSModularEntitiesSystem::Get();
		if (Subsystem == nullptr)
		{
			return;
		}

		if (RuntimeHandle < 0)
		{
			RuntimeHandle = Subsystem.Register(this);
		}
		else
		{
			Subsystem.UpdateRecord(RuntimeHandle, this);
		}
	}

	private void NotifyCompositionChanged()
	{
		CompositionVersion++;
		SentryDebug::LogAssembly(f"Modular: composition changed owner='{GetOwnerName()}' version={CompositionVersion} modules={InstalledModules.Num()} slots={Slots.Num()}");
		UpdateRuntimeRecord();
		OnCompositionChanged.Broadcast(this);
	}

	private FString GetOwnerName() const
	{
		return Owner != nullptr ? Owner.GetName().ToString() : "<null-owner>";
	}
}
