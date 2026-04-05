class UBSTargetWorldSubsystem : UScriptWorldSubsystem
{
	TArray<UBSTargetableComponent> RegisteredTargetables;
	TArray<FBSTargetSnapshot> Snapshots;

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		int WriteIndex = 0;
		Snapshots.SetNum(RegisteredTargetables.Num());

		for (int ReadIndex = 0; ReadIndex < RegisteredTargetables.Num(); ReadIndex++)
		{
			UBSTargetableComponent Targetable = RegisteredTargetables[ReadIndex];
			if (Targetable == nullptr || Targetable.Owner == nullptr || !Targetable.bEnabled)
			{
				continue;
			}

			if (WriteIndex != ReadIndex)
			{
				RegisteredTargetables[WriteIndex] = Targetable;
			}

			Snapshots[WriteIndex] = Targetable.BuildSnapshot(DeltaSeconds);
			WriteIndex++;
		}

		RegisteredTargetables.SetNum(WriteIndex);
		Snapshots.SetNum(WriteIndex);
	}

	void RegisterTargetable(UBSTargetableComponent Targetable)
	{
		if (Targetable != nullptr && !RegisteredTargetables.Contains(Targetable))
		{
			RegisteredTargetables.Add(Targetable);
		}
	}

	void UnregisterTargetable(UBSTargetableComponent Targetable)
	{
		RegisteredTargetables.Remove(Targetable);
	}
}
