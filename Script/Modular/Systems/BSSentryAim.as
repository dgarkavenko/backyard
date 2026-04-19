namespace SentryAim
{
	/**
	 * Reads: BaseRow, AimCold
	 * Writes: AimHot
	 */
	void Tick(const FBSBaseRuntimeRow& BaseRow, const FBSAimColdRow& AimCold, FBSAimHotRow& AimHot, float DeltaSeconds)
	{
		if (AimCold.Rotator0Component == nullptr || AimCold.Rotator1Component == nullptr || AimCold.MuzzleComponent == nullptr)
		{
			return;
		}

		SeedFromComponents(AimCold, AimHot);

		if (AimHot.bHasAimTarget)
		{
			Solve(BaseRow, AimCold, AimHot, DeltaSeconds);
		}
		else if (AimHot.bUseProbe)
		{
			ApplyProbe(AimCold, AimHot, DeltaSeconds);
		}

		Apply(AimCold, AimHot);
		ReadMuzzle(AimCold, AimHot);
	}

	/**
	 * Reads: AimCold
	 * Writes: AimHot.AppliedRotator0Local, AimHot.AppliedRotator1Local
	 */
	void SeedFromComponents(const FBSAimColdRow& AimCold, FBSAimHotRow& AimHot)
	{
		check(AimCold.Rotator0Component != nullptr);
		check(AimCold.Rotator1Component != nullptr);

		AimHot.AppliedRotator0Local = AimCold.Rotator0Component.RelativeRotation;
		AimHot.AppliedRotator1Local = AimCold.Rotator1Component.RelativeRotation;
	}

	/**
	 * Reads: BaseRow, AimCold, AimHot target/constraints
	 * Writes: AimHot.AppliedRotator0Local, AimHot.AppliedRotator1Local
	 */
	void Solve(const FBSBaseRuntimeRow& BaseRow, const FBSAimColdRow& AimCold, FBSAimHotRow& AimHot, float DeltaSeconds)
	{
		check(BaseRow.Actor != nullptr);
		check(BaseRow.Actor.RootComponent != nullptr);
		check(AimCold.Rotator0Component != nullptr);
		check(AimCold.Rotator1Component != nullptr);
		check(AimCold.MuzzleComponent != nullptr);

		FRotator DesiredRotator0;
		FRotator DesiredRotator1;
		ComputeDesiredAim(BaseRow, AimCold, AimHot, DesiredRotator0, DesiredRotator1);

		AimHot.AppliedRotator0Local = ConstrainRotation(
			AimHot.AppliedRotator0Local,
			DesiredRotator0,
			AimHot.Rotator0Constraint,
			DeltaSeconds);

		AimHot.AppliedRotator1Local = ConstrainRotation(
			AimHot.AppliedRotator1Local,
			DesiredRotator1,
			AimHot.Rotator1Constraint,
			DeltaSeconds);
	}

	/**
	 * Reads: AimCold, AimHot.ProbeYawTarget, AimHot constraints
	 * Writes: AimHot.AppliedRotator0Local, AimHot.AppliedRotator1Local
	 */
	void ApplyProbe(const FBSAimColdRow& AimCold, FBSAimHotRow& AimHot, float DeltaSeconds)
	{
		FRotator ProbeYawTarget = AimHot.AppliedRotator0Local;
		ProbeYawTarget.Yaw = AimHot.ProbeYawTarget;

		AimHot.AppliedRotator0Local = ConstrainRotation(
			AimHot.AppliedRotator0Local,
			ProbeYawTarget,
			AimHot.Rotator0Constraint,
			DeltaSeconds);

		AimHot.AppliedRotator1Local = ConstrainRotation(
			AimHot.AppliedRotator1Local,
			FRotator(0, 0, 0),
			AimHot.Rotator1Constraint,
			DeltaSeconds);
	}

	/**
	 * Reads: AimCold, AimHot applied rotations
	 * Writes: no runtime rows; mutates scene components owned by AimCold
	 */
	void Apply(const FBSAimColdRow& AimCold, const FBSAimHotRow& AimHot)
	{
		check(AimCold.Rotator0Component != nullptr);
		check(AimCold.Rotator1Component != nullptr);

		AimCold.Rotator0Component.SetRelativeRotation(AimHot.AppliedRotator0Local);
		AimCold.Rotator1Component.SetRelativeRotation(AimHot.AppliedRotator1Local);
	}

	/**
	 * Reads: AimCold, AimHot.AimTargetLocation
	 * Writes: AimHot.MuzzleWorldLocation, AimHot.MuzzleWorldRotation, AimHot.DistanceToTarget, AimHot.MuzzleError
	 */
	void ReadMuzzle(const FBSAimColdRow& AimCold, FBSAimHotRow& AimHot)
	{
		check(AimCold.MuzzleComponent != nullptr);
		FTransform MuzzleTransformWorld = ResolveMuzzleTransform(AimCold.MuzzleComponent);
		FVector ToTarget = AimHot.AimTargetLocation - MuzzleTransformWorld.Location;
		float DistanceToTarget = ToTarget.Size();
		FVector TargetDirection = DistanceToTarget > 0.0f ? ToTarget / DistanceToTarget : FVector::ZeroVector;
		FRotator MuzzleWorldRotation = MuzzleTransformWorld.Rotation.Rotator();

		AimHot.MuzzleWorldLocation = MuzzleTransformWorld.Location;
		AimHot.MuzzleWorldRotation = MuzzleWorldRotation;
		AimHot.DistanceToTarget = DistanceToTarget;
		AimHot.MuzzleError = DistanceToTarget > 0.0f
			? (TargetDirection.Rotation() - MuzzleWorldRotation).GetNormalized()
			: FRotator(0, 0, 0);
	}

	/**
	 * Reads: BaseRow, AimCold, AimHotTemplate
	 * Writes: no runtime rows; evaluates reachability using a local AimHot copy
	 */
	bool PreviewTarget(const FBSBaseRuntimeRow& BaseRow,
					   const FBSAimColdRow& AimCold,
					   const FBSAimHotRow& AimHotTemplate,
					   const FVector& TargetLocation,
					   float ReachableAngleToleranceDegrees = 1.0f)
	{
		FBSAimHotRow PreviewHot = AimHotTemplate;
		SeedFromComponents(AimCold, PreviewHot);
		PreviewHot.bHasAimTarget = true;
		PreviewHot.AimTargetLocation = TargetLocation;

		FRotator DesiredRotator0;
		FRotator DesiredRotator1;
		ComputeDesiredAim(BaseRow, AimCold, PreviewHot, DesiredRotator0, DesiredRotator1);

		PreviewHot.AppliedRotator0Local = ComputeConstrainedTarget(DesiredRotator0, PreviewHot.Rotator0Constraint);
		PreviewHot.AppliedRotator1Local = ComputeConstrainedTarget(DesiredRotator1, PreviewHot.Rotator1Constraint);
		FVector PreviewMuzzleLocation;
		FRotator PreviewMuzzleRotation;
		BuildPreviewMuzzlePose(BaseRow, AimCold, PreviewHot, PreviewMuzzleLocation, PreviewMuzzleRotation);
		ReadMuzzleFromPose(PreviewMuzzleLocation, PreviewMuzzleRotation, PreviewHot);

		return Math::Abs(PreviewHot.MuzzleError.Yaw) <= ReachableAngleToleranceDegrees
			&& Math::Abs(PreviewHot.MuzzleError.Pitch) <= ReachableAngleToleranceDegrees;
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
	 * Reads: BaseRow, AimCold, AimHot target/geometry/constraints
	 * Writes: no runtime rows; fills DesiredRotator0/DesiredRotator1
	 */
	void ComputeDesiredAim(const FBSBaseRuntimeRow& BaseRow,
						   const FBSAimColdRow& AimCold,
						   const FBSAimHotRow& AimHot,
						   FRotator& DesiredRotator0,
						   FRotator& DesiredRotator1)
	{
		FVector TargetBaseLocal = BaseRow.Actor.ActorTransform.InverseTransformPosition(AimHot.AimTargetLocation) - AimCold.Rotator0OffsetLocal;

		float DesiredYaw = SolvePlanarAngle(
			TargetBaseLocal.X,
			TargetBaseLocal.Y,
			AimCold.Rotator1OffsetLocal.Y + AimCold.MuzzleOffsetLocal.Y,
			AimHot.AppliedRotator0Local.Yaw
		);

		DesiredRotator0 = AimHot.AppliedRotator0Local;
		DesiredRotator0.Yaw = DesiredYaw;

		FQuat DesiredRotator0Quat = FQuat::MakeFromRotator(ComputeConstrainedTarget(DesiredRotator0, AimHot.Rotator0Constraint));
		FVector TargetRotator0Local = DesiredRotator0Quat.Inverse().RotateVector(TargetBaseLocal);
		FVector TargetRotator1Local = TargetRotator0Local - AimCold.Rotator1OffsetLocal;

		float DesiredPitch = SolvePlanarAngle(
			TargetRotator1Local.X,
			TargetRotator1Local.Z,
			AimCold.MuzzleOffsetLocal.Z,
			AimHot.AppliedRotator1Local.Pitch
		);

		DesiredRotator1 = AimHot.AppliedRotator1Local;
		DesiredRotator1.Pitch = DesiredPitch;
	}

	/**
	 * Reads: BaseRow, AimCold, AimHot
	 * Writes: no runtime rows; fills preview muzzle pose outputs
	 */
	void BuildPreviewMuzzlePose(const FBSBaseRuntimeRow& BaseRow,
								const FBSAimColdRow& AimCold,
								const FBSAimHotRow& AimHot,
								FVector& PreviewMuzzleLocation,
								FRotator& PreviewMuzzleRotation)
	{
		check(BaseRow.Actor != nullptr);
		check(BaseRow.Actor.RootComponent != nullptr);

		FTransform BaseWorld = BaseRow.Actor.ActorTransform;
		FQuat Rotator0WorldRotation = BaseWorld.Rotation * AimHot.AppliedRotator0Local.Quaternion();
		FVector Rotator0WorldLocation = BaseWorld.TransformPosition(AimCold.Rotator0OffsetLocal);
		FQuat Rotator1WorldRotation = Rotator0WorldRotation * AimHot.AppliedRotator1Local.Quaternion();
		FVector Rotator1WorldLocation = Rotator0WorldLocation + Rotator0WorldRotation.RotateVector(AimCold.Rotator1OffsetLocal);

		PreviewMuzzleLocation = Rotator1WorldLocation + Rotator1WorldRotation.RotateVector(AimCold.MuzzleOffsetLocal);
		PreviewMuzzleRotation = (Rotator1WorldRotation * AimCold.MuzzleLocalRotation).Rotator();
	}

	/**
	 * Reads: AimHot.AimTargetLocation
	 * Writes: AimHot.MuzzleWorldLocation, AimHot.MuzzleWorldRotation, AimHot.DistanceToTarget, AimHot.MuzzleError
	 */
	void ReadMuzzleFromPose(const FVector& MuzzleWorldLocation, const FRotator& MuzzleWorldRotation, FBSAimHotRow& AimHot)
	{
		FVector ToTarget = AimHot.AimTargetLocation - MuzzleWorldLocation;
		float DistanceToTarget = ToTarget.Size();
		FVector TargetDirection = DistanceToTarget > 0.0f ? ToTarget / DistanceToTarget : FVector::ZeroVector;

		AimHot.MuzzleWorldLocation = MuzzleWorldLocation;
		AimHot.MuzzleWorldRotation = MuzzleWorldRotation;
		AimHot.DistanceToTarget = DistanceToTarget;
		AimHot.MuzzleError = DistanceToTarget > 0.0f
			? (TargetDirection.Rotation() - MuzzleWorldRotation).GetNormalized()
			: FRotator(0, 0, 0);
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
	FRotator ConstrainRotation(const FRotator& Current, const FRotator& Target, const FBSSentryConstraint& Constraint, float DeltaSeconds)
	{
		FRotator ConstrainedTarget = ComputeConstrainedTarget(Target, Constraint);
		return Math::RInterpConstantTo(Current, ConstrainedTarget, DeltaSeconds, Constraint.RotationSpeed);
	}
}
