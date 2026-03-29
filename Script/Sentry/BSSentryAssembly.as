struct FBSBuiltAssemblyElement
{
	FName ElementId;
	USceneComponent Component;
}

struct FBSBuiltModuleView
{
	TArray<FBSBuiltAssemblyElement> Elements;
	USceneComponent PrimaryComponent;
}

class UBSSentryVisualAdapter : UActorComponent
{
	TArray<UStaticMeshComponent> ModuleElementPool;
	TArray<int> ModuleElementGenerations;
	TArray<UStaticMeshComponent> ActiveModuleElements;

	TMap<FName, USceneComponent> SocketOwnerCache;

	UStaticMeshComponent YawPivot;
	UStaticMeshComponent PitchPivot;
	USceneComponent MuzzleComponent;

	int RebuildGeneration = 0;

	FBSSentryConstraint YawConstraint;
	FBSSentryConstraint PitchConstraint;
	FVector YawPivotOffset;
	FVector PitchPivotOffset;
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

		SentryAssembly::Rebuild(this, Sentry, ModularComponent, Sentry.Material);
	}

	bool HasAimRig() const
	{
		return YawPivot != nullptr && PitchPivot != nullptr;
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
		BeginRebuild(Adapter, Sentry);
		SentryDebug::LogAssembly(f"Assembly: rebuild sentry='{Sentry.GetName()}' modules={ModularComponent.InstalledModules.Num()}");

		TArray<FBSBuiltModuleView> InstalledModuleViews;
		for (int Index = 0; Index < ModularComponent.InstalledModules.Num(); Index++)
		{
			InstalledModuleViews.Add(FBSBuiltModuleView());
		}

		for (int ModuleIndex = 0; ModuleIndex < ModularComponent.InstalledModules.Num(); ModuleIndex++)
		{
			UBSModuleDefinition Module = Cast<UBSModuleDefinition>(ModularComponent.InstalledModules[ModuleIndex]);
			if (Module == nullptr)
			{
				UBFModuleDefinition RawModule = ModularComponent.InstalledModules[ModuleIndex];
				FString RawModuleName = RawModule != nullptr ? RawModule.GetName().ToString() : "<none>";
				SentryDebug::LogAssembly(f"Assembly: skipping non-script module '{RawModuleName}'");
				continue;
			}

			int OccupiedSlotIndex = ModularComponent.GetOccupiedSlotIndexForModuleIndex(ModuleIndex);
			FBSBuiltModuleView BuiltView;

			FName Socket = OccupiedSlotIndex >= 0 ? ModularComponent.Slots[OccupiedSlotIndex].Socket : NAME_None;
			USceneComponent PreferredOwner = ResolveSlotOwner(ModularComponent, OccupiedSlotIndex, InstalledModuleViews, Adapter, Sentry);
			BuiltView = BuildModuleElements(Module, PreferredOwner, Socket, Adapter, Sentry, Material);

			auto ChassisDefinition = Cast<UBSChassisDefinition>(Module);
			if (ChassisDefinition != nullptr)
			{
				CacheChassis(ChassisDefinition, BuiltView, Adapter);
			}

			InstalledModuleViews[ModuleIndex] = BuiltView;
		}

		FinishRebuild(Adapter, Sentry);
		CacheGeometry(Adapter, Sentry);
		FString BaseMeshName = Sentry.Base != nullptr && Sentry.Base.StaticMesh != nullptr ? Sentry.Base.StaticMesh.GetName().ToString() : "<none>";
		FString YawName = Adapter.YawPivot != nullptr ? Adapter.YawPivot.GetName().ToString() : "<none>";
		FString PitchName = Adapter.PitchPivot != nullptr ? Adapter.PitchPivot.GetName().ToString() : "<none>";
		FString MuzzleName = Adapter.MuzzleComponent != nullptr ? Adapter.MuzzleComponent.GetName().ToString() : "<none>";
		SentryDebug::LogAssembly(f"Assembly | Rebuild Complete Sentry='{Sentry.GetName()}' BaseMesh='{BaseMeshName}' Rotator0='{YawName}' Rotator1='{PitchName}' Muzzle='{MuzzleName}' ActiveElements={Adapter.ActiveModuleElements.Num()}");
		ValidateNoGarbageComponents(Adapter, Sentry);
	}

	void BeginRebuild(UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		Adapter.RebuildGeneration++;
		Adapter.SocketOwnerCache.Empty();
		Adapter.YawPivot = nullptr;
		Adapter.PitchPivot = nullptr;
		Adapter.MuzzleComponent = nullptr;
		Adapter.YawConstraint = FBSSentryConstraint();
		Adapter.PitchConstraint = FBSSentryConstraint();
		Adapter.YawPivotOffset = FVector::ZeroVector;
		Adapter.PitchPivotOffset = FVector::ZeroVector;
		Adapter.MuzzleOffset = FVector::ZeroVector;
		Adapter.MuzzleForwardRotation = FRotator(0, 0, 0);
		Adapter.ActiveModuleElements.Empty();

		Sentry.Base.SetStaticMesh(nullptr);
		Sentry.Base.SetCollisionEnabled(ECollisionEnabled::NoCollision);
	}

	void FinishRebuild(UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		DeactivateUnusedPoolComponents(Adapter.ModuleElementPool, Adapter.ModuleElementGenerations, Adapter.RebuildGeneration, Sentry);
	}

	void CacheChassis(UBSChassisDefinition Definition, FBSBuiltModuleView BuitView, UBSSentryVisualAdapter Adapter)
	{
		if (Definition.Rotators.Num() > 0)
		{
			USceneComponent FirstRotator = FindBuiltElementById(BuitView, Definition.Rotators[0].ElementId);
			Adapter.YawPivot = Cast<UStaticMeshComponent>(FirstRotator);
			if (Adapter.YawPivot != nullptr)
			{
				Adapter.YawConstraint = Definition.Rotators[0].Constraint;
			}
			else
			{
				Warning(f"SentryAssembly could not resolve first rotator '{Definition.Rotators[0].ElementId}' on chassis '{Definition.GetName()}'");
			}
		}

		if (Definition.Rotators.Num() > 1)
		{
			USceneComponent SecondRotator = FindBuiltElementById(BuitView, Definition.Rotators[1].ElementId);
			Adapter.PitchPivot = Cast<UStaticMeshComponent>(SecondRotator);
			if (Adapter.PitchPivot != nullptr)
			{
				Adapter.PitchConstraint = Definition.Rotators[1].Constraint;
			}
			else
			{
				Warning(f"SentryAssembly could not resolve second rotator '{Definition.Rotators[1].ElementId}' on chassis '{Definition.GetName()}'");
			}
		}
		else
		{
			Adapter.PitchPivot = Adapter.YawPivot;
			Adapter.PitchConstraint = Adapter.YawConstraint;
		}
	}

	FBSBuiltModuleView BuildModuleElements(UBSModuleDefinition Definition, USceneComponent RootOwner, FName RootSocket, UBSSentryVisualAdapter Adapter, ABSSentry Sentry, UMaterialInterface Material)
	{
		FBSBuiltModuleView View;
		if (Definition == nullptr)
		{
			return View;
		}

		if (Definition.Elements.Num() == 0)
		{
			Warning(f"SentryAssembly module '{Definition.GetName()}' has no Elements to build");
			return View;
		}

		FName BaseElementId = NAME_None;

		TArray<bool> BuiltStates;
		BuiltStates.SetNum(Definition.Elements.Num());

		int BuiltCount = 0;
		while (BuiltCount < Definition.Elements.Num())
		{
			bool bBuiltAny = false;

			for (int ElementIndex = 0; ElementIndex < Definition.Elements.Num(); ElementIndex++)
			{
				if (BuiltStates[ElementIndex])
				{
					continue;
				}

				const FBSModuleAssemblyElement& Element = Definition.Elements[ElementIndex];
				if (Element.Mesh == nullptr)
				{
					Warning(f"SentryAssembly element '{Element.ElementId}' in module '{Definition.GetName()}' has no mesh");
				}
				USceneComponent AttachParent = RootOwner;
				FName AttachSocket = RootSocket != NAME_None ? RootSocket : Element.Socket;

				if (Element.ParentElementId != NAME_None)
				{
					if (Element.ParentElementId == BaseElementId)
					{
						AttachParent = Sentry.Base;
					}
					else
					{
						AttachParent = FindBuiltElementById(View, Element.ParentElementId);
						if (AttachParent == nullptr)
						{
							continue;
						}
					}

					AttachSocket = Element.Socket;
				}
				else if (AttachParent == nullptr)
				{
					AttachParent = Adapter.GetDefaultAttachParent(Sentry);
					AttachSocket = Element.Socket;
				}

				UStaticMeshComponent Component = AcquireModuleElement(Adapter, Sentry);
				SetupAssemblyElement(Component, AttachParent, AttachSocket, Element, Material, Sentry);
				RegisterBuiltElement(View, Element, Component);
				
				FString AttachParentName = AttachParent != nullptr ? AttachParent.GetName().ToString() : "<none>";
				FString MeshName = Component != nullptr && Component.StaticMesh != nullptr ? Component.StaticMesh.GetName().ToString() : "<none>";
				SentryDebug::LogAssembly(f"Assembly| Built from '{Definition.GetName()}' | '{Element.ElementId}' as '{Component.GetName()}' Parent: '{AttachParentName}' Socket: '{AttachSocket}' Mesh: '{MeshName}'");

				BuiltStates[ElementIndex] = true;
				BuiltCount++;
				bBuiltAny = true;
			}

			if (!bBuiltAny)
			{
				for (int ElementIndex = 0; ElementIndex < Definition.Elements.Num(); ElementIndex++)
				{
					if (!BuiltStates[ElementIndex])
					{
						Warning(f"Sentry assembly could not resolve parent '{Definition.Elements[ElementIndex].ParentElementId}' for element '{Definition.Elements[ElementIndex].ElementId}' in module '{Definition.GetName()}'");
					}
				}
				break;
			}
		}

		return View;
	}

	USceneComponent ResolveSlotOwner(UBSModularComponent ModularComponent, int SlotIndex, const TArray<FBSBuiltModuleView>& InstalledModuleViews, UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		// meaning root
		if (SlotIndex < 0)
		{
			return Sentry.Base;
		}

		if (SlotIndex >= ModularComponent.Slots.Num())
		{
			return nullptr;
		}

		FName Socket = ModularComponent.Slots[SlotIndex].Socket;
		int ProviderModuleIndex = ModularComponent.GetSlotProviderModuleIndex(SlotIndex);
		if (ProviderModuleIndex >= 0 && ProviderModuleIndex < InstalledModuleViews.Num())
		{
			USceneComponent PreferredOwner = FindBuiltSocketOwner(InstalledModuleViews[ProviderModuleIndex], Socket);
			if (PreferredOwner != nullptr)
			{
				return PreferredOwner;
			}

			return InstalledModuleViews[ProviderModuleIndex].PrimaryComponent;
		}

		return FindSocketOwner(Adapter, Sentry, Socket);
	}

	void RegisterBuiltElement(FBSBuiltModuleView& View, const FBSModuleAssemblyElement& Element, USceneComponent Component)
	{
		FBSBuiltAssemblyElement BuiltElement;
		BuiltElement.ElementId = Element.ElementId;
		BuiltElement.Component = Component;
		View.Elements.Add(BuiltElement);

		if (View.PrimaryComponent == nullptr)
		{
			View.PrimaryComponent = Component;
		}
	}

	USceneComponent FindBuiltElementById(const FBSBuiltModuleView& View, FName ElementId)
	{
		for (const FBSBuiltAssemblyElement& BuiltElement : View.Elements)
		{
			if (BuiltElement.ElementId == ElementId)
			{
				return BuiltElement.Component;
			}
		}

		return nullptr;
	}

	USceneComponent FindBuiltSocketOwner(const FBSBuiltModuleView& View, FName Socket)
	{
		if (Socket == NAME_None)
		{
			return nullptr;
		}

		for (const FBSBuiltAssemblyElement& BuiltElement : View.Elements)
		{
			if (BuiltElement.Component != nullptr && BuiltElement.Component.DoesSocketExist(Socket))
			{
				return BuiltElement.Component;
			}
		}

		return nullptr;
	}

	void SetupAssemblyElement(UStaticMeshComponent Component, USceneComponent AttachParent, FName AttachSocket, const FBSModuleAssemblyElement& Element, UMaterialInterface Material, ABSSentry Sentry)
	{
		if (Component == nullptr)
		{
			return;
		}

		Component.SetStaticMesh(Element.Mesh);
		ApplyMaterial(Component, Material);

		if (AttachParent != nullptr && AttachParent != Component && AttachSocket != NAME_None)
		{
			Component.DetachFromParent();
			Component.AttachTo(AttachParent, AttachSocket);
		}
		else if (AttachParent != nullptr && AttachParent != Component)
		{
			Component.DetachFromParent();
			Component.AttachTo(AttachParent);
		}
		else if (Component != Sentry.Base)
		{
			Component.DetachFromParent();
			Component.AttachTo(Sentry.Base);
		}

		if (Component != Sentry.Base)
		{
			Component.RelativeLocation = Element.Offset;
			Component.SetRelativeRotation(Element.Rotation);
		}
		Component.SetCollisionEnabled(ECollisionEnabled::NoCollision);
	}

	void CacheGeometry(UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		Adapter.YawPivotOffset = FVector::ZeroVector;
		Adapter.PitchPivotOffset = FVector::ZeroVector;
		Adapter.MuzzleOffset = FVector::ZeroVector;
		Adapter.MuzzleForwardRotation = FRotator(0, 0, 0);

		if (Adapter.YawPivot == nullptr || Adapter.PitchPivot == nullptr)
		{
			FString YawName = Adapter.YawPivot != nullptr ? Adapter.YawPivot.GetName().ToString() : "<none>";
			FString PitchName = Adapter.PitchPivot != nullptr ? Adapter.PitchPivot.GetName().ToString() : "<none>";
			SentryDebug::LogAssembly(f"Assembly: missing rotator chain sentry='{Sentry.GetName()}' rotator0='{YawName}' rotator1='{PitchName}'");
			return;
		}

		Adapter.YawPivotOffset = Sentry.Base.WorldTransform.InverseTransformPosition(Adapter.YawPivot.WorldLocation);
		Adapter.PitchPivotOffset = Adapter.YawPivot.WorldTransform.InverseTransformPosition(Adapter.PitchPivot.WorldLocation);

		if (Adapter.MuzzleComponent == nullptr)
		{
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
		}

		if (Adapter.MuzzleComponent != nullptr && Adapter.MuzzleComponent.DoesSocketExist(Sentry::MuzzleSocketName))
		{
			FTransform MuzzleSocketWorld = Adapter.MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
			Adapter.MuzzleOffset = Adapter.PitchPivot.WorldTransform.InverseTransformPosition(MuzzleSocketWorld.Location);
			FVector MuzzleForwardWorld = MuzzleSocketWorld.Rotation.ForwardVector;
			Adapter.MuzzleForwardRotation = Adapter.PitchPivot.WorldTransform.InverseTransformVector(MuzzleForwardWorld).Rotation();
		}
	}

	UStaticMeshComponent AcquireModuleElement(UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		for (int Index = 0; Index < Adapter.ModuleElementPool.Num(); Index++)
		{
			if (Adapter.ModuleElementGenerations[Index] != Adapter.RebuildGeneration)
			{
				Adapter.ModuleElementGenerations[Index] = Adapter.RebuildGeneration;
				UStaticMeshComponent Component = Adapter.ModuleElementPool[Index];
				PreparePooledComponent(Component);
				Adapter.ActiveModuleElements.Add(Component);
				return Component;
			}
		}

		UStaticMeshComponent Created = UStaticMeshComponent::Create(Sentry, FName(f"ModulePool_{Adapter.ModuleElementPool.Num()}"));
		PreparePooledComponent(Created);
		Adapter.ModuleElementPool.Add(Created);
		Adapter.ModuleElementGenerations.Add(Adapter.RebuildGeneration);
		Adapter.ActiveModuleElements.Add(Created);
		return Created;
	}

	void DeactivateUnusedPoolComponents(TArray<UStaticMeshComponent>& Pool, TArray<int>& Generations, int CurrentGeneration, ABSSentry Sentry)
	{
		for (int Index = 0; Index < Pool.Num(); Index++)
		{
			if (Generations[Index] == CurrentGeneration)
			{
				continue;
			}

			DeactivatePooledComponent(Pool[Index], Sentry);
		}
	}

	void PreparePooledComponent(UStaticMeshComponent Component)
	{
		if (Component == nullptr)
		{
			return;
		}

		Component.SetCollisionEnabled(ECollisionEnabled::NoCollision);
	}

	void DeactivatePooledComponent(UStaticMeshComponent Component, ABSSentry Sentry)
	{
		if (Component == nullptr)
		{
			return;
		}

		Component.SetStaticMesh(nullptr);
		Component.DetachFromParent();
		Component.AttachTo(Sentry.Base);
		Component.RelativeLocation = FVector::ZeroVector;
		Component.SetRelativeRotation(FRotator(0, 0, 0));
		Component.SetCollisionEnabled(ECollisionEnabled::NoCollision);
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

		for (UStaticMeshComponent Element : Adapter.ActiveModuleElements)
		{
			if (Element.DoesSocketExist(Socket))
			{
				return Element;
			}
		}

		return nullptr;
	}

	void ValidateNoGarbageComponents(UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		ValidatePoolState(Adapter.ModuleElementPool, Adapter.ActiveModuleElements);

		TArray<USceneComponent> AttachedComponents;
		Sentry.Base.GetChildrenComponents(true, AttachedComponents);

		for (USceneComponent Child : AttachedComponents)
		{
			UStaticMeshComponent MeshComponent = Cast<UStaticMeshComponent>(Child);
			if (MeshComponent == nullptr)
			{
				continue;
			}

			if (!IsManagedDynamicComponent(Adapter, MeshComponent))
			{
				FString Name = MeshComponent.GetName().ToString();
				if (Name.Contains("ModulePool_"))
				{
					Warning(f"Sentry rebuild garbage assert: unmanaged pooled component '{Name}' attached to {Sentry.GetName()}");
				}
			}
		}
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

	bool IsManagedDynamicComponent(UBSSentryVisualAdapter Adapter, UStaticMeshComponent Component)
	{
		return Adapter.ModuleElementPool.Contains(Component);
	}

	void ApplyMaterial(UStaticMeshComponent Component, UMaterialInterface Material)
	{
		if (Component != nullptr && Material != nullptr)
		{
			Component.SetMaterial(0, Material);
		}
	}
}
