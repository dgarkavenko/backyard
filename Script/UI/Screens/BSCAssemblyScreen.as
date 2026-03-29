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

		if (!bInitialized)
		{
			bInitialized = true;
			if (!OwningWorkbench.HasSentry())
			{
				OwningWorkbench.CraftNewSentry();
			}
		}

		ABSSentry Sentry = GetSentry();
		if (Sentry != nullptr && SentryDebug::ShowSockets.Int > 0)
		{
			SentryDebug::DrawSockets(Sentry);
		}

		mm::BeginDraw(MMWidget);

		mm::BeginHorizontalBox();

			mm::Slot_Fill(2.0f);
			mm::VAlign_Fill();
			mm::BeginBorder(PanelColor);
			mm::Padding(20.0f);
			mm::BeginVerticalBox();

				mm::Text("SENTRY ASSEMBLY", 28, FLinearColor::White, false, true);
				mm::Spacer(15.0f);

				if (OwningWorkbench.HasSentry())
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

	private void DrawSlotsSection()
	{
		mm::Text("SLOTS", 20, HeaderColor);
		mm::Spacer(5.0f);

		UBSModularComponent ModularComponent = GetModularComponent();
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
			const FBFModuleSlot& SelectedSlot = ModularComponent.Slots[SelectedSlotIndex];
			FString SelectedLabel = SelectedSlot.Socket.ToString();
			if (SelectedLabel.IsEmpty())
			{
				SelectedLabel = f"Slot {SelectedSlotIndex}";
			}
			mm::Text(f"Selected: [{SelectedSlotIndex}] {SelectedLabel}", 14, FLinearColor::White);
			mm::Spacer(5.0f);
		}

		for (int Index = 0; Index < ModularComponent.Slots.Num(); Index++)
		{
			const FBFModuleSlot& CurrentSlot = ModularComponent.Slots[Index];

			FString SlotLabel = CurrentSlot.Socket.ToString();
			if (SlotLabel.IsEmpty())
			{
				SlotLabel = f"Slot {Index}";
			}

			UBFModuleDefinition InstalledModule = ModularComponent.GetModuleForSlot(Index);
			bool bIsSelected = (SelectedSlotIndex == Index);

			if (InstalledModule != nullptr)
			{
				SlotLabel = f"{SlotLabel}: {InstalledModule.GetName()}";
			}

			auto ButtonState = mm::Button(SlotLabel);

			if (bIsSelected)
			{
				ButtonState.SetButtonStyleColor(SelectedColor);
			}
			else if (CurrentSlot.bOccupied)
			{
				ButtonState.SetButtonStyleColor(OccupiedColor);
			}
			else
			{
				ButtonState.SetButtonStyleColor(EmptySlotColor);
			}

			if (ButtonState)
			{
				if (bIsSelected)
				{
					SentryDebug::LogAssembly(f"Assembly UI: deselected slot {Index}");
					SelectedSlotIndex = -1;
				}
				else if (CurrentSlot.bOccupied && InstalledModule != nullptr)
				{
					SentryDebug::LogAssembly(f"Assembly UI: removing occupied slot {Index} module='{InstalledModule.GetName()}'");
					RemoveModuleAndChildren(ModularComponent, InstalledModule);
					SelectedSlotIndex = -1;
				}
				else
				{
					SentryDebug::LogAssembly(f"Assembly UI: selected slot {Index} socket='{CurrentSlot.Socket}'");
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

		TArray<UBFModuleDefinition> AllModules = OwningWorkbench.GetAvailableModules();

		for (int Index = 0; Index < AllModules.Num(); Index++)
		{
			UBFModuleDefinition Module = AllModules[Index];
			if (Module == nullptr)
			{
				continue;
			}

			bool bAlreadyInstalled = ModularComponent.InstalledModules.Contains(Module);
			bool bRequiresSelectedSlot = !Module.Instalation.IsEmpty();
			bool bCanInstall = false;

			if (!bAlreadyInstalled)
			{
				if (SelectedSlotIndex >= 0)
				{
					bCanInstall = ModularComponent.CanAddModuleToSlot(Module, SelectedSlotIndex);
				}
				else if (!bRequiresSelectedSlot)
				{
					bCanInstall = ModularComponent.CanAddModule(Module);
				}
			}

			if (SelectedSlotIndex >= 0 && !bCanInstall && !bAlreadyInstalled)
			{
				continue;
			}

			auto ModuleButton = mm::Button(Module.GetName().ToString());

			if (bAlreadyInstalled)
			{
				ModuleButton.SetButtonStyleColor(OccupiedColor);
			}
			else if (!bCanInstall)
			{
				ModuleButton.SetButtonStyleColor(DisabledColor);
			}

			if (ModuleButton)
			{
				if (bAlreadyInstalled)
				{
					SentryDebug::LogAssembly(f"Assembly UI: removing '{Module.GetName()}'");
					RemoveModuleAndChildren(ModularComponent, Module);
					SelectedSlotIndex = -1;
				}
				else if (bCanInstall)
				{
					int InstallSlotIndex = SelectedSlotIndex;
					FString InstallSocket = "<none>";
					if (InstallSlotIndex >= 0 && InstallSlotIndex < ModularComponent.Slots.Num())
					{
						InstallSocket = ModularComponent.Slots[InstallSlotIndex].Socket.ToString();
					}
					SentryDebug::LogAssembly(f"Assembly UI: installing '{Module.GetName()}' selectedSlot={InstallSlotIndex} socket='{InstallSocket}'");
					if (InstallSlotIndex >= 0)
					{
						ModularComponent.AddModuleToSlot(Module, InstallSlotIndex);
					}
					else
					{
						ModularComponent.AddModule(Module);
					}
					SelectedSlotIndex = -1;
					ObservedCompositionVersion = ModularComponent.CompositionVersion;
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

		if (ObservedCompositionVersion == ModularComponent.CompositionVersion)
		{
			return;
		}

		ObservedCompositionVersion = ModularComponent.CompositionVersion;
		if (SelectedSlotIndex < 0)
		{
			return;
		}

		bool bInvalidSelection = SelectedSlotIndex >= ModularComponent.Slots.Num();
		if (!bInvalidSelection)
		{
			bInvalidSelection = ModularComponent.Slots[SelectedSlotIndex].bOccupied;
		}

		if (bInvalidSelection)
		{
			SentryDebug::LogAssembly(f"Assembly UI: cleared selected slot {SelectedSlotIndex} after composition version {ObservedCompositionVersion}");
			SelectedSlotIndex = -1;
		}
	}

	private void RemoveModuleAndChildren(UBSModularComponent ModularComponent, UBFModuleDefinition Module)
	{
		TArray<UBFModuleDefinition> ToRemove;
		ToRemove.Add(Module);

		int SearchIndex = 0;
		while (SearchIndex < ToRemove.Num())
		{
			UBFModuleDefinition Current = ToRemove[SearchIndex];
			SearchIndex++;

			for (const FBFModuleSlot& ProvidedSlot : Current.ProvidedSlots)
			{
				for (UBFModuleDefinition Installed : ModularComponent.InstalledModules)
				{
					if (ToRemove.Contains(Installed))
					{
						continue;
					}
					if (!Installed.Instalation.IsEmpty() && Installed.Instalation.Matches(ProvidedSlot.Tags))
					{
						ToRemove.Add(Installed);
					}
				}
			}
		}

		TArray<UBFModuleDefinition> Remaining;
		for (UBFModuleDefinition Installed : ModularComponent.InstalledModules)
		{
			if (!ToRemove.Contains(Installed))
			{
				Remaining.Add(Installed);
			}
		}

		OwningWorkbench.ApplyModules(Remaining);
	}
}
