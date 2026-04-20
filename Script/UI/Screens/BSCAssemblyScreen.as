class UBSAssemblyScreen : UBSMMScreen
{
	ABSAssemblyBench OwningWorkbench;
	default PanelColor = FLinearColor(0.02f, 0.02f, 0.02f, 0.85f);

	bool bInitialized = false;
	int SelectedSlotIndex = -1;
	int ObservedCompositionVersion = -1;

	const FLinearColor SelectedColor = FLinearColor(0.15f, 0.4f, 0.15f);
	const FLinearColor OccupiedColor = FLinearColor(0.4f, 0.3f, 0.1f);
	const FLinearColor DisabledColor = FLinearColor(0.3f, 0.15f, 0.15f);
	const FLinearColor EmptySlotColor = FLinearColor(0.1f, 0.2f, 0.3f);
	const FLinearColor HeaderColor = FLinearColor(0.6f, 0.6f, 0.6f);

	UFUNCTION(BlueprintOverride)
	void OnDeactivated()
	{
		if (OwningWorkbench != nullptr)
		{
			OwningWorkbench.DeactivateWorkbench();
		}
	}

	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float InDeltaTime)
	{
		Super::Tick(MyGeometry, InDeltaTime);

		if (OwningWorkbench == nullptr)
		{
			return;
		}

		ABSSentry Sentry = GetSentry();
		mm::BeginDraw(MMWidget);

		mm::BeginHorizontalBox();

			mm::Slot_Fill(2.0f);
			mm::VAlign_Fill();
			mm::BeginBorder(PanelColor);
			mm::Padding(20.0f);
			mm::BeginVerticalBox();

				mm::Text("SENTRY ASSEMBLY", 28, FLinearColor::White, false, true);
				mm::Spacer(15.0f);

				if (OwningWorkbench.Sentry != nullptr)
				{
					DrawSlotsSection();
					mm::Spacer(15.0f);
					DrawModulesSection();
				}

				mm::Spacer(10.0f);
				if (mm::Button("CLOSE"))
				{
					DeactivateWidget();
				}

			mm::EndVerticalBox();
			mm::EndBorder();

			mm::Slot_Fill(1.0f);
			mm::BeginVerticalBox();
			mm::EndVerticalBox();

		mm::EndHorizontalBox();

		mm::EndDraw();
	}

	private ABSSentry GetSentry() const
	{
		if (OwningWorkbench == nullptr)
		{
			return nullptr;
		}

		return OwningWorkbench.Sentry;
	}

	private UBSModularComponent GetModularComponent() const
	{
		ABSSentry Sentry = GetSentry();
		if (Sentry == nullptr)
		{
			return nullptr;
		}

		return Sentry.ModularComponent;
	}

	private UBSModularView GetView() const
	{
		ABSSentry Sentry = GetSentry();
		if (Sentry == nullptr)
		{
			return nullptr;
		}

		return Sentry.ModularView;
	}

	FString GetLeafNames(FGameplayTagContainer Container)
	{
		TArray<FString> Leafs;

		for (FGameplayTag Tag : Container.GameplayTags)
		{			
			Leafs.Add(String::ParseIntoArray(Tag.ToString(), ".", true).Last());
		}

		return FString::Join(Leafs, ",");
	}

	private void DrawSlotsSection()
	{
		mm::Text("SLOTS", 20, HeaderColor);
		mm::Spacer(5.0f);

		UBSModularComponent ModularComponent = GetModularComponent();
		auto View = GetView();

		if (ModularComponent == nullptr)
		{
			return;
		}

		if (ModularComponent.Slots.Num() == 0)
		{
			mm::Text("No slots available", 14, DisabledColor);
			return;
		}

		SyncSelectedSlot(ModularComponent);

		if (SelectedSlotIndex >= 0 && SelectedSlotIndex < ModularComponent.Slots.Num())
		{
			const FBFModuleSlot& SelectedSlot = ModularComponent.Slots[SelectedSlotIndex].SlotData;
			FString SelectedLabel = GetLeafNames(SelectedSlot.Tags);

			if (SelectedLabel.IsEmpty())
			{
				SelectedLabel = f"Slot {SelectedSlotIndex}";
			}

			mm::Spacer(5.0f);
		}

		for (int Index = 0; Index < ModularComponent.Slots.Num(); Index++)
		{
			const FBFModuleSlot& SlotData = ModularComponent.Slots[Index].SlotData;

			FString SlotLabel = f"{GetLeafNames(SlotData.Tags)} [{SlotData.Socket.ToString()}]";

			if (SlotLabel.IsEmpty())
			{
				SlotLabel = f"Slot {Index}";
				break;
			}

			UBSModuleDefinition InstalledModule = ModularComponent.Slots[Index].Content.IsSet() ? ModularComponent.Slots[Index].GetDefinitionUnsafe(ModularComponent) : nullptr;
			bool bIsSelected = (SelectedSlotIndex == Index);

			if (InstalledModule != nullptr)
			{
				SlotLabel = f"{InstalledModule.GetName()}";
			}

			auto ButtonState = mm::Button(SlotLabel);
			
			auto Color = bIsSelected ? SelectedColor : ModularComponent.Slots[Index].Content.IsSet() ? OccupiedColor : EmptySlotColor;
			ButtonState.SetButtonStyleColor(Color);

			if (View != nullptr && Systems::Debug::ShowSockets.Int > 0)
			{
				if (!ModularComponent.Slots[Index].Content.IsSet())
				{
					Systems::Debug::DrawSlotSocket(View, ModularComponent, Index, Color, bIsSelected ? 20.0f : 10.0f);
				}
			}

			if (ButtonState)
			{
				if (bIsSelected)
				{
					SelectedSlotIndex = -1;
				}
				else if (ModularComponent.Slots[Index].Content.IsSet())
				{
					ModularComponent.RemoveModule(Index);
					SelectedSlotIndex = -1;
				}
				else
				{
					SelectedSlotIndex = Index;
				}
			}
		}
	}

	private void DrawModulesSection()
	{
		mm::Text("MODULES", 20, HeaderColor);
		mm::Spacer(5.0f);

		UBSModularComponent ModularComponent = GetModularComponent();
		if (ModularComponent == nullptr)
		{
			return;
		}

		SyncSelectedSlot(ModularComponent);

		TArray<UBSModuleDefinition> AllModules = Taxonomy::GetAvailableModules();

		for (int Index = 0; Index < AllModules.Num(); Index++)
		{
			UBSModuleDefinition Module = AllModules[Index];
			if (Module == nullptr)
			{
				continue;
			}

			int InstalledCount = ModularComponent.InstalledModules.Num();
			bool bRequiresSelectedSlot = !Module.Instalation.IsEmpty();
			bool bCanInstall = false;
			bool bCanRemoveSingleInstalled = InstalledCount == 1 && SelectedSlotIndex < 0;

			if (SelectedSlotIndex >= 0)
			{
				bCanInstall = ModularComponent.CanAddModuleTo(Module, SelectedSlotIndex);
			}
			else if (!bRequiresSelectedSlot)
			{
				bCanInstall = ModularComponent.CanAddModule(Module);
			}

			if (SelectedSlotIndex >= 0 && !bCanInstall)
			{
				continue;
			}

			FString ModuleLabel = Module.GetName().ToString();
			if (InstalledCount > 0)
			{
				ModuleLabel = f"{ModuleLabel} x{InstalledCount}";
			}

			auto ModuleButton = mm::Button(ModuleLabel);

			if (bCanRemoveSingleInstalled && !bCanInstall)
			{
				ModuleButton.SetButtonStyleColor(OccupiedColor);
			}
			else if (!bCanInstall)
			{
				ModuleButton.SetButtonStyleColor(DisabledColor);
			}

			if (ModuleButton)
			{
				if (bCanInstall)
				{
					int InstallSlotIndex = SelectedSlotIndex;
					FString InstallSocket = "<none>";
					if (InstallSlotIndex >= 0 && InstallSlotIndex < ModularComponent.Slots.Num())
					{
						InstallSocket = ModularComponent.Slots[InstallSlotIndex].SlotData.Socket.ToString();
					}
					if (InstallSlotIndex >= 0)
					{
						ModularComponent.AddModule(Module, InstallSlotIndex);
					}
					else
					{
						ModularComponent.AddModule(Module, 0);
					}
					SelectedSlotIndex = -1;
				}
				else if (bCanRemoveSingleInstalled)
				{
					ModularComponent.RemoveModule(SelectedSlotIndex);
					SelectedSlotIndex = -1;
				}
			}
		}
	}

	private void SyncSelectedSlot(UBSModularComponent ModularComponent)
	{
		if (ModularComponent == nullptr)
		{
			return;
		}

		if (SelectedSlotIndex < 0)
		{
			return;
		}

		bool bInvalidSelection = SelectedSlotIndex >= ModularComponent.Slots.Num();
		if (!bInvalidSelection)
		{
			bInvalidSelection = ModularComponent.Slots[SelectedSlotIndex].Content.IsSet();
		}

		if (bInvalidSelection)
		{
			SelectedSlotIndex = -1;
		}
	}
}
