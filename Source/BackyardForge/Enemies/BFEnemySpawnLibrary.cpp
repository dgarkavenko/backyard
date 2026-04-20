#include "Enemies/BFEnemySpawnLibrary.h"

#include "Components/BoxComponent.h"
#include "GameFramework/Actor.h"
#include "GameFramework/Pawn.h"
#include "NavigationSystem.h"

bool UBFEnemySpawnLibrary::FindRandomSpawnLocation(AActor* SpawnZone, FVector& OutSpawnLocation)
{
	if (SpawnZone == nullptr)
	{
		return false;
	}

	UBoxComponent* SpawnBounds = SpawnZone->FindComponentByClass<UBoxComponent>();
	if (SpawnBounds == nullptr)
	{
		return false;
	}

	const FVector Origin = SpawnBounds->GetComponentLocation();
	const FVector Extent = SpawnBounds->GetScaledBoxExtent();

	if (UNavigationSystemV1* NavigationSystem = FNavigationSystem::GetCurrent<UNavigationSystemV1>(SpawnZone->GetWorld()))
	{
		FNavLocation NavLocation;
		if (NavigationSystem->GetRandomPointInNavigableRadius(Origin, FMath::Max(Extent.X, Extent.Y), NavLocation))
		{
			const FVector Delta = NavLocation.Location - Origin;
			if (FMath::Abs(Delta.X) <= Extent.X && FMath::Abs(Delta.Y) <= Extent.Y && FMath::Abs(Delta.Z) <= Extent.Z + 200.0f)
			{
				OutSpawnLocation = NavLocation.Location;
				return true;
			}
		}
	}

	for (int32 Attempt = 0; Attempt < 16; Attempt++)
	{
		const FVector RandomLocation(
			FMath::FRandRange(-Extent.X, Extent.X),
			FMath::FRandRange(-Extent.Y, Extent.Y),
			FMath::FRandRange(-Extent.Z, Extent.Z));

		const FVector Candidate = Origin + RandomLocation;
		if (UNavigationSystemV1* NavigationSystem = FNavigationSystem::GetCurrent<UNavigationSystemV1>(SpawnZone->GetWorld()))
		{
			FNavLocation ProjectedLocation;
			if (NavigationSystem->ProjectPointToNavigation(Candidate, ProjectedLocation, FVector(150.0f, 150.0f, 300.0f)))
			{
				OutSpawnLocation = ProjectedLocation.Location;
				return true;
			}
		}
		else
		{
			OutSpawnLocation = Candidate;
			return true;
		}
	}

	return false;
}

APawn* UBFEnemySpawnLibrary::SpawnPawnInZone(AActor* WorldContextActor, TSubclassOf<APawn> PawnClass, const FVector SpawnLocation, const FRotator SpawnRotation)
{
	if (WorldContextActor == nullptr || PawnClass == nullptr)
	{
		return nullptr;
	}

	UWorld* World = WorldContextActor->GetWorld();
	if (World == nullptr)
	{
		return nullptr;
	}

	FActorSpawnParameters SpawnParams;
	SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;

	return World->SpawnActor<APawn>(PawnClass, SpawnLocation, SpawnRotation, SpawnParams);
}
