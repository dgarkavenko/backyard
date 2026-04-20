class UBSCSpawnScreen : UBSMMScreen
{
	default PanelColor = FLinearColor(0.02f, 0.02f, 0.02f, 0.9f);

	double SpawnCountSlider = 10.0;
	TArray<ABSBreachEnemySpawner> SpawnZones;
	TArray<bool> ZoneSelection;
	bool bInitialized = false;

	const FLinearColor HeaderColor = FLinearColor(0.6f, 0.6f, 0.6f);
	const FLinearColor ValueColor = FLinearColor(1.0f, 1.0f, 1.0f);
	const FLinearColor MutedColor = FLinearColor(0.55f, 0.55f, 0.55f);
	const FLinearColor SectionColor = FLinearColor(0.08f, 0.08f, 0.08f, 0.9f);
	const FLinearColor SuccessColor = FLinearColor(0.15f, 0.4f, 0.15f);

	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float InDeltaTime)
	{
		Super::Tick(MyGeometry, InDeltaTime);

		if (!bInitialized)
		{
			RefreshZones();
			bInitialized = true;
		}

		mm::BeginDraw(MMWidget);
			mm::HAlign_Fill();
			mm::VAlign_Fill();

			mm::BeginBorder(PanelColor);
			mm::Padding(20.0f);
			mm::BeginScrollBox();
			mm::BeginVerticalBox();

				mm::Text("ENEMY SPAWN", 28, FLinearColor::White, false, true);
				mm::Spacer(12.0f);

				DrawSpawnCountSection();
				mm::Spacer(12.0f);
				DrawZonesSection();
				mm::Spacer(12.0f);
				DrawActions();

			mm::EndVerticalBox();
			mm::EndScrollBox();
			mm::EndBorder();
		mm::EndDraw();
	}

	private void DrawSpawnCountSection()
	{
		mm::Text("COUNT", 20, HeaderColor);
		mm::Spacer(5.0f);

		int32 SpawnCount = GetSpawnCount();
		mm::Text(f"{SpawnCount}", 16, ValueColor, true);
		mm::Slider(SpawnCountSlider, 1.0f, 100.0f);
	}

	private void DrawZonesSection()
	{
		mm::Text("ZONES", 20, HeaderColor);
		mm::Spacer(5.0f);

		mm::BeginBorder(SectionColor);
		mm::Padding(10.0f);
		mm::BeginVerticalBox();

			if (SpawnZones.Num() == 0)
			{
				mm::Text("No spawn zones found.", 14, MutedColor);
			}
			else
			{
				for (int Index = 0; Index < SpawnZones.Num(); Index++)
				{
					ABSBreachEnemySpawner Zone = SpawnZones[Index];
					if (Zone == nullptr)
					{
						continue;
					}

					FString Label = BuildZoneLabel(Zone);
					bool bSelected = ZoneSelection[Index];
					mm::CheckBox(bSelected, Label);
					ZoneSelection[Index] = bSelected;
				}
			}

		mm::EndVerticalBox();
		mm::EndBorder();
	}

	private void DrawActions()
	{
		auto SpawnButton = mm::Button("SPAWN");
		if (!HasSelectedZones())
		{
			SpawnButton.SetButtonStyleColor(MutedColor);
		}
		else
		{
			SpawnButton.SetButtonStyleColor(SuccessColor);
		}

		if (SpawnButton)
		{
			SpawnSelectedZones();
		}

		mm::Spacer(8.0f);
		if (mm::Button("REFRESH ZONES"))
		{
			RefreshZones();
		}

		mm::Spacer(8.0f);
		if (mm::Button("CLOSE"))
		{
			DeactivateWidget();
		}
	}

	private void RefreshZones()
	{
		TArray<AActor> Actors;
		Gameplay::GetAllActorsOfClass(ABSBreachEnemySpawner, Actors);

		SpawnZones.Reset();
		ZoneSelection.Reset();

		for (AActor Actor : Actors)
		{
			ABSBreachEnemySpawner Zone = Cast<ABSBreachEnemySpawner>(Actor);
			if (Zone == nullptr)
			{
				continue;
			}

			SpawnZones.Add(Zone);
			ZoneSelection.Add(true);
		}
	}

	private void SpawnSelectedZones()
	{
		TArray<ABSBreachEnemySpawner> EnabledZones = GetSelectedZones();
		if (EnabledZones.Num() == 0)
		{
			Print("[EnemySpawnScreen] No spawn zones selected.");
			return;
		}

		int32 SpawnCount = GetSpawnCount();
		int32 Spawned = 0;

		for (int Index = 0; Index < SpawnCount; Index++)
		{
			int32 ZoneIndex = Math::RandRange(0, EnabledZones.Num() - 1);
			ABSBreachEnemySpawner Zone = EnabledZones[ZoneIndex];
			if (Zone != nullptr && Zone.SpawnEnemy())
			{
				Spawned++;
			}
		}

		Print(f"[EnemySpawnScreen] Spawned {Spawned}/{SpawnCount} enemies.");
	}

	private TArray<ABSBreachEnemySpawner> GetSelectedZones() const
	{
		TArray<ABSBreachEnemySpawner> EnabledZones;

		for (int Index = 0; Index < SpawnZones.Num(); Index++)
		{
			if (!ZoneSelection[Index])
			{
				continue;
			}

			ABSBreachEnemySpawner Zone = SpawnZones[Index];
			if (Zone != nullptr)
			{
				EnabledZones.Add(Zone);
			}
		}

		return EnabledZones;
	}

	private bool HasSelectedZones() const
	{
		for (bool bSelected : ZoneSelection)
		{
			if (bSelected)
			{
				return true;
			}
		}

		return false;
	}

	private int32 GetSpawnCount() const
	{
		return Math::Clamp(int32(SpawnCountSlider + 0.5), 1, 100);
	}

	private FString BuildZoneLabel(ABSBreachEnemySpawner Zone) const
	{
		FString ZoneLabel = Zone.ActorNameOrLabel;
		FString TargetLabel = Zone.ZoneMarker != nullptr ? Zone.ZoneMarker.ActorNameOrLabel : "<no target>";
		return f"{ZoneLabel} -> {TargetLabel}";
	}
}
