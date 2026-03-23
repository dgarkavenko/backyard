class ABSSentry : AActor
{
	UPROPERTY(DefaultComponent, RootComponent)
	UStaticMeshComponent Base;

	UPROPERTY(DefaultComponent, Attach = Base, AttachSocket = s_child_01)
	UStaticMeshComponent Rotator01;

	UPROPERTY(DefaultComponent, Attach = Rotator01, AttachSocket = s_child_01)
	UStaticMeshComponent Rotator02;
	
	// move to optional visual
	UPROPERTY(DefaultComponent, Attach = Rotator01)
	UStaticMeshComponent RotatorPlatform;

	UPROPERTY(DefaultComponent, Attach = Rotator02, AttachSocket = s_child_01)
	UStaticMeshComponent Chassis;

	UPROPERTY(Instanced, EditAnywhere, Category = "Sentry")
	UBSSentryConfiguration Configuration;

	TArray<UStaticMeshComponent> ChassisElements;
	int ChassisElementCounter = 0;

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
			RotatorPlatform.SetStaticMesh(nullptr);
			Chassis.SetStaticMesh(nullptr);
			BuildChassisElements();
			return;
		}

		Print(f"ApplyConfiguration: Chassis={Configuration.Chassis.GetName()} Arm={Configuration.Chassis.Arm.GetName()}");

		Rotator01.DetachFromParent();
		Rotator02.DetachFromParent();
		RotatorPlatform.DetachFromParent();
		Chassis.DetachFromParent();

		Base.SetStaticMesh(Configuration.Chassis.BaseMesh);
		Rotator01.SetStaticMesh(Configuration.Chassis.Arm.Rotator01.Mesh);
		Rotator02.SetStaticMesh(Configuration.Chassis.Arm.Rotator02.Mesh);
		RotatorPlatform.SetStaticMesh(Configuration.Chassis.Arm.Platform);

		Rotator01.AttachTo(Base, Sentry::ChildSocketName);
		RotatorPlatform.AttachTo(Rotator01);
		Rotator02.AttachTo(Rotator01, Sentry::ChildSocketName);
		Chassis.AttachTo(Rotator02, Sentry::ChildSocketName);

		Print(f"  After reattach: R01 world={Rotator01.WorldLocation} R02 world={Rotator02.WorldLocation} Chassis world={Chassis.WorldLocation}");

		ApplyMaterial(Base);
		ApplyMaterial(Rotator01);
		ApplyMaterial(Rotator02);
		ApplyMaterial(RotatorPlatform);

		if (Configuration.Chassis.Arm.Platform != nullptr)
		{
			float PlatformHeight = RotatorPlatform.StaticMesh.BoundingBox.Extent.Z;
			RotatorPlatform.RelativeLocation = FVector(0, 0, -PlatformHeight);
			Print(f"  Platform height={PlatformHeight}");
		}

		BuildChassisElements();
	}

	void ApplyMaterial(UStaticMeshComponent Component)
	{
		Component.SetMaterial(0, Material);
	}

	void BuildChassisElements()
	{
		for (UStaticMeshComponent Element : ChassisElements)
		{
			Element.DestroyComponent(this);
		}
		ChassisElements.Empty();

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

			UStaticMeshComponent Component = UStaticMeshComponent::Create(this, FName(f"ChassisElement_{ChassisElementCounter++}"));
			Component.SetStaticMesh(Element.Mesh);
			ApplyMaterial(Component);

			FVector FrameOffset = FVector::ZeroVector;
			if (Chassis.StaticMesh != nullptr && Element.ParentIndex < 0)
			{
				FrameOffset = FVector(0,0, Chassis.StaticMesh.BoundingBox.Extent.Z * 2);
			}

			USceneComponent ParentTo = Chassis;
			if (Element.ParentIndex >= 0 && Element.ParentIndex < ChassisElements.Num())
			{
				ParentTo = ChassisElements[Element.ParentIndex];
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
			ChassisElements.Add(Component);
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
