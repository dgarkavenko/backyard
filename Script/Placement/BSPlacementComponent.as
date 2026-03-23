class UBSPlacementComponent : UActorComponent
{
	UPROPERTY(EditAnywhere, Category = "Placement")
	UMaterialInterface GhostMaterial;

	bool bActive = false;
	AActor PreviewActor;

	void ActivatePlacement(UBSHeldItemComponent HeldItem)
	{
		if (HeldItem == nullptr || !HeldItem.IsHolding())
		{
			return;
		}

		UBSItemData ItemData = HeldItem.HeldItemData;
		if (ItemData == nullptr)
		{
			return;
		}

		if (ItemData.PlacementPreviewClass != nullptr)
		{
			PreviewActor = SpawnActor(ItemData.PlacementPreviewClass, Owner.ActorLocation, FRotator());
		}

		if (PreviewActor == nullptr)
		{
			return;
		}

		PreviewActor.SetActorEnableCollision(false);
		PreviewActor.SetActorTickEnabled(false);
		ApplyGhostMaterial(PreviewActor);

		if (HeldItem.GetHoldMode() == EBSHoldMode::Carry)
		{
			HeldItem.PhysicsCarry.Release();
			HeldItem.HeldActor.SetActorHiddenInGame(true);
		}
		else
		{
			HeldItem.DestroyDisplayMesh();
		}

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

	bool ConfirmPlacement(UBSHeldItemComponent HeldItem)
	{
		if (PreviewActor == nullptr || HeldItem == nullptr || !HeldItem.IsHolding())
		{
			return false;
		}

		FVector Location = PreviewActor.GetActorLocation();
		FRotator Rotation = PreviewActor.GetActorRotation();

		HeldItem.PlaceAt(Location, Rotation);

		DestroyPreview();
		bActive = false;
		return true;
	}

	void CancelPlacement(UBSHeldItemComponent HeldItem)
	{
		DestroyPreview();

		if (HeldItem != nullptr && HeldItem.IsHolding())
		{
			if (HeldItem.GetHoldMode() == EBSHoldMode::Carry)
			{
				HeldItem.HeldActor.SetActorHiddenInGame(false);
				UPrimitiveComponent RootPrimitive = Cast<UPrimitiveComponent>(HeldItem.HeldActor.RootComponent);
				if (RootPrimitive != nullptr)
				{
					HeldItem.PhysicsCarry.Grab(RootPrimitive);
				}
			}
			else
			{
				HeldItem.CreateDisplayMesh();
			}
		}

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

		TArray<UStaticMeshComponent> MeshComponents;
		Actor.GetComponentsByClass(MeshComponents);

		for (UStaticMeshComponent MeshComponent : MeshComponents)
		{
			for (int MaterialIndex = 0; MaterialIndex < MeshComponent.GetNumMaterials(); MaterialIndex++)
			{
				MeshComponent.SetMaterial(MaterialIndex, GhostMaterial);
			}
		}
	}
}
