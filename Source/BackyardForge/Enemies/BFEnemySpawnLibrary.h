#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "BFEnemySpawnLibrary.generated.h"

class AActor;
class APawn;

UCLASS()
class BACKYARDFORGE_API UBFEnemySpawnLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	UFUNCTION(ScriptCallable, Category = "Enemy|Spawn")
	static bool FindRandomSpawnLocation(AActor* SpawnZone, FVector& OutSpawnLocation);

	UFUNCTION(ScriptCallable, Category = "Enemy|Spawn",  Meta = (DeterminesOutputType = "PawnClass"))
	static APawn* SpawnPawnInZone(AActor* WorldContextActor, TSubclassOf<APawn> PawnClass, FVector SpawnLocation, FRotator SpawnRotation);
};
