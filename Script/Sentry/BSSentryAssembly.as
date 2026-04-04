namespace SentryAssembly
{
	void Build(ABSSentry Sentry,
			   FBSSentryStatics& Statics,
			   FBSSentryAimCache& AimCache,
			   FBSSentryTargetingRuntime& TargetingRuntime,
			   FBSSentryCombatRuntime& CombatRuntime,
			   FBSSentryPowerRuntime& PowerRuntime,
			   FGameplayTagContainer& Capabilities)
	{
		Statics = FBSSentryStatics();
		AimCache = FBSSentryAimCache();
		TargetingRuntime = FBSSentryTargetingRuntime();
		CombatRuntime = FBSSentryCombatRuntime();
		PowerRuntime = FBSSentryPowerRuntime();

		ResolveStatics(Sentry, Statics);

		FBSSlotRuntime ChassisSlot;
		if (Sentry.ModularComponent.FindModule(UBSChassisDefinition, ChassisSlot) != nullptr)
		{
			CacheChassis(Statics.Chassis, Sentry.ModularView.LastBuildResult.InstalledModuleViews[ChassisSlot.Index], AimCache);
		}

		CacheAimGeometry(Sentry, AimCache);
		CacheCapabilites(Capabilities, Sentry.ModularComponent.InstalledModules);
	}

	void CacheCapabilites(FGameplayTagContainer& Capabilities, TArray<UBSModuleDefinition> Modules)
	{
		Capabilities = FGameplayTagContainer();
		for (auto Module : Modules)
		{
			Capabilities.AppendTags(Module.Capabilities);
		}		
	}

	void ResolveStatics(ABSSentry Sentry, FBSSentryStatics& OutStatics)
	{
		OutStatics.Sentry = Sentry;

		FBSSlotRuntime LookupSlot;
		//TODO: after hardening enough move UBSModularComponent into cpp and use UFUNCTION(Meta=(DeterminesOutputType = "ModuleClass"))
		OutStatics.Chassis = Cast<UBSChassisDefinition>(Sentry.ModularComponent.FindModule(UBSChassisDefinition, LookupSlot));
		OutStatics.PowerSupply = Cast<UBSPowerSupplyUnitDefinition>(Sentry.ModularComponent.FindModule(UBSPowerSupplyUnitDefinition, LookupSlot));
		OutStatics.Turret = Cast<UBSTurretDefinition>(Sentry.ModularComponent.FindModule(UBSTurretDefinition, LookupSlot));
		OutStatics.Battery = Cast<UBSBatteryDefinition>(Sentry.ModularComponent.FindModule(UBSBatteryDefinition, LookupSlot));	
	}

	bool CacheChassis(UBSChassisDefinition Definition, const FBSBuiltModuleView& BuiltView, FBSSentryAimCache& AimCache)
	{
		if (Definition == nullptr)
		{
			return false;
		}

		if (Definition.Rotators.Num() != 2)
		{
			Warning(f"SentryAssembly requires exactly 2 rotators on chassis '{Definition.GetName()}'");
			return false;
		}

		for (int RotatorIndex = 0; RotatorIndex < 2; RotatorIndex++)
		{
			const FBSChassisRotatorSpec& RotatorSpec = Definition.Rotators[RotatorIndex];
			USceneComponent ResolvedRotator = ModularAssembly::FindBuiltElementById(BuiltView, RotatorSpec.ElementId);
			if (ResolvedRotator == nullptr)
			{
				Warning(f"SentryAssembly could not resolve rotator[{RotatorIndex}] '{RotatorSpec.ElementId}' on chassis '{Definition.GetName()}'");
				return false;
			}

			if (RotatorIndex == 0)
			{
				AimCache.Rotator0Component = ResolvedRotator;
				AimCache.Rotator0Constraint = RotatorSpec.Constraint;
			}
			else
			{
				AimCache.Rotator1Component = ResolvedRotator;
				AimCache.Rotator1Constraint = RotatorSpec.Constraint;
			}
		}

		if (!IsYawOnly(AimCache.Rotator0Constraint))
		{
			Warning(f"SentryAssembly requires rotator[0] to be yaw-only on chassis '{Definition.GetName()}'");
			return false;
		}

		if (!IsPitchOnly(AimCache.Rotator1Constraint))
		{
			Warning(f"SentryAssembly requires rotator[1] to be pitch-only on chassis '{Definition.GetName()}'");
			return false;
		}

		return AimCache.Rotator0Component != nullptr && AimCache.Rotator1Component != nullptr;
	}

	bool CacheAimGeometry(ABSSentry Sentry, FBSSentryAimCache& AimCache)
	{
		USceneComponent Rotator0 = AimCache.Rotator0Component;
		USceneComponent Rotator1 = AimCache.Rotator1Component;
		if (Sentry == nullptr || Sentry.Base == nullptr || Rotator0 == nullptr || Rotator1 == nullptr)
		{
			return false;
		}

		USceneComponent MuzzleComponent = ResolveMuzzleComponent(Rotator1);
		if (MuzzleComponent == nullptr || !MuzzleComponent.DoesSocketExist(Sentry::MuzzleSocketName))
		{
			Warning(f"SentryAssembly could not resolve muzzle socket '{Sentry::MuzzleSocketName}' on sentry '{Sentry.GetName()}'");
			return false;
		}

		FTransform MuzzleSocketWorld = MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
		AimCache.MuzzleComponent = MuzzleComponent;
		AimCache.Rotator0OffsetLocal = Sentry.Base.WorldTransform.InverseTransformPosition(Rotator0.WorldLocation);
		AimCache.Rotator1OffsetLocal = Rotator0.WorldTransform.InverseTransformPosition(Rotator1.WorldLocation);
		AimCache.MuzzleOffsetLocal = Rotator1.WorldTransform.InverseTransformPosition(MuzzleSocketWorld.Location);
		AimCache.MuzzleLocalRotation = Rotator1.WorldRotation.Quaternion().Inverse() * MuzzleSocketWorld.Rotation;

		FRotator MuzzleLocalRotation = AimCache.MuzzleLocalRotation.Rotator().GetNormalized();
		if (Math::Abs(MuzzleLocalRotation.Yaw) > 0.1f || Math::Abs(MuzzleLocalRotation.Pitch) > 0.1f)
		{
			Warning(f"SentryAssembly requires muzzle alignment on sentry '{Sentry.GetName()}'");
			return false;
		}

		AimCache.bHasAimCache = true;
		return true;
	}

	USceneComponent ResolveMuzzleComponent(USceneComponent Rotator1)
	{
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

		return nullptr;
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
