namespace SentryAim
{
	void SeedFromComponents(const FBSSentryAimCache& AimCache, FBSSentryTargetingRuntime& TargetingRuntime)
	{
		check(AimCache.Rotator0Component != nullptr);
		check(AimCache.Rotator1Component != nullptr);

		TargetingRuntime.AppliedRotator0Local = AimCache.Rotator0Component.RelativeRotation;
		TargetingRuntime.AppliedRotator1Local = AimCache.Rotator1Component.RelativeRotation;
	}

	void Solve(const FBSSentryStatics& Statics, const FBSSentryAimCache& AimCache, FBSSentryTargetingRuntime& TargetingRuntime, float DeltaSeconds)
	{
		check(Statics.Sentry != nullptr);
		check(Statics.Sentry.Base != nullptr);
		check(AimCache.Rotator0Component != nullptr);
		check(AimCache.Rotator1Component != nullptr);
		check(AimCache.MuzzleComponent != nullptr);

		FRotator DesiredRotator0;
		FRotator DesiredRotator1;
		ComputeDesiredAim(Statics, AimCache, TargetingRuntime, DesiredRotator0, DesiredRotator1);

		TargetingRuntime.AppliedRotator0Local = ConstrainRotation(
			TargetingRuntime.AppliedRotator0Local,
			DesiredRotator0,
			AimCache.Rotator0Constraint,
			DeltaSeconds);

		TargetingRuntime.AppliedRotator1Local = ConstrainRotation(
			TargetingRuntime.AppliedRotator1Local,
			DesiredRotator1,
			AimCache.Rotator1Constraint,
			DeltaSeconds);
	}

	void Apply(const FBSSentryAimCache& AimCache, const FBSSentryTargetingRuntime& TargetingRuntime)
	{
		check(AimCache.Rotator0Component != nullptr);
		check(AimCache.Rotator1Component != nullptr);

		AimCache.Rotator0Component.SetRelativeRotation(TargetingRuntime.AppliedRotator0Local);
		AimCache.Rotator1Component.SetRelativeRotation(TargetingRuntime.AppliedRotator1Local);
	}

	void ReadMuzzle(const FBSSentryAimCache& AimCache, FBSSentryTargetingRuntime& TargetingRuntime)
	{
		check(AimCache.MuzzleComponent != nullptr);
		FTransform MuzzleTransformWorld = ResolveMuzzleTransform(AimCache.MuzzleComponent);
		FVector ToTarget = TargetingRuntime.TargetLocation - MuzzleTransformWorld.Location;
		float DistanceToTarget = ToTarget.Size();
		FVector TargetDirection = DistanceToTarget > 0.0f ? ToTarget / DistanceToTarget : FVector::ZeroVector;
		FRotator MuzzleWorldRotation = MuzzleTransformWorld.Rotation.Rotator();

		TargetingRuntime.MuzzleWorldLocation = MuzzleTransformWorld.Location;
		TargetingRuntime.MuzzleWorldRotation = MuzzleWorldRotation;
		TargetingRuntime.DistanceToTarget = DistanceToTarget;
		TargetingRuntime.MuzzleError = DistanceToTarget > 0.0f
			? (TargetDirection.Rotation() - MuzzleWorldRotation).GetNormalized()
			: FRotator(0, 0, 0);
	}

	bool PreviewTarget(const FBSSentryStatics& Statics,
					   const FBSSentryAimCache& AimCache,
					   const FVector& TargetLocation,
					   FBSSentryTargetingRuntime& PreviewRuntime,
					   float ReachableAngleToleranceDegrees = 1.0f)
	{
		SeedFromComponents(AimCache, PreviewRuntime);
		PreviewRuntime.TargetLocation = TargetLocation;

		FRotator DesiredRotator0;
		FRotator DesiredRotator1;
		ComputeDesiredAim(Statics, AimCache, PreviewRuntime, DesiredRotator0, DesiredRotator1);

		PreviewRuntime.AppliedRotator0Local = ComputeConstrainedTarget(DesiredRotator0, AimCache.Rotator0Constraint);
		PreviewRuntime.AppliedRotator1Local = ComputeConstrainedTarget(DesiredRotator1, AimCache.Rotator1Constraint);
		FVector PreviewMuzzleLocation;
		FRotator PreviewMuzzleRotation;
		BuildPreviewMuzzlePose(Statics, AimCache, PreviewRuntime, PreviewMuzzleLocation, PreviewMuzzleRotation);
		ReadMuzzleFromPose(PreviewMuzzleLocation, PreviewMuzzleRotation, PreviewRuntime);

		return Math::Abs(PreviewRuntime.MuzzleError.Yaw) <= ReachableAngleToleranceDegrees
			&& Math::Abs(PreviewRuntime.MuzzleError.Pitch) <= ReachableAngleToleranceDegrees;
	}

	FTransform ResolveMuzzleTransform(USceneComponent MuzzleComponent)
	{
		check(MuzzleComponent != nullptr);
		if (MuzzleComponent.DoesSocketExist(Sentry::MuzzleSocketName))
		{
			return MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
		}

		return MuzzleComponent.WorldTransform;
	}

	void ComputeDesiredAim(const FBSSentryStatics& Statics,
						   const FBSSentryAimCache& AimCache,
						   const FBSSentryTargetingRuntime& TargetingRuntime,
						   FRotator& DesiredRotator0,
						   FRotator& DesiredRotator1)
	{
		FVector TargetBaseLocal = Statics.Sentry.Base.WorldTransform.InverseTransformPosition(TargetingRuntime.TargetLocation) - AimCache.Rotator0OffsetLocal;

		float DesiredYaw = SolvePlanarAngle(
			TargetBaseLocal.X,
			TargetBaseLocal.Y,
			AimCache.Rotator1OffsetLocal.Y + AimCache.MuzzleOffsetLocal.Y,
			TargetingRuntime.AppliedRotator0Local.Yaw
		);

		DesiredRotator0 = TargetingRuntime.AppliedRotator0Local;
		DesiredRotator0.Yaw = DesiredYaw;

		FQuat DesiredRotator0Quat = FQuat::MakeFromRotator(ComputeConstrainedTarget(DesiredRotator0, AimCache.Rotator0Constraint));
		FVector TargetRotator0Local = DesiredRotator0Quat.Inverse().RotateVector(TargetBaseLocal);
		FVector TargetRotator1Local = TargetRotator0Local - AimCache.Rotator1OffsetLocal;

		float DesiredPitch = SolvePlanarAngle(
			TargetRotator1Local.X,
			TargetRotator1Local.Z,
			AimCache.MuzzleOffsetLocal.Z,
			TargetingRuntime.AppliedRotator1Local.Pitch
		);

		DesiredRotator1 = TargetingRuntime.AppliedRotator1Local;
		DesiredRotator1.Pitch = DesiredPitch;
	}

	void BuildPreviewMuzzlePose(const FBSSentryStatics& Statics,
								const FBSSentryAimCache& AimCache,
								const FBSSentryTargetingRuntime& TargetingRuntime,
								FVector& PreviewMuzzleLocation,
								FRotator& PreviewMuzzleRotation)
	{
		check(Statics.Sentry != nullptr);
		check(Statics.Sentry.Base != nullptr);

		FTransform BaseWorld = Statics.Sentry.Base.WorldTransform;
		FQuat Rotator0WorldRotation = BaseWorld.Rotation * TargetingRuntime.AppliedRotator0Local.Quaternion();
		FVector Rotator0WorldLocation = BaseWorld.TransformPosition(AimCache.Rotator0OffsetLocal);
		FQuat Rotator1WorldRotation = Rotator0WorldRotation * TargetingRuntime.AppliedRotator1Local.Quaternion();
		FVector Rotator1WorldLocation = Rotator0WorldLocation + Rotator0WorldRotation.RotateVector(AimCache.Rotator1OffsetLocal);

		PreviewMuzzleLocation = Rotator1WorldLocation + Rotator1WorldRotation.RotateVector(AimCache.MuzzleOffsetLocal);
		PreviewMuzzleRotation = (Rotator1WorldRotation * AimCache.MuzzleLocalRotation).Rotator();
	}

	void ReadMuzzleFromTransform(const FTransform& MuzzleTransformWorld, FBSSentryTargetingRuntime& TargetingRuntime)
	{
		ReadMuzzleFromPose(MuzzleTransformWorld.Location, MuzzleTransformWorld.Rotation.Rotator(), TargetingRuntime);
	}

	void ReadMuzzleFromPose(const FVector& MuzzleWorldLocation, const FRotator& MuzzleWorldRotation, FBSSentryTargetingRuntime& TargetingRuntime)
	{
		FVector ToTarget = TargetingRuntime.TargetLocation - MuzzleWorldLocation;
		float DistanceToTarget = ToTarget.Size();
		FVector TargetDirection = DistanceToTarget > 0.0f ? ToTarget / DistanceToTarget : FVector::ZeroVector;

		TargetingRuntime.MuzzleWorldLocation = MuzzleWorldLocation;
		TargetingRuntime.MuzzleWorldRotation = MuzzleWorldRotation;
		TargetingRuntime.DistanceToTarget = DistanceToTarget;
		TargetingRuntime.MuzzleError = DistanceToTarget > 0.0f
			? (TargetDirection.Rotation() - MuzzleWorldRotation).GetNormalized()
			: FRotator(0, 0, 0);
	}

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

	FRotator ComputeConstrainedTarget(const FRotator& Target, const FBSSentryConstraint& Constraint)
	{
		FRotator ConstrainedTarget = Target.GetNormalized();
		ConstrainedTarget = MaskRotation(ConstrainedTarget, Constraint);
		ConstrainedTarget = ClampRotation(ConstrainedTarget, Constraint);
		return ConstrainedTarget;
	}

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

	FRotator ConstrainRotation(const FRotator& Current, const FRotator& Target, const FBSSentryConstraint& Constraint, float DeltaSeconds)
	{
		FRotator ConstrainedTarget = ComputeConstrainedTarget(Target, Constraint);
		return Math::RInterpConstantTo(Current, ConstrainedTarget, DeltaSeconds, Constraint.RotationSpeed);
	}
}
