class UBSModuleDefinition : UBFModuleDefinition
{
	UPROPERTY(EditAnywhere, meta = (ForceInlineRow, TitleProperty = "{ElementId} @{ParentElementId} ({Socket})"))
	TArray<FBSModuleAssemblyElement> Elements;

	default Elements.Add(FBSModuleAssemblyElement());
	default Elements[0].ElementId = n"Base";

	UPROPERTY(EditAnywhere, meta = (ClampMin = "0", Units = "Wh"))
	int32 Consumption = 0;
}

mixin bool IsRootModule(UBSModuleDefinition Self)
{
	return Self.Instalation.IsEmpty();
}
