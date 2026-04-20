namespace Systems
{

	namespace SentryFiring
	{
		/**
		 * Reads: BaseRows, FireHot, AimHot, AimCold, FireCold
		 * Writes: FireHot cooldown, AimHot through shot side effects
		 */
		void Tick(FBSRuntimeStore& Store, float DeltaSeconds)
		{
			for (int FireIndex = 0; FireIndex < Store.FireHot.Num(); FireIndex++)
			{
				FBSFireHotRow& FireHot = Store.FireHot[FireIndex];
				if (FireHot.Links.AimIndex < 0)
				{
					continue;
				}

				const FBSBaseRuntimeRow& BaseRow = Store.BaseRows[FireHot.OwnerBaseIndex];
				const FBSAimHotRow& AimHot = Store.AimHot[FireHot.Links.AimIndex];
				FireHot.ShotCooldownRemaining = Math::Max(FireHot.ShotCooldownRemaining - DeltaSeconds, 0.0f);

				if (AimHot.bHasConfirmation)
				{
					if (CanFire(FireHot, AimHot))
					{
						Shot(BaseRow, Store.AimCold[FireHot.Links.AimIndex], Store.FireCold[FireIndex], Store.AimHot[FireHot.Links.AimIndex]);
						FireHot.ShotCooldownRemaining = FireHot.RPM > 0 ? 60.0f / float(FireHot.RPM) : 0.0f;
					};
				}
			}
		}

		/**
		 * Reads: FireHot, AimHot
		 * Writes: no runtime rows
		 */
		bool CanFire(const FBSFireHotRow& FireHot, const FBSAimHotRow& AimHot)
		{
			if (FireHot.RPM <= 0 || FireHot.ShotCooldownRemaining > 0.0f)
			{
				return false;
			}

			if (AimHot.DistanceToTarget <= 0.0f || AimHot.DistanceToTarget > FireHot.MaxDistance)
			{
				return false;
			}

			return Math::Abs(AimHot.MuzzleError.Yaw) <= FireHot.MaxAngleDegrees && Math::Abs(AimHot.MuzzleError.Pitch) <= FireHot.MaxAngleDegrees;
		}

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
			Projectile.DamageRamp = FVector2D(Turret.ProjectileDamage, Turret.ProjectileDamage);
			Projectile.DistanceRamp = FVector2D(0.0f, Turret.ShootingRules.MaxDistance);

			UBFProjectileSubsystem ProjectileSubsystem = UBFProjectileSubsystem::Get();
			if (ProjectileSubsystem != nullptr)
			{
				ProjectileSubsystem.SpawnProjectile(Projectile);
			}
		}
	}
}