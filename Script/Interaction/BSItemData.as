enum EBSHoldMode
{
	Tool,
	Carry
}

class UBSItemData : UDataAsset
{
	UPROPERTY(EditAnywhere, Category = "Display")
	UStaticMesh DisplayMesh;

	UPROPERTY(EditAnywhere, Category = "Display")
	FTransform DisplayMeshOffset;

	UPROPERTY(EditAnywhere, Category = "Tags")
	FGameplayTagContainer GrantedTags;

	UPROPERTY(EditAnywhere, Category = "Hold")
	EBSHoldMode HoldMode = EBSHoldMode::Tool;

	UPROPERTY(EditAnywhere, Category = "Placement")
	bool bPlaceable = false;

	UPROPERTY(EditAnywhere, Category = "Placement")
	TSubclassOf<AActor> PlacementPreviewClass;
}
