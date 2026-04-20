#pragma once

#include "CoreMinimal.h"
#include "AIController.h"
#include "BFBreachEnemyAIController.generated.h"

struct FPathFollowingResult;
struct FAIRequestID;

UCLASS()
class BACKYARDFORGE_API ABFBreachEnemyAIController : public AAIController
{
	GENERATED_BODY()

public:
	ABFBreachEnemyAIController();

	UFUNCTION(ScriptCallable, Category = "Enemy|Navigation")
	bool RequestMoveToActor(AActor* GoalActor, float AcceptanceRadius);

	UFUNCTION(ScriptCallable, Category = "Enemy|Navigation")
	void AbortCurrentMove();

	UFUNCTION(ScriptCallable, Category = "Enemy|Navigation")
	bool ConsumeReachedDestination();

	UFUNCTION(ScriptCallable, Category = "Enemy|Navigation")
	bool ConsumeMoveFailed();

protected:
	virtual void OnMoveCompleted(FAIRequestID RequestID, const FPathFollowingResult& Result) override;

private:
	bool bReachedDestination = false;
	bool bMoveFailed = false;
};
