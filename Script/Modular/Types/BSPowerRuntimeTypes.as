struct FBSPowerHotRow
{
	float Demand;
	float ChainInsufficency;

	int32 OwnerBaseIndex = -1;
	int32 TapSourcePowerIndex = -1;
	float ChildrenReserve = 0.0f;
	float ChildrenCapacity = 0.0f;
	float Reserve = 0.0f;
	float AccumulatedDecrease = 0.0f;
	float AccumulatedTransfer = 0.0f;
	float Insufficency = 0.0f;
	bool bSupplied = false;

	// static
	float Output = 100.0f;
	float Capacity = 0.0f;
}

struct FBSPowerChildRuntime
{
	float Reserve = 0.0f;

	// static
	float Output = 0.0f;
	float Capacity = 0.0f;
}

struct FBSPowerChildrenRow
{
	TArray<FBSPowerChildRuntime> Batteries;
}
