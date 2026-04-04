namespace SentryDebugF
{
	const FConsoleVariable ShowSockets(f"BF.Sentry.ShowSockets", 0);
	const FConsoleVariable ShowAim(f"BF.Sentry.ShowAim", 0);
	const FConsoleVariable ValidateAssembly(f"BF.Sentry.ValidateAssembly", 0);

	bool IsManagedDynamicComponent(UBSModularView ModularView, UStaticMeshComponent Component)
	{
		return ModularView != nullptr && ModularView.ModuleElementPool.Contains(Component);
	}

	void ValidatePoolState(const TArray<UStaticMeshComponent>& Pool, const TArray<UStaticMeshComponent>& ActivePool)
	{
		for (UStaticMeshComponent Component : Pool)
		{
			if (Component == nullptr)
			{
				continue;
			}

			bool bIsActive = ActivePool.Contains(Component);
			if (bIsActive && Component.StaticMesh == nullptr)
			{
				Warning(f"Sentry rebuild garbage assert: active module component '{Component.GetName()}' has no mesh");
			}

			if (!bIsActive && Component.StaticMesh != nullptr)
			{
				Warning(f"Sentry rebuild garbage assert: stale module component '{Component.GetName()}' still has mesh '{Component.StaticMesh.GetName()}'");
			}
		}
	}

	void DrawSockets(ABSSentry Sentry)
	{

	}

	void DrawAim(FBSSentryTargetingRuntime& TargetingRuntime)
	{
		FVector MuzzleLocation = TargetingRuntime.MuzzleWorldLocation;
		float DistanceToTarget = TargetingRuntime.DistanceToTarget;

		FVector MuzzleForward = TargetingRuntime.MuzzleWorldRotation.ForwardVector.GetSafeNormal();

		System::DrawDebugLine(MuzzleLocation, TargetingRuntime.TargetLocation, FLinearColor::Yellow, 0, 2);
		System::DrawDebugLine(MuzzleLocation, MuzzleLocation + MuzzleForward * DistanceToTarget, FLinearColor::Blue, 0, 2);
		System::DrawDebugPoint(TargetingRuntime.TargetLocation, 12.0f, FLinearColor::Yellow, 0, EDrawDebugSceneDepthPriorityGroup::Foreground);
	}
}
