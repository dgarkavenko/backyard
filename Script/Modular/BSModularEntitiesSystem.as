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
