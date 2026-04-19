struct FBSDetectionLinks
{
	int32 AimIndex = -1;
	int32 FireIndex = -1;
}

struct FBSFireLinks
{
	int32 AimIndex = -1;
}

struct FBSLightLinks
{
	int32 DetectionIndex = -1;
	int32 PowerIndex = -1;
}

struct FBSBaseRuntimeRow
{
	AActor Actor;
	UBSModularView ModularView;
	FGameplayTagContainer Capabilities;
	int32 PowerIndex = -1;
	int32 DetectionIndex = -1;
	int32 AimIndex = -1;
	int32 FireIndex = -1;
	int32 LightIndex = -1;
}

mixin FBSDetectionLinks ToDetectionLinks(FBSBaseRuntimeRow Self)
{
	FBSDetectionLinks Links;
	Links.AimIndex = Self.AimIndex;
	Links.FireIndex = Self.FireIndex;
	return Links;
}

mixin FBSFireLinks ToFireLinks(FBSBaseRuntimeRow Self)
{
	FBSFireLinks Links;
	Links.AimIndex = Self.AimIndex;
	return Links;
}

mixin FBSLightLinks ToLightLinks(FBSBaseRuntimeRow Self)
{
	FBSLightLinks Links;
	Links.DetectionIndex = Self.DetectionIndex;
	Links.PowerIndex = Self.PowerIndex;
	return Links;
}
