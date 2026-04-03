class UBSModuleTaxonomy : UBFNativeModuleTaxonomy
{
	TArray<UBSModuleDefinition> GetAllModules() const
	{
		TArray<UBSModuleDefinition> Result;
		TArray<FPrimaryAssetId> Keys;
		Modules.GetKeys(Keys);

		for (FPrimaryAssetId Key : Keys)
		{
			UBSModuleDefinition Module = Cast<UBSModuleDefinition>(Modules[Key].Get());
			if (Module != nullptr)
			{
				Result.Add(Module);
			}
		}

		return Result;
	}
}
