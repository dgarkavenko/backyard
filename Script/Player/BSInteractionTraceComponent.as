event void FBSFocusedInteractableChangedDelegate(UBSInteractionRegistry Previous, UBSInteractionRegistry Current);

class UBSInteractionTraceComponent : UActorComponent
{
	default PrimaryComponentTick.bStartWithTickEnabled = true;

	UPROPERTY()
	float TraceDistance = 600;

	UPROPERTY()
	float InteractionAwarenessRadius = 300;

	UPROPERTY()
	USphereComponent AwarenessSphere;

	UPROPERTY(Category = "Delegates")
	FBSFocusedInteractableChangedDelegate OnFocusedInteractableChanged;

	TWeakObjectPtr<USceneComponent> InteractionCastOrigin;

	TArray<UBSInteractionRegistry> NearbyInteractables;

	bool bCameraTraceHit = false;
	FHitResult CameraTraceResult;
	UBSInteractionRegistry FocusedInteractable;
	
	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		if (InteractionAwarenessRadius > 0)
		{
			AwarenessSphere = USphereComponent::Create(Owner, n"AwarenessSphere");
			AwarenessSphere.AttachTo(Owner.RootComponent);

			AwarenessSphere.SetCollisionEnabled(ECollisionEnabled::QueryOnly);
			AwarenessSphere.SetGenerateOverlapEvents(true);
			AwarenessSphere.SetSphereRadius(InteractionAwarenessRadius);
			AwarenessSphere.OnComponentBeginOverlap.AddUFunction(this, n"OnInteractionSphereBeginOverlap");
			AwarenessSphere.OnComponentEndOverlap.AddUFunction(this, n"OnInteractionSphereEndOverlap");
		}

		ABSCharacter Character = Cast<ABSCharacter>(Owner);
		if (Character != nullptr)
		{
			Character.OnStateTagsChanged.AddUFunction(this, n"OnOwnerStateTagsChanged");
		}
	}
	
	UFUNCTION()
	void OnInteractionSphereBeginOverlap(
		UPrimitiveComponent OverlappedComponent, AActor OtherActor,
		UPrimitiveComponent OtherComponent, int OtherBodyIndex,
		bool bFromSweep, const FHitResult&in Hit)
	{
		UBSInteractionRegistry Interactable = UBSInteractionRegistry::Get(OtherActor);
		if (Interactable != nullptr && !NearbyInteractables.Contains(Interactable))
		{
			NearbyInteractables.Add(Interactable);
		}
	}

	UFUNCTION()
	void OnInteractionSphereEndOverlap(
		UPrimitiveComponent OverlappedComponent, AActor OtherActor,
		UPrimitiveComponent OtherComponent, int OtherBodyIndex)
	{
		UBSInteractionRegistry Interactable = UBSInteractionRegistry::Get(OtherActor);
		if (Interactable != nullptr)
		{
			NearbyInteractables.Remove(Interactable);
		}
	}

	UFUNCTION()
	void OnOwnerStateTagsChanged(FGameplayTagContainer StateTags)
	{
		bool bShouldDisable = StateTags.HasTag(GameplayTags::Backyard_Interaction_Pickup);

		if (bShouldDisable && IsComponentTickEnabled())
		{
			Disable();
		}
		else if (!bShouldDisable && !IsComponentTickEnabled())
		{
			Enable();
		}
	}

	void Enable()
	{
		SetComponentTickEnabled(true);
	}

	void Disable()
	{
		SetComponentTickEnabled(false);

		if (FocusedInteractable != nullptr)
		{
			auto Previous = FocusedInteractable;
			FocusedInteractable = nullptr;
			OnFocusedInteractableChanged.Broadcast(Previous, nullptr);
		}
	}

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		if (!InteractionCastOrigin.IsValid())
		{
			return;
		}

		auto TraceOriginObject = InteractionCastOrigin.Get();

		FVector Start = TraceOriginObject.GetWorldLocation();
		FVector End = Start + TraceOriginObject.GetForwardVector() * TraceDistance;

		TArray<AActor> IgnoredActors;
		IgnoredActors.Add(Owner);

		bCameraTraceHit = System::LineTraceSingle(
			Start,
			End,
			ETraceTypeQuery::TraceTypeQuery2,
			false,
			IgnoredActors,
			EDrawDebugTrace::None,
			CameraTraceResult,
			true
		);

		UBSInteractionRegistry NewFocused = bCameraTraceHit ? BSInteraction::CheckHitForInteractable(CameraTraceResult) : nullptr;
		if (NewFocused != FocusedInteractable)
		{
			UBSInteractionRegistry Previous = FocusedInteractable;
			FocusedInteractable = NewFocused;
			OnFocusedInteractableChanged.Broadcast(Previous, FocusedInteractable);
		}
	}
}