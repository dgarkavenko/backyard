namespace Systems
{
	namespace Articulation
	{
		const float UnpoweredPitchDegrees = -40.0f;
		const float UnpoweredPitchDuration = 0.9f;
		const EBSFloatTweenPreset UnpoweredPitchEasePreset = EBSFloatTweenPreset::SmoothStep;

		/**
		 * Reads: DetectionHot, ArticulationHot, ArticulationCold
		 * Writes: ArticulationHot target/probe intent
		 */
		void Tick(FBSRuntimeStore& Store, float DeltaSeconds)
		{
			for (int ArticulationIndex = 0; ArticulationIndex < Store.ArticulationHot.Num(); ArticulationIndex++)
			{
				FBSArticulationHotRow& ArticulationHot = Store.ArticulationHot[ArticulationIndex];
				if (!HasPower(Store, ArticulationHot.Links.PowerIndex))
				{
					continue;
				}

				ArticulationHot.bWasPowered = true;
				ArticulationHot.UnpoweredPitchTween.bActive = false;

				const FBSArticulationColdRow& ArticulationCold = Store.ArticulationCold[ArticulationIndex];
				if (ArticulationCold.Rotator0Component == nullptr || ArticulationCold.Rotator1Component == nullptr || ArticulationCold.MuzzleComponent == nullptr)
				{
					continue;
				}

				if (ArticulationHot.Links.DetectionIndex >= 0)
				{
					const FBSDetectionHotRow& DetectionHot = Store.DetectionHot[ArticulationHot.Links.DetectionIndex];
					ArticulationHot.bHasTarget = DetectionHot.VisionState == EBSSentryVisionState::Tracking || DetectionHot.VisionState == EBSSentryVisionState::LostHold;
					ArticulationHot.bUseProbe = DetectionHot.VisionState == EBSSentryVisionState::Probing || DetectionHot.VisionState == EBSSentryVisionState::Acquiring;
					ArticulationHot.bHasConfirmation = DetectionHot.VisionState == EBSSentryVisionState::Tracking;
					ArticulationHot.TargetLocation = DetectionHot.CurrentTargetLocation;
					ArticulationHot.ProbeYawTarget = DetectionHot.ProbeTargetYaw;
				}

				const FBSBaseRuntimeRow& BaseRow = Store.BaseRows[ArticulationHot.OwnerBaseIndex];
				SeedFromComponents(ArticulationCold, ArticulationHot);

				if (ArticulationHot.bHasTarget)
				{
					Solve(BaseRow, ArticulationCold, ArticulationHot, DeltaSeconds);
				}
				else if (ArticulationHot.bUseProbe)
				{
					ApplyProbe(ArticulationCold, ArticulationHot, DeltaSeconds);
				}

				Apply(ArticulationCold, ArticulationHot);
				ReadMuzzle(ArticulationCold, ArticulationHot);
			}
		}

		bool HasPower(const FBSRuntimeStore& Store, int PowerIndex)
		{
			return PowerIndex >= 0 && Store.PowerHot[PowerIndex].bSupplied;
		}

		/**
		 * Reads: ArticulationCold
		 * Writes: ArticulationHot.AppliedRotator0Local, ArticulationHot.AppliedRotator1Local
		 */
		void SeedFromComponents(const FBSArticulationColdRow& ArticulationCold, FBSArticulationHotRow& ArticulationHot)
		{
			check(ArticulationCold.Rotator0Component != nullptr);
			check(ArticulationCold.Rotator1Component != nullptr);

			ArticulationHot.AppliedRotator0Local = ArticulationCold.Rotator0Component.RelativeRotation;
			ArticulationHot.AppliedRotator1Local = ArticulationCold.Rotator1Component.RelativeRotation;
		}

		/**
		 * Reads: BaseRow, ArticulationCold, ArticulationHot target/constraints
		 * Writes: ArticulationHot.AppliedRotator0Local, ArticulationHot.AppliedRotator1Local
		 */
		void Solve(const FBSBaseRuntimeRow& BaseRow, const FBSArticulationColdRow& ArticulationCold, FBSArticulationHotRow& ArticulationHot, float DeltaSeconds)
		{
			check(BaseRow.Actor != nullptr);
			check(BaseRow.Actor.RootComponent != nullptr);
			check(ArticulationCold.Rotator0Component != nullptr);
			check(ArticulationCold.Rotator1Component != nullptr);
			check(ArticulationCold.MuzzleComponent != nullptr);

			FRotator DesiredRotator0;
			FRotator DesiredRotator1;
			ComputeDesiredArticulation(BaseRow, ArticulationCold, ArticulationHot, DesiredRotator0, DesiredRotator1);

			ArticulationHot.AppliedRotator0Local = ConstrainRotation(
				ArticulationHot.AppliedRotator0Local,
				DesiredRotator0,
				ArticulationHot.Rotator0Constraint,
				DeltaSeconds);

			ArticulationHot.AppliedRotator1Local = ConstrainRotation(
				ArticulationHot.AppliedRotator1Local,
				DesiredRotator1,
				ArticulationHot.Rotator1Constraint,
				DeltaSeconds);
		}

		/**
		 * Reads: ArticulationCold, ArticulationHot.ProbeYawTarget, ArticulationHot constraints
		 * Writes: ArticulationHot.AppliedRotator0Local, ArticulationHot.AppliedRotator1Local
		 */
		void ApplyProbe(const FBSArticulationColdRow& ArticulationCold, FBSArticulationHotRow& ArticulationHot, float DeltaSeconds)
		{
			FRotator ProbeYawTarget = ArticulationHot.AppliedRotator0Local;
			ProbeYawTarget.Yaw = ArticulationHot.ProbeYawTarget;

			ArticulationHot.AppliedRotator0Local = ConstrainRotation(
				ArticulationHot.AppliedRotator0Local,
				ProbeYawTarget,
				ArticulationHot.Rotator0Constraint,
				DeltaSeconds);

			ArticulationHot.AppliedRotator1Local = ConstrainRotation(
				ArticulationHot.AppliedRotator1Local,
				FRotator(0, 0, 0),
				ArticulationHot.Rotator1Constraint,
				DeltaSeconds);
		}

		/**
		 * Reads: ArticulationCold, ArticulationHot applied rotations
		 * Writes: no runtime rows; mutates scene components owned by ArticulationCold
		 */
		void Apply(const FBSArticulationColdRow& ArticulationCold, const FBSArticulationHotRow& ArticulationHot)
		{
			check(ArticulationCold.Rotator0Component != nullptr);
			check(ArticulationCold.Rotator1Component != nullptr);

			ArticulationCold.Rotator0Component.SetRelativeRotation(ArticulationHot.AppliedRotator0Local);
			ArticulationCold.Rotator1Component.SetRelativeRotation(ArticulationHot.AppliedRotator1Local);
		}

		void ApplyUnpoweredPose(const FBSArticulationColdRow& ArticulationCold, FBSArticulationHotRow& ArticulationHot, float DeltaSeconds)
		{
			if (ArticulationCold.Rotator0Component == nullptr || ArticulationCold.Rotator1Component == nullptr)
			{
				return;
			}

			ArticulationHot.AppliedRotator0Local = ArticulationCold.Rotator0Component.RelativeRotation;
			ArticulationHot.AppliedRotator1Local = ArticulationCold.Rotator1Component.RelativeRotation;

			FRotator TargetPitchRotation = ComputeConstrainedTarget(
				FRotator(UnpoweredPitchDegrees, 0, 0),
				ArticulationHot.Rotator1Constraint);

			if (ArticulationHot.bWasPowered)
			{
				Systems::Tween::StartFloatTween(
					ArticulationHot.UnpoweredPitchTween,
					ArticulationHot.AppliedRotator1Local.Pitch,
					TargetPitchRotation.Pitch,
					UnpoweredPitchDuration,
					UnpoweredPitchEasePreset);
			}

			ArticulationHot.bWasPowered = false;
			ArticulationHot.AppliedRotator1Local.Pitch = Systems::Tween::StepFloatTween(ArticulationHot.UnpoweredPitchTween, DeltaSeconds);
			ArticulationHot.AppliedRotator1Local = ComputeConstrainedTarget(ArticulationHot.AppliedRotator1Local, ArticulationHot.Rotator1Constraint);

			ArticulationCold.Rotator1Component.SetRelativeRotation(ArticulationHot.AppliedRotator1Local);
		}

		/**
		 * Reads: ArticulationCold, ArticulationHot.TargetLocation
		 * Writes: ArticulationHot.MuzzleWorldLocation, ArticulationHot.MuzzleWorldRotation, ArticulationHot.DistanceToTarget, ArticulationHot.MuzzleError
		 */
		void ReadMuzzle(const FBSArticulationColdRow& ArticulationCold, FBSArticulationHotRow& ArticulationHot)
		{
			check(ArticulationCold.MuzzleComponent != nullptr);
			FTransform MuzzleTransformWorld = ResolveMuzzleTransform(ArticulationCold.MuzzleComponent);
			FVector ToTarget = ArticulationHot.TargetLocation - MuzzleTransformWorld.Location;
			float DistanceToTarget = ToTarget.Size();
			FVector TargetDirection = DistanceToTarget > 0.0f ? ToTarget / DistanceToTarget : FVector::ZeroVector;
			FRotator MuzzleWorldRotation = MuzzleTransformWorld.Rotation.Rotator();

			ArticulationHot.MuzzleWorldLocation = MuzzleTransformWorld.Location;
			ArticulationHot.MuzzleWorldRotation = MuzzleWorldRotation;
			ArticulationHot.DistanceToTarget = DistanceToTarget;
			ArticulationHot.MuzzleError = DistanceToTarget > 0.0f ? (TargetDirection.Rotation() - MuzzleWorldRotation).GetNormalized() : FRotator(0, 0, 0);
		}

		/**
		 * Reads: BaseRow, ArticulationCold, ArticulationHotTemplate
		 * Writes: no runtime rows; evaluates reachability using a local ArticulationHot copy
		 */
		bool PreviewTarget(const FBSBaseRuntimeRow& BaseRow,
						   const FBSArticulationColdRow& ArticulationCold,
						   const FBSArticulationHotRow& ArticulationHotTemplate,
						   const FVector& TargetLocation,
						   float ReachableAngleToleranceDegrees = 1.0f)
		{
			FBSArticulationHotRow PreviewHot = ArticulationHotTemplate;
			SeedFromComponents(ArticulationCold, PreviewHot);
			PreviewHot.bHasTarget = true;
			PreviewHot.TargetLocation = TargetLocation;

			FRotator DesiredRotator0;
			FRotator DesiredRotator1;
			ComputeDesiredArticulation(BaseRow, ArticulationCold, PreviewHot, DesiredRotator0, DesiredRotator1);

			PreviewHot.AppliedRotator0Local = ComputeConstrainedTarget(DesiredRotator0, PreviewHot.Rotator0Constraint);
			PreviewHot.AppliedRotator1Local = ComputeConstrainedTarget(DesiredRotator1, PreviewHot.Rotator1Constraint);
			FVector PreviewMuzzleLocation;
			FRotator PreviewMuzzleRotation;
			BuildPreviewMuzzlePose(BaseRow, ArticulationCold, PreviewHot, PreviewMuzzleLocation, PreviewMuzzleRotation);
			ReadMuzzleFromPose(PreviewMuzzleLocation, PreviewMuzzleRotation, PreviewHot);

			return Math::Abs(PreviewHot.MuzzleError.Yaw) <= ReachableAngleToleranceDegrees && Math::Abs(PreviewHot.MuzzleError.Pitch) <= ReachableAngleToleranceDegrees;
		}

		/**
		 * Reads: no runtime rows; reads component/socket state only
		 * Writes: no runtime rows
		 */
		FTransform ResolveMuzzleTransform(USceneComponent MuzzleComponent)
		{
			check(MuzzleComponent != nullptr);
			if (MuzzleComponent.DoesSocketExist(Sentry::MuzzleSocketName))
			{
				return MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
			}

			return MuzzleComponent.WorldTransform;
		}

		/**
		 * Reads: BaseRow, ArticulationCold, ArticulationHot target/geometry/constraints
		 * Writes: no runtime rows; fills DesiredRotator0/DesiredRotator1
		 */
		void ComputeDesiredArticulation(const FBSBaseRuntimeRow& BaseRow,
							   const FBSArticulationColdRow& ArticulationCold,
							   const FBSArticulationHotRow& ArticulationHot,
							   FRotator& DesiredRotator0,
							   FRotator& DesiredRotator1)
		{
			FVector TargetBaseLocal = BaseRow.Actor.ActorTransform.InverseTransformPosition(ArticulationHot.TargetLocation) - ArticulationCold.Rotator0OffsetLocal;

			float DesiredYaw = SolvePlanarAngle(
				TargetBaseLocal.X,
				TargetBaseLocal.Y,
				ArticulationCold.Rotator1OffsetLocal.Y + ArticulationCold.MuzzleOffsetLocal.Y,
				ArticulationHot.AppliedRotator0Local.Yaw);

			DesiredRotator0 = ArticulationHot.AppliedRotator0Local;
			DesiredRotator0.Yaw = DesiredYaw;

			FQuat DesiredRotator0Quat = FQuat::MakeFromRotator(ComputeConstrainedTarget(DesiredRotator0, ArticulationHot.Rotator0Constraint));
			FVector TargetRotator0Local = DesiredRotator0Quat.Inverse().RotateVector(TargetBaseLocal);
			FVector TargetRotator1Local = TargetRotator0Local - ArticulationCold.Rotator1OffsetLocal;

			float DesiredPitch = SolvePlanarAngle(
				TargetRotator1Local.X,
				TargetRotator1Local.Z,
				ArticulationCold.MuzzleOffsetLocal.Z,
				ArticulationHot.AppliedRotator1Local.Pitch);

			DesiredRotator1 = ArticulationHot.AppliedRotator1Local;
			DesiredRotator1.Pitch = DesiredPitch;
		}

		/**
		 * Reads: BaseRow, ArticulationCold, ArticulationHot
		 * Writes: no runtime rows; fills preview muzzle pose outputs
		 */
		void BuildPreviewMuzzlePose(const FBSBaseRuntimeRow& BaseRow,
									const FBSArticulationColdRow& ArticulationCold,
									const FBSArticulationHotRow& ArticulationHot,
									FVector& PreviewMuzzleLocation,
									FRotator& PreviewMuzzleRotation)
		{
			check(BaseRow.Actor != nullptr);
			check(BaseRow.Actor.RootComponent != nullptr);

			FTransform BaseWorld = BaseRow.Actor.ActorTransform;
			FQuat Rotator0WorldRotation = BaseWorld.Rotation * ArticulationHot.AppliedRotator0Local.Quaternion();
			FVector Rotator0WorldLocation = BaseWorld.TransformPosition(ArticulationCold.Rotator0OffsetLocal);
			FQuat Rotator1WorldRotation = Rotator0WorldRotation * ArticulationHot.AppliedRotator1Local.Quaternion();
			FVector Rotator1WorldLocation = Rotator0WorldLocation + Rotator0WorldRotation.RotateVector(ArticulationCold.Rotator1OffsetLocal);

			PreviewMuzzleLocation = Rotator1WorldLocation + Rotator1WorldRotation.RotateVector(ArticulationCold.MuzzleOffsetLocal);
			PreviewMuzzleRotation = (Rotator1WorldRotation * ArticulationCold.MuzzleLocalRotation).Rotator();
		}

		/**
		 * Reads: ArticulationHot.TargetLocation
		 * Writes: ArticulationHot.MuzzleWorldLocation, ArticulationHot.MuzzleWorldRotation, ArticulationHot.DistanceToTarget, ArticulationHot.MuzzleError
		 */
		void ReadMuzzleFromPose(const FVector& MuzzleWorldLocation, const FRotator& MuzzleWorldRotation, FBSArticulationHotRow& ArticulationHot)
		{
			FVector ToTarget = ArticulationHot.TargetLocation - MuzzleWorldLocation;
			float DistanceToTarget = ToTarget.Size();
			FVector TargetDirection = DistanceToTarget > 0.0f ? ToTarget / DistanceToTarget : FVector::ZeroVector;

			ArticulationHot.MuzzleWorldLocation = MuzzleWorldLocation;
			ArticulationHot.MuzzleWorldRotation = MuzzleWorldRotation;
			ArticulationHot.DistanceToTarget = DistanceToTarget;
			ArticulationHot.MuzzleError = DistanceToTarget > 0.0f ? (TargetDirection.Rotation() - MuzzleWorldRotation).GetNormalized() : FRotator(0, 0, 0);
		}

		/**
		 * Reads: no runtime rows
		 * Writes: no runtime rows
		 */
		float SolvePlanarAngle(float TargetForward, float TargetLateral, float LateralOffset, float FallbackAngle)
		{
			float RadiusSquared = TargetForward * TargetForward + TargetLateral * TargetLateral;
			if (RadiusSquared < 0.0001f)
			{
				return FallbackAngle;
			}

			float ForwardSquared = RadiusSquared - LateralOffset * LateralOffset;
			if (ForwardSquared < 0.0f)
			{
				ForwardSquared = 0.0f;
			}

			float ForwardTerm = Math::Sqrt(ForwardSquared);
			float DirectionForward = (ForwardTerm * TargetForward + LateralOffset * TargetLateral) / RadiusSquared;
			float DirectionLateral = (ForwardTerm * TargetLateral - LateralOffset * TargetForward) / RadiusSquared;
			return Math::RadiansToDegrees(Math::Atan2(DirectionLateral, DirectionForward));
		}

		/**
		 * Reads: no runtime rows; reads constraint only
		 * Writes: no runtime rows
		 */
		FRotator ComputeConstrainedTarget(const FRotator& Target, const FBSSentryConstraint& Constraint)
		{
			FRotator ConstrainedTarget = Target.GetNormalized();
			ConstrainedTarget = MaskRotation(ConstrainedTarget, Constraint);
			ConstrainedTarget = ClampRotation(ConstrainedTarget, Constraint);
			return ConstrainedTarget;
		}

		/**
		 * Reads: no runtime rows; reads constraint only
		 * Writes: no runtime rows
		 */
		FRotator MaskRotation(const FRotator& Rotation, const FBSSentryConstraint& Constraint)
		{
			FRotator Result = Rotation;
			if (!Constraint.bYaw)
			{
				Result.Yaw = 0;
			}
			if (!Constraint.bPitch)
			{
				Result.Pitch = 0;
			}
			if (!Constraint.bRoll)
			{
				Result.Roll = 0;
			}
			return Result;
		}

		/**
		 * Reads: no runtime rows; reads constraint only
		 * Writes: no runtime rows
		 */
		FRotator ClampRotation(const FRotator& Rotation, const FBSSentryConstraint& Constraint)
		{
			float HalfRange = Constraint.RotationRange / 2.0f;
			FRotator Result = Rotation;
			if (Constraint.bYaw)
			{
				Result.Yaw = Math::ClampAngle(Result.Yaw, -HalfRange, HalfRange);
			}
			if (Constraint.bPitch)
			{
				Result.Pitch = Math::ClampAngle(Result.Pitch, -HalfRange, HalfRange);
			}
			if (Constraint.bRoll)
			{
				Result.Roll = Math::ClampAngle(Result.Roll, -HalfRange, HalfRange);
			}
			return Result;
		}

		/**
		 * Reads: no runtime rows; reads constraint only
		 * Writes: no runtime rows
		 */
		FRotator ConstrainRotation(const FRotator& Current,
								   const FRotator& Target,
								   const FBSSentryConstraint& Constraint,
								   float DeltaSeconds,
								   float OverrideRotationSpeed = -1.0f)
		{
			FRotator ConstrainedTarget = ComputeConstrainedTarget(Target, Constraint);
			float RotationSpeed = OverrideRotationSpeed >= 0.0f ? OverrideRotationSpeed : Constraint.RotationSpeed;
			return Math::RInterpConstantTo(Current, ConstrainedTarget, DeltaSeconds, RotationSpeed);
		}
	}
}
