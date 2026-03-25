enum EBSInteractionIcon
{
	None,
	Interact,
	Pickup,
	Tool
}

struct FBSInteractionPromptInfo
{
	FText DisplayName;
	EBSInteractionIcon Icon = EBSInteractionIcon::None;
	bool bShowHoldProgress = false;
	float HoldDuration = 0.0f;
	bool bAvailable = false;
}
