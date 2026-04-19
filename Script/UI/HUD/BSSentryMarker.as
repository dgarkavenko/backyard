class UBSSentryMarker : UFUScreenProjectedWidget
{
	UPROPERTY(BindWidget)
	UFUProgressBar Progress;

	ABSSentry Model;
	
	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float InDeltaTime)
	{
		UBSModularView ModularView = Model != nullptr ? Model.ModularView : nullptr;
		if (ModularView != nullptr && ModularView.RuntimePowerIndex >= 0)
		{
			UBSRuntimeSubsystem Runtime = UBSRuntimeSubsystem::Get();
			if (Runtime != nullptr)
			{
				const FBSPowerHotRow& Power = Runtime.GetPowerRuntime(ModularView.RuntimePowerIndex);
				float TotalCapacity = Power.Capacity + Power.ChildrenCapacity;
				float TotalReserve = Power.Reserve + Power.ChildrenReserve;
				Progress.SetValue(TotalCapacity > 0.0f ? TotalReserve / TotalCapacity : 0.0f);
			}
		}
	}
}
