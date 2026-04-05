mixin FRotator MaskYaw (FRotator Self)
{
	return FRotator(0, Self.Yaw, 0);
}

mixin FString GetLeafs(FGameplayTagContainer Self)
{
	TArray<FString> Leafs;

	for (FGameplayTag Tag : Self.GameplayTags)
	{
		Leafs.Add(String::ParseIntoArray(Tag.ToString(), ".", true).Last());
	}

	return FString::Join(Leafs, ",");
}