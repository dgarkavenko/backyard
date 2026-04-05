namespace SentryDebugF
{
	const FConsoleVariable ShowSockets(f"BF.Sentry.ShowSockets", 0);
	const FConsoleVariable ShowAim(f"BF.Sentry.ShowAim", 0);
	const FConsoleVariable ShowVision(f"bf.show.sentryvision", 0);
	const FConsoleVariable ValidateAssembly(f"BF.Sentry.ValidateAssembly", 0);

	bool IsManagedDynamicComponent(UBSModularView ModularView, UStaticMeshComponent Component)
	{
		return ModularView != nullptr && ModularView.ModuleElementPool.Contains(Component);
	}

	void ValidatePoolState(const TArray<UStaticMeshComponent>& Pool, const TArray<UStaticMeshComponent>& ActivePool)
	{
		for (UStaticMeshComponent Component : Pool)
		{
			if (Component == nullptr)
			{
				continue;
			}

			bool bIsActive = ActivePool.Contains(Component);
			if (bIsActive && Component.StaticMesh == nullptr)
			{
				Warning(f"Sentry rebuild garbage assert: active module component '{Component.GetName()}' has no mesh");
			}

			if (!bIsActive && Component.StaticMesh != nullptr)
			{
				Warning(f"Sentry rebuild garbage assert: stale module component '{Component.GetName()}' still has mesh '{Component.StaticMesh.GetName()}'");
			}
		}
	}

	void DrawSockets(ABSSentry Sentry)
	{

	}

	void DrawAim(FBSSentryTargetingRuntime& TargetingRuntime)
	{
		FVector MuzzleLocation = TargetingRuntime.MuzzleWorldLocation;
		float DistanceToTarget = TargetingRuntime.DistanceToTarget;

		FVector MuzzleForward = TargetingRuntime.MuzzleWorldRotation.ForwardVector.GetSafeNormal();

		System::DrawDebugLine(MuzzleLocation, TargetingRuntime.TargetLocation, FLinearColor::Yellow, 0, 2);
		System::DrawDebugLine(MuzzleLocation, MuzzleLocation + MuzzleForward * DistanceToTarget, FLinearColor::Blue, 0, 2);
		System::DrawDebugPoint(TargetingRuntime.TargetLocation, 12.0f, FLinearColor::Yellow, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
	}

	void DrawVision(const FBSSentryStatics& Statics, const FBSSentryAimCache& AimCache, const FBSSentryPerceptionRuntime& PerceptionRuntime)
	{
		FVector SensorOrigin = SentryVision::ResolveSensorOrigin(Statics, AimCache);
		FVector SensorForward = SentryVision::ResolveSensorForward(Statics, AimCache);
		float VisionRange = Statics.Vision != nullptr ? Statics.Vision.Range : 300.0f;

		if (ShowVision.Int >= 1)
		{
			DrawTargetables(Statics);
		}

		if (ShowVision.Int >= 2)
		{
			DrawVisionCandidates(Statics, SensorOrigin, SensorForward, VisionRange);
			DrawVisionSector(Statics, AimCache, SensorOrigin, SensorForward, VisionRange);
		}

		System::DrawDebugPoint(SensorOrigin, 10.0f, FLinearColor::Blue, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
		System::DrawDebugLine(SensorOrigin, SensorOrigin + SensorForward * VisionRange, FLinearColor::Blue, 0, 1.0f);

		for (const FBSSentryContactMemory& Memory : PerceptionRuntime.ContactMemory)
		{
			bool bIsCurrentTarget = PerceptionRuntime.CurrentTarget != nullptr && Memory.Actor == PerceptionRuntime.CurrentTarget;
			if (!Memory.bVisibleThisUpdate && !bIsCurrentTarget)
			{
				continue;
			}

			FLinearColor ContactColor = bIsCurrentTarget
				? FLinearColor::Red
				: (Memory.bSelectable ? FLinearColor::Yellow : FLinearColor::Green);
			float PointSize = bIsCurrentTarget ? 18.0f : (Memory.bSelectable ? 14.0f : 10.0f);
			float LineThickness = bIsCurrentTarget ? 2.0f : 1.0f;

			System::DrawDebugLine(SensorOrigin, Memory.LastKnownLocation, ContactColor, 0, LineThickness);
			System::DrawDebugPoint(Memory.LastKnownLocation, PointSize, ContactColor, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
		}
	}

	void DrawTargetables(const FBSSentryStatics& Statics)
	{
		UBSTargetWorldSubsystem TargetWorldSubsystem = UBSTargetWorldSubsystem::Get();
		if (TargetWorldSubsystem == nullptr)
		{
			return;
		}

		for (const FBSTargetSnapshot& Snapshot : TargetWorldSubsystem.Snapshots)
		{
			if (Snapshot.Actor == nullptr || Snapshot.Actor == Statics.Sentry)
			{
				continue;
			}

			System::DrawDebugPoint(Snapshot.WorldLocation, 6.0f, FLinearColor::White, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
		}
	}

	void DrawVisionCandidates(const FBSSentryStatics& Statics,
							  const FVector& SensorOrigin,
							  const FVector& SensorForward,
							  float VisionRange)
	{
		if (Statics.Vision == nullptr)
		{
			return;
		}

		UBSTargetWorldSubsystem TargetWorldSubsystem = UBSTargetWorldSubsystem::Get();
		if (TargetWorldSubsystem == nullptr)
		{
			return;
		}

		const float VisionRangeSquared = VisionRange * VisionRange;
		const float HalfFovRadians = Math::DegreesToRadians(Statics.Vision.HorizontalFovDegrees * 0.5f);
		const float MinimumDot = Statics.Vision.HorizontalFovDegrees >= 360.0f ? -1.0f : Math::Cos(HalfFovRadians);
		const FVector HorizontalSensorForward = SentryVision::ResolveHorizontalDirection(SensorForward, FVector::ForwardVector);
		const FLinearColor CandidateColor = FLinearColor(0.45f, 0.8f, 1.0f, 0.85f);
		const FLinearColor FailedLineOfSightColor = FLinearColor(0.35f, 0.35f, 0.35f, 0.95f);

		for (const FBSTargetSnapshot& Snapshot : TargetWorldSubsystem.Snapshots)
		{
			if (Snapshot.Actor == nullptr || Snapshot.Actor == Statics.Sentry)
			{
				continue;
			}

			FVector ToTarget = Snapshot.WorldLocation - SensorOrigin;
			float DistanceSquared = ToTarget.SizeSquared();
			if (DistanceSquared <= 0.0f || DistanceSquared > VisionRangeSquared)
			{
				continue;
			}

			FVector HorizontalTargetDirection = SentryVision::ResolveHorizontalDirection(ToTarget, HorizontalSensorForward);
			if (HorizontalSensorForward.DotProduct(HorizontalTargetDirection) < MinimumDot)
			{
				continue;
			}

			bool bHasLineOfSight = SentryVision::HasLineOfSight(Statics.Sentry, SensorOrigin, Snapshot);
			FLinearColor CandidateDrawColor = bHasLineOfSight ? CandidateColor : FailedLineOfSightColor;
			float PointSize = bHasLineOfSight ? 8.0f : 10.0f;

			System::DrawDebugPoint(Snapshot.WorldLocation, PointSize, CandidateDrawColor, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
		}
	}

	void DrawVisionSector(const FBSSentryStatics& Statics,
						  const FBSSentryAimCache& AimCache,
						  const FVector& SensorOrigin,
						  const FVector& SensorForward,
						  float VisionRange)
	{
		if (Statics.Vision == nullptr)
		{
			return;
		}

		FVector SectorOrigin = AimCache.Rotator0Component != nullptr ? AimCache.Rotator0Component.WorldLocation : SensorOrigin;
		FVector HorizontalForward = FVector(SensorForward.X, SensorForward.Y, 0.0f).GetSafeNormal();
		if (HorizontalForward.IsNearlyZero())
		{
			HorizontalForward = FVector::ForwardVector;
		}

		float HalfFovDegrees = Statics.Vision.HorizontalFovDegrees * 0.5f;
		float RadiusStep = 150.0f;
		float AngleStepDegrees = 10.0f;

		for (float Radius = RadiusStep; Radius <= VisionRange; Radius += RadiusStep)
		{
			for (float AngleDegrees = -HalfFovDegrees; AngleDegrees <= HalfFovDegrees; AngleDegrees += AngleStepDegrees)
			{
				FVector DotDirection = FQuat(FVector::UpVector, Math::DegreesToRadians(AngleDegrees)).RotateVector(HorizontalForward);
				FVector DotLocation = SectorOrigin + DotDirection * Radius;
				DotLocation.Z = SectorOrigin.Z;
				System::DrawDebugPoint(DotLocation, 4.0f, FLinearColor(0.1f, 0.4f, 1.0f, 0.35f), 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
			}
		}

		FVector LeftDirection = FQuat(FVector::UpVector, Math::DegreesToRadians(-HalfFovDegrees)).RotateVector(HorizontalForward);
		FVector RightDirection = FQuat(FVector::UpVector, Math::DegreesToRadians(HalfFovDegrees)).RotateVector(HorizontalForward);
		System::DrawDebugLine(SectorOrigin, SectorOrigin + LeftDirection * VisionRange, FLinearColor::Blue, 0, 1.0f);
		System::DrawDebugLine(SectorOrigin, SectorOrigin + RightDirection * VisionRange, FLinearColor::Blue, 0, 1.0f);

		FVector NeutralForward = Statics.Sentry != nullptr && Statics.Sentry.Base != nullptr
			? FVector(Statics.Sentry.Base.WorldRotation.ForwardVector.X, Statics.Sentry.Base.WorldRotation.ForwardVector.Y, 0.0f).GetSafeNormal()
			: HorizontalForward;
		if (NeutralForward.IsNearlyZero())
		{
			NeutralForward = HorizontalForward;
		}

		float HalfYawLimitDegrees = AimCache.Rotator0Constraint.RotationRange * 0.5f;
		FVector LeftYawLimitDirection = FQuat(FVector::UpVector, Math::DegreesToRadians(-HalfYawLimitDegrees)).RotateVector(NeutralForward);
		FVector RightYawLimitDirection = FQuat(FVector::UpVector, Math::DegreesToRadians(HalfYawLimitDegrees)).RotateVector(NeutralForward);
		System::DrawDebugLine(SectorOrigin, SectorOrigin + LeftYawLimitDirection * VisionRange, FLinearColor::Red, 0, 2.0f);
		System::DrawDebugLine(SectorOrigin, SectorOrigin + RightYawLimitDirection * VisionRange, FLinearColor::Red, 0, 2.0f);
	}
}
