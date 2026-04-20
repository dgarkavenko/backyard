#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "BFEnemyNavLibrary.generated.h"

class ABFBreachEnemyAIController;
class APawn;
class AActor;

UCLASS()
class BACKYARDFORGE_API UBFEnemyNavLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	UFUNCTION(ScriptCallable, Category = "Enemy|Navigation")
	static bool EnsureController(APawn* Pawn);

	UFUNCTION(ScriptCallable, Category = "Enemy|Navigation")
	static bool RequestMoveToActor(APawn* Pawn, AActor* GoalActor, float AcceptanceRadius);

	UFUNCTION(ScriptCallable, Category = "Enemy|Navigation")
	static void AbortMove(APawn* Pawn);

	UFUNCTION(ScriptCallable, Category = "Enemy|Navigation")
	static bool ConsumeReachedDestination(APawn* Pawn);

	UFUNCTION(ScriptCallable, Category = "Enemy|Navigation")
	static bool ConsumeMoveFailed(APawn* Pawn);

private:
	static ABFBreachEnemyAIController* ResolveController(APawn* Pawn, bool bCreateIfMissing);
};
