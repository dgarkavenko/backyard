namespace Sentry
{
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
		FRotator ConstrainedTarget = Target.GetNormalized();
		ConstrainedTarget = MaskRotation(ConstrainedTarget, Constraint);
		ConstrainedTarget = ClampRotation(ConstrainedTarget, Constraint);
		return Math::RInterpConstantTo(Current, ConstrainedTarget, DeltaSeconds, Constraint.RotationSpeed);
	}
}
