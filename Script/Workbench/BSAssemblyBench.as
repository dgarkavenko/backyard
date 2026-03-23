class ABSAssemblyBench : AActor
{
	UPROPERTY(DefaultComponent, RootComponent)
	UStaticMeshComponent WorkbenchMesh;

	UPROPERTY(DefaultComponent, Attach = WorkbenchMesh)
	UCameraComponent CameraViewpoint;

	UPROPERTY(DefaultComponent, Attach = WorkbenchMesh)
	USceneComponent SentryMountPoint;

	UPROPERTY(DefaultComponent)
	UBSInteractable Interactable;

	UPROPERTY(EditAnywhere, Category = "Workbench")
	TArray<UBSChassisConfiguration> AvailableChassis;

	UPROPERTY(EditAnywhere, Category = "Workbench")
	TArray<UBSSentryLoadout> AvailableLoadouts;

	UPROPERTY(EditAnywhere, Category = "Workbench")
	TSubclassOf<ABSSentry> SentryClass;

	UPROPERTY(EditAnywhere, Category = "Workbench")
	TSubclassOf<UCommonActivatableWidget> CraftMenuWidgetClass;

	UPROPERTY(EditAnywhere, Category = "Workbench")
	UMaterialInterface SentryMaterial;

	ABSSentry Sentry;
	APlayerController ActiveUser;
	UBSAssemblyScreen CraftMenu;

	default CameraViewpoint.bAutoActivate = false;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		Interactable.OnActionExecuted.AddUFunction(this, n"OnInteracted");
	}

	UFUNCTION()
	void OnInteracted(FGameplayTag ActionTag, AActor Interactor)
	{
		APawn InteractorPawn = Cast<APawn>(Interactor);
		if (InteractorPawn == nullptr)
		{
			return;
		}

		APlayerController Controller = Cast<APlayerController>(InteractorPawn.Controller);
		if (Controller == nullptr)
		{
			return;
		}

		if (ActiveUser != nullptr)
		{
			return;
		}

		ActivateWorkbench(Controller);
	}

	void ActivateWorkbench(APlayerController Controller)
	{
		ActiveUser = Controller;

		if (Sentry == nullptr)
		{
			SpawnSentry();
		}

		CameraViewpoint.Activate();
		Controller.SetViewTargetWithBlend(this, 0.5f);

		ABSPlayerController BSController = Cast<ABSPlayerController>(Controller);
		if (BSController != nullptr)
		{
			UCommonActivatableWidget Widget = BSController.PushWidgetToPrimaryLayout(
				GameplayTags::ForgeryUI_Layer_GameMenu,
				CraftMenuWidgetClass
			);

			CraftMenu = Cast<UBSAssemblyScreen>(Widget);
			if (CraftMenu != nullptr)
			{
				CraftMenu.OwningWorkbench = this;
			}
		}
	}

	void DeactivateWorkbench()
	{
		if (ActiveUser == nullptr)
		{
			return;
		}

		APawn PlayerPawn = ActiveUser.GetControlledPawn();
		if (PlayerPawn != nullptr)
		{
			ActiveUser.SetViewTargetWithBlend(PlayerPawn, 0.5f);
		}

		System::SetTimer(this, n"OnCameraBlendFinished", 0.5f, false);

		if (CraftMenu != nullptr)
		{
			CraftMenu.DeactivateWidget();
			CraftMenu = nullptr;
		}

		ActiveUser = nullptr;
	}

	UFUNCTION()
	private void OnCameraBlendFinished()
	{
		CameraViewpoint.Deactivate();
	}

	void UpdateSentryConfiguration(UBSChassisConfiguration Chassis, UBSSentryLoadout Loadout)
	{
		if (Sentry == nullptr || Sentry.Configuration == nullptr)
		{
			return;
		}

		Sentry.Configuration.Chassis = Chassis;
		Sentry.Configuration.Loadout = Loadout;
		Sentry.ApplyConfiguration();
	}

	private void SpawnSentry()
	{
		if (SentryClass.Get() == nullptr)
		{
			return;
		}

		FVector SpawnLocation = SentryMountPoint.GetWorldLocation();
		FRotator SpawnRotation = SentryMountPoint.GetWorldRotation();

		Sentry = Cast<ABSSentry>(SpawnActor(SentryClass, SpawnLocation, SpawnRotation));
		if (Sentry == nullptr)
		{
			return;
		}

		Sentry.SetActorTickEnabled(false);

		if (SentryMaterial != nullptr)
		{
			Sentry.Material = SentryMaterial;
		}

		if (Sentry.Configuration == nullptr)
		{
			Sentry.Configuration = Cast<UBSSentryConfiguration>(NewObject(Sentry, UBSSentryConfiguration));
		}

		Sentry.ApplyConfiguration();
	}
}
