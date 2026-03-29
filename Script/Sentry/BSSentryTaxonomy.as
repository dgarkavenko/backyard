class UBSModuleTaxonomy : UBFNativeModuleTaxonomy
{
	TArray<UBFModuleDefinition> GetAllModules() const
	{
		TArray<UBFModuleDefinition> Result;
		TArray<FPrimaryAssetId> Keys;
		Modules.GetKeys(Keys);

		for (FPrimaryAssetId Key : Keys)
		{
			UBFModuleDefinition Module = Cast<UBFModuleDefinition>(Modules[Key]);
			if (Module != nullptr)
			{
				Result.Add(Module);
			}
		}

		return Result;
	}
}
