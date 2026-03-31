class UBSModularEntitiesSystem : UScriptWorldSubsystem
{
	TArray<AActor> Owners;
	TArray<UBSModularComponent> Components;
	TArray<FGameplayTagContainer> CapabilitySets;
	TArray<int> FreeList;

	TOptional<int> Register(UBSModularComponent Component)
	{
		TOptional<int> Handle;

		if (FreeList.Num() > 0)
		{
			Handle.Set(FreeList.Last());
			FreeList.RemoveAt(FreeList.Num() - 1);
		}
		else
		{
			Handle.Set(Components.Num());
			Owners.Add(nullptr);
			Components.Add(nullptr);
			CapabilitySets.Add(FGameplayTagContainer());
		}

		UpdateRecord(Handle.Value, Component);
		Component.OnComponentRebuilt.AddUFunction(this, n"ModularComponentRebuilt");

		return Handle;
	}

	UFUNCTION()
	private void ModularComponentRebuilt(UBSModularComponent ModularComponent)
	{
		if (ModularComponent.Owner.IsA(ABSSentry))
		{
			UBSSentryWorldSubsystem::Get().SyncFromModularRuntime(ModularComponent.RuntimeHandle.Value, ModularComponent);
		}
	}

	void UpdateRecord(int Handle, UBSModularComponent Component)
	{
		check(Handle < Components.Num());

		Components[Handle] = Component;
		Owners[Handle] = Component != nullptr ? Cast<AActor>(Component.Owner) : nullptr;
		CapabilitySets[Handle] = Component != nullptr ? Component.Capabilities : FGameplayTagContainer();
	}

	void Unregister(int Handle)
	{
		check(Handle < Components.Num());
		Components[Handle].OnComponentRebuilt.UnbindObject(this);

		Owners[Handle] = nullptr;
		Components[Handle] = nullptr;
		CapabilitySets[Handle] = FGameplayTagContainer();
		FreeList.Add(Handle);
	}
}
