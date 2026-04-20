struct FBSRuntimeStore
{
	TArray<FBSBaseRuntimeRow> BaseRows;
	TMap<AActor, int32> ActorToBaseIndex;

	TArray<FBSPowerHotRow> PowerHot;
	TArray<FBSPowerChildrenRow> PowerChildren;

	TArray<FBSDetectionHotRow> DetectionHot;
	TArray<FBSDetectionColdRow> DetectionCold;

	TArray<FBSAimHotRow> AimHot;
	TArray<FBSAimColdRow> AimCold;

	TArray<FBSFireHotRow> FireHot;
	TArray<FBSFireColdRow> FireCold;

	TArray<FBSIndicationHotRow> IndicationHot;
	TArray<FBSIndicationColdRow> IndicationCold;

	int Num() const
	{
		return BaseRows.Num();
	}

	int CreateBaseRow(AActor Actor, UBSModularView ModularView)
	{
		int BaseIndex = BaseRows.Num();
		FBSBaseRuntimeRow Row;
		Row.Actor = Actor;
		Row.ModularView = ModularView;
		BaseRows.Add(Row);
		return BaseIndex;
	}

	void UpdateMovedBaseOwnership(int BaseIndex)
	{
		if (BaseIndex < 0 || BaseIndex >= BaseRows.Num())
		{
			return;
		}

		FBSBaseRuntimeRow& Row = BaseRows[BaseIndex];
		if (Row.PowerIndex >= 0)
		{
			PowerHot[Row.PowerIndex].OwnerBaseIndex = BaseIndex;
		}
		if (Row.DetectionIndex >= 0)
		{
			DetectionHot[Row.DetectionIndex].OwnerBaseIndex = BaseIndex;
		}
		if (Row.AimIndex >= 0)
		{
			AimHot[Row.AimIndex].OwnerBaseIndex = BaseIndex;
		}
		if (Row.FireIndex >= 0)
		{
			FireHot[Row.FireIndex].OwnerBaseIndex = BaseIndex;
		}
		if (Row.IndicationIndex >= 0)
		{
			IndicationHot[Row.IndicationIndex].OwnerBaseIndex = BaseIndex;
		}
	}

	void RemoveBaseRowSwap(int BaseIndex)
	{
		int LastIndex = BaseRows.Num() - 1;
		if (BaseIndex < 0 || BaseIndex > LastIndex)
		{
			return;
		}

		if (BaseIndex != LastIndex)
		{
			BaseRows[BaseIndex] = BaseRows[LastIndex];
			UpdateMovedBaseOwnership(BaseIndex);
		}

		BaseRows.RemoveAt(LastIndex);
	}

	int CreatePowerRow(int BaseIndex)
	{
		int RowIndex = PowerHot.Num();
		FBSPowerHotRow HotRow;
		HotRow.OwnerBaseIndex = BaseIndex;
		PowerHot.Add(HotRow);
		PowerChildren.Add(FBSPowerChildrenRow());
		BaseRows[BaseIndex].PowerIndex = RowIndex;
		return RowIndex;
	}

	void RemovePowerRowSwap(int RowIndex)
	{
		int LastIndex = PowerHot.Num() - 1;
		if (RowIndex < 0 || RowIndex > LastIndex)
		{
			return;
		}

		if (RowIndex != LastIndex)
		{
			PowerHot[RowIndex] = PowerHot[LastIndex];
			PowerChildren[RowIndex] = PowerChildren[LastIndex];
			BaseRows[PowerHot[RowIndex].OwnerBaseIndex].PowerIndex = RowIndex;
		}

		PowerHot.RemoveAt(LastIndex);
		PowerChildren.RemoveAt(LastIndex);
	}

	int CreateDetectionRow(int BaseIndex)
	{
		int RowIndex = DetectionHot.Num();
		FBSDetectionHotRow HotRow;
		HotRow.OwnerBaseIndex = BaseIndex;
		DetectionHot.Add(HotRow);
		DetectionCold.Add(FBSDetectionColdRow());
		BaseRows[BaseIndex].DetectionIndex = RowIndex;
		return RowIndex;
	}

	void RemoveDetectionRowSwap(int RowIndex)
	{
		int LastIndex = DetectionHot.Num() - 1;
		if (RowIndex < 0 || RowIndex > LastIndex)
		{
			return;
		}

		if (RowIndex != LastIndex)
		{
			DetectionHot[RowIndex] = DetectionHot[LastIndex];
			DetectionCold[RowIndex] = DetectionCold[LastIndex];
			BaseRows[DetectionHot[RowIndex].OwnerBaseIndex].DetectionIndex = RowIndex;
		}

		DetectionHot.RemoveAt(LastIndex);
		DetectionCold.RemoveAt(LastIndex);
	}

	int CreateAimRow(int BaseIndex)
	{
		int RowIndex = AimHot.Num();
		FBSAimHotRow HotRow;
		HotRow.OwnerBaseIndex = BaseIndex;
		AimHot.Add(HotRow);
		AimCold.Add(FBSAimColdRow());
		BaseRows[BaseIndex].AimIndex = RowIndex;
		return RowIndex;
	}

	void RemoveAimRowSwap(int RowIndex)
	{
		int LastIndex = AimHot.Num() - 1;
		if (RowIndex < 0 || RowIndex > LastIndex)
		{
			return;
		}

		if (RowIndex != LastIndex)
		{
			AimHot[RowIndex] = AimHot[LastIndex];
			AimCold[RowIndex] = AimCold[LastIndex];
			BaseRows[AimHot[RowIndex].OwnerBaseIndex].AimIndex = RowIndex;
		}

		AimHot.RemoveAt(LastIndex);
		AimCold.RemoveAt(LastIndex);
	}

	int CreateFireRow(int BaseIndex)
	{
		int RowIndex = FireHot.Num();
		FBSFireHotRow HotRow;
		HotRow.OwnerBaseIndex = BaseIndex;
		FireHot.Add(HotRow);
		FireCold.Add(FBSFireColdRow());
		BaseRows[BaseIndex].FireIndex = RowIndex;
		return RowIndex;
	}

	void RemoveFireRowSwap(int RowIndex)
	{
		int LastIndex = FireHot.Num() - 1;
		if (RowIndex < 0 || RowIndex > LastIndex)
		{
			return;
		}

		if (RowIndex != LastIndex)
		{
			FireHot[RowIndex] = FireHot[LastIndex];
			FireCold[RowIndex] = FireCold[LastIndex];
			BaseRows[FireHot[RowIndex].OwnerBaseIndex].FireIndex = RowIndex;
		}

		FireHot.RemoveAt(LastIndex);
		FireCold.RemoveAt(LastIndex);
	}

	int CreateIndicationRow(int BaseIndex)
	{
		int RowIndex = IndicationHot.Num();
		FBSIndicationHotRow HotRow;
		HotRow.OwnerBaseIndex = BaseIndex;
		IndicationHot.Add(HotRow);
		IndicationCold.Add(FBSIndicationColdRow());
		BaseRows[BaseIndex].IndicationIndex = RowIndex;
		return RowIndex;
	}

	void RemoveIndicationRowSwap(int RowIndex)
	{
		int LastIndex = IndicationHot.Num() - 1;
		if (RowIndex < 0 || RowIndex > LastIndex)
		{
			return;
		}

		if (RowIndex != LastIndex)
		{
			IndicationHot[RowIndex] = IndicationHot[LastIndex];
			IndicationCold[RowIndex] = IndicationCold[LastIndex];
			BaseRows[IndicationHot[RowIndex].OwnerBaseIndex].IndicationIndex = RowIndex;
		}

		IndicationHot.RemoveAt(LastIndex);
		IndicationCold.RemoveAt(LastIndex);
	}

	void RebuildActorLookup()
	{
		ActorToBaseIndex.Empty();

		for (int Index = 0; Index < BaseRows.Num(); Index++)
		{
			AActor Actor = BaseRows[Index].Actor;
			if (Actor != nullptr)
			{
				ActorToBaseIndex.Add(Actor, Index);
			}
		}
	}

	void RebuildDerivedLinks()
	{
		for (int DetectionIndex = 0; DetectionIndex < DetectionHot.Num(); DetectionIndex++)
		{
			FBSDetectionHotRow& HotRow = DetectionHot[DetectionIndex];
			HotRow.Links = BaseRows[HotRow.OwnerBaseIndex].ToDetectionLinks();
		}

		for (int FireIndex = 0; FireIndex < FireHot.Num(); FireIndex++)
		{
			FBSFireHotRow& HotRow = FireHot[FireIndex];
			HotRow.Links = BaseRows[HotRow.OwnerBaseIndex].ToFireLinks();
		}

		for (int IndicationIndex = 0; IndicationIndex < IndicationHot.Num(); IndicationIndex++)
		{
			FBSIndicationHotRow& HotRow = IndicationHot[IndicationIndex];
			HotRow.Links = BaseRows[HotRow.OwnerBaseIndex].ToIndicationLinks();
		}
	}

	int FindBaseIndex(AActor Actor) const
	{
		if (Actor == nullptr || !ActorToBaseIndex.Contains(Actor))
		{
			return -1;
		}

		return ActorToBaseIndex[Actor];
	}

	void Clear()
	{
		BaseRows.Empty();
		ActorToBaseIndex.Empty();
		PowerHot.Empty();
		PowerChildren.Empty();
		DetectionHot.Empty();
		DetectionCold.Empty();
		AimHot.Empty();
		AimCold.Empty();
		FireHot.Empty();
		FireCold.Empty();
		IndicationHot.Empty();
		IndicationCold.Empty();
	}
}
