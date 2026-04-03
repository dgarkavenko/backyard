namespace SentryShoot
{
	void Update(const FBSSentryStatics& Statics, const FBSSentryAimCache& AimCache, FBSSentryTargetingRuntime& TargetingRuntime, FBSSentryCombatRuntime& CombatRuntime)
	{
		ABSSentry Sentry = Statics.Sentry;
		UBSTurretDefinition Turret = Statics.Turret;
		FVector TargetLocation = TargetingRuntime.TargetLocation;

		if (Sentry == nullptr || Turret == nullptr)
		{
			return;
		}

		if (Turret.RPM <= 0)
		{
			return;
		}

		CombatRuntime.ShotCooldownRemaining = 60.0f / float(Turret.RPM);

		if (!TargetingRuntime.bHasMuzzleState)
		{
			return;
		}

		FVector MuzzleLocation = TargetingRuntime.MuzzleWorldLocation;
		FVector ToTarget = TargetLocation - MuzzleLocation;
		float DistanceToTarget = TargetingRuntime.DistanceToTarget;
		if (DistanceToTarget <= 0.0f || DistanceToTarget > Turret.ShootingRules.MaxDistance)
		{
			return;
		}

		float DeltaYaw = TargetingRuntime.MuzzleError.Yaw;
		if (DeltaYaw < 0.0f)
		{
			DeltaYaw = -DeltaYaw;
		}

		float DeltaPitch = TargetingRuntime.MuzzleError.Pitch;
		if (DeltaPitch < 0.0f)
		{
			DeltaPitch = -DeltaPitch;
		}

		if (DeltaYaw > Turret.ShootingRules.MaxAngleDegrees
			|| DeltaPitch > Turret.ShootingRules.MaxAngleDegrees)
		{
			return;
		}

		SpawnPrimaryProjectile(MuzzleLocation, TargetingRuntime.MuzzleWorldRotation.ForwardVector, Sentry);

		MuzzleLocation += TargetingRuntime.MuzzleWorldRotation.RotateVector(FVector(5,0,0));

		if (Turret.ShotEffect_NS.IsValid() && AimCache.MuzzleComponent != nullptr)
		{
			Niagara::SpawnSystemAttached(Turret.ShotEffect_NS.Get(),
										 AimCache.MuzzleComponent,
										 NAME_None,
										 MuzzleLocation,
										 TargetingRuntime.MuzzleWorldRotation,
										 EAttachLocation::KeepWorldPosition,
										 true,
										 true,
										 ENCPoolMethod::AutoRelease);
		}

		if (Turret.ShotEffect_NDC.IsValid())
		{
			const FNiagaraDataChannelSearchParameters SearchParameters;
			UNiagaraDataChannelWriter Writer = NiagaraDataChannel::WriteToNiagaraDataChannel(Turret.ShotEffect_NDC.Get(), SearchParameters, 1, false, true, true, "Fire NDC Write");
			Writer.WritePosition(n"Location", 0, MuzzleLocation);
			Writer.WriteQuat(n"Rotation", 0, TargetingRuntime.MuzzleWorldRotation.Quaternion());
		}
	}

	void SpawnPrimaryProjectile(FVector Origin, FVector Direction, AActor Causer)
	{
		if (Causer == nullptr)
		{
			return;
		}

		FBFProjectileSpawnParams Projectile;

		Projectile.DragType = EBFProjectileDrag::VeryLow;
		Projectile.Instigator = nullptr;
		Projectile.Causer = Causer;
		Projectile.Lifetime = 10;
		Projectile.Position = Origin;
		Projectile.Velocity = Direction.GetSafeNormal() * 5030 * 10;

		auto BFProjectileSubsystem = UBFProjectileSubsystem::Get();
		if (BFProjectileSubsystem != nullptr)
		{
			BFProjectileSubsystem.SpawnProjectile(Projectile);
		}
	}
}
