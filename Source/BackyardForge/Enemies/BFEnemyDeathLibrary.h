#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "BFEnemyDeathLibrary.generated.h"

class ACharacter;

UCLASS()
class BACKYARDFORGE_API UBFEnemyDeathLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	UFUNCTION(ScriptCallable, Category = "Enemy|Death")
	static bool EnterRagdollDeath(ACharacter* Character, bool bBlockMovement);
};
