namespace SentryAssembly
{
	void BuildChassis(UBSChassisDefinition Definition, ABSSentry Sentry, UMaterialInterface Material)
	{
		if (Definition == nullptr)
		{
			Sentry.Base.SetStaticMesh(nullptr);
			Sentry.Rotator01.SetStaticMesh(nullptr);
			Sentry.Rotator02.SetStaticMesh(nullptr);
			return;
		}

		// Set meshes first so sockets exist before re-attachment
		Sentry.Base.SetStaticMesh(Definition.BaseMesh);
		Sentry.Rotator01.SetStaticMesh(Definition.Rotator01Mesh);
		Sentry.Rotator02.SetStaticMesh(Definition.Rotator02Mesh);

		Sentry.Rotator02.DetachFromParent();
		Sentry.Rotator01.DetachFromParent();

		Sentry.Rotator01.AttachTo(Sentry.Base, Sentry::ChildSocketName);
		Sentry.Rotator02.AttachTo(Sentry.Rotator01, Sentry::ChildSocketName);

		ApplyMaterial(Sentry.Base, Material);
		ApplyMaterial(Sentry.Rotator01, Material);
		ApplyMaterial(Sentry.Rotator02, Material);

		BuildChassisElements(Definition, Sentry, Material);
	}

	void BuildChassisElements(UBSChassisDefinition Definition, ABSSentry Sentry, UMaterialInterface Material)
	{
		for (UStaticMeshComponent Element : Sentry.ChassisElements)
		{
			Element.DestroyComponent(Sentry);
		}
		Sentry.ChassisElements.Empty();

		if (Definition.PlatformMesh != nullptr)
		{
			++Sentry.ElementCounter;
			UStaticMeshComponent Platform = UStaticMeshComponent::Create(Sentry, FName(f"ChassisElement_{Sentry.ElementCounter}"));
			Platform.SetStaticMesh(Definition.PlatformMesh);
			Platform.AttachTo(Sentry.Rotator01);

			float PlatformHeight = Platform.StaticMesh.BoundingBox.Extent.Z;
			Platform.RelativeLocation = FVector(0, 0, -PlatformHeight);
			ApplyMaterial(Platform, Material);

			Sentry.ChassisElements.Add(Platform);
		}
	}

	void BuildLoadout(const TArray<FBSLoadoutElement>& Elements, ABSSentry Sentry, UMaterialInterface Material)
	{
		for (UStaticMeshComponent Element : Sentry.LoadoutElements)
		{
			Element.DestroyComponent(Sentry);
		}
		Sentry.LoadoutElements.Empty();

		for (int Index = 0; Index < Elements.Num(); Index++)
		{
			const FBSLoadoutElement& Element = Elements[Index];

			++Sentry.ElementCounter;
			UStaticMeshComponent Component = UStaticMeshComponent::Create(Sentry, FName(f"LoadoutElement_{Sentry.ElementCounter}"));
			Component.SetStaticMesh(Element.Mesh);
			ApplyMaterial(Component, Material);

			USceneComponent ParentTo = Sentry.Rotator02;
			if (Element.ParentIndex >= 0 && Element.ParentIndex < Sentry.LoadoutElements.Num())
			{
				ParentTo = Sentry.LoadoutElements[Element.ParentIndex];
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
			Sentry.LoadoutElements.Add(Component);
		}
	}

	void CacheGeometry(ABSSentry Sentry)
	{
		FVector BasePivotWorld = Sentry.Base.GetSocketLocation(Sentry::ChildSocketName);
		Sentry.Rotator01PivotOffset = Sentry.Base.WorldTransform.InverseTransformPosition(BasePivotWorld);

		FVector Rotator01PivotWorld = Sentry.Rotator01.GetSocketLocation(Sentry::ChildSocketName);
		Sentry.Rotator02PivotOffset = Sentry.Rotator01.WorldTransform.InverseTransformPosition(Rotator01PivotWorld);

		TArray<USceneComponent> AllChildren;
		Sentry.Rotator02.GetChildrenComponents(true, AllChildren);

		Sentry.MuzzleComponent = nullptr;
		for (auto Child : AllChildren)
		{
			auto MeshComponent = Cast<UStaticMeshComponent>(Child);
			if (MeshComponent != nullptr && MeshComponent.DoesSocketExist(Sentry::MuzzleSocketName))
			{
				Sentry.MuzzleComponent = MeshComponent;
				break;
			}
		}

		if (Sentry.MuzzleComponent != nullptr)
		{
			FTransform MuzzleSocketWorld = Sentry.MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
			Sentry.MuzzleOffset = Sentry.Rotator02.WorldTransform.InverseTransformPosition(MuzzleSocketWorld.Location);
			FVector MuzzleForwardWorld = MuzzleSocketWorld.Rotation.ForwardVector;
			Sentry.MuzzleForwardRotation = Sentry.Rotator02.WorldTransform.InverseTransformVector(MuzzleForwardWorld).Rotation();
		}
	}

	void ClearMeshes(ABSSentry Sentry)
	{
		Sentry.SocketOwnerCache.Empty();
		Sentry.Base.SetStaticMesh(nullptr);
		Sentry.Rotator01.SetStaticMesh(nullptr);
		Sentry.Rotator02.SetStaticMesh(nullptr);

		for (UStaticMeshComponent Element : Sentry.ChassisElements)
		{
			Element.DestroyComponent(Sentry);
		}
		Sentry.ChassisElements.Empty();

		for (UStaticMeshComponent Element : Sentry.LoadoutElements)
		{
			Element.DestroyComponent(Sentry);
		}
		Sentry.LoadoutElements.Empty();
	}

	USceneComponent FindSocketOwner(ABSSentry Sentry, FName Socket)
	{
		if (Socket == NAME_None)
		{
			return nullptr;
		}

		if (Sentry.SocketOwnerCache.Contains(Socket))
		{
			return Sentry.SocketOwnerCache[Socket];
		}

		USceneComponent Found = SearchSocketOwner(Sentry, Socket);
		Sentry.SocketOwnerCache.Add(Socket, Found);
		return Found;
	}

	USceneComponent SearchSocketOwner(ABSSentry Sentry, FName Socket)
	{
		if (Sentry.Base.DoesSocketExist(Socket))
		{
			return Sentry.Base;
		}
		if (Sentry.Rotator01.DoesSocketExist(Socket))
		{
			return Sentry.Rotator01;
		}
		if (Sentry.Rotator02.DoesSocketExist(Socket))
		{
			return Sentry.Rotator02;
		}

		for (UStaticMeshComponent Element : Sentry.ChassisElements)
		{
			if (Element.DoesSocketExist(Socket))
			{
				return Element;
			}
		}

		for (UStaticMeshComponent Element : Sentry.LoadoutElements)
		{
			if (Element.DoesSocketExist(Socket))
			{
				return Element;
			}
		}

		return nullptr;
	}

	UStaticMeshComponent AttachModuleMesh(UStaticMesh ModuleMesh, FName Socket, ABSSentry Sentry, UMaterialInterface Material)
	{
		if (ModuleMesh == nullptr)
		{
			return nullptr;
		}

		++Sentry.ElementCounter;
		UStaticMeshComponent Component = UStaticMeshComponent::Create(Sentry, FName(f"ModuleElement_{Sentry.ElementCounter}"));
		Component.SetStaticMesh(ModuleMesh);
		ApplyMaterial(Component, Material);

		USceneComponent SocketOwner = FindSocketOwner(Sentry, Socket);
		if (SocketOwner != nullptr)
		{
			Component.AttachTo(SocketOwner, Socket);
		}
		else
		{
			Component.AttachTo(Sentry.Rotator02);
		}

		Sentry.LoadoutElements.Add(Component);
		return Component;
	}

	void ApplyMaterial(UStaticMeshComponent Component, UMaterialInterface Material)
	{
		if (Material != nullptr)
		{
			Component.SetMaterial(0, Material);
		}
	}
}
