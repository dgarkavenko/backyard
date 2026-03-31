namespace SentryAim
{
	void Update(ABSSentry Sentry, UBSSentryVisualAdapter Adapter, FVector TargetLocation, float DeltaSeconds)
	{
		if (Adapter == nullptr || !Adapter.HasAimRig())
		{
			return;
		}

		USceneComponent Rotator0 = Adapter.RotatorComponents[0];
		USceneComponent Rotator1 = Adapter.RotatorComponents[1];
		FBSSentryConstraint Rotator0Constraint = Adapter.RotatorConstraints.Num() > 0 ? Adapter.RotatorConstraints[0] : FBSSentryConstraint();
		FBSSentryConstraint Rotator1Constraint = Adapter.RotatorConstraints.Num() > 1 ? Adapter.RotatorConstraints[1] : FBSSentryConstraint();
		FVector Rotator0Offset = Adapter.RotatorOffsets.Num() > 0 ? Adapter.RotatorOffsets[0] : FVector::ZeroVector;
		FVector Rotator1Offset = Adapter.RotatorOffsets.Num() > 1 ? Adapter.RotatorOffsets[1] : FVector::ZeroVector;

		FVector Rotator0World = Rotator0.WorldTransform.TransformPosition(Rotator0Offset);
		FVector DirectionToTarget = (TargetLocation - Rotator0World).GetSafeNormal();
		FVector LocalDirection = Sentry.Base.WorldTransform.InverseTransformVector(DirectionToTarget);
		FRotator Constrained = ConstrainRotation(
			Rotator0.RelativeRotation,
			LocalDirection.Rotation(),
			Rotator0Constraint,
			DeltaSeconds
		);

		Rotator0.SetRelativeRotation(Constrained);

		if (Adapter.MuzzleComponent != nullptr)
		{
			FVector MuzzleWorld = Rotator1.WorldTransform.TransformPosition(Adapter.MuzzleOffset);
			DirectionToTarget = (TargetLocation - MuzzleWorld).GetSafeNormal();
			LocalDirection = Rotator0.WorldTransform.InverseTransformVector(DirectionToTarget);
			FRotator DesiredRotation = LocalDirection.Rotation() - Adapter.MuzzleForwardRotation;
			Constrained = ConstrainRotation(
				Rotator1.RelativeRotation,
				DesiredRotation,
				Rotator1Constraint,
				DeltaSeconds
			);
		}
		else
		{
			FVector Rotator1World = Rotator0.WorldTransform.TransformPosition(Rotator1Offset);
			DirectionToTarget = (TargetLocation - Rotator1World).GetSafeNormal();
			LocalDirection = Rotator0.WorldTransform.InverseTransformVector(DirectionToTarget);
			Constrained = ConstrainRotation(
				Rotator1.RelativeRotation,
				LocalDirection.Rotation(),
				Rotator1Constraint,
				DeltaSeconds
			);
		}

		Rotator1.SetRelativeRotation(Constrained);
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
		FRotator ConstrainedTarget = Target.GetNormalized();
		ConstrainedTarget = MaskRotation(ConstrainedTarget, Constraint);
		ConstrainedTarget = ClampRotation(ConstrainedTarget, Constraint);
		return Math::RInterpConstantTo(Current, ConstrainedTarget, DeltaSeconds, Constraint.RotationSpeed);
	}
}
