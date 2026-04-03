namespace SentryAssembly
{
	void Build(UBSSentryView Adapter, ABSSentry Sentry, UBSModularComponent ModularComponent, UBSModularView ModularView)
	{
		BeginRebuild(Adapter);
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

			CacheChassis(ChassisDefinition, ModularView.LastBuildResult.InstalledModuleViews[SlotIndex], Adapter);
		}

		CacheGeometry(Adapter, Sentry);

		UBSSentryWorldSubsystem SentrySubsystem = UBSSentryWorldSubsystem::Get();
		if (SentrySubsystem != nullptr)
		{
			SentrySubsystem.SyncSentry(Sentry);
		}

		SentryDebugF::LogAssembled(Sentry, Adapter, ModularView);
		SentryDebugF::ValidateNoGarbageComponents(Adapter, ModularView, Sentry);
	}

	void BeginRebuild(UBSSentryView Adapter)
	{
		Adapter.RotatorComponents.Empty();
		Adapter.RotatorConstraints.Empty();
		Adapter.RotatorOffsets.Empty();
		Adapter.MuzzleComponent = nullptr;
		Adapter.bHasYawPitchFastPath = false;
		Adapter.Rotator1OffsetLocal = FVector::ZeroVector;
		Adapter.MuzzleOffsetLocal = FVector::ZeroVector;
		Adapter.MuzzleOffset = FVector::ZeroVector;
		Adapter.MuzzleLocalRotation = FQuat::Identity;
		Adapter.CachedYawLateralOffset = 0.0f;
		Adapter.CachedYawForwardOffset = 0.0f;
		Adapter.CachedPitchVerticalOffset = 0.0f;
		Adapter.CachedPitchForwardOffset = 0.0f;
	}

	void CacheChassis(UBSChassisDefinition Definition, const FBSBuiltModuleView& BuiltView, UBSSentryView Adapter)
	{
		for (int RotatorIndex = 0; RotatorIndex < Definition.Rotators.Num(); RotatorIndex++)
		{
			const FBSChassisRotatorSpec& RotatorSpec = Definition.Rotators[RotatorIndex];
			USceneComponent ResolvedRotator = ModularAssembly::FindBuiltElementById(BuiltView, RotatorSpec.ElementId);
			if (ResolvedRotator != nullptr)
			{
				Adapter.RotatorComponents.Add(ResolvedRotator);
				Adapter.RotatorConstraints.Add(RotatorSpec.Constraint);
			}
			else
			{
				Warning(f"SentryAssembly could not resolve rotator[{RotatorIndex}] '{RotatorSpec.ElementId}' on chassis '{Definition.GetName()}'");
			}
		}
	}

	void CacheGeometry(UBSSentryView Adapter, ABSSentry Sentry)
	{
		Adapter.RotatorOffsets.Empty();
		Adapter.RotatorOffsets.SetNum(Adapter.RotatorComponents.Num());
		Adapter.bHasYawPitchFastPath = false;
		Adapter.Rotator1OffsetLocal = FVector::ZeroVector;
		Adapter.MuzzleOffsetLocal = FVector::ZeroVector;
		Adapter.MuzzleOffset = FVector::ZeroVector;
		Adapter.MuzzleLocalRotation = FQuat::Identity;
		Adapter.CachedYawLateralOffset = 0.0f;
		Adapter.CachedYawForwardOffset = 0.0f;
		Adapter.CachedPitchVerticalOffset = 0.0f;
		Adapter.CachedPitchForwardOffset = 0.0f;

		if (Adapter.RotatorComponents.Num() < 2 || Adapter.RotatorComponents[0] == nullptr || Adapter.RotatorComponents[1] == nullptr)
		{
			FString Rotator0Name = Adapter.RotatorComponents.Num() > 0 && Adapter.RotatorComponents[0] != nullptr ? Adapter.RotatorComponents[0].GetName().ToString() : "<none>";
			FString Rotator1Name = Adapter.RotatorComponents.Num() > 1 && Adapter.RotatorComponents[1] != nullptr ? Adapter.RotatorComponents[1].GetName().ToString() : "<none>";
			SentryDebugF::LogAssembly(f"Assembly: missing rotator chain sentry='{Sentry.GetName()}' rotatorCount={Adapter.RotatorComponents.Num()} rotator0='{Rotator0Name}' rotator1='{Rotator1Name}'");
			return;
		}

		USceneComponent Rotator0 = Adapter.RotatorComponents[0];
		USceneComponent Rotator1 = Adapter.RotatorComponents[1];
		Adapter.RotatorOffsets[0] = Sentry.Base.WorldTransform.InverseTransformPosition(Rotator0.WorldLocation);
		Adapter.RotatorOffsets[1] = Rotator0.WorldTransform.InverseTransformPosition(Rotator1.WorldLocation);
		Adapter.Rotator1OffsetLocal = Adapter.RotatorOffsets[1];

		if (Adapter.MuzzleComponent == nullptr)
		{
			TArray<USceneComponent> AllChildren;
			Rotator1.GetChildrenComponents(true, AllChildren);

			for (USceneComponent Child : AllChildren)
			{
				if (Child.DoesSocketExist(Sentry::MuzzleSocketName))
				{
					Adapter.MuzzleComponent = Child;
					break;
				}
			}
		}

		if (Adapter.MuzzleComponent != nullptr && Adapter.MuzzleComponent.DoesSocketExist(Sentry::MuzzleSocketName))
		{
			FTransform MuzzleSocketWorld = Adapter.MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
			Adapter.MuzzleOffset = Rotator1.WorldTransform.InverseTransformPosition(MuzzleSocketWorld.Location);
			Adapter.MuzzleOffsetLocal = Adapter.MuzzleOffset;
			Adapter.MuzzleLocalRotation = Rotator1.WorldRotation.Quaternion().Inverse() * MuzzleSocketWorld.Rotation;

			if (HasYawPitchFastPath(Adapter))
			{
				Adapter.bHasYawPitchFastPath = true;
				Adapter.CachedYawLateralOffset = Adapter.Rotator1OffsetLocal.Y + Adapter.MuzzleOffsetLocal.Y;
				Adapter.CachedYawForwardOffset = Adapter.Rotator1OffsetLocal.X + Adapter.MuzzleOffsetLocal.X;
				Adapter.CachedPitchVerticalOffset = Adapter.MuzzleOffsetLocal.Z;
				Adapter.CachedPitchForwardOffset = Adapter.MuzzleOffsetLocal.X;
			}
		}
	}

	bool HasYawPitchFastPath(UBSSentryView Adapter)
	{
		if (Adapter == nullptr || Adapter.RotatorConstraints.Num() < 2)
		{
			return false;
		}

		const FBSSentryConstraint& Rotator0Constraint = Adapter.RotatorConstraints[0];
		const FBSSentryConstraint& Rotator1Constraint = Adapter.RotatorConstraints[1];
		if (!Rotator0Constraint.bYaw || Rotator0Constraint.bPitch || Rotator0Constraint.bRoll)
		{
			return false;
		}

		if (!Rotator1Constraint.bPitch || Rotator1Constraint.bYaw || Rotator1Constraint.bRoll)
		{
			return false;
		}

		FRotator MuzzleLocal = Adapter.MuzzleLocalRotation.Rotator().GetNormalized();
		return Math::Abs(MuzzleLocal.Yaw) < 0.1f
			&& Math::Abs(MuzzleLocal.Pitch) < 0.1f;
	}
}
