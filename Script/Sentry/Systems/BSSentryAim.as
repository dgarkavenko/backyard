namespace SentryAim
{
	void Update(const FBSSentryBindings& Bindings, FBSSentryTargetingRuntime& TargetingRuntime, float DeltaSeconds)
	{
		ABSSentry Sentry = Bindings.Sentry;
		UBSSentryView Adapter = Bindings.VisualAdapter;
		FVector TargetLocation = TargetingRuntime.TargetLocation;

		if (Adapter == nullptr)
		{
			return;
		}

		if (!Adapter.HasAimRig())
		{
			return;
		}

		USceneComponent Rotator0 = Adapter.RotatorComponents[0];
		USceneComponent Rotator1 = Adapter.RotatorComponents[1];
		FBSSentryConstraint Rotator0Constraint = Adapter.RotatorConstraints.Num() > 0 ? Adapter.RotatorConstraints[0] : FBSSentryConstraint();
		FBSSentryConstraint Rotator1Constraint = Adapter.RotatorConstraints.Num() > 1 ? Adapter.RotatorConstraints[1] : FBSSentryConstraint();

		if (Adapter.bHasYawPitchFastPath)
		{
			UpdateFastYawPitch(Sentry, Adapter, Rotator0, Rotator1, Rotator0Constraint, Rotator1Constraint, TargetLocation, DeltaSeconds);
			return;
		}

		UpdateFallback(Sentry, Adapter, Rotator0, Rotator1, Rotator0Constraint, Rotator1Constraint, TargetLocation, DeltaSeconds);
	}

	void UpdateFastYawPitch(
		ABSSentry Sentry,
		UBSSentryView Adapter,
		USceneComponent Rotator0,
		USceneComponent Rotator1,
		const FBSSentryConstraint& Rotator0Constraint,
		const FBSSentryConstraint& Rotator1Constraint,
		FVector TargetLocation,
		float DeltaSeconds
	)
	{
		FVector TargetBaseLocal = Sentry.Base.WorldTransform.InverseTransformPosition(TargetLocation) - Adapter.RotatorOffsets[0];
		float DesiredYaw = SolvePlanarAngle(TargetBaseLocal.X, TargetBaseLocal.Y, Adapter.CachedYawLateralOffset, Rotator0.RelativeRotation.Yaw);

		FRotator DesiredRotator0 = Rotator0.RelativeRotation;
		DesiredRotator0.Yaw = DesiredYaw;

		FQuat DesiredRotator0Quat = FQuat::MakeFromRotator(ComputeConstrainedTarget(DesiredRotator0, Rotator0Constraint));
		FVector TargetRotator0Local = DesiredRotator0Quat.Inverse().RotateVector(TargetBaseLocal);
		FVector TargetRotator1Local = TargetRotator0Local - Adapter.Rotator1OffsetLocal;

		float DesiredPitch = SolvePlanarAngle(TargetRotator1Local.X, TargetRotator1Local.Z, Adapter.CachedPitchVerticalOffset, Rotator1.RelativeRotation.Pitch);

		FRotator DesiredRotator1 = Rotator1.RelativeRotation;
		DesiredRotator1.Pitch = DesiredPitch;

		FRotator AppliedRotator0 = ConstrainRotation(
			Rotator0.RelativeRotation,
			DesiredRotator0,
			Rotator0Constraint,
			DeltaSeconds
		);
		Rotator0.SetRelativeRotation(AppliedRotator0);

		FRotator AppliedRotator1 = ConstrainRotation(
			Rotator1.RelativeRotation,
			DesiredRotator1,
			Rotator1Constraint,
			DeltaSeconds
		);
		Rotator1.SetRelativeRotation(AppliedRotator1);

		SentryDebugF::LogAimState(Sentry, Adapter, TargetLocation, DesiredRotator0, AppliedRotator0, DesiredRotator1, AppliedRotator1);
	}

	void UpdateFallback(
		ABSSentry Sentry,
		UBSSentryView Adapter,
		USceneComponent Rotator0,
		USceneComponent Rotator1,
		const FBSSentryConstraint& Rotator0Constraint,
		const FBSSentryConstraint& Rotator1Constraint,
		FVector TargetLocation,
		float DeltaSeconds
	)
	{
		FVector Rotator0Offset = Adapter.RotatorOffsets.Num() > 0 ? Adapter.RotatorOffsets[0] : FVector::ZeroVector;
		FVector Rotator1Offset = Adapter.RotatorOffsets.Num() > 1 ? Adapter.RotatorOffsets[1] : FVector::ZeroVector;
		FRotator DesiredRotator0 = Rotator0.RelativeRotation;
		FRotator DesiredRotator1 = Rotator1.RelativeRotation;

		if (Adapter.MuzzleComponent != nullptr)
		{
			for (int Iteration = 0; Iteration < 2; Iteration++)
			{
				DesiredRotator0 = ComputeDesiredRotator0FromFiringOrigin(
					Sentry,
					Adapter,
					Rotator0Offset,
					Rotator1Offset,
					DesiredRotator0,
					DesiredRotator1,
					TargetLocation,
					Rotator0Constraint
				);

				DesiredRotator1 = ComputeDesiredRotator1FromMuzzle(
					Sentry,
					Adapter,
					Rotator0Offset,
					Rotator1Offset,
					DesiredRotator0,
					DesiredRotator1,
					TargetLocation,
					Rotator1Constraint
				);
			}
		}
		else
		{
			DesiredRotator0 = ComputeDesiredRotator0FromFiringOrigin(
				Sentry,
				Adapter,
				Rotator0Offset,
				Rotator1Offset,
				DesiredRotator0,
				DesiredRotator1,
				TargetLocation,
				Rotator0Constraint
			);

			DesiredRotator1 = ComputeDesiredRotator1WithoutMuzzle(
				Sentry,
				Rotator0Offset,
				Rotator1Offset,
				DesiredRotator0,
				TargetLocation,
				Rotator1Constraint
			);
		}

		FRotator AppliedRotator0 = ConstrainRotation(
			Rotator0.RelativeRotation,
			DesiredRotator0,
			Rotator0Constraint,
			DeltaSeconds
		);
		Rotator0.SetRelativeRotation(AppliedRotator0);

		FRotator AppliedRotator1 = ConstrainRotation(
			Rotator1.RelativeRotation,
			DesiredRotator1,
			Rotator1Constraint,
			DeltaSeconds
		);
		Rotator1.SetRelativeRotation(AppliedRotator1);

		SentryDebugF::LogAimState(Sentry, Adapter, TargetLocation, DesiredRotator0, AppliedRotator0, DesiredRotator1, AppliedRotator1);
	}

	FRotator ComputeDesiredRotator0FromFiringOrigin(
		ABSSentry Sentry,
		UBSSentryView Adapter,
		FVector Rotator0Offset,
		FVector Rotator1Offset,
		const FRotator& Rotator0Rotation,
		const FRotator& Rotator1Rotation,
		FVector TargetLocation,
		const FBSSentryConstraint& Rotator0Constraint
	)
	{
		FVector FiringOriginWorld = Adapter.MuzzleComponent != nullptr
			? ComputeMuzzleWorldLocation(Sentry, Adapter, Rotator0Offset, Rotator1Offset, Rotator0Rotation, Rotator1Rotation)
			: ComputeRotator1WorldLocation(Sentry, Rotator0Offset, Rotator1Offset, Rotator0Rotation);
		FVector DirectionToTarget = (TargetLocation - FiringOriginWorld).GetSafeNormal();
		FVector LocalDirection = Sentry.Base.WorldTransform.InverseTransformVector(DirectionToTarget);
		return ComputeConstrainedTarget(LocalDirection.Rotation(), Rotator0Constraint);
	}

	FRotator ComputeDesiredRotator1FromMuzzle(
		ABSSentry Sentry,
		UBSSentryView Adapter,
		FVector Rotator0Offset,
		FVector Rotator1Offset,
		const FRotator& Rotator0Rotation,
		const FRotator& Rotator1Rotation,
		FVector TargetLocation,
		const FBSSentryConstraint& Rotator1Constraint
	)
	{
		FVector MuzzleWorld = ComputeMuzzleWorldLocation(Sentry, Adapter, Rotator0Offset, Rotator1Offset, Rotator0Rotation, Rotator1Rotation);
		FVector DirectionToTarget = (TargetLocation - MuzzleWorld).GetSafeNormal();
		FQuat DesiredSocketWorldRotation = DirectionToTarget.Rotation().Quaternion();
		FQuat DesiredRotator1WorldRotation = DesiredSocketWorldRotation * Adapter.MuzzleLocalRotation.Inverse();
		FQuat DesiredRotator0WorldRotation = ComputeRotator0WorldRotation(Sentry, Rotator0Rotation);
		FQuat DesiredRotator1LocalRotation = DesiredRotator0WorldRotation.Inverse() * DesiredRotator1WorldRotation;
		return ComputeConstrainedTarget(DesiredRotator1LocalRotation.Rotator(), Rotator1Constraint);
	}

	FRotator ComputeDesiredRotator1WithoutMuzzle(
		ABSSentry Sentry,
		FVector Rotator0Offset,
		FVector Rotator1Offset,
		const FRotator& Rotator0Rotation,
		FVector TargetLocation,
		const FBSSentryConstraint& Rotator1Constraint
	)
	{
		FVector Rotator1World = ComputeRotator1WorldLocation(Sentry, Rotator0Offset, Rotator1Offset, Rotator0Rotation);
		FVector DirectionToTarget = (TargetLocation - Rotator1World).GetSafeNormal();
		FQuat Rotator0WorldRotation = ComputeRotator0WorldRotation(Sentry, Rotator0Rotation);
		FVector LocalDirection = Rotator0WorldRotation.Inverse().RotateVector(DirectionToTarget);
		return ComputeConstrainedTarget(LocalDirection.Rotation(), Rotator1Constraint);
	}

	FVector ComputeRotator0WorldLocation(ABSSentry Sentry, FVector Rotator0Offset)
	{
		return Sentry.Base.WorldTransform.TransformPosition(Rotator0Offset);
	}

	FQuat ComputeRotator0WorldRotation(ABSSentry Sentry, const FRotator& Rotator0Rotation)
	{
		return Sentry.Base.WorldRotation.Quaternion() * Rotator0Rotation.Quaternion();
	}

	FVector ComputeRotator1WorldLocation(ABSSentry Sentry, FVector Rotator0Offset, FVector Rotator1Offset, const FRotator& Rotator0Rotation)
	{
		FVector Rotator0WorldLocation = ComputeRotator0WorldLocation(Sentry, Rotator0Offset);
		FQuat Rotator0WorldRotation = ComputeRotator0WorldRotation(Sentry, Rotator0Rotation);
		return Rotator0WorldLocation + Rotator0WorldRotation.RotateVector(Rotator1Offset);
	}

	FQuat ComputeRotator1WorldRotation(ABSSentry Sentry, const FRotator& Rotator0Rotation, const FRotator& Rotator1Rotation)
	{
		FQuat Rotator0WorldRotation = ComputeRotator0WorldRotation(Sentry, Rotator0Rotation);
		return Rotator0WorldRotation * Rotator1Rotation.Quaternion();
	}

	FVector ComputeMuzzleWorldLocation(
		ABSSentry Sentry,
		UBSSentryView Adapter,
		FVector Rotator0Offset,
		FVector Rotator1Offset,
		const FRotator& Rotator0Rotation,
		const FRotator& Rotator1Rotation
	)
	{
		FVector Rotator1WorldLocation = ComputeRotator1WorldLocation(Sentry, Rotator0Offset, Rotator1Offset, Rotator0Rotation);
		FQuat Rotator1WorldRotation = ComputeRotator1WorldRotation(Sentry, Rotator0Rotation, Rotator1Rotation);
		return Rotator1WorldLocation + Rotator1WorldRotation.RotateVector(Adapter.MuzzleOffset);
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
