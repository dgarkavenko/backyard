class ABSSentry : AActor
{
	UPROPERTY(DefaultComponent)
	UBSInteractionRegistry InteractionRegistry;

	UPROPERTY(DefaultComponent)
	UBSTerminalInteraction TerminalInteraction;
	
	UPROPERTY(DefaultComponent)
	UBSDragInteraction DragInteraction;

	default DragInteraction.Action.HoldDuration = 1.0f;

	UPROPERTY(DefaultComponent, RootComponent)
	UStaticMeshComponent Base;

	UPROPERTY(DefaultComponent, Attach = Base, AttachSocket = s_child_01)
	UStaticMeshComponent Rotator01;

	UPROPERTY(DefaultComponent, Attach = Rotator01, AttachSocket = s_child_01)
	UStaticMeshComponent Rotator02;

	UPROPERTY(DefaultComponent, Attach = Rotator02, AttachSocket = s_child_01)
	UStaticMeshComponent Chassis;

	UPROPERTY(Instanced, EditAnywhere, Category = "Sentry")
	UBSSentryConfiguration Configuration;

	TArray<UStaticMeshComponent> LoadoutElements;
	TArray<UStaticMeshComponent> ChassisElements;

	int ElementCounter = 0;

	UPROPERTY(EditAnywhere, Category = "Sentry")
	UMaterialInterface Material;

	FVector Rotator01PivotOffset;
	FVector Rotator02PivotOffset;

	UStaticMeshComponent MuzzleComponent;
	FVector MuzzleOffset;
	FRotator MuzzleForwardRotation;

	void ApplyConfiguration()
	{
		if (Configuration == nullptr)
		{
			return;
		}

		if (Configuration.Chassis == nullptr)
		{
			Base.SetStaticMesh(nullptr);
			Rotator01.SetStaticMesh(nullptr);
			Rotator02.SetStaticMesh(nullptr);
			Chassis.SetStaticMesh(nullptr);
			BuildLoadoutElements();
			return;
		}

		Print(f"ApplyConfiguration: Chassis={Configuration.Chassis.GetName()} Arm={Configuration.Chassis.Arm.GetName()}");

		Rotator01.DetachFromParent();
		Rotator02.DetachFromParent();
		Chassis.DetachFromParent();

		Base.SetStaticMesh(Configuration.Chassis.BaseMesh);
		Rotator01.SetStaticMesh(Configuration.Chassis.Arm.Rotator01.Mesh);
		Rotator02.SetStaticMesh(Configuration.Chassis.Arm.Rotator02.Mesh);

		Rotator01.AttachTo(Base, Sentry::ChildSocketName);
		Rotator02.AttachTo(Rotator01, Sentry::ChildSocketName);
		Chassis.AttachTo(Rotator02, Sentry::ChildSocketName);

		ApplyMaterial(Base);
		ApplyMaterial(Rotator01);
		ApplyMaterial(Rotator02);



		BuildChassisElements();
		BuildLoadoutElements();
	}

	void BuildChassisElements()
	{
		for (UStaticMeshComponent Element : ChassisElements)
		{
			Element.DestroyComponent(this);
		}

		ChassisElements.Empty();

		if (Configuration.Chassis.Arm.Platform != nullptr)
		{
			++ElementCounter;
			ChassisElements.Add(UStaticMeshComponent::Create(this, FName(f"ChassisElement_{ElementCounter}")));
			
			ChassisElements[0].SetStaticMesh(Configuration.Chassis.Arm.Platform);
			ChassisElements[0].AttachTo(Rotator01);

			float PlatformHeight = ChassisElements[0].StaticMesh.BoundingBox.Extent.Z;
			ChassisElements[0].RelativeLocation = FVector(0, 0, -PlatformHeight);
			ApplyMaterial(ChassisElements[0]);
		}
	}

	void ApplyMaterial(UStaticMeshComponent Component)
	{
		Component.SetMaterial(0, Material);
	}

	void BuildLoadoutElements()
	{
		for (UStaticMeshComponent Element : LoadoutElements)
		{
			Element.DestroyComponent(this);
		}
		LoadoutElements.Empty();

		if (Configuration.Chassis != nullptr)
		{
			Chassis.SetStaticMesh(Configuration.Chassis.FrameMesh);
			ApplyMaterial(Chassis);
		}

		if (Configuration.Loadout == nullptr)
		{
			return;
		}

		for (int Index = 0; Index < Configuration.Loadout.Elements.Num(); Index++)
		{
			const FBSLoadoutElement& Element = Configuration.Loadout.Elements[Index];

			++ElementCounter;
			UStaticMeshComponent Component = UStaticMeshComponent::Create(this, FName(f"LoadoutElement_{ElementCounter}"));
			Component.SetStaticMesh(Element.Mesh);
			ApplyMaterial(Component);

			FVector FrameOffset = FVector::ZeroVector;
			if (Chassis.StaticMesh != nullptr && Element.ParentIndex < 0)
			{
				FrameOffset = FVector(0,0, Chassis.StaticMesh.BoundingBox.Extent.Z * 2);
			}

			USceneComponent ParentTo = Chassis;
			if (Element.ParentIndex >= 0 && Element.ParentIndex < LoadoutElements.Num())
			{
				ParentTo = LoadoutElements[Element.ParentIndex];
			}

			if (Element.Socket != NAME_None)
			{
				Component.AttachTo(ParentTo, Element.Socket);
			}
			else
			{
				Component.AttachTo(ParentTo);
			}

			Component.RelativeLocation = Element.Offset + FrameOffset;
			LoadoutElements.Add(Component);
		}
	}

	UFUNCTION(BlueprintOverride)
	void ConstructionScript()
	{
		ApplyConfiguration();
	}

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		Base.SetGenerateOverlapEvents(true);
		CacheGeometry();
	}

	void CacheGeometry()
	{
		FVector BasePivotWorld = Base.GetSocketLocation(Sentry::ChildSocketName);
		Rotator01PivotOffset = Base.WorldTransform.InverseTransformPosition(BasePivotWorld);

		FVector Rotator01PivotWorld = Rotator01.GetSocketLocation(Sentry::ChildSocketName);
		Rotator02PivotOffset = Rotator01.WorldTransform.InverseTransformPosition(Rotator01PivotWorld);

		TArray<USceneComponent> ChassisChildren;
		Chassis.GetChildrenComponents(true, ChassisChildren);

		MuzzleComponent = nullptr;
		for (auto Child : ChassisChildren)
		{
			auto MeshComponent = Cast<UStaticMeshComponent>(Child);
			if (MeshComponent != nullptr && MeshComponent.DoesSocketExist(Sentry::MuzzleSocketName))
			{
				MuzzleComponent = MeshComponent;
				break;
			}
		}

		if (MuzzleComponent != nullptr)
		{
			FTransform MuzzleSocketWorld = MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
			MuzzleOffset = Rotator02.WorldTransform.InverseTransformPosition(MuzzleSocketWorld.Location);
			FVector MuzzleForwardWorld = MuzzleSocketWorld.Rotation.ForwardVector;
			MuzzleForwardRotation = Rotator02.WorldTransform.InverseTransformVector(MuzzleForwardWorld).Rotation();
		}
	}

	void DisableTerminalInteraction()
	{
		InteractionRegistry.UnregisterActionByTag(GameplayTags::Backyard_Interaction_Terminal);
	}

	void EnableTerminalInteraction()
	{
		InteractionRegistry.RegisterAction(TerminalInteraction.TerminalInteraction);
	}

	UFUNCTION(BlueprintCallable, Category = "Sentry")
	void AimAt(FVector WorldLocation, float DeltaSeconds)
	{
		if (Configuration == nullptr || Configuration.Chassis.Arm == nullptr)
		{
			return;
		}

		FVector Rotator01PivotWorld = Base.WorldTransform.TransformPosition(Rotator01PivotOffset);
		FVector DirectionToTarget = (WorldLocation - Rotator01PivotWorld).GetSafeNormal();
		FVector LocalDirection = Base.WorldTransform.InverseTransformVector(DirectionToTarget);
		FRotator Constrained = Sentry::ConstrainRotation(
			Rotator01.RelativeRotation, LocalDirection.Rotation(),
			Configuration.Chassis.Arm.Rotator01.Constraint, DeltaSeconds
		);
		Rotator01.SetRelativeRotation(Constrained);

		if (MuzzleComponent != nullptr)
		{
			FVector MuzzleWorld = Rotator02.WorldTransform.TransformPosition(MuzzleOffset);
			DirectionToTarget = (WorldLocation - MuzzleWorld).GetSafeNormal();
			LocalDirection = Rotator01.WorldTransform.InverseTransformVector(DirectionToTarget);
			FRotator DesiredRotation = LocalDirection.Rotation() - MuzzleForwardRotation;
			Constrained = Sentry::ConstrainRotation(
				Rotator02.RelativeRotation, DesiredRotation,
				Configuration.Chassis.Arm.Rotator02.Constraint, DeltaSeconds
			);
		}
		else
		{
			FVector Rotator02PivotWorld = Rotator01.WorldTransform.TransformPosition(Rotator02PivotOffset);
			DirectionToTarget = (WorldLocation - Rotator02PivotWorld).GetSafeNormal();
			LocalDirection = Rotator01.WorldTransform.InverseTransformVector(DirectionToTarget);
			Constrained = Sentry::ConstrainRotation(
				Rotator02.RelativeRotation, LocalDirection.Rotation(),
				Configuration.Chassis.Arm.Rotator02.Constraint, DeltaSeconds
			);
		}
		Rotator02.SetRelativeRotation(Constrained);
	}
	
	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		auto PlayerCharacter = Gameplay::GetPlayerCharacter(0);
		if (PlayerCharacter != nullptr)
		{
			AimAt(PlayerCharacter.ActorLocation, DeltaSeconds);
		}		
	}
}
