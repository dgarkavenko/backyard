class ABSAssemblyBench : AActor
{
	UPROPERTY(DefaultComponent, RootComponent)
	UStaticMeshComponent WorkbenchMesh;

	UPROPERTY(DefaultComponent, Attach = WorkbenchMesh)
	UCameraComponent CameraViewpoint;

	UPROPERTY(DefaultComponent, Attach = WorkbenchMesh)
	USceneComponent SentryMountPoint;
	
	UPROPERTY(DefaultComponent, Attach = SentryMountPoint)
	USphereComponent SnapZone;
	default SnapZone.SetSphereRadius(75.0f);
	default SnapZone.SetCollisionEnabled(ECollisionEnabled::QueryOnly);
	default SnapZone.SetGenerateOverlapEvents(true);
	default SnapZone.SetCollisionResponseToAllChannels(ECollisionResponse::ECR_Ignore);
	default SnapZone.SetCollisionResponseToChannel(ECollisionChannel::ECC_WorldDynamic, ECollisionResponse::ECR_Overlap);

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

	ABSSentry Sentry;
	ABSSentry PendingSentry;
	ABSPlayerController ActiveUser;
	UBSAssemblyScreen CraftMenu;
	
	FTimerHandle PendingSentryTimerHandle;

	default CameraViewpoint.bAutoActivate = false;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		WorkbenchAction.Delegate.BindUFunction(this, n"OnInteracted");
		InteractionRegistry.RegisterAction(WorkbenchAction);
		
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

		ABSPlayerController Controller = Cast<ABSPlayerController>(InteractorPawn.Controller);
		if (Controller != nullptr)
		{	
			EnsureSentry();
			ActivateWorkbench(Controller);
		}
	}

	void EnsureSentry()
	{
		if (SentryClass.Get() != nullptr && Sentry == nullptr)
		{
			FVector SpawnLocation = SentryMountPoint.GetWorldLocation();
			FRotator SpawnRotation = SentryMountPoint.GetWorldRotation();
			ABSSentry NewSentry = Cast<ABSSentry>(SpawnActor(SentryClass, SpawnLocation, SpawnRotation));
			MountSentry(NewSentry);
		}
	}

	void ActivateWorkbench(ABSPlayerController Controller)
	{
		ActiveUser = Controller;
		CameraViewpoint.Activate();
		Controller.SetViewTargetWithBlend(this, 0.5f);

		UCommonActivatableWidget Widget = Controller.PushWidgetToPrimaryLayout(
			GameplayTags::ForgeryUI_Layer_GameMenu,
			CraftMenuWidgetClass);

		CraftMenu = Cast<UBSAssemblyScreen>(Widget);
		if (CraftMenu != nullptr)
		{
			CraftMenu.OwningWorkbench = this;
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

	void UnmountSentry()
	{
		if (Sentry != nullptr)
		{
			Sentry.EnableTerminalInteraction();
			Sentry = nullptr;
		}
	}

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
