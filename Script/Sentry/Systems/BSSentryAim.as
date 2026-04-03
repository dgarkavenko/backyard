namespace SentryAim
{
	void SeedRuntime(const FBSSentryAimCache& AimCache, FBSSentryTargetingRuntime& TargetingRuntime)
	{
		ResetRuntime(TargetingRuntime);
		if (!AimCache.bHasAimCache)
		{
			return;
		}

		if (AimCache.Rotator0Component == nullptr || AimCache.Rotator1Component == nullptr)
		{
			return;
		}

		TargetingRuntime.DesiredRotator0Local = AimCache.Rotator0Component.RelativeRotation;
		TargetingRuntime.DesiredRotator1Local = AimCache.Rotator1Component.RelativeRotation;
		TargetingRuntime.AppliedRotator0Local = AimCache.Rotator0Component.RelativeRotation;
		TargetingRuntime.AppliedRotator1Local = AimCache.Rotator1Component.RelativeRotation;
		TargetingRuntime.bHasAimSolution = true;
		UpdateMuzzleRuntime(AimCache, TargetingRuntime);
	}

	void Solve(const FBSSentryAimCache& AimCache, FBSSentryTargetingRuntime& TargetingRuntime, float DeltaSeconds)
	{
		TargetingRuntime.bHasAimSolution = false;
		TargetingRuntime.bHasMuzzleState = false;
		TargetingRuntime.bApplyAim = false;

		if (!AimCache.bHasAimCache)
		{
			return;
		}

		FVector TargetBaseLocal = AimCache.BaseWorldTransform.InverseTransformPosition(TargetingRuntime.TargetLocation) - AimCache.Rotator0OffsetLocal;
		float DesiredYaw = SolvePlanarAngle(
			TargetBaseLocal.X,
			TargetBaseLocal.Y,
			AimCache.CachedYawLateralOffset,
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
			AimCache.CachedPitchVerticalOffset,
			TargetingRuntime.AppliedRotator1Local.Pitch
		);

		FRotator DesiredRotator1 = TargetingRuntime.AppliedRotator1Local;
		DesiredRotator1.Pitch = DesiredPitch;

		TargetingRuntime.DesiredRotator0Local = DesiredRotator0;
		TargetingRuntime.DesiredRotator1Local = DesiredRotator1;
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
		TargetingRuntime.bHasAimSolution = true;
		TargetingRuntime.bApplyAim = true;
		UpdateMuzzleRuntime(AimCache, TargetingRuntime);
	}

	void Apply(const FBSSentryAimCache& AimCache, FBSSentryTargetingRuntime& TargetingRuntime)
	{
		if (!AimCache.bHasAimCache || !TargetingRuntime.bApplyAim)
		{
			return;
		}

		if (AimCache.Rotator0Component == nullptr || AimCache.Rotator1Component == nullptr)
		{
			TargetingRuntime.bApplyAim = false;
			return;
		}

		AimCache.Rotator0Component.SetRelativeRotation(TargetingRuntime.AppliedRotator0Local);
		AimCache.Rotator1Component.SetRelativeRotation(TargetingRuntime.AppliedRotator1Local);
		TargetingRuntime.bApplyAim = false;
	}

	void ResetRuntime(FBSSentryTargetingRuntime& TargetingRuntime)
	{
		TargetingRuntime.DesiredRotator0Local = FRotator(0, 0, 0);
		TargetingRuntime.DesiredRotator1Local = FRotator(0, 0, 0);
		TargetingRuntime.AppliedRotator0Local = FRotator(0, 0, 0);
		TargetingRuntime.AppliedRotator1Local = FRotator(0, 0, 0);
		TargetingRuntime.MuzzleWorldLocation = FVector::ZeroVector;
		TargetingRuntime.MuzzleWorldRotation = FRotator(0, 0, 0);
		TargetingRuntime.MuzzleError = FRotator(0, 0, 0);
		TargetingRuntime.DistanceToTarget = 0.0f;
		TargetingRuntime.AimDot = 0.0f;
		TargetingRuntime.bHasAimSolution = false;
		TargetingRuntime.bHasMuzzleState = false;
		TargetingRuntime.bApplyAim = false;
	}

	void UpdateMuzzleRuntime(const FBSSentryAimCache& AimCache, FBSSentryTargetingRuntime& TargetingRuntime)
	{
		TargetingRuntime.bHasMuzzleState = false;

		if (!AimCache.bHasAimCache)
		{
			return;
		}

		FVector Rotator0WorldLocation = AimCache.BaseWorldTransform.TransformPosition(AimCache.Rotator0OffsetLocal);
		FQuat Rotator0WorldRotation = AimCache.BaseWorldRotation * TargetingRuntime.AppliedRotator0Local.Quaternion();
		FVector Rotator1WorldLocation = Rotator0WorldLocation + Rotator0WorldRotation.RotateVector(AimCache.Rotator1OffsetLocal);
		FQuat Rotator1WorldRotation = Rotator0WorldRotation * TargetingRuntime.AppliedRotator1Local.Quaternion();
		FVector MuzzleWorldLocation = Rotator1WorldLocation + Rotator1WorldRotation.RotateVector(AimCache.MuzzleOffsetLocal);
		FQuat MuzzleWorldRotation = Rotator1WorldRotation * AimCache.MuzzleLocalRotation;
		FVector ToTarget = TargetingRuntime.TargetLocation - MuzzleWorldLocation;
		float DistanceToTarget = ToTarget.Size();
		FVector MuzzleForward = MuzzleWorldRotation.Rotator().ForwardVector.GetSafeNormal();
		FVector TargetDirection = DistanceToTarget > 0.0f ? ToTarget / DistanceToTarget : FVector::ZeroVector;

		TargetingRuntime.MuzzleWorldLocation = MuzzleWorldLocation;
		TargetingRuntime.MuzzleWorldRotation = MuzzleWorldRotation.Rotator();
		TargetingRuntime.DistanceToTarget = DistanceToTarget;
		TargetingRuntime.AimDot = DistanceToTarget > 0.0f ? MuzzleForward.DotProduct(TargetDirection) : 0.0f;
		TargetingRuntime.MuzzleError = DistanceToTarget > 0.0f
			? (TargetDirection.Rotation() - MuzzleForward.Rotation()).GetNormalized()
			: FRotator(0, 0, 0);
		TargetingRuntime.bHasMuzzleState = true;
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
