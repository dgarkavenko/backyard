#include "BFPhysicsCarryComponent.h"

#include "PhysicsEngine/PhysicsHandleComponent.h"

UBFPhysicsCarryComponent::UBFPhysicsCarryComponent()
{
	PrimaryComponentTick.bCanEverTick = false;

	PhysicsHandle = CreateDefaultSubobject<UPhysicsHandleComponent>(TEXT("PhysicsHandle"));
}

void UBFPhysicsCarryComponent::Grab(UPrimitiveComponent* Component)
{
	if (!PhysicsHandle || !Component)
	{
		return;
	}

	PhysicsHandle->LinearStiffness = LinearStiffness;
	PhysicsHandle->LinearDamping = LinearDamping;
	PhysicsHandle->AngularStiffness = AngularStiffness;
	PhysicsHandle->AngularDamping = AngularDamping;

	PhysicsHandle->GrabComponentAtLocationWithRotation(
		Component,
		NAME_None,
		Component->GetComponentLocation(),
		Component->GetComponentRotation()
	);
}

void UBFPhysicsCarryComponent::Release()
{
	if (PhysicsHandle)
	{
		PhysicsHandle->ReleaseComponent();
	}
}

void UBFPhysicsCarryComponent::UpdateTarget(FVector Location)
{
	if (PhysicsHandle)
	{
		PhysicsHandle->SetTargetLocation(Location);
	}
}

void UBFPhysicsCarryComponent::UpdateTargetRotation(FRotator Rotation)
{
	if (PhysicsHandle)
	{
		PhysicsHandle->SetTargetRotation(Rotation);
	}
}

bool UBFPhysicsCarryComponent::IsCarrying() const
{
	return PhysicsHandle && PhysicsHandle->GetGrabbedComponent() != nullptr;
}
