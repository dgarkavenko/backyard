class UBSModularPreset : UActorComponent
{
	UPROPERTY()
	UBSModuleDefinition Chassis;

	UPROPERTY()
	TArray<UBSModuleDefinition> Modules;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		System::SetTimerForNextTick(this, "Assemble");
	}

	UFUNCTION()
	private void Assemble()
	{
		auto Modular = UBSModularComponent::GetOrCreate(Owner);
		Modular.AddModule(Chassis, 0);
		
		for (auto Module : Modules)
		{
			bool bAdded = false;

			for (int SlotIndex = 0; SlotIndex < Modular.Slots.Num(); SlotIndex++)
			{
				if (Modular.CanAddModuleTo(Module, SlotIndex))
				{			
					bAdded = true;		
					Modular.AddModule(Module, SlotIndex);
					break;
				}
			}

			if(!bAdded)
			{
				Error(f"Could not add module {Module}");
			}				
		}
	}
}