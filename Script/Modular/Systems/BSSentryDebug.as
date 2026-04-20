namespace Systems
{
	namespace Debug
	{
		const FConsoleVariable ShowSockets(f"BF.Sentry.ShowSockets", 1);
		const FConsoleVariable ShowArticulation(f"BF.Sentry.ShowArticulation", 0);
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

		void DrawSlotSocket(UBSModularView View, UBSModularComponent ModularComponent, int SlotIndex, FLinearColor Color, float PointSize = 10.0f)
		{
			if (ModularComponent == nullptr || SlotIndex < 0 || SlotIndex >= ModularComponent.Slots.Num())
			{
				return;
			}

			const FBSSlotRuntime& Slot = ModularComponent.Slots[SlotIndex];
			USceneComponent SocketOwner = ResolveSlotSocketOwner(View, Slot);
			if (SocketOwner == nullptr)
			{
				return;
			}

			FTransform SocketTransform = ResolveSlotSocketTransform(SocketOwner, Slot);
			FVector BaseSocketLocation = SocketTransform.Location;
			FVector SocketOffset = ResolveSlotSocketOverlapOffset(View, ModularComponent, SlotIndex, BaseSocketLocation);
			FVector SocketLocation = BaseSocketLocation + SocketOffset;

			if (!SocketOffset.IsNearlyZero())
			{
				System::DrawDebugLine(BaseSocketLocation, SocketLocation, FLinearColor::White / 2, 0, 0.75f);
			}

			System::DrawDebugPoint(SocketLocation, PointSize, Color, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);

			FName SocketName = Slot.SlotData.Socket;
			bool bHasSocket = SocketName != NAME_None && SocketOwner.DoesSocketExist(SocketName);
			bool bMissingNamedSocket = SocketName != NAME_None && !bHasSocket;
			if (bMissingNamedSocket)
			{
				System::DrawDebugPoint(SocketLocation, 18.0f, FLinearColor(1.0f, 0.25f, 0.25f, 0.9f), 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
			}
		}

		FTransform ResolveSlotSocketTransform(USceneComponent SocketOwner, const FBSSlotRuntime& Slot)
		{
			if (SocketOwner == nullptr)
			{
				return FTransform();
			}

			FName SocketName = Slot.SlotData.Socket;
			if (SocketName != NAME_None && SocketOwner.DoesSocketExist(SocketName))
			{
				return SocketOwner.GetSocketTransform(SocketName);
			}

			return SocketOwner.WorldTransform;
		}

		FVector ResolveSlotSocketOverlapOffset(UBSModularView View,
											   UBSModularComponent ModularComponent,
											   int SlotIndex,
											   const FVector& SocketLocation)
		{
			if (ModularComponent == nullptr)
			{
				return FVector::ZeroVector;
			}

			const float OverlapToleranceSquared = 1.0f;
			const float MarkerSpacing = 3.0f;
			int OverlapCount = 0;
			int OverlapOrdinal = 0;

			for (int OtherSlotIndex = 0; OtherSlotIndex < ModularComponent.Slots.Num(); OtherSlotIndex++)
			{
				USceneComponent OtherSocketOwner = ResolveSlotSocketOwner(View, ModularComponent.Slots[OtherSlotIndex]);
				if (OtherSocketOwner == nullptr)
				{
					continue;
				}

				FVector OtherSocketLocation = ResolveSlotSocketTransform(OtherSocketOwner, ModularComponent.Slots[OtherSlotIndex]).Location;
				if ((OtherSocketLocation - SocketLocation).SizeSquared() > OverlapToleranceSquared)
				{
					continue;
				}

				if (OtherSlotIndex < SlotIndex)
				{
					OverlapOrdinal++;
				}

				OverlapCount++;
			}

			if (OverlapCount <= 1)
			{
				return FVector::ZeroVector;
			}

			return FVector::UpVector * (OverlapOrdinal * MarkerSpacing);
		}

		USceneComponent ResolveSlotSocketOwner(UBSModularView View, const FBSSlotRuntime& Slot)
		{
			if (View == nullptr)
			{
				return nullptr;
			}

			if (Slot.ParentIndex.IsSet() && Slot.ParentIndex.Value >= 0 && Slot.ParentIndex.Value < View.Build.Num())
			{
				USceneComponent ParentSocketOwner = ModularAssembly::FindBuiltSocketOwner(View.Build[Slot.ParentIndex.Value], Slot.SlotData.Socket);
				if (ParentSocketOwner != nullptr)
				{
					return ParentSocketOwner;
				}

				USceneComponent ParentPrimaryComponent = View.Build[Slot.ParentIndex.Value].PrimaryComponent;
				if (ParentPrimaryComponent != nullptr)
				{
					return ParentPrimaryComponent;
				}
			}

			AActor Owner = View.Owner;
			return Owner != nullptr ? Owner.RootComponent : nullptr;
		}

		void Tick(FBSRuntimeStore& Store)
		{
			if (Debug::ShowArticulation.Int > 0)
			{
				for (int ArticulationIndex = 0; ArticulationIndex < Store.ArticulationHot.Num(); ArticulationIndex++)
				{
					Debug::DrawArticulation(Store.ArticulationHot[ArticulationIndex]);
				}
			}

			if (Debug::ShowVision.Int > 0)
			{
				for (int DetectionIndex = 0; DetectionIndex < Store.DetectionHot.Num(); DetectionIndex++)
				{
					const FBSDetectionHotRow& DetectionHot = Store.DetectionHot[DetectionIndex];
					const FBSDetectionColdRow& DetectionCold = Store.DetectionCold[DetectionIndex];
					const FBSBaseRuntimeRow& BaseRow = Store.BaseRows[DetectionHot.OwnerBaseIndex];
					FBSArticulationColdRow ArticulationCold;
					FBSArticulationHotRow ArticulationHot;
					bool bHasArticulation = BaseRow.ArticulationIndex >= 0;
					if (bHasArticulation)
					{
						ArticulationCold = Store.ArticulationCold[BaseRow.ArticulationIndex];
						ArticulationHot = Store.ArticulationHot[BaseRow.ArticulationIndex];
					}

					Debug::DrawVision(Store, BaseRow, DetectionHot, DetectionCold, ArticulationCold, ArticulationHot, bHasArticulation);
				}
			}
		}

		void DrawArticulation(const FBSArticulationHotRow& ArticulationHot)
		{
			FVector MuzzleLocation = ArticulationHot.MuzzleWorldLocation;
			float DistanceToTarget = ArticulationHot.DistanceToTarget;
			FVector MuzzleForward = ArticulationHot.MuzzleWorldRotation.ForwardVector.GetSafeNormal();

			System::DrawDebugLine(MuzzleLocation, ArticulationHot.TargetLocation, FLinearColor::Yellow, 0, 2);
			System::DrawDebugLine(MuzzleLocation, MuzzleLocation + MuzzleForward * DistanceToTarget, FLinearColor::Blue, 0, 2);
			System::DrawDebugPoint(ArticulationHot.TargetLocation, 12.0f, FLinearColor::Yellow, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
		}

		void DrawVision(const FBSRuntimeStore& Store,
						const FBSBaseRuntimeRow& BaseRow,
						const FBSDetectionHotRow& DetectionHot,
						const FBSDetectionColdRow& DetectionCold,
						const FBSArticulationColdRow& ArticulationCold,
						const FBSArticulationHotRow& ArticulationHot,
						bool bHasArticulation)
		{
			FVector SensorOrigin = Systems::SentryVision::ResolveSensorOrigin(BaseRow, DetectionCold);
			FVector SensorForward = Systems::SentryVision::ResolveSensorForward(BaseRow, DetectionCold);
			float VisionRange = DetectionHot.Range;

			if (ShowVision.Int >= 1)
			{
				DrawTargetables(BaseRow);
			}

			if (ShowVision.Int >= 2)
			{
				DrawVisionCandidates(BaseRow, DetectionHot, SensorOrigin, SensorForward, VisionRange);
				DrawVisionSector(BaseRow, DetectionHot, ArticulationCold, SensorOrigin, SensorForward, VisionRange, bHasArticulation);
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

				FLinearColor ContactColor = bIsCurrentTarget ? FLinearColor::Red : (Memory.bSelectable ? FLinearColor::Yellow : FLinearColor::Green);
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
			const FVector HorizontalSensorForward = Systems::SentryVision::ResolveHorizontalDirection(SensorForward, FVector::ForwardVector);
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

				FVector HorizontalTargetDirection = Systems::SentryVision::ResolveHorizontalDirection(ToTarget, HorizontalSensorForward);
				if (HorizontalSensorForward.DotProduct(HorizontalTargetDirection) < MinimumDot)
				{
					continue;
				}

				bool bHasLineOfSight = Systems::SentryVision::HasLineOfSight(BaseRow.Actor, SensorOrigin, Snapshot);
				FLinearColor CandidateDrawColor = bHasLineOfSight ? CandidateColor : FailedLineOfSightColor;
				float PointSize = bHasLineOfSight ? 8.0f : 10.0f;

				System::DrawDebugPoint(Snapshot.WorldLocation, PointSize, CandidateDrawColor, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
			}
		}

		void DrawVisionSector(const FBSBaseRuntimeRow& BaseRow,
							  const FBSDetectionHotRow& DetectionHot,
							  const FBSArticulationColdRow& ArticulationCold,
							  const FVector& SensorOrigin,
							  const FVector& SensorForward,
							  float VisionRange,
							  bool bHasArticulation)
		{
			FVector SectorOrigin = ArticulationCold.Rotator0Component != nullptr ? ArticulationCold.Rotator0Component.WorldLocation : SensorOrigin;
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

			if (!bHasArticulation)
			{
				return;
			}

			FVector NeutralForward = BaseRow.Actor != nullptr && BaseRow.Actor.RootComponent != nullptr ? FVector(BaseRow.Actor.ActorRotation.ForwardVector.X, BaseRow.Actor.ActorRotation.ForwardVector.Y, 0.0f).GetSafeNormal() : HorizontalForward;
			if (NeutralForward.IsNearlyZero())
			{
				NeutralForward = HorizontalForward;
			}

			float HalfYawLimitDegrees = ArticulationCold.Rotator0Component != nullptr ? StoreYawHalfRangeHint(ArticulationCold) : 0.0f;
			FVector LeftYawLimitDirection = FQuat(FVector::UpVector, Math::DegreesToRadians(-HalfYawLimitDegrees)).RotateVector(NeutralForward);
			FVector RightYawLimitDirection = FQuat(FVector::UpVector, Math::DegreesToRadians(HalfYawLimitDegrees)).RotateVector(NeutralForward);
			System::DrawDebugLine(SectorOrigin, SectorOrigin + LeftYawLimitDirection * VisionRange, FLinearColor::Red, 0, 2.0f);
			System::DrawDebugLine(SectorOrigin, SectorOrigin + RightYawLimitDirection * VisionRange, FLinearColor::Red, 0, 2.0f);
		}

		float StoreYawHalfRangeHint(const FBSArticulationColdRow& ArticulationCold)
		{
			if (ArticulationCold.Chassis == nullptr || ArticulationCold.Chassis.Rotators.Num() < 1)
			{
				return 0.0f;
			}

			return ArticulationCold.Chassis.Rotators[0].Constraint.RotationRange * 0.5f;
		}
	}
}
