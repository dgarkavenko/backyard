class UBSSentryView : UActorComponent
{
	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		UBSModularComponent ModularComponent = UBSModularComponent::Get(Owner);
		if (ModularComponent != nullptr)
		{
			ModularComponent.OnViewBuilt.AddUFunction(this, n"OnViewBuilt");
		}
	}

	UFUNCTION(BlueprintOverride)
	void EndPlay(EEndPlayReason Reason)
	{
		UBSModularComponent ModularComponent = UBSModularComponent::Get(Owner);
		if (ModularComponent != nullptr)
		{
			ModularComponent.OnViewBuilt.UnbindObject(this);
		}

		ABSSentry Sentry = Cast<ABSSentry>(Owner);
		if (Sentry == nullptr)
		{
			return;
		}

		UBSSentryWorldSubsystem SentrySubsystem = UBSSentryWorldSubsystem::Get();
		if (SentrySubsystem != nullptr)
		{
			SentrySubsystem.RemoveSentry(Sentry);
		}
	}

	UFUNCTION()
	void OnViewBuilt(UBSModularComponent ModularComponent, UBSModularView ModularView)
	{
		ABSSentry Sentry = Cast<ABSSentry>(Owner);
		check(Sentry != nullptr);
		check(ModularComponent != nullptr);
		check(ModularView != nullptr);

		UBSSentryWorldSubsystem SentrySubsystem = UBSSentryWorldSubsystem::Get();
		if (SentrySubsystem != nullptr)
		{
			SentrySubsystem.SyncSentry(Sentry);
		}
	}
}
