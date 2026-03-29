class UBSSentryVisualAdapter : UActorComponent
{
	TArray<UStaticMeshComponent> LoadoutElements;
	TArray<UStaticMeshComponent> ChassisElements;
	TMap<FName, USceneComponent> SocketOwnerCache;

	UStaticMeshComponent YawPivot;
	UStaticMeshComponent PitchPivot;

	int ElementCounter = 0;
	int LastCompositionVersion = -1;

	UBSChassisDefinition ActiveChassis;

	FVector YawPivotOffset;
	FVector PitchPivotOffset;
	USceneComponent MuzzleComponent;
	FVector MuzzleOffset;
	FRotator MuzzleForwardRotation;

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		UBSModularComponent ModularComponent = UBSModularComponent::Get(Owner);
		if (ModularComponent != nullptr)
		{
			ModularComponent.OnCompositionChanged.AddUFunction(this, n"OnCompositionChanged");
		}

		RebuildFromCurrentModules();
	}

	UFUNCTION()
	void OnCompositionChanged(UBSModularComponent ModularComponent)
	{
		RebuildFromCurrentModules();
	}

	void RebuildFromCurrentModules()
	{
		ABSSentry Sentry = Cast<ABSSentry>(Owner);
		UBSModularComponent ModularComponent = UBSModularComponent::Get(Owner);
		if (Sentry == nullptr || ModularComponent == nullptr)
		{
			return;
		}

		LastCompositionVersion = ModularComponent.CompositionVersion;
		SentryAssembly::Rebuild(this, Sentry, ModularComponent, Sentry.Material);
	}

	bool HasAimRig() const
	{
		return ActiveChassis != nullptr && YawPivot != nullptr && PitchPivot != nullptr;
	}

	USceneComponent GetDefaultAttachParent(ABSSentry Sentry) const
	{
		if (PitchPivot != nullptr)
		{
			return PitchPivot;
		}

		if (YawPivot != nullptr)
		{
			return YawPivot;
		}

		return Sentry.Base;
	}
}

namespace SentryAssembly
{
	void Rebuild(UBSSentryVisualAdapter Adapter, ABSSentry Sentry, UBSModularComponent ModularComponent, UMaterialInterface Material)
	{
		ClearMeshes(Adapter, Sentry);

		Adapter.ActiveChassis = FindChassis(ModularComponent);
		if (Adapter.ActiveChassis != nullptr)
		{
			BuildChassis(Adapter.ActiveChassis, Adapter, Sentry, Material);
		}

		for (UBFModuleDefinition Module : ModularComponent.InstalledModules)
		{
			if (Module == nullptr)
			{
				continue;
			}

			auto TurretDefinition = Cast<UBSTurretDefinition>(Module);
			if (TurretDefinition != nullptr)
			{
				AppendLoadout(TurretDefinition.Elements, Adapter, Sentry, Material);
				continue;
			}

			auto GenericDefinition = Cast<UBSGenericModule>(Module);
			if (GenericDefinition != nullptr && GenericDefinition.BaseMesh != nullptr)
			{
				FName Socket = ResolveOccupiedSocket(ModularComponent, Module);
				AttachModuleMesh(GenericDefinition.BaseMesh, Socket, Adapter, Sentry, Material);
			}
		}

		CacheGeometry(Adapter, Sentry);
	}

	UBSChassisDefinition FindChassis(UBSModularComponent ModularComponent)
	{
		for (UBFModuleDefinition Module : ModularComponent.InstalledModules)
		{
			auto ChassisDefinition = Cast<UBSChassisDefinition>(Module);
			if (ChassisDefinition != nullptr)
			{
				return ChassisDefinition;
			}
		}

		return nullptr;
	}

	FName ResolveOccupiedSocket(UBSModularComponent ModularComponent, UBFModuleDefinition Module)
	{
		for (int SlotIndex = 0; SlotIndex < ModularComponent.SlotModuleIndices.Num(); SlotIndex++)
		{
			UBFModuleDefinition Occupant = ModularComponent.GetModuleForSlot(SlotIndex);
			if (Occupant == Module)
			{
				return ModularComponent.Slots[SlotIndex].Socket;
			}
		}

		return NAME_None;
	}

	void BuildChassis(UBSChassisDefinition Definition, UBSSentryVisualAdapter Adapter, ABSSentry Sentry, UMaterialInterface Material)
	{
		EnsurePivotComponents(Adapter, Sentry);

		Sentry.Base.SetStaticMesh(Definition.BaseMesh);
		Adapter.YawPivot.SetStaticMesh(Definition.Rotator01Mesh);
		Adapter.PitchPivot.SetStaticMesh(Definition.Rotator02Mesh);

		Adapter.YawPivot.DetachFromParent();
		Adapter.PitchPivot.DetachFromParent();

		Adapter.YawPivot.AttachTo(Sentry.Base, Sentry::ChildSocketName);
		Adapter.PitchPivot.AttachTo(Adapter.YawPivot, Sentry::ChildSocketName);

		Adapter.YawPivot.SetRelativeRotation(FRotator(0, 0, 0));
		Adapter.PitchPivot.SetRelativeRotation(FRotator(0, 0, 0));

		ApplyMaterial(Sentry.Base, Material);
		ApplyMaterial(Adapter.YawPivot, Material);
		ApplyMaterial(Adapter.PitchPivot, Material);

		BuildChassisElements(Definition, Adapter, Sentry, Material);
	}

	void EnsurePivotComponents(UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		if (Adapter.YawPivot == nullptr)
		{
			Adapter.YawPivot = UStaticMeshComponent::Create(Sentry, n"SentryYawPivot");
			Adapter.YawPivot.AttachTo(Sentry.Base);
		}

		if (Adapter.PitchPivot == nullptr)
		{
			Adapter.PitchPivot = UStaticMeshComponent::Create(Sentry, n"SentryPitchPivot");
			Adapter.PitchPivot.AttachTo(Adapter.YawPivot);
		}
	}

	void BuildChassisElements(UBSChassisDefinition Definition, UBSSentryVisualAdapter Adapter, ABSSentry Sentry, UMaterialInterface Material)
	{
		for (UStaticMeshComponent Element : Adapter.ChassisElements)
		{
			Element.DestroyComponent(Sentry);
		}
		Adapter.ChassisElements.Empty();

		if (Definition.PlatformMesh != nullptr)
		{
			++Adapter.ElementCounter;
			UStaticMeshComponent Platform = UStaticMeshComponent::Create(Sentry, FName(f"ChassisElement_{Adapter.ElementCounter}"));
			Platform.SetStaticMesh(Definition.PlatformMesh);
			Platform.AttachTo(Adapter.YawPivot != nullptr ? Adapter.YawPivot : Sentry.Base);

			float PlatformHeight = Platform.StaticMesh.BoundingBox.Extent.Z;
			Platform.RelativeLocation = FVector(0, 0, -PlatformHeight);
			ApplyMaterial(Platform, Material);

			Adapter.ChassisElements.Add(Platform);
		}
	}

	void AppendLoadout(const TArray<FBSLoadoutElement>& Elements, UBSSentryVisualAdapter Adapter, ABSSentry Sentry, UMaterialInterface Material)
	{
		for (int Index = 0; Index < Elements.Num(); Index++)
		{
			const FBSLoadoutElement& Element = Elements[Index];

			++Adapter.ElementCounter;
			UStaticMeshComponent Component = UStaticMeshComponent::Create(Sentry, FName(f"LoadoutElement_{Adapter.ElementCounter}"));
			Component.SetStaticMesh(Element.Mesh);
			ApplyMaterial(Component, Material);

			USceneComponent ParentTo = Adapter.GetDefaultAttachParent(Sentry);
			if (Element.ParentIndex >= 0 && Element.ParentIndex < Adapter.LoadoutElements.Num())
			{
				ParentTo = Adapter.LoadoutElements[Element.ParentIndex];
			}

			if (Element.Socket != NAME_None)
			{
				Component.AttachTo(ParentTo, Element.Socket);
			}
			else
			{
				Component.AttachTo(ParentTo);
			}

			Component.RelativeLocation = Element.Offset;
			Adapter.LoadoutElements.Add(Component);
		}
	}

	void CacheGeometry(UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		Adapter.MuzzleComponent = nullptr;
		Adapter.YawPivotOffset = FVector::ZeroVector;
		Adapter.PitchPivotOffset = FVector::ZeroVector;
		Adapter.MuzzleOffset = FVector::ZeroVector;
		Adapter.MuzzleForwardRotation = FRotator(0, 0, 0);

		if (Adapter.YawPivot == nullptr || Adapter.PitchPivot == nullptr)
		{
			return;
		}

		FVector BasePivotWorld = Sentry.Base.DoesSocketExist(Sentry::ChildSocketName)
			? Sentry.Base.GetSocketLocation(Sentry::ChildSocketName)
			: Adapter.YawPivot.WorldLocation;
		Adapter.YawPivotOffset = Sentry.Base.WorldTransform.InverseTransformPosition(BasePivotWorld);

		FVector PitchPivotWorld = Adapter.YawPivot.DoesSocketExist(Sentry::ChildSocketName)
			? Adapter.YawPivot.GetSocketLocation(Sentry::ChildSocketName)
			: Adapter.PitchPivot.WorldLocation;
		Adapter.PitchPivotOffset = Adapter.YawPivot.WorldTransform.InverseTransformPosition(PitchPivotWorld);

		TArray<USceneComponent> AllChildren;
		Adapter.PitchPivot.GetChildrenComponents(true, AllChildren);

		for (USceneComponent Child : AllChildren)
		{
			if (Child.DoesSocketExist(Sentry::MuzzleSocketName))
			{
				Adapter.MuzzleComponent = Child;
				break;
			}
		}

		if (Adapter.MuzzleComponent == nullptr && Adapter.PitchPivot.DoesSocketExist(Sentry::MuzzleSocketName))
		{
			Adapter.MuzzleComponent = Adapter.PitchPivot;
		}

		if (Adapter.MuzzleComponent != nullptr)
		{
			FTransform MuzzleSocketWorld = Adapter.MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
			Adapter.MuzzleOffset = Adapter.PitchPivot.WorldTransform.InverseTransformPosition(MuzzleSocketWorld.Location);
			FVector MuzzleForwardWorld = MuzzleSocketWorld.Rotation.ForwardVector;
			Adapter.MuzzleForwardRotation = Adapter.PitchPivot.WorldTransform.InverseTransformVector(MuzzleForwardWorld).Rotation();
		}
	}

	void ClearMeshes(UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		Adapter.SocketOwnerCache.Empty();
		Adapter.ActiveChassis = nullptr;
		Adapter.MuzzleComponent = nullptr;
		Adapter.ElementCounter = 0;

		Sentry.Base.SetStaticMesh(nullptr);

		if (Adapter.YawPivot != nullptr)
		{
			Adapter.YawPivot.SetStaticMesh(nullptr);
			Adapter.YawPivot.SetRelativeRotation(FRotator(0, 0, 0));
		}

		if (Adapter.PitchPivot != nullptr)
		{
			Adapter.PitchPivot.SetStaticMesh(nullptr);
			Adapter.PitchPivot.SetRelativeRotation(FRotator(0, 0, 0));
		}

		for (UStaticMeshComponent Element : Adapter.ChassisElements)
		{
			Element.DestroyComponent(Sentry);
		}
		Adapter.ChassisElements.Empty();

		for (UStaticMeshComponent Element : Adapter.LoadoutElements)
		{
			Element.DestroyComponent(Sentry);
		}
		Adapter.LoadoutElements.Empty();
	}

	USceneComponent FindSocketOwner(UBSSentryVisualAdapter Adapter, ABSSentry Sentry, FName Socket)
	{
		if (Socket == NAME_None)
		{
			return nullptr;
		}

		if (Adapter.SocketOwnerCache.Contains(Socket))
		{
			return Adapter.SocketOwnerCache[Socket];
		}

		USceneComponent Found = SearchSocketOwner(Adapter, Sentry, Socket);
		Adapter.SocketOwnerCache.Add(Socket, Found);
		return Found;
	}

	USceneComponent SearchSocketOwner(UBSSentryVisualAdapter Adapter, ABSSentry Sentry, FName Socket)
	{
		if (Sentry.Base.DoesSocketExist(Socket))
		{
			return Sentry.Base;
		}
		if (Adapter.YawPivot != nullptr && Adapter.YawPivot.DoesSocketExist(Socket))
		{
			return Adapter.YawPivot;
		}
		if (Adapter.PitchPivot != nullptr && Adapter.PitchPivot.DoesSocketExist(Socket))
		{
			return Adapter.PitchPivot;
		}

		for (UStaticMeshComponent Element : Adapter.ChassisElements)
		{
			if (Element.DoesSocketExist(Socket))
			{
				return Element;
			}
		}

		for (UStaticMeshComponent Element : Adapter.LoadoutElements)
		{
			if (Element.DoesSocketExist(Socket))
			{
				return Element;
			}
		}

		return nullptr;
	}

	UStaticMeshComponent AttachModuleMesh(UStaticMesh ModuleMesh, FName Socket, UBSSentryVisualAdapter Adapter, ABSSentry Sentry, UMaterialInterface Material)
	{
		if (ModuleMesh == nullptr)
		{
			return nullptr;
		}

		++Adapter.ElementCounter;
		UStaticMeshComponent Component = UStaticMeshComponent::Create(Sentry, FName(f"ModuleElement_{Adapter.ElementCounter}"));
		Component.SetStaticMesh(ModuleMesh);
		ApplyMaterial(Component, Material);

		USceneComponent SocketOwner = FindSocketOwner(Adapter, Sentry, Socket);
		if (SocketOwner != nullptr)
		{
			Component.AttachTo(SocketOwner, Socket);
		}
		else
		{
			Component.AttachTo(Adapter.GetDefaultAttachParent(Sentry));
		}

		Adapter.LoadoutElements.Add(Component);
		return Component;
	}

	void ApplyMaterial(UStaticMeshComponent Component, UMaterialInterface Material)
	{
		if (Component != nullptr && Material != nullptr)
		{
			Component.SetMaterial(0, Material);
		}
	}
}
