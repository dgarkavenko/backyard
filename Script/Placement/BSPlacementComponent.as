class UBSPlacementComponent : UActorComponent
{
	UPROPERTY(EditAnywhere, Category = "Placement")
	UMaterialInterface GhostMaterial;

	bool bActive = false;
	AActor PreviewActor;

	void ActivatePlacement(UBSItemData ItemData)
	{
		if (ItemData == nullptr || ItemData.PlacementPreviewClass == nullptr)
		{
			return;
		}

		PreviewActor = SpawnActor(ItemData.PlacementPreviewClass, Owner.ActorLocation, FRotator());

		if (PreviewActor == nullptr)
		{
			return;
		}

		PreviewActor.SetActorEnableCollision(false);
		PreviewActor.SetActorTickEnabled(false);
		ApplyGhostMaterial(PreviewActor);

		bActive = true;
	}

	void UpdatePreview(FHitResult HitResult)
	{
		if (PreviewActor == nullptr)
		{
			return;
		}

		PreviewActor.SetActorLocation(HitResult.ImpactPoint);
	}

	bool ConfirmPlacement(FVector& OutLocation, FRotator& OutRotation)
	{
		if (PreviewActor == nullptr)
		{
			return false;
		}

		OutLocation = PreviewActor.GetActorLocation();
		OutRotation = PreviewActor.GetActorRotation();

		DestroyPreview();
		bActive = false;
		return true;
	}

	void CancelPlacement()
	{
		DestroyPreview();
		bActive = false;
	}

	private void DestroyPreview()
	{
		if (PreviewActor != nullptr)
		{
			PreviewActor.DestroyActor();
			PreviewActor = nullptr;
		}
	}

	private void ApplyGhostMaterial(AActor Actor)
	{
		if (GhostMaterial == nullptr)
		{
			return;
		}

		TArray<UStaticMeshComponent> MeshComponents = Actor.GetComponentsByClass(UStaticMeshComponent);

		for (UStaticMeshComponent MeshComponent : MeshComponents)
		{
			for (int MaterialIndex = 0; MaterialIndex < MeshComponent.GetNumMaterials(); MaterialIndex++)
			{
				MeshComponent.SetMaterial(MaterialIndex, GhostMaterial);
			}
		}
	}
}
