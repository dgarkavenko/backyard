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

	TArray<USceneComponent> RotatorComponents;
	TArray<FBSSentryConstraint> RotatorConstraints;
	TArray<FVector> RotatorOffsets;
	USceneComponent MuzzleComponent;

	int RebuildGeneration = 0;

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
		return RotatorComponents.Num() >= 2
			&& RotatorComponents[0] != nullptr
			&& RotatorComponents[1] != nullptr;
	}

	USceneComponent GetDefaultAttachParent(ABSSentry Sentry) const
	{
		if (RotatorComponents.Num() > 0)
		{
			return RotatorComponents.Last();
		}

		return Sentry.Base;
	}
}

namespace SentryAssembly
{
	void Rebuild(UBSSentryVisualAdapter Adapter, ABSSentry Sentry, UBSModularComponent ModularComponent, UMaterialInterface Material)
	{
		BeginRebuild(Adapter, Sentry);
		SentryDebugF::LogAssembly(f"Assembly: rebuild sentry='{Sentry.GetName()}' modules={ModularComponent.InstalledModules.Num()}");

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
				SentryDebugF::LogAssembly(f"Assembly: skipping non-script module '{RawModuleName}'");
				continue;
			}

			TOptional<int32> OccupiedSlotIndex = ModularComponent.GetSlotByModuleIndex(ModuleIndex);
			FBSBuiltModuleView BuiltView;

			FName Socket = OccupiedSlotIndex.IsSet() ? ModularComponent.Slots[OccupiedSlotIndex.Value].SlotData.Socket : NAME_None;
			USceneComponent PreferredOwner = OccupiedSlotIndex.IsSet() ? ResolveSlotOwner(ModularComponent, OccupiedSlotIndex.Value, InstalledModuleViews, Adapter, Sentry) : nullptr;
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

		ModularComponent.BroadcastRebuilt();

		SentryDebugF::LogAssembled(Sentry, Adapter);		
		SentryDebugF::ValidateNoGarbageComponents(Adapter, Sentry);
	}

	void BeginRebuild(UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		Adapter.RebuildGeneration++;
		Adapter.SocketOwnerCache.Empty();
		Adapter.RotatorComponents.Empty();
		Adapter.RotatorConstraints.Empty();
		Adapter.RotatorOffsets.Empty();
		Adapter.MuzzleComponent = nullptr;
		Adapter.MuzzleOffset = FVector::ZeroVector;
		Adapter.MuzzleForwardRotation = FRotator(0, 0, 0);
		Adapter.ActiveModuleElements.Empty();

		Sentry.Base.SetStaticMesh(nullptr);
	}

	void FinishRebuild(UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		DeactivateUnusedPoolComponents(Adapter.ModuleElementPool, Adapter.ModuleElementGenerations, Adapter.RebuildGeneration, Sentry);
	}

	void CacheChassis(UBSChassisDefinition Definition, FBSBuiltModuleView BuiltView, UBSSentryVisualAdapter Adapter)
	{
		for (int RotatorIndex = 0; RotatorIndex < Definition.Rotators.Num(); RotatorIndex++)
		{
			const FBSChassisRotatorSpec& RotatorSpec = Definition.Rotators[RotatorIndex];
			USceneComponent ResolvedRotator = FindBuiltElementById(BuiltView, RotatorSpec.ElementId);
			if (ResolvedRotator != nullptr)
			{
				Adapter.RotatorComponents.Add(ResolvedRotator);
				Adapter.RotatorConstraints.Add(RotatorSpec.Constraint);
			}
			else
			{
				Warning(f"SentryAssembly could not resolve rotator[{RotatorIndex}] '{RotatorSpec.ElementId}' on chassis '{Definition.GetName()}'");
			}
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
				SentryDebugF::LogAssembly(f"Assembly| Built from '{Definition.GetName()}' | '{Element.ElementId}' as '{Component.GetName()}' Parent: '{AttachParentName}' Socket: '{AttachSocket}' Mesh: '{MeshName}'");

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
		if (SlotIndex >= ModularComponent.Slots.Num())
		{
			return nullptr;
		}

		FName Socket = ModularComponent.Slots[SlotIndex].SlotData.Socket;
		int ProviderModuleIndex = ModularComponent.Slots[SlotIndex].ParentIndex.IsSet() ? ModularComponent.Slots[SlotIndex].ParentIndex.Value : -1;
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
	}

	void CacheGeometry(UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		Adapter.RotatorOffsets.Empty();
		Adapter.RotatorOffsets.SetNum(Adapter.RotatorComponents.Num());
		Adapter.MuzzleOffset = FVector::ZeroVector;
		Adapter.MuzzleForwardRotation = FRotator(0, 0, 0);

		if (Adapter.RotatorComponents.Num() < 2 || Adapter.RotatorComponents[0] == nullptr || Adapter.RotatorComponents[1] == nullptr)
		{
			FString Rotator0Name = Adapter.RotatorComponents.Num() > 0 && Adapter.RotatorComponents[0] != nullptr ? Adapter.RotatorComponents[0].GetName().ToString() : "<none>";
			FString Rotator1Name = Adapter.RotatorComponents.Num() > 1 && Adapter.RotatorComponents[1] != nullptr ? Adapter.RotatorComponents[1].GetName().ToString() : "<none>";
			SentryDebugF::LogAssembly(f"Assembly: missing rotator chain sentry='{Sentry.GetName()}' rotatorCount={Adapter.RotatorComponents.Num()} rotator0='{Rotator0Name}' rotator1='{Rotator1Name}'");
			return;
		}

		USceneComponent Rotator0 = Adapter.RotatorComponents[0];
		USceneComponent Rotator1 = Adapter.RotatorComponents[1];
		Adapter.RotatorOffsets[0] = Sentry.Base.WorldTransform.InverseTransformPosition(Rotator0.WorldLocation);
		Adapter.RotatorOffsets[1] = Rotator0.WorldTransform.InverseTransformPosition(Rotator1.WorldLocation);

		if (Adapter.MuzzleComponent == nullptr)
		{
			TArray<USceneComponent> AllChildren;
			Rotator1.GetChildrenComponents(true, AllChildren);

			for (USceneComponent Child : AllChildren)
			{
				if (Child.DoesSocketExist(Sentry::MuzzleSocketName))
				{
					Adapter.MuzzleComponent = Child;
					break;
				}
			}

			if (Adapter.MuzzleComponent == nullptr && Rotator1.DoesSocketExist(Sentry::MuzzleSocketName))
			{
				Adapter.MuzzleComponent = Rotator1;
			}
		}

		if (Adapter.MuzzleComponent != nullptr && Adapter.MuzzleComponent.DoesSocketExist(Sentry::MuzzleSocketName))
		{
			FTransform MuzzleSocketWorld = Adapter.MuzzleComponent.GetSocketTransform(Sentry::MuzzleSocketName);
			Adapter.MuzzleOffset = Rotator1.WorldTransform.InverseTransformPosition(MuzzleSocketWorld.Location);
			FVector MuzzleForwardWorld = MuzzleSocketWorld.Rotation.ForwardVector;
			Adapter.MuzzleForwardRotation = Rotator1.WorldTransform.InverseTransformVector(MuzzleForwardWorld).Rotation();
		}
	}

	UStaticMeshComponent AcquireModuleElement(UBSSentryVisualAdapter Adapter, ABSSentry Sentry)
	{
		if (Sentry.Base.StaticMesh == nullptr)
		{
			return Sentry.Base;
		}

		for (int Index = 0; Index < Adapter.ModuleElementPool.Num(); Index++)
		{
			if (Adapter.ModuleElementGenerations[Index] != Adapter.RebuildGeneration)
			{
				Adapter.ModuleElementGenerations[Index] = Adapter.RebuildGeneration;
				UStaticMeshComponent Component = Adapter.ModuleElementPool[Index];
				Adapter.ActiveModuleElements.Add(Component);
				return Component;
			}
		}

		UStaticMeshComponent Created = UStaticMeshComponent::Create(Sentry, FName(f"ModulePool_{Adapter.ModuleElementPool.Num()}"));
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

	void ApplyMaterial(UStaticMeshComponent Component, UMaterialInterface Material)
	{
		if (Component != nullptr && Material != nullptr)
		{
			Component.SetMaterial(0, Material);
		}
	}
}
