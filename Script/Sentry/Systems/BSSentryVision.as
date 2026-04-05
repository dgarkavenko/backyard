namespace SentryVision
{
	void Update(const FGameplayTagContainer& Capabilities,
				const FBSSentryStatics& Statics,
				const FBSSentryAimCache& AimCache,
				FBSSentryPerceptionRuntime& PerceptionRuntime,
				float DeltaSeconds)
	{
		check(Statics.Sentry != nullptr);
		check(Statics.Vision != nullptr, "Detection capability requires a detector module");

		RefreshStateBetweenDetection(PerceptionRuntime);

		PerceptionRuntime.DetectionCooldownRemaining -= DeltaSeconds;
		if (PerceptionRuntime.DetectionCooldownRemaining > 0.0f)
		{
			return;
		}

		float DetectionStep = Statics.Vision.DetectionInterval > 0.0f ? Statics.Vision.DetectionInterval : DeltaSeconds;
		PerceptionRuntime.DetectionCooldownRemaining = Math::Max(Statics.Vision.DetectionInterval, 0.0f);
		GatherContacts(Capabilities, Statics, AimCache, PerceptionRuntime);
		SyncContactMemory(Capabilities, Statics, AimCache, PerceptionRuntime, DetectionStep);
		AcquireTarget(Capabilities, Statics, AimCache, PerceptionRuntime);
	}

	void GatherContacts(const FGameplayTagContainer& Capabilities,
						const FBSSentryStatics& Statics,
						const FBSSentryAimCache& AimCache,
						FBSSentryPerceptionRuntime& PerceptionRuntime)
	{
		UBSTargetWorldSubsystem TargetWorldSubsystem = UBSTargetWorldSubsystem::Get();
		check(TargetWorldSubsystem != nullptr);

		PerceptionRuntime.Contacts.Empty();
		const FVector SensorOrigin = ResolveSensorOrigin(Statics, AimCache);
		const FVector SensorForward = ResolveSensorForward(Statics, AimCache);
		const FVector HorizontalSensorForward = ResolveHorizontalDirection(SensorForward, FVector::ForwardVector);
		const float MaxDistance = Statics.Vision.Range;
		const float MaxDistanceSquared = MaxDistance * MaxDistance;
		const float HalfFovRadians = Math::DegreesToRadians(Statics.Vision.HorizontalFovDegrees * 0.5f);
		const float MinimumDot = Statics.Vision.HorizontalFovDegrees >= 360.0f ? -1.0f : Math::Cos(HalfFovRadians);
		int RemainingLosChecks = Statics.Vision.MaxLosChecksPerUpdate;

		for (const FBSTargetSnapshot& Snapshot : TargetWorldSubsystem.Snapshots)
		{
			if (Snapshot.Actor == nullptr || Snapshot.Actor == Statics.Sentry)
			{
				continue;
			}

			FVector ToTarget = Snapshot.WorldLocation - SensorOrigin;
			float DistanceSquared = ToTarget.SizeSquared();
			if (DistanceSquared <= 0.0f || DistanceSquared > MaxDistanceSquared)
			{
				continue;
			}

			FVector HorizontalTargetDirection = ResolveHorizontalDirection(ToTarget, HorizontalSensorForward);
			if (HorizontalSensorForward.DotProduct(HorizontalTargetDirection) < MinimumDot)
			{
				continue;
			}

			if (Statics.Vision.DetectorType == EBSSentryDetectorType::MotionSensor && !Snapshot.bIsMoving)
			{
				continue;
			}

			if (RemainingLosChecks <= 0)
			{
				break;
			}

			RemainingLosChecks--;
			if (!HasLineOfSight(Statics.Sentry, SensorOrigin, Snapshot))
			{
				continue;
			}

			FBSSensedContact Contact;
			Contact.Actor = Snapshot.Actor;
			Contact.WorldLocation = Snapshot.WorldLocation;
			Contact.Velocity = Snapshot.Velocity;
			Contact.Distance = Math::Sqrt(DistanceSquared);
			Contact.bHasLineOfSight = true;
			Contact.bRecognizedHostile = CanRecognizeHostile(Capabilities, Snapshot);
			PerceptionRuntime.Contacts.Add(Contact);
		}
	}

	void SyncContactMemory(const FGameplayTagContainer& Capabilities,
						   const FBSSentryStatics& Statics,
						   const FBSSentryAimCache& AimCache,
						   FBSSentryPerceptionRuntime& PerceptionRuntime,
						   float DetectionStep)
	{
		for (int MemoryIndex = 0; MemoryIndex < PerceptionRuntime.ContactMemory.Num(); MemoryIndex++)
		{
			PerceptionRuntime.ContactMemory[MemoryIndex].bVisibleThisUpdate = false;
			PerceptionRuntime.ContactMemory[MemoryIndex].bSelectable = false;
		}

		for (const FBSSensedContact& Contact : PerceptionRuntime.Contacts)
		{
			int MemoryIndex = FindContactMemoryIndex(PerceptionRuntime.ContactMemory, Contact.Actor);
			if (MemoryIndex < 0)
			{
				FBSSentryContactMemory NewMemory;
				NewMemory.Actor = Contact.Actor;
				PerceptionRuntime.ContactMemory.Add(NewMemory);
				MemoryIndex = PerceptionRuntime.ContactMemory.Num() - 1;
			}

			FBSSentryContactMemory& Memory = PerceptionRuntime.ContactMemory[MemoryIndex];
			Memory.Actor = Contact.Actor;
			Memory.LastKnownLocation = Contact.WorldLocation;
			Memory.LastKnownVelocity = Contact.Velocity;
			Memory.bVisibleThisUpdate = true;
			Memory.bRecognizedHostile = Contact.bRecognizedHostile;
			Memory.Distance = Contact.Distance;
			Memory.PresenceTime += DetectionStep;
			Memory.TimeSinceVisible = 0.0f;
			Memory.bSelectable = IsSelectableContact(Capabilities, Statics, AimCache, Contact);
			if (Memory.bSelectable)
			{
				Memory.TimeSinceSelectable = 0.0f;
			}
		}

		for (int MemoryIndex = PerceptionRuntime.ContactMemory.Num() - 1; MemoryIndex >= 0; MemoryIndex--)
		{
			FBSSentryContactMemory& Memory = PerceptionRuntime.ContactMemory[MemoryIndex];
			if (!Memory.bVisibleThisUpdate)
			{
				Memory.TimeSinceVisible += DetectionStep;
			}

			if (!Memory.bSelectable)
			{
				Memory.TimeSinceSelectable += DetectionStep;
			}

			bool bForget = Memory.TimeSinceVisible > Statics.Vision.ReturnToSweepDelay;
			bool bIsCurrentTarget = PerceptionRuntime.CurrentTarget != nullptr && Memory.Actor == PerceptionRuntime.CurrentTarget;
			if (bForget && !bIsCurrentTarget)
			{
				PerceptionRuntime.ContactMemory.RemoveAt(MemoryIndex);
			}
		}
	}

	void AcquireTarget(const FGameplayTagContainer& Capabilities,
					   const FBSSentryStatics& Statics,
					   const FBSSentryAimCache& AimCache,
					   FBSSentryPerceptionRuntime& PerceptionRuntime)
	{
		int CurrentTargetMemoryIndex = FindContactMemoryIndex(PerceptionRuntime.ContactMemory, PerceptionRuntime.CurrentTarget);
		if (CurrentTargetMemoryIndex >= 0 && CanKeepTracking(PerceptionRuntime.ContactMemory[CurrentTargetMemoryIndex]))
		{
			const FBSSentryContactMemory& CurrentMemory = PerceptionRuntime.ContactMemory[CurrentTargetMemoryIndex];
			PerceptionRuntime.CurrentTargetLocation = CurrentMemory.LastKnownLocation;
			PerceptionRuntime.VisionState = EBSSentryVisionState::Tracking;
			return;
		}

		int ReadyTargetMemoryIndex = FindBestVisibleSelectableMemory(PerceptionRuntime.ContactMemory, Statics.Vision.TargetAcquireTime, true);
		if (ReadyTargetMemoryIndex >= 0)
		{
			const FBSSentryContactMemory& ReadyMemory = PerceptionRuntime.ContactMemory[ReadyTargetMemoryIndex];
			PerceptionRuntime.CurrentTarget = ReadyMemory.Actor;
			PerceptionRuntime.CurrentTargetLocation = ReadyMemory.LastKnownLocation;
			PerceptionRuntime.VisionState = EBSSentryVisionState::Tracking;
			return;
		}

		bool bCanHoldLostTarget = CurrentTargetMemoryIndex >= 0
			&& PerceptionRuntime.ContactMemory[CurrentTargetMemoryIndex].TimeSinceSelectable <= Statics.Vision.ReturnToSweepDelay;
		if (bCanHoldLostTarget)
		{
			PerceptionRuntime.CurrentTargetLocation = PerceptionRuntime.ContactMemory[CurrentTargetMemoryIndex].LastKnownLocation;
			PerceptionRuntime.VisionState = EBSSentryVisionState::LostHold;
			return;
		}

		int AcquiringTargetMemoryIndex = FindBestVisibleSelectableMemory(PerceptionRuntime.ContactMemory, Statics.Vision.TargetAcquireTime, false);
		if (AcquiringTargetMemoryIndex >= 0)
		{
			PerceptionRuntime.CurrentTarget = nullptr;
			PerceptionRuntime.CurrentTargetLocation = FVector::ZeroVector;
			EnterSweepState(EBSSentryVisionState::Acquiring, Statics, AimCache, PerceptionRuntime);
			return;
		}

		PerceptionRuntime.CurrentTarget = nullptr;
		PerceptionRuntime.CurrentTargetLocation = FVector::ZeroVector;
		EnterSweepState(EBSSentryVisionState::Probing, Statics, AimCache, PerceptionRuntime);
	}

	void ApplyProbing(const FBSSentryStatics& Statics,
					  const FBSSentryAimCache& AimCache,
					  FBSSentryTargetingRuntime& TargetingRuntime,
					  FBSSentryPerceptionRuntime& PerceptionRuntime,
					  float DeltaSeconds)
	{
		check(Statics.Vision != nullptr);
		SentryAim::SeedFromComponents(AimCache, TargetingRuntime);

		const float HalfArc = Statics.Vision.ProbeArcDegrees * 0.5f;
		if (HalfArc > 0.0f && PerceptionRuntime.ProbeYawSpeed > 0.0f)
		{
			float DesiredProbeYaw = GetProbeEdgeYaw(Statics, PerceptionRuntime);
			FRotator ProbeYawTarget = TargetingRuntime.AppliedRotator0Local;
			ProbeYawTarget.Yaw = DesiredProbeYaw;
			FBSSentryConstraint ProbeYawConstraint = AimCache.Rotator0Constraint;
			ProbeYawConstraint.RotationSpeed = PerceptionRuntime.ProbeYawSpeed;
			TargetingRuntime.AppliedRotator0Local = SentryAim::ConstrainRotation(
				TargetingRuntime.AppliedRotator0Local,
				ProbeYawTarget,
				ProbeYawConstraint,
				DeltaSeconds
			);

			if (HasReachedProbeEdge(TargetingRuntime.AppliedRotator0Local, DesiredProbeYaw))
			{
				AdvanceProbeDwell(Statics, PerceptionRuntime, DeltaSeconds);
			}
			else
			{
				PerceptionRuntime.ProbeDwellRemaining = 0.0f;
			}
		}
		else
		{
			PerceptionRuntime.ProbeDirection = 1.0f;
			PerceptionRuntime.ProbeDwellRemaining = 0.0f;
		}

		TargetingRuntime.AppliedRotator1Local = SentryAim::ConstrainRotation(
			TargetingRuntime.AppliedRotator1Local,
			FRotator(0, 0, 0),
			AimCache.Rotator1Constraint,
			DeltaSeconds
		);

		SentryAim::Apply(AimCache, TargetingRuntime);
		SentryAim::ReadMuzzle(AimCache, TargetingRuntime);
	}

	void ApplyVisorLightColor(const FBSSentryStatics& Statics, const FBSSentryPerceptionRuntime& PerceptionRuntime)
	{
		check(Statics.Sentry != nullptr);
		if (Statics.Sentry.ModularView == nullptr)
		{
			return;
		}

		USpotLightComponent VisorSpotLight = Statics.Sentry.ModularView.CachedVisorSpotLight;
		if (VisorSpotLight == nullptr)
		{
			return;
		}

		VisorSpotLight.SetLightColor(ResolveVisorLightColor(PerceptionRuntime.VisionState), true);
	}

	FLinearColor ResolveVisorLightColor(EBSSentryVisionState VisionState)
	{
		if (VisionState == EBSSentryVisionState::Probing)
		{
			return Sentry::VisorSweepLightColor;
		}

		return Sentry::VisorActiveLightColor;
	}

	int FindContactMemoryIndex(const TArray<FBSSentryContactMemory>& ContactMemory, AActor TargetActor)
	{
		if (TargetActor == nullptr)
		{
			return -1;
		}

		for (int Index = 0; Index < ContactMemory.Num(); Index++)
		{
			if (ContactMemory[Index].Actor == TargetActor)
			{
				return Index;
			}
		}

		return -1;
	}

	int FindBestVisibleSelectableMemory(const TArray<FBSSentryContactMemory>& ContactMemory,
										float TargetAcquireTime,
										bool bRequireReady)
	{
		int BestIndex = -1;
		float BestDistance = 999999999.0f;

		for (int Index = 0; Index < ContactMemory.Num(); Index++)
		{
			const FBSSentryContactMemory& Memory = ContactMemory[Index];
			if (!Memory.bVisibleThisUpdate || !Memory.bSelectable)
			{
				continue;
			}

			if (bRequireReady && Memory.PresenceTime < TargetAcquireTime)
			{
				continue;
			}

			if (Memory.Distance < BestDistance)
			{
				BestDistance = Memory.Distance;
				BestIndex = Index;
			}
		}

		return BestIndex;
	}

	bool CanKeepTracking(const FBSSentryContactMemory& Memory)
	{
		return Memory.bVisibleThisUpdate && Memory.bSelectable;
	}

	bool IsSelectableContact(const FGameplayTagContainer& Capabilities,
							 const FBSSentryStatics& Statics,
							 const FBSSentryAimCache& AimCache,
							 const FBSSensedContact& Contact)
	{
		if (!IsDetectorValidContact(Capabilities, Statics, Contact))
		{
			return false;
		}

		if (Capabilities.HasTag(GameplayTags::Backyard_Capability_Fire))
		{
			UBSTurretDefinition Turret = Statics.Turret;
			check(Turret != nullptr, "Fire capability requires a turret module");
			if (Contact.Distance > Turret.ShootingRules.MaxDistance)
			{
				return false;
			}
		}

		if (!Capabilities.HasTag(GameplayTags::Backyard_Capability_Aim))
		{
			return true;
		}

		FBSSentryTargetingRuntime PreviewRuntime;
		float ReachabilityTolerance = 1.0f;
		if (Capabilities.HasTag(GameplayTags::Backyard_Capability_Fire))
		{
			ReachabilityTolerance = Statics.Turret.ShootingRules.MaxAngleDegrees;
		}

		return SentryAim::PreviewTarget(Statics, AimCache, Contact.WorldLocation, PreviewRuntime, ReachabilityTolerance);
	}

	bool IsDetectorValidContact(const FGameplayTagContainer& Capabilities,
								const FBSSentryStatics& Statics,
								const FBSSensedContact& Contact)
	{
		if (!Contact.bHasLineOfSight)
		{
			return false;
		}

		switch (Statics.Vision.DetectorType)
		{
			case EBSSentryDetectorType::MotionSensor:
				return true;
			case EBSSentryDetectorType::CameraRecognition:
				return Contact.bRecognizedHostile;
			case EBSSentryDetectorType::Lidar:
				if (Capabilities.HasTag(GameplayTags::Backyard_Capability_TargetRecognition))
				{
					return Contact.bRecognizedHostile;
				}
				return true;
		}
	}

	void RefreshStateBetweenDetection(FBSSentryPerceptionRuntime& PerceptionRuntime)
	{
		if (PerceptionRuntime.VisionState == EBSSentryVisionState::Tracking && PerceptionRuntime.CurrentTarget != nullptr)
		{
			PerceptionRuntime.CurrentTargetLocation = ResolveTrackedTargetLocation(PerceptionRuntime.CurrentTarget);
		}
	}

	void EnterSweepState(EBSSentryVisionState TargetState,
						 const FBSSentryStatics& Statics,
						 const FBSSentryAimCache& AimCache,
						 FBSSentryPerceptionRuntime& PerceptionRuntime)
	{
		if (!IsSweepState(PerceptionRuntime.VisionState))
		{
			InitializeProbeState(Statics, AimCache, PerceptionRuntime);
		}

		PerceptionRuntime.VisionState = TargetState;
	}

	bool IsSweepState(EBSSentryVisionState VisionState)
	{
		return VisionState == EBSSentryVisionState::Probing || VisionState == EBSSentryVisionState::Acquiring;
	}

	void InitializeProbeState(const FBSSentryStatics& Statics,
							  const FBSSentryAimCache& AimCache,
							  FBSSentryPerceptionRuntime& PerceptionRuntime)
	{
		if (PerceptionRuntime.ProbeDirection == 0.0f)
		{
			PerceptionRuntime.ProbeDirection = 1.0f;
		}

		PerceptionRuntime.ProbeDwellRemaining = 0.0f;

		if (AimCache.Rotator0Component == nullptr || Statics.Vision == nullptr)
		{
			return;
		}

		float HalfArc = Statics.Vision.ProbeArcDegrees * 0.5f;
		if (HalfArc <= 0.0f)
		{
			return;
		}

		if (HasReachedProbeEdge(AimCache.Rotator0Component.RelativeRotation, GetProbeEdgeYaw(Statics, PerceptionRuntime)))
		{
			PerceptionRuntime.ProbeDwellRemaining = Statics.Vision.ProbeDwellTime;
		}
	}

	float GetProbeEdgeYaw(const FBSSentryStatics& Statics, const FBSSentryPerceptionRuntime& PerceptionRuntime)
	{
		float HalfArc = Statics.Vision != nullptr ? Statics.Vision.ProbeArcDegrees * 0.5f : 0.0f;
		return PerceptionRuntime.ProbeDirection >= 0.0f ? HalfArc : -HalfArc;
	}

	bool HasReachedProbeEdge(const FRotator& CurrentRotator0, float DesiredEdgeYaw)
	{
		FRotator DesiredRotator = CurrentRotator0;
		DesiredRotator.Yaw = DesiredEdgeYaw;

		FRotator DeltaRotator = (DesiredRotator - CurrentRotator0).GetNormalized();
		return Math::Abs(DeltaRotator.Yaw) <= 1.0f;
	}

	void AdvanceProbeDwell(const FBSSentryStatics& Statics,
						   FBSSentryPerceptionRuntime& PerceptionRuntime,
						   float DeltaSeconds)
	{
		check(Statics.Vision != nullptr);

		if (PerceptionRuntime.ProbeDwellRemaining <= 0.0f)
		{
			PerceptionRuntime.ProbeDwellRemaining = Statics.Vision.ProbeDwellTime;
			if (PerceptionRuntime.ProbeDwellRemaining <= 0.0f)
			{
				FlipProbeDirection(PerceptionRuntime);
			}
			return;
		}

		PerceptionRuntime.ProbeDwellRemaining = Math::Max(PerceptionRuntime.ProbeDwellRemaining - DeltaSeconds, 0.0f);
		if (PerceptionRuntime.ProbeDwellRemaining <= 0.0f)
		{
			FlipProbeDirection(PerceptionRuntime);
		}
	}

	void FlipProbeDirection(FBSSentryPerceptionRuntime& PerceptionRuntime)
	{
		PerceptionRuntime.ProbeDirection = PerceptionRuntime.ProbeDirection >= 0.0f ? -1.0f : 1.0f;
		PerceptionRuntime.ProbeDwellRemaining = 0.0f;
	}

	bool HasLineOfSight(ABSSentry Sentry, const FVector& SensorOrigin, const FBSTargetSnapshot& Snapshot)
	{
		TArray<AActor> IgnoredActors;
		IgnoredActors.Add(Sentry);
		IgnoredActors.Add(Snapshot.Actor);

		FHitResult HitResult;
		return !System::LineTraceSingle(
			SensorOrigin,
			Snapshot.WorldLocation,
			ETraceTypeQuery::TraceTypeQuery1,
			false,
			IgnoredActors,
			EDrawDebugTrace::None,
			HitResult,
			true
		);
	}

	bool CanRecognizeHostile(const FGameplayTagContainer& Capabilities, const FBSTargetSnapshot& Snapshot)
	{
		if (!Capabilities.HasTag(GameplayTags::Backyard_Capability_TargetRecognition))
		{
			return false;
		}

		return Snapshot.Tags.HasTag(GameplayTags::Backyard_Target_Hostile);
	}

	FVector ResolveSensorOrigin(const FBSSentryStatics& Statics, const FBSSentryAimCache& AimCache)
	{
		if (AimCache.MuzzleComponent != nullptr)
		{
			return SentryAim::ResolveMuzzleTransform(AimCache.MuzzleComponent).Location;
		}

		check(Statics.Sentry != nullptr);
		check(Statics.Sentry.Base != nullptr);
		return Statics.Sentry.Base.WorldLocation;
	}

	FVector ResolveSensorForward(const FBSSentryStatics& Statics, const FBSSentryAimCache& AimCache)
	{
		if (AimCache.MuzzleComponent != nullptr)
		{
			return SentryAim::ResolveMuzzleTransform(AimCache.MuzzleComponent).Rotation.Rotator().ForwardVector.GetSafeNormal();
		}

		check(Statics.Sentry != nullptr);
		check(Statics.Sentry.Base != nullptr);
		return Statics.Sentry.Base.WorldRotation.ForwardVector.GetSafeNormal();
	}

	FVector ResolveTrackedTargetLocation(AActor TargetActor)
	{
		if (TargetActor == nullptr)
		{
			return FVector::ZeroVector;
		}

		UBSTargetWorldSubsystem TargetWorldSubsystem = UBSTargetWorldSubsystem::Get();
		if (TargetWorldSubsystem != nullptr)
		{
			for (const FBSTargetSnapshot& Snapshot : TargetWorldSubsystem.Snapshots)
			{
				if (Snapshot.Actor == TargetActor)
				{
					return Snapshot.WorldLocation;
				}
			}
		}

		return TargetActor.ActorLocation;
	}

	FVector ResolveHorizontalDirection(const FVector& Direction, const FVector& FallbackDirection)
	{
		FVector HorizontalDirection = FVector(Direction.X, Direction.Y, 0.0f).GetSafeNormal();
		if (!HorizontalDirection.IsNearlyZero())
		{
			return HorizontalDirection;
		}

		FVector HorizontalFallbackDirection = FVector(FallbackDirection.X, FallbackDirection.Y, 0.0f).GetSafeNormal();
		if (!HorizontalFallbackDirection.IsNearlyZero())
		{
			return HorizontalFallbackDirection;
		}

		return FVector::ForwardVector;
	}
}
