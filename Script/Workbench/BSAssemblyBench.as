class ABSAssemblyBench : AActor
{
	UPROPERTY(DefaultComponent, RootComponent)
	UStaticMeshComponent WorkbenchMesh;

	UPROPERTY(DefaultComponent, Attach = WorkbenchMesh)
	UCameraComponent CameraViewpoint;

	UPROPERTY(DefaultComponent, Attach = WorkbenchMesh)
	USceneComponent SentryMountPoint;

	UPROPERTY(DefaultComponent)
	UBSInteractionRegistry InteractionRegistry;

	UPROPERTY(EditAnywhere, Category = "Workbench")
	TSubclassOf<ABSSentry> SentryClass;

	UPROPERTY(EditAnywhere, Category = "Workbench")
	TSubclassOf<UCommonActivatableWidget> CraftMenuWidgetClass;

	UPROPERTY(EditAnywhere, Category = "Workbench")
	UMaterialInterface SentryMaterial;

	UPROPERTY(EditAnywhere, Category = "Workbench")
	FBFInteraction WorkbenchAction;

	UPROPERTY(EditAnywhere, Category = "Workbench|Snap", meta = (ClampMin = "10", ClampMax = "300", Units = "cm"))
	float SnapZoneRadius = 75.0f;

	TArray<UBSModuleDefinition> GetAvailableModules() const
	{
		UBSModuleTaxonomy Taxonomy = UBSModuleTaxonomy::Get();
		if (Taxonomy != nullptr)
		{
			return Taxonomy.GetAllModules();
		}
		return TArray<UBSModuleDefinition>();
	}

	ABSSentry Sentry;
	ABSSentry PendingSentry;
	APlayerController ActiveUser;
	UBSAssemblyScreen CraftMenu;
	USphereComponent SnapZone;
	FTimerHandle PendingSentryTimerHandle;

	default CameraViewpoint.bAutoActivate = false;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		WorkbenchAction.Delegate.BindUFunction(this, n"OnInteracted");
		InteractionRegistry.RegisterAction(WorkbenchAction);

		SnapZone = USphereComponent::Create(this, n"SnapZone");
		SnapZone.AttachTo(SentryMountPoint);
		SnapZone.SetSphereRadius(SnapZoneRadius);
		SnapZone.SetCollisionEnabled(ECollisionEnabled::QueryOnly);
		SnapZone.SetGenerateOverlapEvents(true);
		SnapZone.SetCollisionResponseToAllChannels(ECollisionResponse::ECR_Ignore);
		SnapZone.SetCollisionResponseToChannel(ECollisionChannel::ECC_WorldDynamic, ECollisionResponse::ECR_Overlap);
		SnapZone.OnComponentBeginOverlap.AddUFunction(this, n"OnSnapZoneBeginOverlap");
		SnapZone.OnComponentEndOverlap.AddUFunction(this, n"OnSnapZoneEndOverlap");
	}

	UFUNCTION()
	void OnInteracted(AActor Interactor)
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

	// Sentry State

	bool HasSentry() const
	{
		return Sentry != nullptr;
	}

	void MountSentry(ABSSentry SentryToMount)
	{
		if (SentryToMount == nullptr)
		{
			return;
		}

		Sentry = SentryToMount;

		Sentry.SetActorLocationAndRotation(
			SentryMountPoint.GetWorldLocation(),
			Sentry.ActorRotation.MaskYaw()
		);

		UPrimitiveComponent RootPrimitive = Cast<UPrimitiveComponent>(Sentry.RootComponent);
		if (RootPrimitive != nullptr)
		{
			RootPrimitive.SetSimulatePhysics(false);
		}

		Sentry.SetActorTickEnabled(false);
		Sentry.DisableTerminalInteraction();

		if (SentryMaterial != nullptr)
		{
			Sentry.Material = SentryMaterial;
		}

		if (Sentry.ModularView != nullptr)
		{
			Sentry.ModularView.MaterialOverride = Sentry.Material;
		}
	}

	ABSSentry UnmountSentry()
	{
		if (Sentry == nullptr)
		{
			return nullptr;
		}

		ABSSentry Dismounted = Sentry;
		Sentry = nullptr;

		Dismounted.EnableTerminalInteraction();

		return Dismounted;
	}

	void CraftNewSentry()
	{
		if (SentryClass.Get() == nullptr || Sentry != nullptr)
		{
			return;
		}

		FVector SpawnLocation = SentryMountPoint.GetWorldLocation();
		FRotator SpawnRotation = SentryMountPoint.GetWorldRotation();

		ABSSentry NewSentry = Cast<ABSSentry>(SpawnActor(SentryClass, SpawnLocation, SpawnRotation));
		if (NewSentry == nullptr)
		{
			return;
		}

		MountSentry(NewSentry);
	}

	// Snap Zone

	UFUNCTION()
	void OnSnapZoneBeginOverlap(
		UPrimitiveComponent OverlappedComponent, AActor OtherActor,
		UPrimitiveComponent OtherComponent, int OtherBodyIndex,
		bool bFromSweep, const FHitResult&in Hit)
	{
		ABSSentry IncomingSentry = Cast<ABSSentry>(OtherActor);
		if (IncomingSentry == nullptr || IncomingSentry == Sentry)
		{
			return;
		}

		if (Sentry != nullptr)
		{
			return;
		}

		ABSCharacter Player = Cast<ABSCharacter>(Gameplay::GetPlayerCharacter(0));
		if (Player != nullptr && Player.DragComponent.IsDragging())
		{
			PendingSentry = IncomingSentry;
			PendingSentryTimerHandle = System::SetTimer(this, n"OnCheckPendingSentry", 0.2f, true);
			return;
		}

		MountSentry(IncomingSentry);
	}

	UFUNCTION()
	void OnSnapZoneEndOverlap(
		UPrimitiveComponent OverlappedComponent, AActor OtherActor,
		UPrimitiveComponent OtherComponent, int OtherBodyIndex)
	{
		if (OtherActor == PendingSentry)
		{
			PendingSentry = nullptr;
			System::ClearAndInvalidateTimerHandle(PendingSentryTimerHandle);
		}

		if (OtherActor == Sentry)
		{
			ABSCharacter Player = Cast<ABSCharacter>(Gameplay::GetPlayerCharacter(0));
			if (Player != nullptr && Player.DragComponent.DraggedActor == Sentry)
			{
				UnmountSentry();
			}
		}
	}

	UFUNCTION()
	void OnCheckPendingSentry()
	{
		if (PendingSentry == nullptr || Sentry != nullptr)
		{
			PendingSentry = nullptr;
			System::ClearAndInvalidateTimerHandle(PendingSentryTimerHandle);
			return;
		}

		ABSCharacter Player = Cast<ABSCharacter>(Gameplay::GetPlayerCharacter(0));
		if (Player != nullptr && Player.DragComponent.IsDragging())
		{
			return;
		}

		if (SnapZone.IsOverlappingActor(PendingSentry))
		{
			MountSentry(PendingSentry);
		}

		PendingSentry = nullptr;
		System::ClearAndInvalidateTimerHandle(PendingSentryTimerHandle);
	}
}
