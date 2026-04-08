class UBSSentryMarker : UFUScreenProjectedWidget
{
	UPROPERTY(BindWidget)
	UFUProgressBar Progress;

	ABSSentry Model;
	
	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float InDeltaTime)
	{
		UBSRuntimeSubsystem Runtime = UBSRuntimeSubsystem::Get();
		if (Runtime != nullptr)
		{
			auto Index = Runtime.GetRowIndex(Model);
			if (Index.IsSet())
			{
				FBSPowerRuntime Power = Runtime.Store.PowerRuntime[Index.Value];
				Progress.SetValue((Power.ChildrenReserve + Power.Reserve) / (Power.Capacity + Power.ChildrenCapacity));
			}
		}
	}
}