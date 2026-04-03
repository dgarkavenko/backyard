event void FBSUBSModularComponentDelegate(UBSModularComponent ModularComponent);
event void FBSUBSModularViewBuiltDelegate(UBSModularComponent ModularComponent, UBSModularView ModularView);

struct FBSSlotRuntime
{	
	UPROPERTY()
	FBFModuleSlot SlotData;

	UPROPERTY()
	TOptional<int32> Content;

	UPROPERTY()
	int32 Index = 0;

	UPROPERTY()
	TOptional<int32> ParentIndex;
}

mixin UBSModuleDefinition GetDefinitionUnsafe(const FBSSlotRuntime& Self, UBSModularComponent ModularComponent)
{
	return ModularComponent.InstalledModules[Self.Content.Value];
}

mixin UBSModuleDefinition GetDefinitionSafe(const FBSSlotRuntime& Self, UBSModularComponent ModularComponent)
{	
	if (!Self.Content.IsSet() && Self.Content.Value < ModularComponent.InstalledModules.Num())
	{
		return ModularComponent.InstalledModules[Self.Content.Value];
	}
	return nullptr;
}

mixin bool IsRoot(const FBSSlotRuntime& Self)
{
	return Self.Index == 0;
}

mixin bool IsChildOf(const FBSSlotRuntime& Self, int32 ParentId)
{
	return Self.ParentIndex.IsSet() && Self.ParentIndex.Value == ParentId;
}

class UBSModularComponent : UActorComponent
{
	UPROPERTY()
	TArray<UBSModuleDefinition> InstalledModules;

	UPROPERTY()
	TArray<FBSSlotRuntime> Slots;

	UPROPERTY()
	FGameplayTagContainer Capabilities;

	UPROPERTY(Category = "Delegates")
	FBSUBSModularComponentDelegate OnCompositionChanged;

	UPROPERTY(Category = "Delegates")
	FBSUBSModularViewBuiltDelegate OnViewBuilt;

	default EnsureRootSlot();

	bool CanAddModule(UBSModuleDefinition NewModule) const
	{
		for (FBSSlotRuntime Slot : Slots)
		{
			if (CanAddModuleTo(NewModule, Slot.Index))
			{
				return true;
			}
		}

		return false;
	}

	bool CanAddModuleTo(UBSModuleDefinition NewModule, int32 Index) const
	{
		if (Index >= Slots.Num())
		{
			return false;
		}

		const FBSSlotRuntime& TargetSlot = Slots[Index];

		if (TargetSlot.IsRoot() && NewModule.IsRootModule() && !TargetSlot.Content.IsSet())
		{
			return true;
		}

		return !TargetSlot.Content.IsSet() && NewModule.Instalation.Matches(TargetSlot.SlotData.Tags);
	}

	bool AddModule(UBSModuleDefinition NewModule, int32 Index)
	{		
		InstalledModules.Add(NewModule);

		Slots[Index].Content.Set(InstalledModules.Num() - 1);

		for (FBFModuleSlot SlotData : NewModule.ProvidedSlots)
		{
			FBSSlotRuntime SlotRuntime;
			SlotRuntime.SlotData = SlotData;
			SlotRuntime.ParentIndex = Index;
			SlotRuntime.Index = Slots.Num();
			Slots.Add(SlotRuntime);
		}
		
		BuildCapabilities();
		OnCompositionChanged.Broadcast(this);

		return true;
	}

	void RemoveModule(int32 Index)
	{
		if (Index < 0 || Index >= Slots.Num())
		{
			return;
		}

		TArray<int32> RemoveList;
		GatherRecursive(Index, RemoveList);

		TArray<int32> SurvivedDefinitions;
		TArray<int32> OrdinalIndex;
		int32 InsertIndex = 0;

		// Shift slots to left
		for (int32 SlotIndex = 0; SlotIndex < Slots.Num(); SlotIndex++)
		{
			bool bSurvived = !RemoveList.Contains(SlotIndex);
			if (bSurvived)
			{				
				bool bMove = InsertIndex != SlotIndex;
				if (bMove)
				{
					MoveSlot(InsertIndex, SlotIndex);
				}

				if (Slots[InsertIndex].Content.IsSet())
				{
					SurvivedDefinitions.Add(Slots[InsertIndex].Content.Value);
					OrdinalIndex.Add(InsertIndex);
				}

				InsertIndex++;
			}
		}

		Slots.SetNum(InsertIndex);

		InsertIndex = 0;
		// Shift definitions to left
		for (int32 DefinitionIndex = 0; DefinitionIndex < InstalledModules.Num(); DefinitionIndex++)
		{
			bool bSurvived = SurvivedDefinitions.Contains(DefinitionIndex);
			if (bSurvived)
			{
				bool bMove = InsertIndex != DefinitionIndex;
				if (bMove)
				{
					InstalledModules[InsertIndex] = InstalledModules[DefinitionIndex];
					int32 OrdinalSlotIndex = OrdinalIndex[InsertIndex];
					Slots[OrdinalSlotIndex].Content = InsertIndex;
				}

				InsertIndex++;	
			}
		}

		InstalledModules.SetNum(InsertIndex);

		EnsureRootSlot();
		BuildCapabilities();

		OnCompositionChanged.Broadcast(this);

	}

	TOptional<int32> GetSlotByModule(UBSModuleDefinition Module)
	{
		return InstalledModules.FindIndex(Module);
	}

	TOptional<int32> GetSlotByModuleIndex(int32 ModuleIndex)
	{
		if (ModuleIndex >= 0 && ModuleIndex < InstalledModules.Num())
		{
			for (int32 SlotIndex = 0; SlotIndex < Slots.Num(); SlotIndex++)
			{
				if (Slots[SlotIndex].Content == ModuleIndex)
				{
					return TOptional<int>(SlotIndex);
				}
			}
		}

		return TOptional<int>();
	}

	private void EnsureRootSlot()
	{		
		if (Slots.Num() < 1)
		{
			Slots.Add(FBSSlotRuntime());
		}
	}

	void BuildCapabilities()
	{
		Capabilities = FGameplayTagContainer();
		for (auto Definition : InstalledModules)
		{
			Capabilities.AppendTags(Definition.Capabilities);
		}
	}

	private void MoveSlot(int32 NewIndex, int32 OldIndex)
	{
		Slots[NewIndex] = Slots[OldIndex];
		Slots[NewIndex].Index = NewIndex;		
		
		for (FBSSlotRuntime Slot : Slots)
		{
			if(Slot.IsChildOf(OldIndex))
			{
				Slot.ParentIndex.Set(NewIndex);
			}
		}
	}

	private void GatherRecursive(int32 Index, TArray<int32>& RemoveList)
	{
		for (FBSSlotRuntime Slot : Slots)
		{
			if (Slot.IsChildOf(Index))
			{
				GatherRecursive(Slot.Index, RemoveList);
			}
		}

		RemoveList.Add(Index);
	}	
	
	private FString GetOwnerName() const
	{
		return Owner != nullptr ? Owner.GetName().ToString() : "<null-owner>";
	}
}
