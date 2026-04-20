#include "Enemies/BFBreachEnemyAIController.h"

#include "BackyardForge.h"
#include "Navigation/PathFollowingComponent.h"

ABFBreachEnemyAIController::ABFBreachEnemyAIController()
{
	bStartAILogicOnPossess = true;
}

bool ABFBreachEnemyAIController::RequestMoveToActor(AActor* GoalActor, const float AcceptanceRadius)
{
	bReachedDestination = false;
	bMoveFailed = false;

	if (GoalActor == nullptr || GetPawn() == nullptr)
	{
		UE_LOG(LogBackyardForge, Warning, TEXT("BreachEnemyAIController could not request move: missing pawn or goal."));
		bMoveFailed = true;
		return false;
	}

	const EPathFollowingRequestResult::Type Result = MoveToActor(
		GoalActor,
		AcceptanceRadius,
		true,
		true,
		true,
		nullptr,
		true);

	if (Result == EPathFollowingRequestResult::Failed)
	{
		UE_LOG(LogBackyardForge, Warning, TEXT("BreachEnemyAIController failed to path '%s' to '%s'."),
			*GetNameSafe(GetPawn()),
			*GetNameSafe(GoalActor));
		bMoveFailed = true;
		return false;
	}

	if (Result == EPathFollowingRequestResult::AlreadyAtGoal)
	{
		bReachedDestination = true;
	}

	return true;
}

void ABFBreachEnemyAIController::AbortCurrentMove()
{
	if (UPathFollowingComponent* PathFollowing = GetPathFollowingComponent())
	{
		PathFollowing->AbortMove(*this, FPathFollowingResultFlags::UserAbort);
	}
}

bool ABFBreachEnemyAIController::ConsumeReachedDestination()
{
	const bool bResult = bReachedDestination;
	bReachedDestination = false;
	return bResult;
}

bool ABFBreachEnemyAIController::ConsumeMoveFailed()
{
	const bool bResult = bMoveFailed;
	bMoveFailed = false;
	return bResult;
}

void ABFBreachEnemyAIController::OnMoveCompleted(const FAIRequestID RequestID, const FPathFollowingResult& Result)
{
	Super::OnMoveCompleted(RequestID, Result);

	if (Result.Code == EPathFollowingResult::Success)
	{
		bReachedDestination = true;
		return;
	}

	if (Result.Code != EPathFollowingResult::Aborted)
	{
		bMoveFailed = true;
	}
}
