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

struct FBSModularBuildResult
{
	/**Matches Slot indexes */
	TArray<FBSBuiltModuleView> InstalledModuleViews;	
}

namespace ModularAssembly
{
	FBSModularBuildResult Build(UBSModularView View, AActor Owner, UBSModularComponent ModularComponent)
	{
		BeginRebuild(View, Owner);

		FBSModularBuildResult Result;
		Result.InstalledModuleViews.SetNum(ModularComponent.Slots.Num());

		for (int SlotIndex = 0; SlotIndex < ModularComponent.Slots.Num(); SlotIndex++)
		{
			FBSSlotRuntime Slot = ModularComponent.Slots[SlotIndex];

			if (Slot.Content.IsSet())
			{
				UBSModuleDefinition Module = Slot.GetDefinitionUnsafe(ModularComponent);
				FBSBuiltModuleView BuiltView;

				if (Module.Elements.Num() > 0)
				{
					USceneComponent SlotProviderComponent = ResolveSlotProvider(ModularComponent, SlotIndex, Result.InstalledModuleViews);
					Log(n"Assembly", f"Build: {Slot.Index}){Module} with SlotProvider {SlotProviderComponent}@{Slot.SlotData.Socket}");

					BuiltView = BuildModuleElements(Module, SlotProviderComponent, Slot, View, Owner);
				}

				Result.InstalledModuleViews[SlotIndex] = BuiltView;
			}
		}

		FinishRebuild(View, Owner);
		View.LastBuildResult = Result;
		return Result;
	}

	void BeginRebuild(UBSModularView View, AActor Owner)
	{
		View.Generation++;
		View.SocketOwnerCache.Empty();
		View.ActiveModuleElements.Empty();
		View.LastBuildResult.InstalledModuleViews.Empty();
	}

	void FinishRebuild(UBSModularView View, AActor Owner)
	{
		DeactivateUnusedPoolComponents(View.ModuleElementPool, View.ModuleElementGenerations, View.Generation, Owner);
	}

	FBSBuiltModuleView BuildModuleElements(UBSModuleDefinition Definition, USceneComponent SlotProviderComponent, FBSSlotRuntime BuiltSlot, UBSModularView View, AActor BuiltActor)
	{
		FBSBuiltModuleView BuiltView;

		for (int ElementIndex = 0; ElementIndex < Definition.Elements.Num(); ElementIndex++)
		{
			const FBSModuleAssemblyElement& Element = Definition.Elements[ElementIndex];
			if (Element.Mesh == nullptr)
			{
				Warning(f"ModularAssembly element '{Element.ElementId}' in module '{Definition.GetName()}' has no mesh");
			}

			USceneComponent AttachParent = SlotProviderComponent;
			FName AttachSocket = BuiltSlot.SlotData.Socket;

			bool bAttachesToSlotProvider = Element.ParentElementId == NAME_None;

			if (!bAttachesToSlotProvider)
			{
				AttachSocket = Element.Socket;
				AttachParent = FindBuiltElementById(BuiltView, Element.ParentElementId);
				check(AttachParent != nullptr, f"{Element.ParentElementId} is not on the list or wrong order {Definition.GetName()}");
			}

			UStaticMeshComponent Component = AcquireElementSMC(View, BuiltActor, BuiltSlot.IsRoot() && bAttachesToSlotProvider);
			Log(n"Assembly", f"SetupAssemblyElement: {Component} attaches to {AttachParent}@{AttachSocket}");

			SetupAssemblyElement(Component, AttachParent, AttachSocket, Element, View.MaterialOverride);
			RegisterBuiltElement(BuiltView, Element, Component);
		}

		return BuiltView;
	}

	USceneComponent ResolveSlotProvider(
		UBSModularComponent ModularComponent,
		int SlotIndex,
		const TArray<FBSBuiltModuleView>& InstalledModuleViews,
	)
	{
		TOptional<int> ParentSlotIndex = ModularComponent.Slots[SlotIndex].ParentIndex;
		if (ParentSlotIndex.IsSet())
		{
			FName Socket = ModularComponent.Slots[SlotIndex].SlotData.Socket;
			USceneComponent PreferredOwner = FindBuiltSocketOwner(InstalledModuleViews[ParentSlotIndex.Value], Socket);
			if (PreferredOwner != nullptr)
			{
				return PreferredOwner;
			}
			
			return InstalledModuleViews[ParentSlotIndex.Value].PrimaryComponent;
		}

		return nullptr;
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

	void SetupAssemblyElement(UStaticMeshComponent Component, USceneComponent AttachParent, FName AttachSocket, const FBSModuleAssemblyElement& Element, UMaterialInterface Material)
	{
		if (Component == nullptr)
		{
			return;
		}

		Component.SetStaticMesh(Element.Mesh);
		ApplyMaterial(Component, Material);

		if (AttachParent != nullptr)
		{
			Component.DetachFromParent();
			Component.AttachTo(AttachParent, AttachSocket);
			Component.RelativeLocation = Element.Offset;
			Component.SetRelativeRotation(Element.Rotation);
		}
	}

	UStaticMeshComponent AcquireElementSMC(UBSModularView View, AActor BuiltActor, bool bIsRootElement0)
	{
		if (bIsRootElement0)
		{
			check(BuiltActor.RootComponent.IsA(UStaticMeshComponent), "Root component is not a UStaticMeshComponent");
			return Cast<UStaticMeshComponent>(BuiltActor.RootComponent);
		}

		for (int Index = 0; Index < View.ModuleElementPool.Num(); Index++)
		{
			if (View.ModuleElementGenerations[Index] != View.Generation)
			{
				UStaticMeshComponent Component = View.ModuleElementPool[Index];
				View.ModuleElementGenerations[Index] = View.Generation;
				View.ActiveModuleElements.Add(Component);
				return Component;
			}
		}

		UStaticMeshComponent Created = UStaticMeshComponent::Create(BuiltActor, FName(f"ModulePool_{View.ModuleElementPool.Num()}"));
		View.ModuleElementPool.Add(Created);
		View.ModuleElementGenerations.Add(View.Generation);
		View.ActiveModuleElements.Add(Created);
		return Created;
	}

	void DeactivateUnusedPoolComponents(TArray<UStaticMeshComponent>& Pool, TArray<int>& Generations, int CurrentGeneration, AActor Owner)
	{
		for (int Index = 0; Index < Pool.Num(); Index++)
		{
			if (Generations[Index] == CurrentGeneration)
			{
				continue;
			}

			DeactivatePooledComponent(Pool[Index], Owner);
		}
	}

	void DeactivatePooledComponent(UStaticMeshComponent Component, AActor Owner)
	{
		if (Component == nullptr)
		{
			return;
		}

		USceneComponent RootComponent = Owner.RootComponent;
		Component.SetStaticMesh(nullptr);
		Component.DetachFromParent();
		if (RootComponent != nullptr)
		{
			Component.AttachTo(RootComponent);
		}
		Component.RelativeLocation = FVector::ZeroVector;
		Component.SetRelativeRotation(FRotator(0, 0, 0));
		Component.SetCollisionEnabled(ECollisionEnabled::NoCollision);
	}

	void ApplyMaterial(UStaticMeshComponent Component, UMaterialInterface Material)
	{
		if (Component != nullptr && Material != nullptr)
		{
			Component.SetMaterial(0, Material);
		}
	}
}
