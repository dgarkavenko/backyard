class UBSModularPreset : UActorComponent
{
	UPROPERTY()
	UBSModuleDefinition Chassis;

	UPROPERTY()
	TArray<UBSModuleDefinition> Modules;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		auto Modular = UBSModularComponent::GetOrCreate(Owner);
		Modular.AddModule(Chassis, 0);
		
		for (auto Module : Modules)
		{
			for (int SlotIndex = 0; SlotIndex < Modular.Slots.Num(); SlotIndex++)
			{
				if (Modular.CanAddModuleTo(Module, SlotIndex))
				{
					Modular.AddModule(Module, SlotIndex);
					break;
				}
			}
		}
	}
}