#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "BFPhysicsCarryComponent.generated.h"

class UPhysicsHandleComponent;

UCLASS(ClassGroup=(Custom), meta=(BlueprintSpawnableComponent))
class BACKYARDFORGE_API UBFPhysicsCarryComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UBFPhysicsCarryComponent();

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Carry", meta = (ClampMin = "50", ClampMax = "500", Units = "cm"))
	float CarryDistance = 200.0f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Carry")
	float LinearStiffness = 750.0f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Carry")
	float LinearDamping = 100.0f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Carry")
	float AngularStiffness = 1500.0f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Carry")
	float AngularDamping = 500.0f;

	UFUNCTION(BlueprintCallable, Category = "Carry")
	void Grab(UPrimitiveComponent* Component);

	UFUNCTION(BlueprintCallable, Category = "Carry")
	void Release();

	UFUNCTION(BlueprintCallable, Category = "Carry")
	void UpdateTarget(FVector Location);

	UFUNCTION(BlueprintCallable, Category = "Carry")
	void UpdateTargetRotation(FRotator Rotation);

	UFUNCTION(BlueprintPure, Category = "Carry")
	bool IsCarrying() const;

private:
	UPROPERTY()
	TObjectPtr<UPhysicsHandleComponent> PhysicsHandle;
};
