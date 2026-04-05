namespace SentryFiring
{
	void Shot(const FBSSentryStatics& Statics, const FBSSentryAimCache& AimCache, FBSSentryTargetingRuntime& TargetingRuntime)
	{
		ABSSentry Sentry = Statics.Sentry;
		UBSTurretDefinition Turret = Statics.Turret;
		check(Sentry != nullptr);
		check(Turret != nullptr);
		check(AimCache.MuzzleComponent != nullptr);

		FVector MuzzleLocation = TargetingRuntime.MuzzleWorldLocation;		
		
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


		FBFProjectileSpawnParams Projectile;

		Projectile.DragType = EBFProjectileDrag::VeryLow;
		Projectile.Instigator = nullptr;
		Projectile.Causer = Sentry;
		Projectile.Lifetime = 10;
		Projectile.Position = MuzzleLocation;
		Projectile.Velocity = TargetingRuntime.MuzzleWorldRotation.ForwardVector * 300 * 100;

		auto BFProjectileSubsystem = UBFProjectileSubsystem::Get();
		if (BFProjectileSubsystem != nullptr)
		{
			BFProjectileSubsystem.SpawnProjectile(Projectile);
		}
	}
}
