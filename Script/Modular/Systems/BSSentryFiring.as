namespace Systems
{

	namespace SentryFiring
	{
		/**
		 * Reads: BaseRows, FireHot, ArticulationHot, ArticulationCold, FireCold
		 * Writes: FireHot cooldown, ArticulationHot through shot side effects
		 */
		void Tick(FBSRuntimeStore& Store, float DeltaSeconds)
		{
			for (int FireIndex = 0; FireIndex < Store.FireHot.Num(); FireIndex++)
			{
				FBSFireHotRow& FireHot = Store.FireHot[FireIndex];
				if (!HasPower(Store, FireHot.Links.PowerIndex) || FireHot.Links.ArticulationIndex < 0)
				{
					continue;
				}

				const FBSBaseRuntimeRow& BaseRow = Store.BaseRows[FireHot.OwnerBaseIndex];
				const FBSArticulationHotRow& ArticulationHot = Store.ArticulationHot[FireHot.Links.ArticulationIndex];
				FireHot.ShotCooldownRemaining = Math::Max(FireHot.ShotCooldownRemaining - DeltaSeconds, 0.0f);

				if (ArticulationHot.bHasConfirmation)
				{
					if (CanFire(FireHot, ArticulationHot))
					{
						Shot(BaseRow, Store.ArticulationCold[FireHot.Links.ArticulationIndex], Store.FireCold[FireIndex], Store.ArticulationHot[FireHot.Links.ArticulationIndex]);
						FireHot.ShotCooldownRemaining = FireHot.RPM > 0 ? 60.0f / float(FireHot.RPM) : 0.0f;
					};
				}
			}
		}

		bool HasPower(const FBSRuntimeStore& Store, int PowerIndex)
		{
			return PowerIndex >= 0 && Store.PowerHot[PowerIndex].bSupplied;
		}

		/**
		 * Reads: FireHot, ArticulationHot
		 * Writes: no runtime rows
		 */
		bool CanFire(const FBSFireHotRow& FireHot, const FBSArticulationHotRow& ArticulationHot)
		{
			if (FireHot.RPM <= 0 || FireHot.ShotCooldownRemaining > 0.0f)
			{
				return false;
			}

			if (ArticulationHot.DistanceToTarget <= 0.0f || ArticulationHot.DistanceToTarget > FireHot.MaxDistance)
			{
				return false;
			}

			return Math::Abs(ArticulationHot.MuzzleError.Yaw) <= FireHot.MaxAngleDegrees && Math::Abs(ArticulationHot.MuzzleError.Pitch) <= FireHot.MaxAngleDegrees;
		}

		/**
		 * Reads: BaseRow, ArticulationCold, FireCold, ArticulationHot
		 * Writes: ArticulationHot (none intentional; passed mutable for call-site convenience)
		 */
		void Shot(const FBSBaseRuntimeRow& BaseRow, const FBSArticulationColdRow& ArticulationCold, const FBSFireColdRow& FireCold, FBSArticulationHotRow& ArticulationHot)
		{
			UBSTurretDefinition Turret = FireCold.Turret;
			check(Turret != nullptr);
			check(ArticulationCold.MuzzleComponent != nullptr);

			FVector MuzzleLocation = ArticulationHot.MuzzleWorldLocation;
			MuzzleLocation += ArticulationHot.MuzzleWorldRotation.RotateVector(FVector(5, 0, 0));

			if (Turret.ShotEffect_NS.IsValid())
			{
				Niagara::SpawnSystemAttached(Turret.ShotEffect_NS.Get(),
											 ArticulationCold.MuzzleComponent,
											 NAME_None,
											 MuzzleLocation,
											 ArticulationHot.MuzzleWorldRotation,
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
				Writer.WriteQuat(n"Rotation", 0, ArticulationHot.MuzzleWorldRotation.Quaternion());
			}

			FBFProjectileSpawnParams Projectile;
			Projectile.DragType = EBFProjectileDrag::VeryLow;
			Projectile.Instigator = nullptr;
			Projectile.Causer = BaseRow.Actor;
			Projectile.Lifetime = 10;
			Projectile.Position = MuzzleLocation;
			Projectile.Velocity = ArticulationHot.MuzzleWorldRotation.ForwardVector * 300 * 100;
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
