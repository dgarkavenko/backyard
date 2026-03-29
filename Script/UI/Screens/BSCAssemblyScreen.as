class UBSAssemblyScreen : UBSMMScreen
{
	ABSAssemblyBench OwningWorkbench;
	default PanelColor = FLinearColor(0.02f, 0.02f, 0.02f, 0.85f);

	bool bInitialized = false;
	int SelectedSlotIndex = -1;

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
					SelectedSlotIndex = -1;
				}
				else if (CurrentSlot.bOccupied && InstalledModule != nullptr)
				{
					RemoveModuleAndChildren(ModularComponent, InstalledModule);
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

		TArray<UBFModuleDefinition> AllModules = OwningWorkbench.GetAvailableModules();

		for (int Index = 0; Index < AllModules.Num(); Index++)
		{
			UBFModuleDefinition Module = AllModules[Index];
			if (Module == nullptr)
			{
				continue;
			}

			bool bAlreadyInstalled = ModularComponent.InstalledModules.Contains(Module);
			bool bFitsSelectedSlot = false;

			if (SelectedSlotIndex >= 0 && SelectedSlotIndex < ModularComponent.Slots.Num())
			{
				const FBFModuleSlot& SelectedSlot = ModularComponent.Slots[SelectedSlotIndex];
				if (!SelectedSlot.bOccupied && !Module.Instalation.IsEmpty())
				{
					bFitsSelectedSlot = Module.Instalation.Matches(SelectedSlot.Tags);
				}
			}

			if (SelectedSlotIndex >= 0 && !bFitsSelectedSlot && !bAlreadyInstalled)
			{
				continue;
			}

			bool bIsUnconditional = Module.Instalation.IsEmpty();
			bool bCanInstall = !bAlreadyInstalled && (bIsUnconditional || bFitsSelectedSlot);

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
					RemoveModuleAndChildren(ModularComponent, Module);
					SelectedSlotIndex = -1;
				}
				else if (bCanInstall)
				{
					ModularComponent.AddModule(Module);
					SelectedSlotIndex = -1;
				}
			}
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
