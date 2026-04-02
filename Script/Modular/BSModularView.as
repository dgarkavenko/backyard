class UBSModularView : UActorComponent
{
	TArray<UStaticMeshComponent> ModuleElementPool;
	TArray<int> ModuleElementGenerations;
	TArray<UStaticMeshComponent> ActiveModuleElements;
	int RebuildGeneration = 0;
}