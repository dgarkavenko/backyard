namespace SentryAssembly
{
	void BuildRow(FBSSentryStore& Store, int RowIndex, AActor Actor)
	{
		auto Sentry = Cast<ABSSentry>(Actor);

		if (Sentry != nullptr)
		{
			Build(Sentry,
				  Store.Statics[RowIndex],
				  Store.AimCache[RowIndex],
				  Store.TargetingRuntime[RowIndex],
				  Store.PerceptionRuntime[RowIndex],
				  Store.CombatRuntime[RowIndex],
				  Store.Capabilities[RowIndex]);
		}
	}

	void Build(ABSSentry Sentry,
			   FBSSentryStatics& Statics,
			   FBSSentryAimCache& AimCache,
			   FBSSentryTargetingRuntime& TargetingRuntime,
			   FBSSentryPerceptionRuntime& PerceptionRuntime,
			   FBSSentryCombatRuntime& CombatRuntime,
			   FGameplayTagContainer& Capabilities)
	{
		check(Sentry != nullptr);
		check(Sentry.ModularComponent != nullptr);
		check(Sentry.ModularView != nullptr);

		AimCache = FBSSentryAimCache();
		TargetingRuntime = FBSSentryTargetingRuntime();
		PerceptionRuntime = FBSSentryPerceptionRuntime();
		CombatRuntime = FBSSentryCombatRuntime();

		ResolveStatics(Sentry, Statics);

		if (Capabilities.HasTag(GameplayTags::Backyard_Capability_Detection))
		{
			check(Statics.Vision != nullptr, "Detection capability requires exactly one detector module");
			AddSpotLightToVisorComponent(Sentry, Statics.Vision);
		}

		if (Capabilities.HasTag(GameplayTags::Backyard_Capability_Aim))
		{
			check(Statics.Chassis != nullptr, "Aim capability requires a chassis module");

			FBSSlotRuntime ChassisSlot;
			UBSModuleDefinition Chassis = Sentry.ModularComponent.FindModule(UBSChassisDefinition, ChassisSlot);
			check(Chassis != nullptr, "Aim capability requires a resolvable chassis slot");

			CacheChassis(Statics.Chassis, Sentry.ModularView.Build[ChassisSlot.Index], AimCache);
			CacheAimGeometry(Sentry, AimCache);
			CacheMotionRuntime(Statics.Chassis, PerceptionRuntime);
		}

		if (Capabilities.HasTag(GameplayTags::Backyard_Capability_Fire))
		{
			check(Statics.Turret != nullptr, "Fire capability requires a turret module");
		}
	}

	void ResolveStatics(ABSSentry Sentry, FBSSentryStatics& OutStatics)
	{
		FBSSlotRuntime LookupSlot;
		// TODO: after hardening enough move UBSModularComponent into cpp and use UFUNCTION(Meta=(DeterminesOutputType = "ModuleClass"))
		OutStatics.Chassis = Cast<UBSChassisDefinition>(Sentry.ModularComponent.FindModule(UBSChassisDefinition, LookupSlot));
		OutStatics.Vision = Cast<UBSVisorDefinition>(Sentry.ModularComponent.FindModule(UBSVisorDefinition, LookupSlot));
		OutStatics.Turret = Cast<UBSTurretDefinition>(Sentry.ModularComponent.FindModule(UBSTurretDefinition, LookupSlot));
	}

	void CacheChassis(UBSChassisDefinition Definition, const FBSBuiltModuleView& BuiltView, FBSSentryAimCache& AimCache)
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
				AimCache.Rotator0Component = ResolvedRotator;
				AimCache.Rotator0Constraint = RotatorSpec.Constraint;
				AimCache.Rotator0Constraint.RotationSpeed = Definition.RotationSpeed;
			}
			else
			{
				AimCache.Rotator1Component = ResolvedRotator;
				AimCache.Rotator1Constraint = RotatorSpec.Constraint;
				AimCache.Rotator1Constraint.RotationSpeed = Definition.RotationSpeed;
			}
		}

		check(IsYawOnly(AimCache.Rotator0Constraint), f"SentryAssembly requires rotator[0] to be yaw-only on chassis '{Definition.GetName()}'");
		check(IsPitchOnly(AimCache.Rotator1Constraint), f"SentryAssembly requires rotator[1] to be pitch-only on chassis '{Definition.GetName()}'");
	}

	void CacheMotionRuntime(UBSChassisDefinition Definition, FBSSentryPerceptionRuntime& PerceptionRuntime)
	{
		check(Definition != nullptr);
		PerceptionRuntime.ProbeYawSpeed = Definition.SweepSpeed;
	}

	void AddSpotLightToVisorComponent(ABSSentry Sentry, UBSVisorDefinition Vision)
	{
		check(Sentry != nullptr);
		check(Vision != nullptr);
		check(Sentry.ModularView != nullptr);

		USceneComponent VisorComponent = ResolveVisorComponent(Sentry);
		if (VisorComponent == nullptr)
		{
			return;
		}

		USpotLightComponent VisorSpotLight = Sentry.ModularView.CachedVisorSpotLight;
		if (VisorSpotLight == nullptr)
		{
			VisorSpotLight = USpotLightComponent::GetOrCreate(Sentry, n"VisorSpotLight");
			Sentry.ModularView.CachedVisorSpotLight = VisorSpotLight;
		}

		check(VisorSpotLight != nullptr, f"SentryAssembly could not create visor spotlight on sentry '{Sentry.GetName()}'");

		VisorSpotLight.AttachToComponent(VisorComponent);
		VisorSpotLight.SetIntensityUnits(ELightUnits::Lumens);
		VisorSpotLight.SetIntensity(400.0f);
		VisorSpotLight.SetLightColor(Sentry::VisorSweepLightColor, true);
		VisorSpotLight.AttenuationRadius = 500.0f;

		float OuterConeAngle = Vision.HorizontalFovDegrees * 0.5f;
		OuterConeAngle = Math::Clamp(OuterConeAngle, 1.0f, 90.0f);

		VisorSpotLight.InnerConeAngle = OuterConeAngle * 0.1f;
		VisorSpotLight.OuterConeAngle = OuterConeAngle;

		if (VisorComponent.DoesSocketExist(Sentry::VisorSocketName))
		{
			FTransform VisorSocketTransform = VisorComponent.GetSocketTransform(Sentry::VisorSocketName);
			VisorSpotLight.WorldLocation = VisorSocketTransform.Location;
			VisorSpotLight.WorldRotation = VisorSocketTransform.Rotation.Rotator();
			return;
		}

		VisorSpotLight.RelativeLocation = FVector(30.0f, 0.0f, 0.0f);
		VisorSpotLight.RelativeRotation = FRotator(-30.0f, 0.0f, 0.0f);
	}

	void CacheAimGeometry(ABSSentry Sentry, FBSSentryAimCache& AimCache)
	{
		USceneComponent Rotator0 = AimCache.Rotator0Component;
		USceneComponent Rotator1 = AimCache.Rotator1Component;
		check(Sentry != nullptr);
		check(Sentry.Base != nullptr);
		check(Rotator0 != nullptr);
		check(Rotator1 != nullptr);

		USceneComponent MuzzleComponent = ResolveMuzzleComponent(Sentry, Rotator1);
		check(MuzzleComponent != nullptr, f"SentryAssembly could not resolve muzzle component on sentry '{Sentry.GetName()}'");

		FTransform MuzzleTransformWorld = ResolveMuzzleTransform(MuzzleComponent);
		AimCache.MuzzleComponent = MuzzleComponent;
		AimCache.Rotator0OffsetLocal = Sentry.Base.WorldTransform.InverseTransformPosition(Rotator0.WorldLocation);
		AimCache.Rotator1OffsetLocal = Rotator0.WorldTransform.InverseTransformPosition(Rotator1.WorldLocation);
		AimCache.MuzzleOffsetLocal = Rotator1.WorldTransform.InverseTransformPosition(MuzzleTransformWorld.Location);
		AimCache.MuzzleLocalRotation = Rotator1.WorldRotation.Quaternion().Inverse() * MuzzleTransformWorld.Rotation;

		FRotator MuzzleLocalRotation = AimCache.MuzzleLocalRotation.Rotator().GetNormalized();
		check(Math::Abs(MuzzleLocalRotation.Yaw) <= 0.1f && Math::Abs(MuzzleLocalRotation.Pitch) <= 0.1f,
			  f"SentryAssembly requires muzzle alignment on sentry '{Sentry.GetName()}'");
	}

	USceneComponent ResolveVisorComponent(ABSSentry Sentry)
	{
		check(Sentry != nullptr);
		if (Sentry.ModularComponent == nullptr || Sentry.ModularView == nullptr)
		{
			return nullptr;
		}

		FBSSlotRuntime VisorSlot;
		UBSModuleDefinition Visor = Sentry.ModularComponent.FindModule(UBSVisorDefinition, VisorSlot);
		if (Visor == nullptr)
		{
			return nullptr;
		}

		return ResolveVisorComponentInView(Sentry.ModularView.Build[VisorSlot.Index]);
	}

	USceneComponent ResolveMuzzleComponent(ABSSentry Sentry, USceneComponent Rotator1)
	{
		check(Sentry != nullptr);
		if (Sentry.ModularComponent != nullptr && Sentry.ModularView != nullptr)
		{
			FBSSlotRuntime ModuleSlot;
			UBSModuleDefinition Turret = Sentry.ModularComponent.FindModule(UBSTurretDefinition, ModuleSlot);
			if (Turret != nullptr)
			{
				USceneComponent TurretMuzzle = ResolveMuzzleComponentInView(Sentry.ModularView.Build[ModuleSlot.Index]);
				if (TurretMuzzle != nullptr)
				{
					return TurretMuzzle;
				}
			}

			UBSModuleDefinition Visor = Sentry.ModularComponent.FindModule(UBSVisorDefinition, ModuleSlot);
			if (Visor != nullptr)
			{
				USceneComponent VisorMuzzle = ResolveMuzzleComponentInView(Sentry.ModularView.Build[ModuleSlot.Index]);
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
}
