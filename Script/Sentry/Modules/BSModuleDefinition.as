class UBSModuleDefinition : UBFModuleDefinition
{
	UPROPERTY(EditAnywhere, meta = (ForceInlineRow, TitleProperty = "{ElementId} @{ParentElementId} ({Socket})"))
	TArray<FBSModuleAssemblyElement> Elements;

	default Elements.Add(FBSModuleAssemblyElement());
	default Elements[0].ElementId = n"Base";
}
