namespace SentryShoot
{
	void Update(ABSSentry Sentry, UBSSentryVisualAdapter Adapter, UBSTurretDefinition Turret, FVector TargetLocation, float& ShotCooldownRemaining)
	{
		ShotCooldownRemaining = 60.0f / float(Turret.RPM);

		if (Turret.RPM <= 0 || Adapter.MuzzleComponent == nullptr || !Adapter.MuzzleComponent.DoesSocketExist(Sentry::MuzzleSocketName))
		{
			return;
		}

		FTransform MuzzleSocketWorld = Adapter.MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
		FVector MuzzleLocation = MuzzleSocketWorld.Location;
		FVector ToTarget = TargetLocation - MuzzleLocation;
		float DistanceToTarget = ToTarget.Size();
		if (DistanceToTarget <= 0.0f || DistanceToTarget > Turret.ShootingRules.MaxDistance)
		{
			return;
		}

		FVector TargetDirection = ToTarget / DistanceToTarget;
		FRotator CurrentRotation = MuzzleSocketWorld.Rotation.ForwardVector.Rotation();
		FRotator DesiredRotation = TargetDirection.Rotation();
		FRotator DeltaRotation = (DesiredRotation - CurrentRotation).GetNormalized();
		float DeltaYaw = DeltaRotation.Yaw;
		if (DeltaYaw < 0.0f)
		{
			DeltaYaw = -DeltaYaw;
		}

		float DeltaPitch = DeltaRotation.Pitch;
		if (DeltaPitch < 0.0f)
		{
			DeltaPitch = -DeltaPitch;
		}

		if (DeltaYaw > Turret.ShootingRules.MaxAngleDegrees
			|| DeltaPitch > Turret.ShootingRules.MaxAngleDegrees)
		{
			return;
		}

		SpawnPrimaryProjectile(MuzzleLocation, MuzzleSocketWorld.Rotation.ForwardVector, Sentry);

		MuzzleLocation += Adapter.MuzzleComponent.WorldRotation.RotateVector(FVector(5,0,0)); 

		if (Turret.ShotEffect_NS.IsValid())
		{
			Niagara::SpawnSystemAttached(Turret.ShotEffect_NS.Get(),
										 Adapter.MuzzleComponent,
										 NAME_None,
										 MuzzleLocation,
										 Adapter.MuzzleComponent.WorldRotation,
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
			Writer.WriteQuat(n"Rotation", 0, Adapter.MuzzleComponent.WorldRotation.Quaternion());
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
