class UBSAssemblyScreen : UBSMMScreen
{
	ABSAssemblyBench OwningWorkbench;
	default PanelColor = FLinearColor(0.02f, 0.02f, 0.02f, 0.85f);

	int SelectedChassisIndex = -1;
	int SelectedLoadoutIndex = -1;
	bool bConfigurationDirty = false;

	const FLinearColor SelectedColor = FLinearColor(0.15f, 0.4f, 0.15f);
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
		//Super::Tick(MyGeometry, InDeltaTime);
		if (OwningWorkbench == nullptr)
		{
			return;
		}

		if (bConfigurationDirty)
		{
			bConfigurationDirty = false;
			ApplyConfiguration();
		}

		mm::BeginDraw(MMWidget);

		mm::BeginHorizontalBox();

			mm::Slot_Fill(2.0f);
			mm::VAlign_Fill();
			mm::BeginBorder(PanelColor);
			mm::Padding(20.0f);
			mm::BeginVerticalBox();

				mm::Text("SENTRY WORKBENCH", 28, FLinearColor::White, false, true);
				mm::Spacer(15.0f);

				DrawChassisSection();

				if (SelectedChassisIndex >= 0)
				{
					mm::Spacer(10.0f);
					DrawLoadoutSection();
				}

				mm::Spacer(30.0f);
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

	private void DrawChassisSection()
	{
		mm::Text("CHASSIS", 20, HeaderColor);
		mm::Spacer(5.0f);

		auto NoneButton = mm::Button("None");
		if (SelectedChassisIndex < 0)
		{
			NoneButton.SetButtonStyleColor(SelectedColor);
		}
		if (NoneButton)
		{
			SelectedChassisIndex = -1;
			bConfigurationDirty = true;
		}

		for (int Index = 0; Index < OwningWorkbench.AvailableChassis.Num(); Index++)
		{
			UBSChassisConfiguration Chassis = OwningWorkbench.AvailableChassis[Index];
			if (Chassis == nullptr)
			{
				continue;
			}

			auto ButtonState = mm::Button(Chassis.GetName().ToString());
			if (Index == SelectedChassisIndex)
			{
				ButtonState.SetButtonStyleColor(SelectedColor);
			}
			if (ButtonState)
			{
				SelectedChassisIndex = Index;
				bConfigurationDirty = true;
			}
		}
	}

	private void DrawLoadoutSection()
	{
		mm::Text("LOADOUT", 20, HeaderColor);
		mm::Spacer(5.0f);

		auto NoneButton = mm::Button("None");
		if (SelectedLoadoutIndex < 0)
		{
			NoneButton.SetButtonStyleColor(SelectedColor);
		}
		if (NoneButton)
		{
			SelectedLoadoutIndex = -1;
			bConfigurationDirty = true;
		}

		for (int Index = 0; Index < OwningWorkbench.AvailableLoadouts.Num(); Index++)
		{
			UBSSentryLoadout Loadout = OwningWorkbench.AvailableLoadouts[Index];
			if (Loadout == nullptr)
			{
				continue;
			}

			auto ButtonState = mm::Button(Loadout.GetName().ToString());
			if (Index == SelectedLoadoutIndex)
			{
				ButtonState.SetButtonStyleColor(SelectedColor);
			}
			if (ButtonState)
			{
				SelectedLoadoutIndex = Index;
				bConfigurationDirty = true;
			}
		}
	}

	private void ApplyConfiguration()
	{
		if (OwningWorkbench == nullptr)
		{
			return;
		}

		UBSChassisConfiguration Chassis = nullptr;
		if (SelectedChassisIndex >= 0 && SelectedChassisIndex < OwningWorkbench.AvailableChassis.Num())
		{
			Chassis = OwningWorkbench.AvailableChassis[SelectedChassisIndex];
		}

		UBSSentryLoadout Loadout = nullptr;
		if (SelectedLoadoutIndex >= 0 && SelectedLoadoutIndex < OwningWorkbench.AvailableLoadouts.Num())
		{
			Loadout = OwningWorkbench.AvailableLoadouts[SelectedLoadoutIndex];
		}

		OwningWorkbench.UpdateSentryConfiguration(Chassis, Loadout);
	}
}
