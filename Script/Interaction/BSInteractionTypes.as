enum EBSActionOutcome
{
	None,
	PickupTarget
}

enum EBSInteractionIcon
{
	None,
	Interact,
	Pickup,
	Tool
}

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

	UPROPERTY(EditAnywhere, Category = "Action", meta = (ClampMin = "0", ClampMax = "5", Units = "s"))
	float HoldDuration = 0.0f;

	UPROPERTY(EditAnywhere, Category = "Action")
	EBSActionOutcome Outcome = EBSActionOutcome::None;
}

class UBSInteractionActionSet : UDataAsset
{
	UPROPERTY(EditAnywhere, Category = "Interaction")
	TArray<FBSInteractionAction> Actions;
}

struct FBSInteractionPromptInfo
{
	FText DisplayName;
	EBSInteractionIcon Icon = EBSInteractionIcon::None;
	bool bShowHoldProgress = false;
	float HoldDuration = 0.0f;
	bool bAvailable = false;
}
