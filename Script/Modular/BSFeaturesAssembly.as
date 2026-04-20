namespace FeaturesAssembly
{
	void BuildDetectionFeature(FBSRuntimeStore& Store,
							   int BaseIndex,
							   AActor Actor,
							   UBSModularComponent ModularComponent,
							   UBSModularView ModularView)
	{
		FBSSlotRuntime DetectorSlot;
		UBSVisorDefinition Detector = Cast<UBSVisorDefinition>(ModularComponent.FindModule(UBSVisorDefinition, DetectorSlot));
		if (Detector == nullptr)
		{
			return;
		}

		int DetectionIndex = Store.CreateDetectionRow(BaseIndex);
		FBSDetectionHotRow& DetectionHot = Store.DetectionHot[DetectionIndex];
		FBSDetectionColdRow& DetectionCold = Store.DetectionCold[DetectionIndex];

		DetectionCold.Detector = Detector;
		DetectionCold.SensorComponent = ResolveVisorComponent(ModularComponent, ModularView);

		DetectionHot.DetectorType = Detector.DetectorType;
		DetectionHot.Range = Detector.Range;
		DetectionHot.HorizontalFovDegrees = Detector.HorizontalFovDegrees;
		DetectionHot.DetectionInterval = Detector.DetectionInterval;
		DetectionHot.TargetAcquireTime = Detector.TargetAcquireTime;
		DetectionHot.ReturnToSweepDelay = Detector.ReturnToSweepDelay;
		DetectionHot.ProbeArcDegrees = Detector.ProbeArcDegrees;
		DetectionHot.ProbeDwellTime = Detector.ProbeDwellTime;
		DetectionHot.MaxLosChecksPerUpdate = Detector.MaxLosChecksPerUpdate;
		DetectionHot.DetectionPowerDrawWatts = Detector.DetectionPowerDrawWatts;

		FBSSlotRuntime ChassisSlot;
		UBSChassisDefinition Chassis = Cast<UBSChassisDefinition>(ModularComponent.FindModule(UBSChassisDefinition, ChassisSlot));
		if (Chassis != nullptr)
		{
			DetectionHot.ProbeYawSpeed = Chassis.SweepSpeed;
		}
	}

	void BuildArticulationFeature(FBSRuntimeStore& Store,
						  int BaseIndex,
						  AActor Actor,
						  UBSModularComponent ModularComponent,
						  UBSModularView ModularView)
	{
		FBSSlotRuntime ChassisSlot;
		UBSChassisDefinition Chassis = Cast<UBSChassisDefinition>(ModularComponent.FindModule(UBSChassisDefinition, ChassisSlot));
		if (Chassis == nullptr)
		{
			return;
		}

		int ArticulationIndex = Store.CreateArticulationRow(BaseIndex);
		FBSArticulationHotRow& ArticulationHot = Store.ArticulationHot[ArticulationIndex];
		FBSArticulationColdRow& ArticulationCold = Store.ArticulationCold[ArticulationIndex];
		ArticulationCold.Chassis = Chassis;

		CacheChassis(Chassis, ModularView.Build[ChassisSlot.Index], ArticulationCold, ArticulationHot);
		CacheArticulationGeometry(Actor, ModularComponent, ModularView, ArticulationCold);
	}

	void BuildFireFeature(FBSRuntimeStore& Store,
						   int BaseIndex,
						   UBSModularComponent ModularComponent)
	{
		FBSSlotRuntime TurretSlot;
		UBSTurretDefinition Turret = Cast<UBSTurretDefinition>(ModularComponent.FindModule(UBSTurretDefinition, TurretSlot));
		if (Turret == nullptr)
		{
			return;
		}

		int FireIndex = Store.CreateFireRow(BaseIndex);
		FBSFireHotRow& FireHot = Store.FireHot[FireIndex];
		FBSFireColdRow& FireCold = Store.FireCold[FireIndex];
		FireCold.Turret = Turret;
		FireHot.RPM = Turret.RPM;
		FireHot.MaxDistance = Turret.ShootingRules.MaxDistance;
		FireHot.MaxAngleDegrees = Turret.ShootingRules.MaxAngleDegrees;
		FireHot.FiringPowerDrawWatts = Turret.FiringPowerDrawWatts;
	}

	void BuildIndicationFeature(FBSRuntimeStore& Store,
								int BaseIndex,
								AActor Actor,
								UBSModularView ModularView)
	{
		FBSBaseRuntimeRow& BaseRow = Store.BaseRows[BaseIndex];
		if (BaseRow.DetectionIndex < 0)
		{
			return;
		}

		FBSDetectionColdRow& DetectionCold = Store.DetectionCold[BaseRow.DetectionIndex];
		if (DetectionCold.Detector == nullptr || DetectionCold.SensorComponent == nullptr)
		{
			return;
		}

		int IndicationIndex = Store.CreateIndicationRow(BaseIndex);
		FBSIndicationHotRow& IndicationHot = Store.IndicationHot[IndicationIndex];
		FBSIndicationColdRow& IndicationCold = Store.IndicationCold[IndicationIndex];

		USpotLightComponent IndicatorComponent = ModularView.CachedVisorIndicator;
		if (IndicatorComponent == nullptr)
		{
			IndicatorComponent = USpotLightComponent::GetOrCreate(Actor, n"VisorSpotLight");
			ModularView.CachedVisorIndicator = IndicatorComponent;
		}

		check(IndicatorComponent != nullptr, f"SentryAssembly could not create visor indicator on actor '{Actor.GetName()}'");

		IndicatorComponent.AttachToComponent(DetectionCold.SensorComponent);
		IndicatorComponent.SetIntensityUnits(ELightUnits::Lumens);
		IndicatorComponent.SetIntensity(IndicationHot.NominalIntensity);
		IndicatorComponent.SetLightColor(IndicationHot.SweepColor, true);
		IndicatorComponent.AttenuationRadius = 500.0f;

		float OuterConeAngle = DetectionCold.Detector.HorizontalFovDegrees * 0.5f;
		OuterConeAngle = Math::Clamp(OuterConeAngle, 1.0f, 90.0f);
		IndicatorComponent.InnerConeAngle = OuterConeAngle * 0.1f;
		IndicatorComponent.OuterConeAngle = OuterConeAngle;

		if (DetectionCold.SensorComponent.DoesSocketExist(Sentry::VisorSocketName))
		{
			FTransform SensorSocketTransform = DetectionCold.SensorComponent.GetSocketTransform(Sentry::VisorSocketName);
			IndicatorComponent.WorldLocation = SensorSocketTransform.Location;
			IndicatorComponent.WorldRotation = SensorSocketTransform.Rotation.Rotator();
		}
		else
		{
			IndicatorComponent.RelativeLocation = FVector(30.0f, 0.0f, 0.0f);
			IndicatorComponent.RelativeRotation = FRotator(-30.0f, 0.0f, 0.0f);
		}

		IndicationCold.IndicatorComponent = IndicatorComponent;
	}

	USceneComponent ResolveVisorComponent(UBSModularComponent ModularComponent, UBSModularView ModularView)
	{
		if (ModularComponent == nullptr || ModularView == nullptr)
		{
			return nullptr;
		}

		FBSSlotRuntime VisorSlot;
		UBSModuleDefinition Visor = ModularComponent.FindModule(UBSVisorDefinition, VisorSlot);
		if (Visor == nullptr)
		{
			return nullptr;
		}

		return ResolveVisorComponentInView(ModularView.Build[VisorSlot.Index]);
	}

	void CacheChassis(UBSChassisDefinition Definition,
					  const FBSBuiltModuleView& BuiltView,
					  FBSArticulationColdRow& ArticulationCold,
					  FBSArticulationHotRow& ArticulationHot)
	{
		check(Definition != nullptr);
		check(Definition.Rotators.Num() == 2, f"SentryAssembly requires exactly 2 rotators on chassis '{Definition.GetName()}'");

		for (int RotatorIndex = 0; RotatorIndex < 2; RotatorIndex++)
		{
			const FBSChassisRotatorSpec& RotatorSpec = Definition.Rotators[RotatorIndex];
			USceneComponent ResolvedRotator = ModularAssembly::FindBuiltElementById(BuiltView, RotatorSpec.ElementId);
			check(ResolvedRotator != nullptr, f"SentryAssembly could not resolve rotator[{RotatorIndex}] '{RotatorSpec.ElementId}' on chassis '{Definition.GetName()}'");

			if (RotatorIndex == 0)
			{
				ArticulationCold.Rotator0Component = ResolvedRotator;
				ArticulationHot.Rotator0Constraint = RotatorSpec.Constraint;
				ArticulationHot.Rotator0Constraint.RotationSpeed = Definition.RotationSpeed;
			}
			else
			{
				ArticulationCold.Rotator1Component = ResolvedRotator;
				ArticulationHot.Rotator1Constraint = RotatorSpec.Constraint;
				ArticulationHot.Rotator1Constraint.RotationSpeed = Definition.RotationSpeed;
			}
		}

		check(IsYawOnly(ArticulationHot.Rotator0Constraint), f"SentryAssembly requires rotator[0] to be yaw-only on chassis '{Definition.GetName()}'");
		check(IsPitchOnly(ArticulationHot.Rotator1Constraint), f"SentryAssembly requires rotator[1] to be pitch-only on chassis '{Definition.GetName()}'");
	}

	void CacheArticulationGeometry(AActor Actor,
						  UBSModularComponent ModularComponent,
						  UBSModularView ModularView,
						  FBSArticulationColdRow& ArticulationCold)
	{
		check(Actor != nullptr);
		check(Actor.RootComponent != nullptr);
		check(ArticulationCold.Rotator0Component != nullptr);
		check(ArticulationCold.Rotator1Component != nullptr);

		USceneComponent MuzzleComponent = ResolveMuzzleComponent(ModularComponent, ModularView, ArticulationCold.Rotator1Component);
		check(MuzzleComponent != nullptr, f"SentryAssembly could not resolve muzzle component on actor '{Actor.GetName()}'");

		FTransform MuzzleTransformWorld = ResolveMuzzleTransform(MuzzleComponent);
		ArticulationCold.MuzzleComponent = MuzzleComponent;
		ArticulationCold.Rotator0OffsetLocal = Actor.ActorTransform.InverseTransformPosition(ArticulationCold.Rotator0Component.WorldLocation);
		ArticulationCold.Rotator1OffsetLocal = ArticulationCold.Rotator0Component.WorldTransform.InverseTransformPosition(ArticulationCold.Rotator1Component.WorldLocation);
		ArticulationCold.MuzzleOffsetLocal = ArticulationCold.Rotator1Component.WorldTransform.InverseTransformPosition(MuzzleTransformWorld.Location);
		ArticulationCold.MuzzleLocalRotation = ArticulationCold.Rotator1Component.WorldRotation.Quaternion().Inverse() * MuzzleTransformWorld.Rotation;

		FRotator MuzzleLocalRotation = ArticulationCold.MuzzleLocalRotation.Rotator().GetNormalized();
		check(Math::Abs(MuzzleLocalRotation.Yaw) <= 0.1f && Math::Abs(MuzzleLocalRotation.Pitch) <= 0.1f,
			  f"SentryAssembly requires muzzle alignment on actor '{Actor.GetName()}'");
	}

	USceneComponent ResolveMuzzleComponent(UBSModularComponent ModularComponent, UBSModularView ModularView, USceneComponent Rotator1)
	{
		if (ModularComponent != nullptr && ModularView != nullptr)
		{
			FBSSlotRuntime ModuleSlot;
			UBSModuleDefinition Turret = ModularComponent.FindModule(UBSTurretDefinition, ModuleSlot);
			if (Turret != nullptr)
			{
				USceneComponent TurretMuzzle = ResolveMuzzleComponentInView(ModularView.Build[ModuleSlot.Index]);
				if (TurretMuzzle != nullptr)
				{
					return TurretMuzzle;
				}
			}

			UBSModuleDefinition Visor = ModularComponent.FindModule(UBSVisorDefinition, ModuleSlot);
			if (Visor != nullptr)
			{
				USceneComponent VisorMuzzle = ResolveMuzzleComponentInView(ModularView.Build[ModuleSlot.Index]);
				if (VisorMuzzle != nullptr)
				{
					return VisorMuzzle;
				}
			}
		}

		if (Rotator1 == nullptr)
		{
			return nullptr;
		}

		if (Rotator1.DoesSocketExist(Sentry::MuzzleSocketName))
		{
			return Rotator1;
		}

		TArray<USceneComponent> Children;
		Rotator1.GetChildrenComponents(true, Children);
		for (USceneComponent Child : Children)
		{
			if (Child != nullptr && Child.DoesSocketExist(Sentry::MuzzleSocketName))
			{
				return Child;
			}
		}

		return Rotator1;
	}

	USceneComponent ResolveMuzzleComponentInView(const FBSBuiltModuleView& BuiltView)
	{
		USceneComponent SocketOwner = ModularAssembly::FindBuiltSocketOwner(BuiltView, Sentry::MuzzleSocketName);
		if (SocketOwner != nullptr)
		{
			return SocketOwner;
		}

		return BuiltView.PrimaryComponent;
	}

	USceneComponent ResolveVisorComponentInView(const FBSBuiltModuleView& BuiltView)
	{
		USceneComponent SocketOwner = ModularAssembly::FindBuiltSocketOwner(BuiltView, Sentry::VisorSocketName);
		if (SocketOwner != nullptr)
		{
			return SocketOwner;
		}

		return BuiltView.PrimaryComponent;
	}

	FTransform ResolveMuzzleTransform(USceneComponent MuzzleComponent)
	{
		check(MuzzleComponent != nullptr);
		if (MuzzleComponent.DoesSocketExist(Sentry::MuzzleSocketName))
		{
			return MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
		}

		return MuzzleComponent.WorldTransform;
	}

	bool IsYawOnly(const FBSSentryConstraint& Constraint)
	{
		return Constraint.bYaw && !Constraint.bPitch && !Constraint.bRoll;
	}

	bool IsPitchOnly(const FBSSentryConstraint& Constraint)
	{
		return Constraint.bPitch && !Constraint.bYaw && !Constraint.bRoll;
	}

	void BuildPowerFeature(FBSRuntimeStore& Store, int BaseIndex, UBSModularComponent ModularComponent)
	{
		FBSSlotRuntime PSU;
		UBSModuleDefinition PSUDefinition = ModularComponent.FindModule(UBSPowerSupplyUnitDefinition, PSU);
		TArray<FBSSlotRuntime> BatterySlots;
		ModularComponent.FindSlotsWithModuleType(UBSBatteryDefinition, BatterySlots);

		if (PSUDefinition == nullptr && BatterySlots.Num() == 0)
		{
			return;
		}

		int PowerIndex = Store.CreatePowerRow(BaseIndex);
		FBSPowerHotRow& PowerRuntime = Store.PowerHot[PowerIndex];
		FBSPowerChildrenRow& PowerRuntimeChildren = Store.PowerChildren[PowerIndex];

		if (PSUDefinition != nullptr)
		{
			UBSPowerSupplyUnitDefinition PowerSupply = Cast<UBSPowerSupplyUnitDefinition>(PSUDefinition);
			PowerRuntime.Output = PowerSupply.MaxOutputWatts;
			PowerRuntime.Reserve = PowerSupply.Capacity;
			PowerRuntime.Capacity = PowerSupply.Capacity;
		}

		for (FBSSlotRuntime Slot : BatterySlots)
		{
			FBSPowerChildRuntime ChildRuntime;
			UBSModuleDefinition Def = Slot.GetDefinitionUnsafe(ModularComponent);
			UBSBatteryDefinition PowerDef = Cast<UBSBatteryDefinition>(Def);
			ChildRuntime.Output = PowerDef.MaxOutputWatts;
			ChildRuntime.Reserve = PowerDef.Capacity;
			ChildRuntime.Capacity = PowerDef.Capacity;

			PowerRuntimeChildren.Batteries.Add(ChildRuntime);

			PowerRuntime.ChildrenReserve += ChildRuntime.Reserve;
			PowerRuntime.ChildrenCapacity += ChildRuntime.Capacity;
		}
	}
}
