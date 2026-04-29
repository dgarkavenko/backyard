// Copyright Epic Games, Inc. All Rights Reserved.

using UnrealBuildTool;

public class BackyardForge : ModuleRules
{
	public BackyardForge(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

		PublicDependencyModuleNames.AddRange(new string[] {
			"Core",
			"CoreUObject",
			"Engine",
			"InputCore",
			"EnhancedInput",
			"AIModule",
			"NavigationSystem",
			"StateTreeModule",
			"GameplayStateTreeModule",
			"UMG",
			"Slate",
			"CommonGame",
			"CommonUI",
			"ModularGameplayActors",
			"ForgeryUI",
			"GameplayTags",
			"PhysicsCore",
			"Niagara",
			"DeveloperSettings",
			"PCG"
		});

		PrivateDependencyModuleNames.AddRange(new string[] { });

		PublicIncludePaths.AddRange(new string[] {
			"BackyardForge",
			"BackyardForge/Enemies",
			"BackyardForge/Framework",
			"BackyardForge/Player",
			"BackyardForge/Interaction",
			"BackyardForge/Projectile",
			"BackyardForge/Utility",
			"BackyardForge/PCG",
			"BackyardForge/Variant_Shooter",
			"BackyardForge/Variant_Shooter/AI",
			"BackyardForge/Variant_Shooter/UI",
			"BackyardForge/Variant_Shooter/Weapons",
			"BackyardForge/Sentry"
		});

		// Uncomment if you are using Slate UI
		// PrivateDependencyModuleNames.AddRange(new string[] { "Slate", "SlateCore" });

		// Uncomment if you are using online features
		// PrivateDependencyModuleNames.Add("OnlineSubsystem");

		// To include OnlineSubsystemSteam, add it to the plugins section in your uproject file with the Enabled attribute set to true
	}
}
