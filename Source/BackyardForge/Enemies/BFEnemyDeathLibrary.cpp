#include "Enemies/BFEnemyDeathLibrary.h"

#include "AIController.h"
#include "Components/CapsuleComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "GameFramework/Character.h"
#include "GameFramework/CharacterMovementComponent.h"

bool UBFEnemyDeathLibrary::EnterRagdollDeath(ACharacter* Character, const bool bBlockMovement)
{
	if (Character == nullptr)
	{
		return false;
	}

	if (AAIController* AIController = Cast<AAIController>(Character->GetController()))
	{
		AIController->StopMovement();
		AIController->UnPossess();
		AIController->Destroy();
	}
	else if (AController* Controller = Character->GetController())
	{
		Controller->UnPossess();
	}

	if (UCapsuleComponent* Capsule = Character->GetCapsuleComponent())
	{
		Capsule->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	}

	if (UCharacterMovementComponent* CharacterMovement = Character->GetCharacterMovement())
	{
		CharacterMovement->StopMovementImmediately();
		CharacterMovement->DisableMovement();
	}

	USkeletalMeshComponent* Mesh = Character->GetMesh();
	if (Mesh == nullptr)
	{
		return false;
	}

	Mesh->SetCollisionProfileName(FName("Ragdoll"));
	if (!bBlockMovement)
	{
		Mesh->SetCollisionResponseToChannel(ECC_Pawn, ECR_Ignore);
	}

	Mesh->SetSimulatePhysics(true);
	Mesh->SetPhysicsBlendWeight(1.0f);
	Mesh->WakeAllRigidBodies();
	return true;
}
