class UBSRuntimeSubsystem : UScriptWorldSubsystem
{
	FBSRuntimeStore Store;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		Systems::Power::AccumulateDemand(Store);
		Systems::Power::Tick(Store, DeltaSeconds);

		Systems::SentryVision::Tick(Store, DeltaSeconds);
		Systems::Articulation::Tick(Store, DeltaSeconds);
		Systems::SentryFiring::Tick(Store, DeltaSeconds);

		Systems::Indication::Tick(Store, DeltaSeconds);

		Systems::Debug::Tick(Store);
	}

	TOptional<int> SyncActor(UBSModularComponent ModularComponent, UBSModularView View)
	{
		AActor Actor = ModularComponent.Owner;
		if (Actor == nullptr)
		{
			return TOptional<int>();
		}

		int BaseIndex = Store.FindBaseIndex(Actor);
		if (BaseIndex < 0)
		{
			BaseIndex = Store.CreateBaseRow(Actor, View);
		}

		ClearBaseFeatures(BaseIndex);

		FBSBaseRuntimeRow& BaseRow = Store.BaseRows[BaseIndex];
		BaseRow.Actor = Actor;
		BaseRow.ModularView = View;
		BaseRow.Capabilities = FGameplayTagContainer();
		ModularComponent.GetAllCapabilities(BaseRow.Capabilities);

		ModularAssembly::AssembleView(View, Actor, ModularComponent);

		FeaturesAssembly::BuildPowerFeature(Store, BaseIndex, ModularComponent);

		if (BaseRow.Capabilities.HasTag(GameplayTags::Backyard_Capability_Detection))
		{
			FeaturesAssembly::BuildDetectionFeature(Store, BaseIndex, Actor, ModularComponent, View);
			FeaturesAssembly::BuildIndicationFeature(Store, BaseIndex, Actor, View);
		}
		if (BaseRow.Capabilities.HasTag(GameplayTags::Backyard_Capability_Aim))
		{
			FeaturesAssembly::BuildArticulationFeature(Store, BaseIndex, Actor, ModularComponent, View);
		}
		if (BaseRow.Capabilities.HasTag(GameplayTags::Backyard_Capability_Fire))
		{
			FeaturesAssembly::BuildFireFeature(Store, BaseIndex, ModularComponent);
		}

		Store.RebuildActorLookup();
		Store.RebuildDerivedLinks();
		PushCachedFeatureIndices();
		return TOptional<int>(BaseIndex);
	}

	/**
	 * Reads: ActorToBaseIndex, BaseRows
	 * Writes: BaseRows, PowerHot, PowerChildren, DetectionHot, DetectionCold, ArticulationHot, ArticulationCold, FireHot, FireCold, IndicationHot, IndicationCold, ActorToBaseIndex
	 */
	void RemoveActor(AActor Actor)
	{
		int BaseIndex = Store.FindBaseIndex(Actor);
		if (BaseIndex < 0)
		{
			return;
		}

		UBSModularView ModularView = Store.BaseRows[BaseIndex].ModularView;
		if (ModularView != nullptr)
		{
			ModularView.ClearRuntimeFeatureIndices();
		}

		ClearBaseFeatures(BaseIndex);
		Store.RemoveBaseRowSwap(BaseIndex);
		Store.RebuildActorLookup();
		Store.RebuildDerivedLinks();
		PushCachedFeatureIndices();
	}

	/**
	 * Reads: BaseRows
	 * Writes: BaseRows, PowerHot, PowerChildren, DetectionHot, DetectionCold, ArticulationHot, ArticulationCold, FireHot, FireCold, IndicationHot, IndicationCold
	 */
	private void ClearBaseFeatures(int BaseIndex)
	{
		if (BaseIndex < 0 || BaseIndex >= Store.BaseRows.Num())
		{
			return;
		}

		FBSBaseRuntimeRow& BaseRow = Store.BaseRows[BaseIndex];
		if (BaseRow.IndicationIndex >= 0)
		{
			USpotLightComponent IndicatorComponent = Store.IndicationCold[BaseRow.IndicationIndex].IndicatorComponent;
			if (IndicatorComponent != nullptr)
			{
				IndicatorComponent.SetIntensity(0.0f);
			}
			Store.RemoveIndicationRowSwap(BaseRow.IndicationIndex);
			BaseRow.IndicationIndex = -1;
		}
		if (BaseRow.FireIndex >= 0)
		{
			Store.RemoveFireRowSwap(BaseRow.FireIndex);
			BaseRow.FireIndex = -1;
		}
		if (BaseRow.ArticulationIndex >= 0)
		{
			Store.RemoveArticulationRowSwap(BaseRow.ArticulationIndex);
			BaseRow.ArticulationIndex = -1;
		}
		if (BaseRow.DetectionIndex >= 0)
		{
			Store.RemoveDetectionRowSwap(BaseRow.DetectionIndex);
			BaseRow.DetectionIndex = -1;
		}
		if (BaseRow.PowerIndex >= 0)
		{
			Store.RemovePowerRowSwap(BaseRow.PowerIndex);
			BaseRow.PowerIndex = -1;
		}
	}

	/**
	 * Reads: BaseRows
	 * Writes: ModularView runtime index cache only
	 */
	private void PushCachedFeatureIndices()
	{
		for (int BaseIndex = 0; BaseIndex < Store.BaseRows.Num(); BaseIndex++)
		{
			FBSBaseRuntimeRow& BaseRow = Store.BaseRows[BaseIndex];
			if (BaseRow.ModularView != nullptr)
			{
				BaseRow.ModularView.SetRuntimeFeatureIndices(BaseRow, BaseIndex);
			}
		}
	}

	int GetBaseIndex(AActor Actor) const
	{
		return Store.FindBaseIndex(Actor);
	}

	int GetRowCount() const
	{
		return Store.Num();
	}

	//TODO: remove getters

	const FBSBaseRuntimeRow& GetBaseRow(int BaseIndex) const
	{
		return Store.BaseRows[BaseIndex];
	}

	const FBSDetectionHotRow& GetDetectionRuntime(int DetectionIndex) const
	{
		return Store.DetectionHot[DetectionIndex];
	}

	const FBSArticulationHotRow& GetArticulationRuntime(int ArticulationIndex) const
	{
		return Store.ArticulationHot[ArticulationIndex];
	}

	const FBSFireHotRow& GetFireRuntime(int FireIndex) const
	{
		return Store.FireHot[FireIndex];
	}

	const FBSPowerHotRow& GetPowerRuntime(int PowerIndex) const
	{
		return Store.PowerHot[PowerIndex];
	}

	const FBSPowerChildrenRow& GetPowerChildren(int PowerIndex) const
	{
		return Store.PowerChildren[PowerIndex];
	}

	const FBSDetectionColdRow& GetDetectionCold(int DetectionIndex) const
	{
		return Store.DetectionCold[DetectionIndex];
	}

	const FBSArticulationColdRow& GetArticulationCold(int ArticulationIndex) const
	{
		return Store.ArticulationCold[ArticulationIndex];
	}

}
