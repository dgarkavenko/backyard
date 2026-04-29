using UnrealBuildTool;

public class AgxTonemapper : ModuleRules
{
	public AgxTonemapper(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

		PublicDependencyModuleNames.AddRange(new[]
		{
			"Core",
			"CoreUObject",
			"Engine",
			"DeveloperSettings"
		});

		PrivateDependencyModuleNames.AddRange(new[]
		{
			"Projects",
			"RenderCore"
		});
	}
}
