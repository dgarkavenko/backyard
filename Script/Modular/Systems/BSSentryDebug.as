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

	void Tick(FBSRuntimeStore& Store)
	{
		if (SentryDebugF::ShowAim.Int > 0)
		{
			for (int AimIndex = 0; AimIndex < Store.AimHot.Num(); AimIndex++)
			{
				SentryDebugF::DrawAim(Store.AimHot[AimIndex]);
			}
		}

		if (SentryDebugF::ShowVision.Int > 0)
		{
			for (int DetectionIndex = 0; DetectionIndex < Store.DetectionHot.Num(); DetectionIndex++)
			{
				const FBSDetectionHotRow& DetectionHot = Store.DetectionHot[DetectionIndex];
				const FBSDetectionColdRow& DetectionCold = Store.DetectionCold[DetectionIndex];
				const FBSBaseRuntimeRow& BaseRow = Store.BaseRows[DetectionHot.OwnerBaseIndex];
				FBSAimColdRow AimCold;
				FBSAimHotRow AimHot;
				bool bHasAim = BaseRow.AimIndex >= 0;
				if (bHasAim)
				{
					AimCold = Store.AimCold[BaseRow.AimIndex];
					AimHot = Store.AimHot[BaseRow.AimIndex];
				}

				SentryDebugF::DrawVision(Store, BaseRow, DetectionHot, DetectionCold, AimCold, AimHot, bHasAim);
			}
		}
	}

	void DrawAim(const FBSAimHotRow& AimHot)
	{
		FVector MuzzleLocation = AimHot.MuzzleWorldLocation;
		float DistanceToTarget = AimHot.DistanceToTarget;
		FVector MuzzleForward = AimHot.MuzzleWorldRotation.ForwardVector.GetSafeNormal();

		System::DrawDebugLine(MuzzleLocation, AimHot.AimTargetLocation, FLinearColor::Yellow, 0, 2);
		System::DrawDebugLine(MuzzleLocation, MuzzleLocation + MuzzleForward * DistanceToTarget, FLinearColor::Blue, 0, 2);
		System::DrawDebugPoint(AimHot.AimTargetLocation, 12.0f, FLinearColor::Yellow, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
	}

	void DrawVision(const FBSRuntimeStore& Store,
					const FBSBaseRuntimeRow& BaseRow,
					const FBSDetectionHotRow& DetectionHot,
					const FBSDetectionColdRow& DetectionCold,
					const FBSAimColdRow& AimCold,
					const FBSAimHotRow& AimHot,
					bool bHasAim)
	{
		FVector SensorOrigin = SentryVision::ResolveSensorOrigin(BaseRow, DetectionCold);
		FVector SensorForward = SentryVision::ResolveSensorForward(BaseRow, DetectionCold);
		float VisionRange = DetectionHot.Range;

		if (ShowVision.Int >= 1)
		{
			DrawTargetables(BaseRow);
		}

		if (ShowVision.Int >= 2)
		{
			DrawVisionCandidates(BaseRow, DetectionHot, SensorOrigin, SensorForward, VisionRange);
			DrawVisionSector(BaseRow, DetectionHot, AimCold, SensorOrigin, SensorForward, VisionRange, bHasAim);
		}

		System::DrawDebugPoint(SensorOrigin, 10.0f, FLinearColor::Blue, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
		System::DrawDebugLine(SensorOrigin, SensorOrigin + SensorForward * VisionRange, FLinearColor::Blue, 0, 1.0f);

		for (const FBSSentryContactMemory& Memory : DetectionHot.ContactMemory)
		{
			bool bIsCurrentTarget = DetectionHot.CurrentTarget != nullptr && Memory.Actor == DetectionHot.CurrentTarget;
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

	void DrawTargetables(const FBSBaseRuntimeRow& BaseRow)
	{
		UBSTargetWorldSubsystem TargetWorldSubsystem = UBSTargetWorldSubsystem::Get();
		if (TargetWorldSubsystem == nullptr)
		{
			return;
		}

		for (const FBSTargetSnapshot& Snapshot : TargetWorldSubsystem.Snapshots)
		{
			if (Snapshot.Actor == nullptr || Snapshot.Actor == BaseRow.Actor)
			{
				continue;
			}

			System::DrawDebugPoint(Snapshot.WorldLocation, 6.0f, FLinearColor::White, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
		}
	}

	void DrawVisionCandidates(const FBSBaseRuntimeRow& BaseRow,
							  const FBSDetectionHotRow& DetectionHot,
							  const FVector& SensorOrigin,
							  const FVector& SensorForward,
							  float VisionRange)
	{
		const float VisionRangeSquared = VisionRange * VisionRange;
		const float HalfFovRadians = Math::DegreesToRadians(DetectionHot.HorizontalFovDegrees * 0.5f);
		const float MinimumDot = DetectionHot.HorizontalFovDegrees >= 360.0f ? -1.0f : Math::Cos(HalfFovRadians);
		const FVector HorizontalSensorForward = SentryVision::ResolveHorizontalDirection(SensorForward, FVector::ForwardVector);
		const FLinearColor CandidateColor = FLinearColor(0.45f, 0.8f, 1.0f, 0.85f);
		const FLinearColor FailedLineOfSightColor = FLinearColor(0.35f, 0.35f, 0.35f, 0.95f);

		UBSTargetWorldSubsystem TargetWorldSubsystem = UBSTargetWorldSubsystem::Get();
		if (TargetWorldSubsystem == nullptr)
		{
			return;
		}

		for (const FBSTargetSnapshot& Snapshot : TargetWorldSubsystem.Snapshots)
		{
			if (Snapshot.Actor == nullptr || Snapshot.Actor == BaseRow.Actor)
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

			bool bHasLineOfSight = SentryVision::HasLineOfSight(BaseRow.Actor, SensorOrigin, Snapshot);
			FLinearColor CandidateDrawColor = bHasLineOfSight ? CandidateColor : FailedLineOfSightColor;
			float PointSize = bHasLineOfSight ? 8.0f : 10.0f;

			System::DrawDebugPoint(Snapshot.WorldLocation, PointSize, CandidateDrawColor, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
		}
	}

	void DrawVisionSector(const FBSBaseRuntimeRow& BaseRow,
						  const FBSDetectionHotRow& DetectionHot,
						  const FBSAimColdRow& AimCold,
						  const FVector& SensorOrigin,
						  const FVector& SensorForward,
						  float VisionRange,
						  bool bHasAim)
	{
		FVector SectorOrigin = AimCold.Rotator0Component != nullptr ? AimCold.Rotator0Component.WorldLocation : SensorOrigin;
		FVector HorizontalForward = FVector(SensorForward.X, SensorForward.Y, 0.0f).GetSafeNormal();
		if (HorizontalForward.IsNearlyZero())
		{
			HorizontalForward = FVector::ForwardVector;
		}

		float HalfFovDegrees = DetectionHot.HorizontalFovDegrees * 0.5f;
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

		if (!bHasAim)
		{
			return;
		}

		FVector NeutralForward = BaseRow.Actor != nullptr && BaseRow.Actor.RootComponent != nullptr
			? FVector(BaseRow.Actor.ActorRotation.ForwardVector.X, BaseRow.Actor.ActorRotation.ForwardVector.Y, 0.0f).GetSafeNormal()
			: HorizontalForward;
		if (NeutralForward.IsNearlyZero())
		{
			NeutralForward = HorizontalForward;
		}

		float HalfYawLimitDegrees = AimCold.Rotator0Component != nullptr ? StoreYawHalfRangeHint(AimCold) : 0.0f;
		FVector LeftYawLimitDirection = FQuat(FVector::UpVector, Math::DegreesToRadians(-HalfYawLimitDegrees)).RotateVector(NeutralForward);
		FVector RightYawLimitDirection = FQuat(FVector::UpVector, Math::DegreesToRadians(HalfYawLimitDegrees)).RotateVector(NeutralForward);
		System::DrawDebugLine(SectorOrigin, SectorOrigin + LeftYawLimitDirection * VisionRange, FLinearColor::Red, 0, 2.0f);
		System::DrawDebugLine(SectorOrigin, SectorOrigin + RightYawLimitDirection * VisionRange, FLinearColor::Red, 0, 2.0f);
	}

	float StoreYawHalfRangeHint(const FBSAimColdRow& AimCold)
	{
		if (AimCold.Chassis == nullptr || AimCold.Chassis.Rotators.Num() < 1)
		{
			return 0.0f;
		}

		return AimCold.Chassis.Rotators[0].Constraint.RotationRange * 0.5f;
	}
}
