namespace SentryVision
{
	/**
	 * Reads: BaseRows, DetectionHot, DetectionCold, AimCold, FireHot
	 * Writes: DetectionHot
	 */
	void Tick(FBSRuntimeStore& Store, float DeltaSeconds)
	{
		for (int DetectionIndex = 0; DetectionIndex < Store.DetectionHot.Num(); DetectionIndex++)
		{
			FBSDetectionHotRow& DetectionHot = Store.DetectionHot[DetectionIndex];
			const FBSDetectionColdRow& DetectionCold = Store.DetectionCold[DetectionIndex];
			const FBSBaseRuntimeRow& BaseRow = Store.BaseRows[DetectionHot.OwnerBaseIndex];

			check(BaseRow.Actor != nullptr);

			RefreshStateBetweenDetection(DetectionHot);

			DetectionHot.DetectionCooldownRemaining -= DeltaSeconds;
			if (DetectionHot.DetectionCooldownRemaining > 0.0f)
			{
				UpdateProbeIntent(Store, DetectionHot, DeltaSeconds);
				return;
			}

			float DetectionStep = DetectionHot.DetectionInterval > 0.0f ? DetectionHot.DetectionInterval : DeltaSeconds;
			DetectionHot.DetectionCooldownRemaining = Math::Max(DetectionHot.DetectionInterval, 0.0f);
			GatherContacts(BaseRow, DetectionCold, DetectionHot);
			SyncContactMemory(Store, BaseRow, DetectionHot, DetectionStep);
			AcquireTarget(DetectionHot);
			UpdateProbeIntent(Store, DetectionHot, DeltaSeconds);
		}
	}

	/**
	 * Reads: BaseRows, DetectionCold, DetectionHot
	 * Writes: DetectionHot.Contacts
	 */
	void GatherContacts(const FBSBaseRuntimeRow& BaseRow,
						const FBSDetectionColdRow& DetectionCold,
						FBSDetectionHotRow& DetectionHot)
	{
		UBSTargetWorldSubsystem TargetWorldSubsystem = UBSTargetWorldSubsystem::Get();
		check(TargetWorldSubsystem != nullptr);

		DetectionHot.Contacts.Empty();
		const FVector SensorOrigin = ResolveSensorOrigin(BaseRow, DetectionCold);
		const FVector SensorForward = ResolveSensorForward(BaseRow, DetectionCold);
		const FVector HorizontalSensorForward = ResolveHorizontalDirection(SensorForward, FVector::ForwardVector);
		const float MaxDistance = DetectionHot.Range;
		const float MaxDistanceSquared = MaxDistance * MaxDistance;
		const float HalfFovRadians = Math::DegreesToRadians(DetectionHot.HorizontalFovDegrees * 0.5f);
		const float MinimumDot = DetectionHot.HorizontalFovDegrees >= 360.0f ? -1.0f : Math::Cos(HalfFovRadians);
		int RemainingLosChecks = DetectionHot.MaxLosChecksPerUpdate;

		for (const FBSTargetSnapshot& Snapshot : TargetWorldSubsystem.Snapshots)
		{
			if (Snapshot.Actor == nullptr || Snapshot.Actor == BaseRow.Actor)
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

			if (DetectionHot.DetectorType == EBSSentryDetectorType::MotionSensor && !Snapshot.bIsMoving)
			{
				continue;
			}

			if (RemainingLosChecks <= 0)
			{
				break;
			}

			RemainingLosChecks--;
			if (!HasLineOfSight(BaseRow.Actor, SensorOrigin, Snapshot))
			{
				continue;
			}

			FBSSensedContact Contact;
			Contact.Actor = Snapshot.Actor;
			Contact.WorldLocation = Snapshot.WorldLocation;
			Contact.Velocity = Snapshot.Velocity;
			Contact.Distance = Math::Sqrt(DistanceSquared);
			Contact.bHasLineOfSight = true;
			Contact.bRecognizedHostile = CanRecognizeHostile(BaseRow.Capabilities, Snapshot);
			DetectionHot.Contacts.Add(Contact);
		}
	}

	/**
	 * Reads: BaseRows, DetectionHot.Contacts, FireHot, AimHot, AimCold
	 * Writes: DetectionHot.ContactMemory
	 */
	void SyncContactMemory(const FBSRuntimeStore& Store,
						   const FBSBaseRuntimeRow& BaseRow,
						   FBSDetectionHotRow& DetectionHot,
						   float DetectionStep)
	{
		for (int MemoryIndex = 0; MemoryIndex < DetectionHot.ContactMemory.Num(); MemoryIndex++)
		{
			DetectionHot.ContactMemory[MemoryIndex].bVisibleThisUpdate = false;
			DetectionHot.ContactMemory[MemoryIndex].bSelectable = false;
		}

		for (const FBSSensedContact& Contact : DetectionHot.Contacts)
		{
			int MemoryIndex = FindContactMemoryIndex(DetectionHot.ContactMemory, Contact.Actor);
			if (MemoryIndex < 0)
			{
				FBSSentryContactMemory NewMemory;
				NewMemory.Actor = Contact.Actor;
				DetectionHot.ContactMemory.Add(NewMemory);
				MemoryIndex = DetectionHot.ContactMemory.Num() - 1;
			}

			FBSSentryContactMemory& Memory = DetectionHot.ContactMemory[MemoryIndex];
			Memory.Actor = Contact.Actor;
			Memory.LastKnownLocation = Contact.WorldLocation;
			Memory.LastKnownVelocity = Contact.Velocity;
			Memory.bVisibleThisUpdate = true;
			Memory.bRecognizedHostile = Contact.bRecognizedHostile;
			Memory.Distance = Contact.Distance;
			Memory.PresenceTime += DetectionStep;
			Memory.TimeSinceVisible = 0.0f;
			Memory.bSelectable = IsSelectableContact(Store, BaseRow, DetectionHot, Contact);
			if (Memory.bSelectable)
			{
				Memory.TimeSinceSelectable = 0.0f;
			}
		}

		for (int MemoryIndex = DetectionHot.ContactMemory.Num() - 1; MemoryIndex >= 0; MemoryIndex--)
		{
			FBSSentryContactMemory& Memory = DetectionHot.ContactMemory[MemoryIndex];
			if (!Memory.bVisibleThisUpdate)
			{
				Memory.TimeSinceVisible += DetectionStep;
			}

			if (!Memory.bSelectable)
			{
				Memory.TimeSinceSelectable += DetectionStep;
			}

			bool bForget = Memory.TimeSinceVisible > DetectionHot.ReturnToSweepDelay;
			bool bIsCurrentTarget = DetectionHot.CurrentTarget != nullptr && Memory.Actor == DetectionHot.CurrentTarget;
			if (bForget && !bIsCurrentTarget)
			{
				DetectionHot.ContactMemory.RemoveAt(MemoryIndex);
			}
		}
	}

	/**
	 * Reads: DetectionHot.ContactMemory
	 * Writes: DetectionHot.CurrentTarget, DetectionHot.CurrentTargetLocation, DetectionHot.VisionState
	 */
	void AcquireTarget(FBSDetectionHotRow& DetectionHot)
	{
		int CurrentTargetMemoryIndex = FindContactMemoryIndex(DetectionHot.ContactMemory, DetectionHot.CurrentTarget);
		if (CurrentTargetMemoryIndex >= 0 && CanKeepTracking(DetectionHot.ContactMemory[CurrentTargetMemoryIndex]))
		{
			const FBSSentryContactMemory& CurrentMemory = DetectionHot.ContactMemory[CurrentTargetMemoryIndex];
			DetectionHot.CurrentTargetLocation = CurrentMemory.LastKnownLocation;
			DetectionHot.VisionState = EBSSentryVisionState::Tracking;
			return;
		}

		int ReadyTargetMemoryIndex = FindBestVisibleSelectableMemory(DetectionHot.ContactMemory, DetectionHot.TargetAcquireTime, true);
		if (ReadyTargetMemoryIndex >= 0)
		{
			const FBSSentryContactMemory& ReadyMemory = DetectionHot.ContactMemory[ReadyTargetMemoryIndex];
			DetectionHot.CurrentTarget = ReadyMemory.Actor;
			DetectionHot.CurrentTargetLocation = ReadyMemory.LastKnownLocation;
			DetectionHot.VisionState = EBSSentryVisionState::Tracking;
			return;
		}

		bool bCanHoldLostTarget = CurrentTargetMemoryIndex >= 0
			&& DetectionHot.ContactMemory[CurrentTargetMemoryIndex].TimeSinceSelectable <= DetectionHot.ReturnToSweepDelay;
		if (bCanHoldLostTarget)
		{
			DetectionHot.CurrentTargetLocation = DetectionHot.ContactMemory[CurrentTargetMemoryIndex].LastKnownLocation;
			DetectionHot.VisionState = EBSSentryVisionState::LostHold;
			return;
		}

		int AcquiringTargetMemoryIndex = FindBestVisibleSelectableMemory(DetectionHot.ContactMemory, DetectionHot.TargetAcquireTime, false);
		if (AcquiringTargetMemoryIndex >= 0)
		{
			DetectionHot.CurrentTarget = nullptr;
			DetectionHot.CurrentTargetLocation = FVector::ZeroVector;
			DetectionHot.VisionState = EBSSentryVisionState::Acquiring;
			return;
		}

		DetectionHot.CurrentTarget = nullptr;
		DetectionHot.CurrentTargetLocation = FVector::ZeroVector;
		DetectionHot.VisionState = EBSSentryVisionState::Probing;
	}

	/**
	 * Reads: DetectionHot, AimCold
	 * Writes: DetectionHot.ProbeTargetYaw, DetectionHot.ProbeDwellRemaining, DetectionHot.ProbeDirection
	 */
	void UpdateProbeIntent(const FBSRuntimeStore& Store, FBSDetectionHotRow& DetectionHot, float DeltaSeconds)
	{
		bool bSweepState = DetectionHot.VisionState == EBSSentryVisionState::Probing
			|| DetectionHot.VisionState == EBSSentryVisionState::Acquiring;
		if (!bSweepState)
		{
			DetectionHot.ProbeTargetYaw = 0.0f;
			DetectionHot.ProbeDwellRemaining = 0.0f;
			return;
		}

		float HalfArc = DetectionHot.ProbeArcDegrees * 0.5f;
		if (HalfArc <= 0.0f || DetectionHot.ProbeYawSpeed <= 0.0f)
		{
			DetectionHot.ProbeDirection = 1.0f;
			DetectionHot.ProbeTargetYaw = 0.0f;
			DetectionHot.ProbeDwellRemaining = 0.0f;
			return;
		}

		DetectionHot.ProbeTargetYaw = GetProbeEdgeYaw(DetectionHot);
		if (DetectionHot.Links.AimIndex < 0)
		{
			return;
		}

		const FBSAimColdRow& AimCold = Store.AimCold[DetectionHot.Links.AimIndex];
		if (AimCold.Rotator0Component == nullptr)
		{
			return;
		}

		if (HasReachedProbeEdge(AimCold.Rotator0Component.RelativeRotation, DetectionHot.ProbeTargetYaw))
		{
			AdvanceProbeDwell(DetectionHot, DeltaSeconds);
		}
		else
		{
			DetectionHot.ProbeDwellRemaining = 0.0f;
		}
	}

	/**
	 * Reads: no runtime rows
	 * Writes: no runtime rows
	 */
	FLinearColor ResolveLightColor(EBSSentryVisionState VisionState)
	{
		if (VisionState == EBSSentryVisionState::Probing)
		{
			return Sentry::VisorSweepLightColor;
		}

		return Sentry::VisorActiveLightColor;
	}

	/**
	 * Reads: ContactMemory only
	 * Writes: no runtime rows
	 */
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

	/**
	 * Reads: ContactMemory only
	 * Writes: no runtime rows
	 */
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

	/**
	 * Reads: ContactMemory entry only
	 * Writes: no runtime rows
	 */
	bool CanKeepTracking(const FBSSentryContactMemory& Memory)
	{
		return Memory.bVisibleThisUpdate && Memory.bSelectable;
	}

	/**
	 * Reads: BaseRows, DetectionHot, FireHot, AimHot, AimCold
	 * Writes: no runtime rows
	 */
	bool IsSelectableContact(const FBSRuntimeStore& Store,
							 const FBSBaseRuntimeRow& BaseRow,
							 const FBSDetectionHotRow& DetectionHot,
							 const FBSSensedContact& Contact)
	{
		if (!IsDetectorValidContact(BaseRow.Capabilities, DetectionHot, Contact))
		{
			return false;
		}

		if (DetectionHot.Links.FireIndex >= 0)
		{
			const FBSFireHotRow& FireHot = Store.FireHot[DetectionHot.Links.FireIndex];
			if (Contact.Distance > FireHot.MaxDistance)
			{
				return false;
			}
		}

		if (DetectionHot.Links.AimIndex < 0)
		{
			return true;
		}

		float ReachabilityTolerance = 1.0f;
		if (DetectionHot.Links.FireIndex >= 0)
		{
			ReachabilityTolerance = Store.FireHot[DetectionHot.Links.FireIndex].MaxAngleDegrees;
		}

		return SentryAim::PreviewTarget(BaseRow, Store.AimCold[DetectionHot.Links.AimIndex], Store.AimHot[DetectionHot.Links.AimIndex], Contact.WorldLocation, ReachabilityTolerance);
	}

	/**
	 * Reads: BaseRow capabilities, DetectionHot, Contact
	 * Writes: no runtime rows
	 */
	bool IsDetectorValidContact(const FGameplayTagContainer& Capabilities,
								const FBSDetectionHotRow& DetectionHot,
								const FBSSensedContact& Contact)
	{
		if (!Contact.bHasLineOfSight)
		{
			return false;
		}

		switch (DetectionHot.DetectorType)
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

	/**
	 * Reads: DetectionHot.CurrentTarget
	 * Writes: DetectionHot.CurrentTargetLocation
	 */
	void RefreshStateBetweenDetection(FBSDetectionHotRow& DetectionHot)
	{
		if (DetectionHot.VisionState == EBSSentryVisionState::Tracking && DetectionHot.CurrentTarget != nullptr)
		{
			DetectionHot.CurrentTargetLocation = ResolveTrackedTargetLocation(DetectionHot.CurrentTarget);
		}
	}

	/**
	 * Reads: DetectionHot.ProbeArcDegrees, DetectionHot.ProbeDirection
	 * Writes: no runtime rows
	 */
	float GetProbeEdgeYaw(const FBSDetectionHotRow& DetectionHot)
	{
		float HalfArc = DetectionHot.ProbeArcDegrees * 0.5f;
		return DetectionHot.ProbeDirection >= 0.0f ? HalfArc : -HalfArc;
	}

	/**
	 * Reads: no runtime rows
	 * Writes: no runtime rows
	 */
	bool HasReachedProbeEdge(const FRotator& CurrentRotator0, float DesiredEdgeYaw)
	{
		FRotator DesiredRotator = CurrentRotator0;
		DesiredRotator.Yaw = DesiredEdgeYaw;

		FRotator DeltaRotator = (DesiredRotator - CurrentRotator0).GetNormalized();
		return Math::Abs(DeltaRotator.Yaw) <= 1.0f;
	}

	/**
	 * Reads: DetectionHot.ProbeDwellTime
	 * Writes: DetectionHot.ProbeDwellRemaining, DetectionHot.ProbeDirection, DetectionHot.ProbeTargetYaw
	 */
	void AdvanceProbeDwell(FBSDetectionHotRow& DetectionHot, float DeltaSeconds)
	{
		if (DetectionHot.ProbeDwellRemaining <= 0.0f)
		{
			DetectionHot.ProbeDwellRemaining = DetectionHot.ProbeDwellTime;
			if (DetectionHot.ProbeDwellRemaining <= 0.0f)
			{
				FlipProbeDirection(DetectionHot);
			}
			return;
		}

		DetectionHot.ProbeDwellRemaining = Math::Max(DetectionHot.ProbeDwellRemaining - DeltaSeconds, 0.0f);
		if (DetectionHot.ProbeDwellRemaining <= 0.0f)
		{
			FlipProbeDirection(DetectionHot);
		}
	}

	/**
	 * Reads: DetectionHot.ProbeDirection, DetectionHot.ProbeArcDegrees
	 * Writes: DetectionHot.ProbeDirection, DetectionHot.ProbeDwellRemaining, DetectionHot.ProbeTargetYaw
	 */
	void FlipProbeDirection(FBSDetectionHotRow& DetectionHot)
	{
		DetectionHot.ProbeDirection = DetectionHot.ProbeDirection >= 0.0f ? -1.0f : 1.0f;
		DetectionHot.ProbeDwellRemaining = 0.0f;
		DetectionHot.ProbeTargetYaw = GetProbeEdgeYaw(DetectionHot);
	}

	/**
	 * Reads: no runtime rows; uses world trace state only
	 * Writes: no runtime rows
	 */
	bool HasLineOfSight(AActor SensorActor, const FVector& SensorOrigin, const FBSTargetSnapshot& Snapshot)
	{
		TArray<AActor> IgnoredActors;
		IgnoredActors.Add(SensorActor);
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

	/**
	 * Reads: Capabilities, Snapshot
	 * Writes: no runtime rows
	 */
	bool CanRecognizeHostile(const FGameplayTagContainer& Capabilities, const FBSTargetSnapshot& Snapshot)
	{
		if (!Capabilities.HasTag(GameplayTags::Backyard_Capability_TargetRecognition))
		{
			return false;
		}

		return Snapshot.Tags.HasTag(GameplayTags::Backyard_Target_Hostile);
	}

	/**
	 * Reads: BaseRows, DetectionCold
	 * Writes: no runtime rows
	 */
	FVector ResolveSensorOrigin(const FBSBaseRuntimeRow& BaseRow, const FBSDetectionColdRow& DetectionCold)
	{
		USceneComponent SensorComponent = DetectionCold.SensorComponent;
		if (SensorComponent != nullptr)
		{
			if (SensorComponent.DoesSocketExist(Sentry::VisorSocketName))
			{
				return SensorComponent.GetSocketTransform(Sentry::VisorSocketName).Location;
			}

			return SensorComponent.WorldLocation;
		}

		check(BaseRow.Actor != nullptr);
		return BaseRow.Actor.ActorLocation;
	}

	/**
	 * Reads: BaseRows, DetectionCold
	 * Writes: no runtime rows
	 */
	FVector ResolveSensorForward(const FBSBaseRuntimeRow& BaseRow, const FBSDetectionColdRow& DetectionCold)
	{
		USceneComponent SensorComponent = DetectionCold.SensorComponent;
		if (SensorComponent != nullptr)
		{
			if (SensorComponent.DoesSocketExist(Sentry::VisorSocketName))
			{
				return SensorComponent.GetSocketTransform(Sentry::VisorSocketName).Rotation.Rotator().ForwardVector.GetSafeNormal();
			}

			return SensorComponent.WorldRotation.ForwardVector.GetSafeNormal();
		}

		check(BaseRow.Actor != nullptr);
		return BaseRow.Actor.ActorForwardVector;
	}

	/**
	 * Reads: no runtime rows; reads target world snapshots only
	 * Writes: no runtime rows
	 */
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

	/**
	 * Reads: no runtime rows
	 * Writes: no runtime rows
	 */
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
