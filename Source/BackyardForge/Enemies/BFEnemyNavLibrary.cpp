#include "Enemies/BFEnemyNavLibrary.h"

#include "BackyardForge.h"
#include "Enemies/BFBreachEnemyAIController.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"

bool UBFEnemyNavLibrary::EnsureController(APawn* Pawn)
{
	return ResolveController(Pawn, true) != nullptr;
}

bool UBFEnemyNavLibrary::RequestMoveToActor(APawn* Pawn, AActor* GoalActor, const float AcceptanceRadius)
{
	if (ABFBreachEnemyAIController* Controller = ResolveController(Pawn, true))
	{
		return Controller->RequestMoveToActor(GoalActor, AcceptanceRadius);
	}

	return false;
}

void UBFEnemyNavLibrary::AbortMove(APawn* Pawn)
{
	if (ABFBreachEnemyAIController* Controller = ResolveController(Pawn, false))
	{
		Controller->AbortCurrentMove();
	}
}

bool UBFEnemyNavLibrary::ConsumeReachedDestination(APawn* Pawn)
{
	if (ABFBreachEnemyAIController* Controller = ResolveController(Pawn, false))
	{
		return Controller->ConsumeReachedDestination();
	}

	return false;
}

bool UBFEnemyNavLibrary::ConsumeMoveFailed(APawn* Pawn)
{
	if (ABFBreachEnemyAIController* Controller = ResolveController(Pawn, false))
	{
		return Controller->ConsumeMoveFailed();
	}

	return false;
}

ABFBreachEnemyAIController* UBFEnemyNavLibrary::ResolveController(APawn* Pawn, const bool bCreateIfMissing)
{
	if (Pawn == nullptr)
	{
		return nullptr;
	}

	if (ABFBreachEnemyAIController* Controller = Cast<ABFBreachEnemyAIController>(Pawn->GetController()))
	{
		return Controller;
	}

	if (Pawn->GetController() != nullptr)
	{
		UE_LOG(LogBackyardForge, Warning, TEXT("BFEnemyNavLibrary expected '%s' to use ABFBreachEnemyAIController, but found '%s'."),
			*GetNameSafe(Pawn),
			*GetNameSafe(Pawn->GetController()));
		return nullptr;
	}

	if (!bCreateIfMissing)
	{
		return nullptr;
	}

	UWorld* World = Pawn->GetWorld();
	if (World == nullptr)
	{
		return nullptr;
	}

	FActorSpawnParameters SpawnParams;
	SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

	ABFBreachEnemyAIController* Controller = World->SpawnActor<ABFBreachEnemyAIController>(
		ABFBreachEnemyAIController::StaticClass(),
		Pawn->GetActorLocation(),
		Pawn->GetActorRotation(),
		SpawnParams);

	if (Controller == nullptr)
	{
		UE_LOG(LogBackyardForge, Warning, TEXT("BFEnemyNavLibrary failed to spawn controller for '%s'."), *GetNameSafe(Pawn));
		return nullptr;
	}

	Controller->Possess(Pawn);
	return Controller;
}
