event void FBSEnemyDeathDelegate(ABSBreachEnemyCharacter Enemy);

class ABSBreachEnemyCharacter : ACharacter
{
	UPROPERTY(DefaultComponent)
	UBSTargetableComponent Targetable;

	UPROPERTY(EditAnywhere, Category = "Damage", meta = (ClampMin = "1"))
	float MaxHP = 25.0f;

	UPROPERTY(EditAnywhere, Category = "Movement", meta = (ClampMin = "0", Units = "cm/s"))
	float WalkSpeed = 220.0f;

	UPROPERTY(EditAnywhere, Category = "Movement", meta = (ClampMin = "0", Units = "cm"))
	float MoveAcceptanceRadius = 100.0f;

	UPROPERTY(EditAnywhere, Category = "Death", meta = (ClampMin = "0.1", Units = "s"))
	float CorpseLifetimeSeconds = 8.0f;

	UPROPERTY(EditAnywhere, Category = "Death")
	bool bCorpseBlocksMovement = false;

	UPROPERTY()
	ABSBreachZone ZoneMarker;

	UPROPERTY(Category = "Delegates")
	FBSEnemyDeathDelegate OnEnemyDied;

	UPROPERTY(Category = "State")
	float CurrentHP = 0.0f;

	UPROPERTY(Category = "State")
	bool bIsDead = false;

	UPROPERTY(Category = "State")
	bool bHasArrived = false;

	bool bRequestedMove = false;
	bool bMoveFailed = false;
	FTimerHandle DeathCleanupTimer;

	default CapsuleComponent.CapsuleRadius = 34.0f;
	default CapsuleComponent.CapsuleHalfHeight = 88.0f;
	default CharacterMovement.MaxWalkSpeed = 220.0f;
	default CharacterMovement.BrakingDecelerationWalking = 1200.0f;
	default CharacterMovement.bUseControllerDesiredRotation = true;
	default CharacterMovement.bOrientRotationToMovement = false;
	default Targetable.MovingSpeedThreshold = 5.0f;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		CurrentHP = MaxHP;
		CharacterMovement.MaxWalkSpeed = WalkSpeed;
		Targetable.Tags.AddTag(GameplayTags::Backyard_Target_Hostile);
		OnTakeAnyDamage.AddUFunction(this, n"HandleAnyDamage");
		BFEnemyNav::EnsureController(this);
	}

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		if (bIsDead || ZoneMarker == nullptr || bMoveFailed)
		{
			return;
		}

		if (!bHasArrived && !bRequestedMove)
		{
			if (!BFEnemyNav::RequestMoveToActor(this, ZoneMarker, MoveAcceptanceRadius))
			{
				Print("Breach enemy failed to request nav move.");
				HandleMoveFailure();
				return;
			}

			bRequestedMove = true;
		}

		if (bHasArrived)
		{
			return;
		}

		if (BFEnemyNav::ConsumeReachedDestination(this))
		{
			bHasArrived = true;
			bRequestedMove = false;
			CharacterMovement.StopMovementImmediately();
			return;
		}

		if (BFEnemyNav::ConsumeMoveFailed(this))
		{
			Print("Breach enemy move failed after spawn.");
			HandleMoveFailure();
		}
	}

	UFUNCTION()
	private void HandleAnyDamage(AActor DamagedActor, float32 Damage, const UDamageType DamageType, AController InstigatedBy, AActor DamageCauser)
	{
		if (bIsDead || Damage <= 0.0f)
		{
			return;
		}

		CurrentHP = Math::Max(0.0f, CurrentHP - Damage);
		if (CurrentHP <= 0.0f)
		{
			Die();
		}
	}

	private void Die()
	{
		if (bIsDead)
		{
			return;
		}

		bIsDead = true;
		Targetable.bEnabled = false;
		BFEnemyNav::AbortMove(this);
		OnEnemyDied.Broadcast(this);

		if (!BFEnemyDeath::EnterRagdollDeath(this, bCorpseBlocksMovement))
		{
			DestroyActor();
			return;
		}

		System::ClearAndInvalidateTimerHandle(DeathCleanupTimer);
		DeathCleanupTimer = System::SetTimer(this, n"DestroyAfterDeath", CorpseLifetimeSeconds, false);
	}

	UFUNCTION()
	private void DestroyAfterDeath()
	{
		DestroyActor();
	}

	private void HandleMoveFailure()
	{
		bMoveFailed = true;
		bRequestedMove = false;
		CharacterMovement.StopMovementImmediately();
		Print("Breach enemy could not reach its zone marker. Check navmesh coverage for the spawn point and zone.");
	}
}
