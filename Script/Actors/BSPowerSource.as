class ABSPowerSource : AActor
{
	UPROPERTY(DefaultComponent, RootComponent)
	UStaticMeshComponent Mesh;

	UPROPERTY(DefaultComponent)
	UBSModularComponent ModularComponent;

	UPROPERTY(DefaultComponent)
	UBSModularView ModularView;

	UPROPERTY(DefaultComponent)
	UBSModularPreset Preset;

}
