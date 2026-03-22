class UBSPlacementComponent : UActorComponent
{
	UPROPERTY(EditAnywhere, Category = "Placement")
	TArray<TSubclassOf<ABSSentry>> InventorySlots;

	UPROPERTY(EditAnywhere, Category = "Placement")
	UMaterialInterface GhostMaterial;

	bool bActive = false;
	int SelectedSlot = -1;
	ABSSentry PreviewActor;

	void Toggle()
	{
		if (bActive)
		{
			DeactivatePlacement();
		}
		else
		{
			ActivatePlacement();
		}
	}

	void ActivatePlacement()
	{
		if (SelectedSlot < 0 && InventorySlots.Num() > 0)
		{
			SelectedSlot = 0;
		}

		if (!IsValidSlot(SelectedSlot))
		{
			return;
		}

		bActive = true;
		SpawnPreview();
	}

	void DeactivatePlacement()
	{
		bActive = false;
		DestroyPreview();
	}

	void SelectSlot(int SlotIndex)
	{
		if (!IsValidSlot(SlotIndex))
		{
			return;
		}

		SelectedSlot = SlotIndex;

		if (bActive)
		{
			DestroyPreview();
			SpawnPreview();
		}
	}

	void UpdatePreview(FHitResult HitResult)
	{
		if (PreviewActor == nullptr)
		{
			return;
		}

		PreviewActor.SetActorLocation(HitResult.ImpactPoint);
	}

	bool ConfirmPlacement()
	{
		if (PreviewActor == nullptr || !IsValidSlot(SelectedSlot))
		{
			return false;
		}

		FVector Location = PreviewActor.GetActorLocation();
		FRotator Rotation = PreviewActor.GetActorRotation();

		SpawnActor(InventorySlots[SelectedSlot], Location, Rotation);

		DestroyPreview();
		SpawnPreview();
		return true;
	}

	private void SpawnPreview()
	{
		if (!IsValidSlot(SelectedSlot))
		{
			return;
		}

		PreviewActor = Cast<ABSSentry>(SpawnActor(InventorySlots[SelectedSlot], Owner.GetActorLocation(), FRotator()));
		if (PreviewActor == nullptr)
		{
			return;
		}

		PreviewActor.SetActorEnableCollision(false);
		ApplyGhostMaterial();
	}

	private void DestroyPreview()
	{
		if (PreviewActor != nullptr)
		{
			PreviewActor.DestroyActor();
			PreviewActor = nullptr;
		}
	}

	private void ApplyGhostMaterial()
	{
		if (PreviewActor == nullptr || GhostMaterial == nullptr)
		{
			return;
		}

		PreviewActor.Base.SetMaterial(0, GhostMaterial);
		PreviewActor.Rotator01.SetMaterial(0, GhostMaterial);
		PreviewActor.Rotator02.SetMaterial(0, GhostMaterial);
		//PreviewActor.Body.SetMaterial(0, GhostMaterial);
	}

	private bool IsValidSlot(int SlotIndex)
	{
		return SlotIndex >= 0 && SlotIndex < InventorySlots.Num() && InventorySlots[SlotIndex] != nullptr;
	}
}
