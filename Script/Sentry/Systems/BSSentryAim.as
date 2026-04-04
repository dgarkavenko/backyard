namespace SentryAim
{
	void SeedFromComponents(const FBSSentryAimCache& AimCache, FBSSentryTargetingRuntime& TargetingRuntime)
	{
		if (AimCache.Rotator0Component == nullptr || AimCache.Rotator1Component == nullptr)
		{
			return;
		}

		TargetingRuntime.AppliedRotator0Local = AimCache.Rotator0Component.RelativeRotation;
		TargetingRuntime.AppliedRotator1Local = AimCache.Rotator1Component.RelativeRotation;
	}

	bool Solve(const FBSSentryStatics& Statics, const FBSSentryAimCache& AimCache, FBSSentryTargetingRuntime& TargetingRuntime, float DeltaSeconds)
	{
		if (!AimCache.bHasAimCache || Statics.Sentry == nullptr || Statics.Sentry.Base == nullptr)
		{
			return false;
		}

		FVector TargetBaseLocal = Statics.Sentry.Base.WorldTransform.InverseTransformPosition(TargetingRuntime.TargetLocation) - AimCache.Rotator0OffsetLocal;

		float DesiredYaw = SolvePlanarAngle(
			TargetBaseLocal.X,
			TargetBaseLocal.Y,
			AimCache.Rotator1OffsetLocal.Y + AimCache.MuzzleOffsetLocal.Y,
			TargetingRuntime.AppliedRotator0Local.Yaw
		);

		FRotator DesiredRotator0 = TargetingRuntime.AppliedRotator0Local;
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

		FRotator DesiredRotator1 = TargetingRuntime.AppliedRotator1Local;
		DesiredRotator1.Pitch = DesiredPitch;

		TargetingRuntime.AppliedRotator0Local = ConstrainRotation(
			TargetingRuntime.AppliedRotator0Local,
			DesiredRotator0,
			AimCache.Rotator0Constraint,
			DeltaSeconds
		);

		TargetingRuntime.AppliedRotator1Local = ConstrainRotation(
			TargetingRuntime.AppliedRotator1Local,
			DesiredRotator1,
			AimCache.Rotator1Constraint,
			DeltaSeconds
		);

		return true;
	}

	bool Apply(const FBSSentryAimCache& AimCache, const FBSSentryTargetingRuntime& TargetingRuntime)
	{
		if (AimCache.Rotator0Component == nullptr || AimCache.Rotator1Component == nullptr)
		{
			return false;
		}

		AimCache.Rotator0Component.SetRelativeRotation(TargetingRuntime.AppliedRotator0Local);
		AimCache.Rotator1Component.SetRelativeRotation(TargetingRuntime.AppliedRotator1Local);
		return true;
	}

	bool ReadMuzzle(const FBSSentryAimCache& AimCache, FBSSentryTargetingRuntime& TargetingRuntime)
	{
		if (AimCache.MuzzleComponent == nullptr || !AimCache.MuzzleComponent.DoesSocketExist(Sentry::MuzzleSocketName))
		{
			ResetMuzzle(TargetingRuntime);
			return false;
		}

		FTransform MuzzleSocketWorld = AimCache.MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
		FVector ToTarget = TargetingRuntime.TargetLocation - MuzzleSocketWorld.Location;
		float DistanceToTarget = ToTarget.Size();
		FVector TargetDirection = DistanceToTarget > 0.0f ? ToTarget / DistanceToTarget : FVector::ZeroVector;
		FRotator MuzzleWorldRotation = MuzzleSocketWorld.Rotation.Rotator();

		TargetingRuntime.MuzzleWorldLocation = MuzzleSocketWorld.Location;
		TargetingRuntime.MuzzleWorldRotation = MuzzleWorldRotation;
		TargetingRuntime.DistanceToTarget = DistanceToTarget;
		TargetingRuntime.MuzzleError = DistanceToTarget > 0.0f
			? (TargetDirection.Rotation() - MuzzleWorldRotation).GetNormalized()
			: FRotator(0, 0, 0);

		return true;
	}

	void ResetMuzzle(FBSSentryTargetingRuntime& TargetingRuntime)
	{
		TargetingRuntime.MuzzleWorldLocation = FVector::ZeroVector;
		TargetingRuntime.MuzzleWorldRotation = FRotator(0, 0, 0);
		TargetingRuntime.DistanceToTarget = 0.0f;
		TargetingRuntime.MuzzleError = FRotator(0, 0, 0);
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
