event void FBSInteractionDelegate(FGameplayTag ActionTag, AActor Interactor);

class UBSInteractable : UActorComponent
{
	UPROPERTY(EditAnywhere, Category = "Interaction")
	UBSInteractionActionSet ActionSet;

	UPROPERTY(Category = "Interaction")
	FBSInteractionDelegate OnActionExecuted;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		UPrimitiveComponent RootPrimitive = Cast<UPrimitiveComponent>(Owner.RootComponent);
		if (RootPrimitive != nullptr)
		{
			RootPrimitive.SetCollisionResponseToChannel(ECollisionChannel::ECC_GameTraceChannel2, ECollisionResponse::ECR_Block);
		}
	}
}
