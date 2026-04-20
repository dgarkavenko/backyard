class ABSBreachEnemySpawner : AActor
{
	UPROPERTY(DefaultComponent, RootComponent)
	USceneComponent SceneRoot;

	UPROPERTY(DefaultComponent, Attach = SceneRoot)
	UBoxComponent SpawnBounds;

	UPROPERTY(DefaultComponent, Attach = SceneRoot)
	UBillboardComponent Billboard;

	UPROPERTY(EditAnywhere, Category = "Spawner")
	FString DisplayName = "Zone";

	UPROPERTY(EditAnywhere, Category = "Spawner")
	TSubclassOf<ABSBreachEnemyCharacter> EnemyClass;

	UPROPERTY(EditAnywhere, Category = "Spawner")
	ABSBreachZone ZoneMarker;

	UPROPERTY(EditAnywhere, Category = "Spawner", meta = (ClampMin = "0", Units = "cm"))
	float MoveAcceptanceRadius = 100.0f;

	default SpawnBounds.SetBoxExtent(FVector(300.0f, 300.0f, 150.0f));
	default SpawnBounds.SetCollisionEnabled(ECollisionEnabled::NoCollision);
	default SpawnBounds.SetGenerateOverlapEvents(false);

	UFUNCTION(BlueprintPure)
	FString GetZoneLabel() const
	{
		FString ActorName = GetName().ToString();
		return DisplayName.IsEmpty() ? ActorName : f"{DisplayName} ({ActorName})";
	}

	UFUNCTION()
	bool SpawnEnemy()
	{
		if (EnemyClass.Get() == nullptr || ZoneMarker == nullptr)
		{
			Print(f"[EnemySpawner] '{GetZoneLabel()}' requires EnemyClass and ZoneMarker.");
			return false;
		}

		FVector SpawnLocation;
		if (!BFEnemySpawn::FindRandomSpawnLocation(this, SpawnLocation))
		{
			Print(f"[EnemySpawner] '{GetZoneLabel()}' could not find a navigable spawn point inside its bounds.");
			return false;
		}

		FRotator SpawnRotation = ActorRotation;

		auto SpawnedEnemy = BFEnemySpawn::SpawnPawnInZone(this, EnemyClass, SpawnLocation, SpawnRotation);

		if (SpawnedEnemy == nullptr)
		{
			Print(f"[EnemySpawner] '{GetZoneLabel()}' failed to spawn enemy at {SpawnLocation}.");
			return false;
		}

		SpawnedEnemy.ZoneMarker = ZoneMarker;
		SpawnedEnemy.MoveAcceptanceRadius = MoveAcceptanceRadius;
		return true;
	}
}
