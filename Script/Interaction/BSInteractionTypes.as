struct FBSInteractionAction
{
	UPROPERTY(EditAnywhere, Category = "Action")
	FGameplayTag ActionTag;

	UPROPERTY(EditAnywhere, Category = "Action")
	FText DisplayName;

	UPROPERTY(EditAnywhere, Category = "Action")
	UInputAction InputAction;

	UPROPERTY(EditAnywhere, Category = "Action")
	FGameplayTagContainer RequiredTags;
}

class UBSInteractionActionSet : UDataAsset
{
	UPROPERTY(EditAnywhere, Category = "Interaction")
	TArray<FBSInteractionAction> Actions;
}
