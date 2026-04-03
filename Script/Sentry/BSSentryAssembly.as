namespace SentryAssembly
{
	void Build(UBSSentryWorldSubsystem SentrySubsystem, int RowIndex, ABSSentry Sentry, UBSModularComponent ModularComponent, UBSModularView ModularView)
	{
		if (SentrySubsystem == nullptr || RowIndex < 0 || RowIndex >= SentrySubsystem.AimCache.Num())
		{
			return;
		}

		BeginRebuild(SentrySubsystem, RowIndex);
		SentryDebugF::LogAssembly(f"Assembly: cache sentry='{Sentry.GetName()}' modules={ModularComponent.InstalledModules.Num()}");

		for (int SlotIndex = 0; SlotIndex < ModularComponent.Slots.Num(); SlotIndex++)
		{
			FBSSlotRuntime Slot = ModularComponent.Slots[SlotIndex];
			if (!Slot.Content.IsSet() || SlotIndex >= ModularView.LastBuildResult.InstalledModuleViews.Num())
			{
				continue;
			}

			UBSChassisDefinition ChassisDefinition = Cast<UBSChassisDefinition>(Slot.GetDefinitionUnsafe(ModularComponent));
			if (ChassisDefinition == nullptr)
			{
				continue;
			}

			CacheChassis(ChassisDefinition, ModularView.LastBuildResult.InstalledModuleViews[SlotIndex], SentrySubsystem, RowIndex);
		}

		CacheGeometry(SentrySubsystem, RowIndex, Sentry);
		SentryDebugF::LogAssembled(Sentry, SentrySubsystem.AimCache[RowIndex], ModularView);
		SentryDebugF::ValidateNoGarbageComponents(ModularView, Sentry);
	}

	void BeginRebuild(UBSSentryWorldSubsystem SentrySubsystem, int RowIndex)
	{
		SentrySubsystem.AimCache[RowIndex] = FBSSentryAimCache();
	}

	void CacheChassis(UBSChassisDefinition Definition, const FBSBuiltModuleView& BuiltView, UBSSentryWorldSubsystem SentrySubsystem, int RowIndex)
	{
		for (int RotatorIndex = 0; RotatorIndex < Definition.Rotators.Num(); RotatorIndex++)
		{
			const FBSChassisRotatorSpec& RotatorSpec = Definition.Rotators[RotatorIndex];
			USceneComponent ResolvedRotator = ModularAssembly::FindBuiltElementById(BuiltView, RotatorSpec.ElementId);
			if (ResolvedRotator == nullptr)
			{
				Warning(f"SentryAssembly could not resolve rotator[{RotatorIndex}] '{RotatorSpec.ElementId}' on chassis '{Definition.GetName()}'");
				continue;
			}

			if (SentrySubsystem.AimCache[RowIndex].Rotator0Component == nullptr)
			{
				SentrySubsystem.AimCache[RowIndex].Rotator0Component = ResolvedRotator;
				SentrySubsystem.AimCache[RowIndex].Rotator0Constraint = RotatorSpec.Constraint;
			}
			else if (SentrySubsystem.AimCache[RowIndex].Rotator1Component == nullptr)
			{
				SentrySubsystem.AimCache[RowIndex].Rotator1Component = ResolvedRotator;
				SentrySubsystem.AimCache[RowIndex].Rotator1Constraint = RotatorSpec.Constraint;
			}
			else
			{
				Warning(f"SentryAssembly ignores extra rotator[{RotatorIndex}] '{RotatorSpec.ElementId}' on chassis '{Definition.GetName()}'");
			}
		}
	}

	void CacheGeometry(UBSSentryWorldSubsystem SentrySubsystem, int RowIndex, ABSSentry Sentry)
	{
		FBSSentryAimCache Cache = SentrySubsystem.AimCache[RowIndex];
		if (Sentry == nullptr || Sentry.Base == nullptr)
		{
			return;
		}

		USceneComponent Rotator0 = Cache.Rotator0Component;
		USceneComponent Rotator1 = Cache.Rotator1Component;
		if (Rotator0 == nullptr || Rotator1 == nullptr)
		{
			FString Rotator0Name = Rotator0 != nullptr ? Rotator0.GetName().ToString() : "<none>";
			FString Rotator1Name = Rotator1 != nullptr ? Rotator1.GetName().ToString() : "<none>";
			SentryDebugF::LogAssembly(f"Assembly: missing rotator chain sentry='{Sentry.GetName()}' rotator0='{Rotator0Name}' rotator1='{Rotator1Name}'");
			SentrySubsystem.AimCache[RowIndex] = FBSSentryAimCache();
			return;
		}

		Cache.BaseWorldTransform = Sentry.Base.WorldTransform;
		Cache.BaseWorldRotation = Sentry.Base.WorldRotation.Quaternion();
		Cache.Rotator0OffsetLocal = Sentry.Base.WorldTransform.InverseTransformPosition(Rotator0.WorldLocation);
		Cache.Rotator1OffsetLocal = Rotator0.WorldTransform.InverseTransformPosition(Rotator1.WorldLocation);

		if (Cache.MuzzleComponent == nullptr)
		{
			TArray<USceneComponent> AllChildren;
			Rotator1.GetChildrenComponents(true, AllChildren);

			for (USceneComponent Child : AllChildren)
			{
				if (Child.DoesSocketExist(Sentry::MuzzleSocketName))
				{
					Cache.MuzzleComponent = Child;
					break;
				}
			}
		}

		if (Cache.MuzzleComponent == nullptr || !Cache.MuzzleComponent.DoesSocketExist(Sentry::MuzzleSocketName))
		{
			SentryDebugF::LogAssembly(f"Assembly: missing muzzle sentry='{Sentry.GetName()}'");
			SentrySubsystem.AimCache[RowIndex] = FBSSentryAimCache();
			return;
		}

		FTransform MuzzleSocketWorld = Cache.MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
		Cache.MuzzleOffsetLocal = Rotator1.WorldTransform.InverseTransformPosition(MuzzleSocketWorld.Location);
		Cache.MuzzleLocalRotation = Rotator1.WorldRotation.Quaternion().Inverse() * MuzzleSocketWorld.Rotation;
		if (!HasYawPitchFastPath(Cache))
		{
			SentryDebugF::LogAssembly(f"Assembly: invalid yaw/pitch fast path sentry='{Sentry.GetName()}'");
			SentrySubsystem.AimCache[RowIndex] = FBSSentryAimCache();
			return;
		}

		Cache.bHasAimCache = true;
		Cache.CachedYawLateralOffset = Cache.Rotator1OffsetLocal.Y + Cache.MuzzleOffsetLocal.Y;
		Cache.CachedYawForwardOffset = Cache.Rotator1OffsetLocal.X + Cache.MuzzleOffsetLocal.X;
		Cache.CachedPitchVerticalOffset = Cache.MuzzleOffsetLocal.Z;
		Cache.CachedPitchForwardOffset = Cache.MuzzleOffsetLocal.X;
		SentrySubsystem.AimCache[RowIndex] = Cache;
	}

	bool HasYawPitchFastPath(const FBSSentryAimCache& Cache)
	{
		const FBSSentryConstraint& Rotator0Constraint = Cache.Rotator0Constraint;
		const FBSSentryConstraint& Rotator1Constraint = Cache.Rotator1Constraint;
		if (!Rotator0Constraint.bYaw || Rotator0Constraint.bPitch || Rotator0Constraint.bRoll)
		{
			return false;
		}

		if (!Rotator1Constraint.bPitch || Rotator1Constraint.bYaw || Rotator1Constraint.bRoll)
		{
			return false;
		}

		FRotator MuzzleLocal = Cache.MuzzleLocalRotation.Rotator().GetNormalized();
		return Math::Abs(MuzzleLocal.Yaw) < 0.1f
			&& Math::Abs(MuzzleLocal.Pitch) < 0.1f;
	}
}
