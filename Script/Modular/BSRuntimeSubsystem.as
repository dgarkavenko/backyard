class UBSRuntimeSubsystem : UScriptWorldSubsystem
{
	FBSRuntimeStore Store;


	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		Power::Tick(Store, DeltaSeconds);
		SentryVision::Tick(Store, DeltaSeconds);

		CoordinateDetectionToAim();
		TickAim(DeltaSeconds);
		TickFire(DeltaSeconds);
		TickLight(DeltaSeconds);
		SentryDebugF::Tick(Store);
	}


	/**
	 * Reads: DetectionHot, AimHot
	 * Writes: AimHot target/probe intent
	 */
	private void CoordinateDetectionToAim()
	{
		for (int DetectionIndex = 0; DetectionIndex < Store.DetectionHot.Num(); DetectionIndex++)
		{
			const FBSDetectionHotRow& DetectionHot = Store.DetectionHot[DetectionIndex];
			if (DetectionHot.Links.AimIndex < 0)
			{
				continue;
			}

			FBSAimHotRow& AimHot = Store.AimHot[DetectionHot.Links.AimIndex];
			bool bTrackAimState = DetectionHot.VisionState == EBSSentryVisionState::Tracking
				|| DetectionHot.VisionState == EBSSentryVisionState::LostHold;
			bool bUseProbeState = DetectionHot.VisionState == EBSSentryVisionState::Probing
				|| DetectionHot.VisionState == EBSSentryVisionState::Acquiring;

			AimHot.bHasAimTarget = bTrackAimState;
			AimHot.bUseProbe = bUseProbeState;
			AimHot.AimTargetLocation = bTrackAimState ? DetectionHot.CurrentTargetLocation : FVector::ZeroVector;
			AimHot.ProbeYawTarget = bUseProbeState ? DetectionHot.ProbeTargetYaw : 0.0f;
		}
	}

	/**
	 * Reads: BaseRows, AimHot, AimCold
	 * Writes: AimHot
	 */
	private void TickAim(float DeltaSeconds)
	{
		for (int AimIndex = 0; AimIndex < Store.AimHot.Num(); AimIndex++)
		{
			FBSAimHotRow& AimHot = Store.AimHot[AimIndex];
			const FBSBaseRuntimeRow& BaseRow = Store.BaseRows[AimHot.OwnerBaseIndex];
			SentryAim::Tick(BaseRow, Store.AimCold[AimIndex], AimHot, DeltaSeconds);
		}
	}

	/**
	 * Reads: BaseRows, FireHot, AimHot, AimCold, FireCold
	 * Writes: FireHot cooldown, AimHot through shot side effects
	 */
	private void TickFire(float DeltaSeconds)
	{
		for (int FireIndex = 0; FireIndex < Store.FireHot.Num(); FireIndex++)
		{
			FBSFireHotRow& FireHot = Store.FireHot[FireIndex];
			if (FireHot.Links.AimIndex < 0)
			{
				continue;
			}

			const FBSBaseRuntimeRow& BaseRow = Store.BaseRows[FireHot.OwnerBaseIndex];
			const FBSAimHotRow& AimHot = Store.AimHot[FireHot.Links.AimIndex];
			if (!AimHot.bHasAimTarget)
			{
				continue;
			}

			FireHot.ShotCooldownRemaining -= DeltaSeconds;
			if (CanFire(FireHot, AimHot))
			{
				SentryFiring::Shot(BaseRow, Store.AimCold[FireHot.Links.AimIndex], Store.FireCold[FireIndex], Store.AimHot[FireHot.Links.AimIndex]);
				FireHot.ShotCooldownRemaining = FireHot.RPM > 0 ? 60.0f / float(FireHot.RPM) : 0.0f;
			}
		}
	}

	/**
	 * Reads: LightHot, LightCold, DetectionHot, PowerHot
	 * Writes: LightHot desired state
	 */
	private void TickLight(float DeltaSeconds)
	{
		for (int LightIndex = 0; LightIndex < Store.LightHot.Num(); LightIndex++)
		{
			FBSLightHotRow& LightHot = Store.LightHot[LightIndex];
			FBSLightColdRow& LightCold = Store.LightCold[LightIndex];
			USpotLightComponent LightComponent = LightCold.LightComponent;
			if (LightComponent == nullptr)
			{
				continue;
			}

			float ChainInsuficency = 0.0f;
			bool bSupplied = true;
			if (LightHot.Links.PowerIndex >= 0)
			{
				ChainInsuficency = 0;
				bSupplied = Store.PowerHot[LightHot.Links.PowerIndex].bSupplied;
			}

			if (LightHot.Links.DetectionIndex >= 0)
			{
				const FBSDetectionHotRow& DetectionHot = Store.DetectionHot[LightHot.Links.DetectionIndex];
				LightHot.DesiredColor = DetectionHot.VisionState == EBSSentryVisionState::Probing
					? LightHot.SweepColor
					: LightHot.ActiveColor;
			}

			if (!bSupplied)
			{
				LightHot.DesiredIntensity = 0.0f;
			}
			else if (ChainInsuficency > 0.0f)
			{
				float T = Gameplay::TimeSeconds + LightIndex;
				float I = Math::Min(1.0f, Math::Abs(2.0f * Math::Sin(0.3f * T) + Math::Cos(T * 6.0f)));
				LightHot.DesiredIntensity = Math::Lerp(LightHot.FlickerLowIntensity, LightHot.FlickerHighIntensity, I);
			}
			else
			{
				LightHot.DesiredIntensity = LightHot.NominalIntensity;
			}

			LightComponent.SetIntensity(LightHot.DesiredIntensity);
			LightComponent.SetLightColor(LightHot.DesiredColor, true);
		}
	}

	/**
	 * Reads: ActorToBaseIndex, BaseRows, modular composition
	 * Writes: BaseRows, PowerHot, PowerChildren, DetectionHot, DetectionCold, AimHot, AimCold, FireHot, FireCold, LightHot, LightCold, ActorToBaseIndex
	 */
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
		}
		if (BaseRow.Capabilities.HasTag(GameplayTags::Backyard_Capability_Aim))
		{
			FeaturesAssembly::BuildAimFeature(Store, BaseIndex, Actor, ModularComponent, View);
		}
		if (BaseRow.Capabilities.HasTag(GameplayTags::Backyard_Capability_Fire))
		{
			FeaturesAssembly::BuildFireFeature(Store, BaseIndex, ModularComponent);
		}
		if (BaseRow.Capabilities.HasTag(GameplayTags::Backyard_Capability_Detection))
		{
			FeaturesAssembly::BuildLightFeature(Store, BaseIndex, Actor, View);
		}

		Store.RebuildActorLookup();
		Store.RebuildDerivedLinks();
		PushCachedFeatureIndices();
		return TOptional<int>(BaseIndex);
	}

	/**
	 * Reads: ActorToBaseIndex, BaseRows
	 * Writes: BaseRows, PowerHot, PowerChildren, DetectionHot, DetectionCold, AimHot, AimCold, FireHot, FireCold, LightHot, LightCold, ActorToBaseIndex
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
	 * Writes: BaseRows, PowerHot, PowerChildren, DetectionHot, DetectionCold, AimHot, AimCold, FireHot, FireCold, LightHot, LightCold
	 */
	private void ClearBaseFeatures(int BaseIndex)
	{
		if (BaseIndex < 0 || BaseIndex >= Store.BaseRows.Num())
		{
			return;
		}

		FBSBaseRuntimeRow& BaseRow = Store.BaseRows[BaseIndex];
		if (BaseRow.LightIndex >= 0)
		{
			USpotLightComponent LightComponent = Store.LightCold[BaseRow.LightIndex].LightComponent;
			if (LightComponent != nullptr)
			{
				LightComponent.SetIntensity(0.0f);
			}
			Store.RemoveLightRowSwap(BaseRow.LightIndex);
			BaseRow.LightIndex = -1;
		}
		if (BaseRow.FireIndex >= 0)
		{
			Store.RemoveFireRowSwap(BaseRow.FireIndex);
			BaseRow.FireIndex = -1;
		}
		if (BaseRow.AimIndex >= 0)
		{
			Store.RemoveAimRowSwap(BaseRow.AimIndex);
			BaseRow.AimIndex = -1;
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

	const FBSBaseRuntimeRow& GetBaseRow(int BaseIndex) const
	{
		return Store.BaseRows[BaseIndex];
	}

	const FBSDetectionHotRow& GetDetectionRuntime(int DetectionIndex) const
	{
		return Store.DetectionHot[DetectionIndex];
	}

	const FBSAimHotRow& GetAimRuntime(int AimIndex) const
	{
		return Store.AimHot[AimIndex];
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

	const FBSAimColdRow& GetAimCold(int AimIndex) const
	{
		return Store.AimCold[AimIndex];
	}

	/**
	 * Reads: FireHot, AimHot
	 * Writes: no runtime rows
	 */
	private bool CanFire(const FBSFireHotRow& FireHot, const FBSAimHotRow& AimHot) const
	{
		if (FireHot.RPM <= 0 || FireHot.ShotCooldownRemaining > 0.0f)
		{
			return false;
		}

		if (AimHot.DistanceToTarget <= 0.0f || AimHot.DistanceToTarget > FireHot.MaxDistance)
		{
			return false;
		}

		return Math::Abs(AimHot.MuzzleError.Yaw) <= FireHot.MaxAngleDegrees
			&& Math::Abs(AimHot.MuzzleError.Pitch) <= FireHot.MaxAngleDegrees;
	}
}
