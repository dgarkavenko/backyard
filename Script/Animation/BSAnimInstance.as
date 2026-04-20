class UBSAnimInstance : UAnimInstance
{
	UPROPERTY()
	ACharacter Character;

	UPROPERTY(EditAnywhere)
	UCharacterMovementComponent MovementComponent;

	UPROPERTY()
	FVector Velocity;

	UPROPERTY()
	float GroundSpeed;

	UPROPERTY()
	float Direction;

	UPROPERTY()
	bool bShouldMove;

	UPROPERTY()
	bool bIsFalling;

	UFUNCTION(BlueprintOverride)
	void BlueprintInitializeAnimation()
	{
		Character = Cast<ACharacter>(GetOwningActor());
		if (Character != nullptr)
		{
			MovementComponent = Character.CharacterMovement;
		}
	}
    
	UFUNCTION(BlueprintOverride)
	void BlueprintUpdateAnimation(float DeltaTimeX)
	{
		if (Character == nullptr)
			return;

		Velocity = MovementComponent.Velocity;
		GroundSpeed = Velocity.Size2D();

		float RawDirection = CalculateDirection(Velocity, Character.GetActorRotation());
		if (MovementComponent.bOrientRotationToMovement)
		{
			Direction = Math::Clamp(RawDirection, -45.0f, 45.0f);
		}
		else
		{
			Direction = RawDirection;
		}

		bShouldMove = (GroundSpeed > 0.01f);// && (MovementComponent.GetCurrentAcceleration() != FVector::ZeroVector);
		bIsFalling = MovementComponent.IsFalling();
	}
}

class UBSCopyPoseAnimInstance : UAnimInstance
{
	UPROPERTY(EditInstanceOnly)
	TObjectPtr<USkeletalMeshComponent> DonorSMC;
}