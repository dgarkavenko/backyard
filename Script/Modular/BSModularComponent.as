event void FBSModularCompositionChangedDelegate(UBSModularComponent ModularComponent);

class UBSModularComponent : UActorComponent
{
	TArray<FBFModuleSlot> Slots;
	TArray<int> SlotModuleIndices;
	TArray<UBFModuleDefinition> InstalledModules;
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

	bool AddModule(UBFModuleDefinition NewModule)
	{
		if (!CanAddModule(NewModule))
		{
			return false;
		}

		AppendModule(NewModule);
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
				AppendModule(Module);
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

	private void AppendModule(UBFModuleDefinition NewModule)
	{
		int ModuleIndex = InstalledModules.Num();
		InstalledModules.Add(NewModule);
		Capabilities.AppendTags(NewModule.Capabilities);

		if (!NewModule.Instalation.IsEmpty())
		{
			for (int SlotIndex = 0; SlotIndex < Slots.Num(); SlotIndex++)
			{
				if (!Slots[SlotIndex].bOccupied && NewModule.Instalation.Matches(Slots[SlotIndex].Tags))
				{
					Slots[SlotIndex].bOccupied = true;
					SlotModuleIndices[SlotIndex] = ModuleIndex;
					break;
				}
			}
		}

		for (const FBFModuleSlot& ProvidedSlot : NewModule.ProvidedSlots)
		{
			Slots.Add(ProvidedSlot);
			SlotModuleIndices.Add(-1);
		}
	}

	private void ResetResolvedState()
	{
		Slots.Empty();
		SlotModuleIndices.Empty();
		InstalledModules.Empty();
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
		UpdateRuntimeRecord();
		OnCompositionChanged.Broadcast(this);
	}
}

class UBSModularEntitiesSystem : UScriptWorldSubsystem
{
	TArray<AActor> Owners;
	TArray<UBSModularComponent> Components;
	TArray<FGameplayTagContainer> CapabilitySets;
	TArray<int> CompositionVersions;
	TArray<int> FreeList;

	int Register(UBSModularComponent Component)
	{
		int Handle = -1;

		if (FreeList.Num() > 0)
		{
			Handle = FreeList.Last();
			FreeList.RemoveAt(FreeList.Num() - 1);
		}
		else
		{
			Handle = Components.Num();
			Owners.Add(nullptr);
			Components.Add(nullptr);
			CapabilitySets.Add(FGameplayTagContainer());
			CompositionVersions.Add(0);
		}

		UpdateRecord(Handle, Component);
		return Handle;
	}

	void UpdateRecord(int Handle, UBSModularComponent Component)
	{
		if (Handle < 0 || Handle >= Components.Num())
		{
			return;
		}

		Components[Handle] = Component;
		Owners[Handle] = Component != nullptr ? Cast<AActor>(Component.Owner) : nullptr;
		CapabilitySets[Handle] = Component != nullptr ? Component.Capabilities : FGameplayTagContainer();
		CompositionVersions[Handle] = Component != nullptr ? Component.CompositionVersion : 0;
	}

	void Unregister(int Handle)
	{
		if (Handle < 0 || Handle >= Components.Num())
		{
			return;
		}

		Owners[Handle] = nullptr;
		Components[Handle] = nullptr;
		CapabilitySets[Handle] = FGameplayTagContainer();
		CompositionVersions[Handle] = 0;
		FreeList.Add(Handle);
	}
}
