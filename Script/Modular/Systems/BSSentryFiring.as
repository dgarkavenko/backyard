namespace SentryFiring
{
	/**
	 * Reads: BaseRow, AimCold, FireCold, AimHot
	 * Writes: AimHot (none intentional; passed mutable for call-site convenience)
	 */
	void Shot(const FBSBaseRuntimeRow& BaseRow, const FBSAimColdRow& AimCold, const FBSFireColdRow& FireCold, FBSAimHotRow& AimHot)
	{
		UBSTurretDefinition Turret = FireCold.Turret;
		check(Turret != nullptr);
		check(AimCold.MuzzleComponent != nullptr);

		FVector MuzzleLocation = AimHot.MuzzleWorldLocation;
		MuzzleLocation += AimHot.MuzzleWorldRotation.RotateVector(FVector(5, 0, 0));

		if (Turret.ShotEffect_NS.IsValid())
		{
			Niagara::SpawnSystemAttached(Turret.ShotEffect_NS.Get(),
										 AimCold.MuzzleComponent,
										 NAME_None,
										 MuzzleLocation,
										 AimHot.MuzzleWorldRotation,
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
			Writer.WriteQuat(n"Rotation", 0, AimHot.MuzzleWorldRotation.Quaternion());
		}

		FBFProjectileSpawnParams Projectile;
		Projectile.DragType = EBFProjectileDrag::VeryLow;
		Projectile.Instigator = nullptr;
		Projectile.Causer = BaseRow.Actor;
		Projectile.Lifetime = 10;
		Projectile.Position = MuzzleLocation;
		Projectile.Velocity = AimHot.MuzzleWorldRotation.ForwardVector * 300 * 100;

		UBFProjectileSubsystem ProjectileSubsystem = UBFProjectileSubsystem::Get();
		if (ProjectileSubsystem != nullptr)
		{
			ProjectileSubsystem.SpawnProjectile(Projectile);
		}
	}
}
