event void FBSStateTagsChangedDelegate(FGameplayTagContainer StateTags);

class ABSCharacter : ACharacter
{
	UPROPERTY(DefaultComponent, Attach = CharacterMesh0)
	USkeletalMeshComponent FirstPersonMesh;

	UPROPERTY(DefaultComponent, Attach = FirstPersonMesh, AttachSocket = head)
	UCameraComponent Camera;

	UPROPERTY(DefaultComponent, Attach = Camera)
	USpotLightComponent SpotLight;

	UPROPERTY(DefaultComponent)
	UBFPhysicsCarryComponent PhysicsCarry;

	UPROPERTY(DefaultComponent)
	UBSDragComponent DragComponent;

	UPROPERTY(DefaultComponent)
	UBSCharacterInputComponent CharacterInputComponent;

	UPROPERTY(DefaultComponent)
	UBSInteractionTraceComponent InteractorComponent;
	default InteractorComponent.InteractionCastOrigin = Camera;

	UPROPERTY(EditAnywhere, Category = "Walk")
	float WalkSpeed = 250.0f;

	UPROPERTY(EditAnywhere, Category = "Sprint", meta = (ClampMin = "0"))
	float SprintSpeed = 600.0f;

	FGameplayTagContainer StateTags;

	UPROPERTY(Category = "Delegates")
	FBSStateTagsChangedDelegate OnStateTagsChanged;

	default Camera.RelativeLocation = FVector(-2.8f, 5.89f, 0.0f);
	default Camera.RelativeRotation = FRotator(0.0f, 90.0f, -90.0f);
	default Camera.bUsePawnControlRotation = true;

	default SpotLight.RelativeLocation = FVector(30.0f, 17.5f, -5.0f);
	default SpotLight.RelativeRotation = FRotator(-18.6f, -1.3f, 5.26f);
	default SpotLight.SetIntensity(0.5f);
	default SpotLight.AttenuationRadius = 1050.0f;
	default SpotLight.InnerConeAngle = 18.7f;
	default SpotLight.OuterConeAngle = 45.24f;

	default CapsuleComponent.CapsuleRadius = 34.0f;
	default CapsuleComponent.CapsuleHalfHeight = 96.0f;

	default CharacterMovement.BrakingDecelerationFalling = 1500.0f;
	default CharacterMovement.AirControl = 0.5f;

	default Mesh.VisibilityBasedAnimTickOption = EVisibilityBasedAnimTickOption::AlwaysTickPoseAndRefreshBones;
	default Mesh.SetOwnerNoSee(true);
	default Mesh.SetVisibility(false);

	default FirstPersonMesh.bOnlyOwnerSee = true;
	default FirstPersonMesh.SetCollisionProfileName(n"NoCollision");

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		Mesh.FirstPersonPrimitiveType = EFirstPersonPrimitiveType::WorldSpaceRepresentation;
		FirstPersonMesh.FirstPersonPrimitiveType = EFirstPersonPrimitiveType::FirstPerson;

		UBSCopyPoseAnimInstance CopyPoseAnimInstance = Cast<UBSCopyPoseAnimInstance>(FirstPersonMesh.AnimInstance);
		if (CopyPoseAnimInstance != nullptr)
		{
			CopyPoseAnimInstance.DonorSMC = Mesh;
		}

		Camera.bEnableFirstPersonFieldOfView = true;
		Camera.bEnableFirstPersonScale = true;
		Camera.FirstPersonFieldOfView = 70.0f;
		Camera.FieldOfView = 90.0f;
		Camera.FirstPersonScale = 0.6f;

		SpotLight.SetIntensityUnits(ELightUnits::Lumens);

		CharacterMovement.MaxWalkSpeed = WalkSpeed;
	}

	void StartSprint()
	{
		CharacterMovement.MaxWalkSpeed = SprintSpeed;		
	}

	void StopSprint()
	{
		CharacterMovement.MaxWalkSpeed = WalkSpeed;
	}

	void AddStateTag(FGameplayTag Tag)
	{
		if (!StateTags.HasTag(Tag))
		{
			StateTags.AddTag(Tag);
			OnStateTagsChanged.Broadcast(StateTags);
		}
	}

	void RemoveStateTag(FGameplayTag Tag)
	{
		if (StateTags.HasTag(Tag))
		{
			StateTags.RemoveTag(Tag);
			OnStateTagsChanged.Broadcast(StateTags);
		}
	}

	FGameplayTagContainer GetCombinedInteractorTags()
	{
		return StateTags;
	}

	bool TryResolveCharacterAction()
	{
		if (DragComponent.IsDragging())
		{
			DragComponent.StopDrag();
			return true;
		}

		return false;
	}
}
