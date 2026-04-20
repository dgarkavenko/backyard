struct FBSDetectionLinks
{
	int32 ArticulationIndex = -1;
	int32 FireIndex = -1;
	int32 PowerIndex = -1;
}

struct FBSArticulationLinks
{
	int32 DetectionIndex = -1;
	int32 PowerIndex = -1;
}

struct FBSFireLinks
{
	int32 ArticulationIndex = -1;
	int32 PowerIndex = -1;
}

struct FBSIndicationLinks
{
	int32 DetectionIndex = -1;
	int32 ArticulationIndex = -1;
	int32 PowerIndex = -1;
}

struct FBSBaseRuntimeRow
{
	AActor Actor;
	UBSModularView ModularView;
	FGameplayTagContainer Capabilities;
	int32 PowerIndex = -1;
	int32 DetectionIndex = -1;
	int32 ArticulationIndex = -1;
	int32 FireIndex = -1;
	int32 IndicationIndex = -1;
}

mixin FBSDetectionLinks ToDetectionLinks(FBSBaseRuntimeRow Self)
{
	FBSDetectionLinks Links;
	Links.ArticulationIndex = Self.ArticulationIndex;
	Links.FireIndex = Self.FireIndex;
	Links.PowerIndex = Self.PowerIndex;
	return Links;
}

mixin FBSArticulationLinks ToArticulationLinks(FBSBaseRuntimeRow Self)
{
	FBSArticulationLinks Links;
	Links.DetectionIndex = Self.DetectionIndex;
	Links.PowerIndex = Self.PowerIndex;
	return Links;
}

mixin FBSFireLinks ToFireLinks(FBSBaseRuntimeRow Self)
{
	FBSFireLinks Links;
	Links.ArticulationIndex = Self.ArticulationIndex;
	Links.PowerIndex = Self.PowerIndex;
	return Links;
}

mixin FBSIndicationLinks ToIndicationLinks(FBSBaseRuntimeRow Self)
{
	FBSIndicationLinks Links;
	Links.DetectionIndex = Self.DetectionIndex;
	Links.ArticulationIndex = Self.ArticulationIndex;
	Links.PowerIndex = Self.PowerIndex;
	return Links;
}
