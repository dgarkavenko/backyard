class UBSSentryScreen : UBSMMScreen
{
	UPROPERTY(EditAnywhere, Category = "Sentry")
	ABSSentry OwningSentry;

	default PanelColor = FLinearColor(0.02f, 0.02f, 0.02f, 0.9f);

	bool bShowPerceptionRuntime = false;
	bool bShowTargetingRuntime = false;
	bool bShowCombatRuntime = false;
	bool bShowPowerRuntime = false;

	const FLinearColor HeaderColor = FLinearColor(0.6f, 0.6f, 0.6f);
	const FLinearColor LabelColor = FLinearColor(0.8f, 0.8f, 0.8f);
	const FLinearColor ValueColor = FLinearColor(1.0f, 1.0f, 1.0f);
	const FLinearColor MutedColor = FLinearColor(0.55f, 0.55f, 0.55f);
	const FLinearColor SectionColor = FLinearColor(0.08f, 0.08f, 0.08f, 0.9f);

	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float InDeltaTime)
	{
		Super::Tick(MyGeometry, InDeltaTime);

		ABSSentry Sentry = OwningSentry;
		TOptional<int> RowIndex = FindRowIndex(Sentry);

		mm::BeginDraw(MMWidget);
			mm::HAlign_Fill();
			mm::VAlign_Fill();

			mm::BeginBorder(PanelColor);			
			mm::Padding(20.0f);
			mm::BeginScrollBox();
			mm::BeginVerticalBox();

				if (Sentry != nullptr)
				{
					for (auto SentrySlot : Sentry.ModularComponent.Slots)
					{
						mm::BeginHorizontalBox();
						mm::Text(f"[{SentrySlot.Index} {SentrySlot.SlotData.Tags.GetLeafs()}]: ", 14, ValueColor, true);
						if (SentrySlot.Content.IsSet())
						{
							mm::Text(f"{SentrySlot.GetDefinitionUnsafe(Sentry.ModularComponent).Name}", 14, ValueColor, true);
						}					

						mm::EndHorizontalBox();
					}

					DrawLabeledValue("Sentry", Sentry.GetName().ToString());
					DrawLabeledValue("Runtime Row", RowIndex.IsSet() ? f"{RowIndex.Value}" : "<missing>");
					mm::Spacer(12.0f);

					DrawCapabilities(RowIndex);
					mm::Spacer(12.0f);

					if (RowIndex.IsSet())
					{
						UBSRuntimeSubsystem SentrySubsystem = UBSRuntimeSubsystem::Get();
						check(SentrySubsystem != nullptr);

						DrawRuntimeHeader("PERCEPTION", bShowPerceptionRuntime);
						if (bShowPerceptionRuntime)
						{
							DrawPerceptionRuntime(SentrySubsystem, RowIndex.Value);
						}

						mm::Spacer(8.0f);
						DrawRuntimeHeader("TARGETING", bShowTargetingRuntime);
						if (bShowTargetingRuntime)
						{
							DrawTargetingRuntime(SentrySubsystem, RowIndex.Value);
						}

						mm::Spacer(8.0f);
						DrawRuntimeHeader("COMBAT", bShowCombatRuntime);
						if (bShowCombatRuntime)
						{
							DrawCombatRuntime(SentrySubsystem, RowIndex.Value);
						}

						mm::Spacer(8.0f);
						DrawRuntimeHeader("POWER", bShowPowerRuntime);
						if (bShowPowerRuntime)
						{
							DrawPowerRuntime(SentrySubsystem, RowIndex.Value);
						}
					}
					else
					{
						mm::Text("Sentry has no runtime row yet.", 14, MutedColor);
					}
				}

				mm::Spacer(12.0f);
				if (mm::Button("CLOSE"))
				{
					DeactivateWidget();
				}

			mm::EndVerticalBox();
			mm::EndScrollBox();
			mm::EndBorder();			
		mm::EndDraw();
	}

	private void DrawCapabilities(TOptional<int> RowIndex) const
	{
		mm::Text("CAPABILITIES", 20, HeaderColor);
		mm::Spacer(5.0f);

		FGameplayTagContainer CapabilityTags = ResolveCapabilities(RowIndex);
		if (CapabilityTags.GameplayTags.Num() == 0)
		{
			mm::Text("<none>", 14, MutedColor);
			return;
		}

		for (FGameplayTag Tag : CapabilityTags.GameplayTags)
		{
			mm::Text(Tag.ToString(), 14, ValueColor, true);
		}
	}

	private void DrawRuntimeHeader(const FString& Title, bool& bExpanded)
	{
		FString Prefix = bExpanded ? "[-]" : "[+]";
		if (mm::Button(f"{Prefix} {Title}"))
		{
			bExpanded = !bExpanded;
		}
	}

	private void DrawPerceptionRuntime(UBSRuntimeSubsystem SentrySubsystem, int RowIndex) const
	{
		const FBSSentryPerceptionRuntime& Perception = SentrySubsystem.GetPerceptionRuntime(RowIndex);
		const FBSSentryStatics& RowStatics = SentrySubsystem.GetStatics(RowIndex);

		mm::BeginBorder(SectionColor);
		mm::Padding(10.0f);
		mm::BeginVerticalBox();

			DrawLabeledValue("Detector", DescribeObject(RowStatics.Vision));
			DrawLabeledValue("State", DescribeVisionState(Perception.VisionState));
			DrawLabeledValue("CurrentTarget", DescribeActor(Perception.CurrentTarget));
			DrawLabeledValue("CurrentTargetLocation", FormatVector(Perception.CurrentTargetLocation));
			DrawLabeledValue("DetectionCooldownRemaining", f"{Perception.DetectionCooldownRemaining}");
			DrawLabeledValue("ProbeDirection", f"{Perception.ProbeDirection}");
			DrawLabeledValue("Contacts", f"{Perception.Contacts.Num()}");
			DrawLabeledValue("Memories", f"{Perception.ContactMemory.Num()}");

			for (int ContactIndex = 0; ContactIndex < Perception.Contacts.Num(); ContactIndex++)
			{
				const FBSSensedContact& Contact = Perception.Contacts[ContactIndex];
				mm::Spacer(6.0f);
				mm::Text(f"Contact[{ContactIndex}]", 14, HeaderColor);
				DrawLabeledValue("  Actor", DescribeActor(Contact.Actor));
				DrawLabeledValue("  Location", FormatVector(Contact.WorldLocation));
				DrawLabeledValue("  Velocity", FormatVector(Contact.Velocity));
				DrawLabeledValue("  Distance", f"{Contact.Distance}");
				DrawLabeledValue("  LineOfSight", Contact.bHasLineOfSight ? "true" : "false");
				DrawLabeledValue("  RecognizedHostile", Contact.bRecognizedHostile ? "true" : "false");
			}

		mm::EndVerticalBox();
		mm::EndBorder();
	}

	private void DrawTargetingRuntime(UBSRuntimeSubsystem SentrySubsystem, int RowIndex) const
	{
		const FBSSentryTargetingRuntime& Targeting = SentrySubsystem.GetTargetingRuntime(RowIndex);

		mm::BeginBorder(SectionColor);
		mm::Padding(10.0f);
		mm::BeginVerticalBox();

			DrawLabeledValue("TargetLocation", FormatVector(Targeting.TargetLocation));
			DrawLabeledValue("AppliedRotator0Local", FormatRotator(Targeting.AppliedRotator0Local));
			DrawLabeledValue("AppliedRotator1Local", FormatRotator(Targeting.AppliedRotator1Local));
			DrawLabeledValue("MuzzleWorldLocation", FormatVector(Targeting.MuzzleWorldLocation));
			DrawLabeledValue("MuzzleWorldRotation", FormatRotator(Targeting.MuzzleWorldRotation));
			DrawLabeledValue("DistanceToTarget", f"{Targeting.DistanceToTarget}");
			DrawLabeledValue("MuzzleError", FormatRotator(Targeting.MuzzleError));

		mm::EndVerticalBox();
		mm::EndBorder();
	}

	private void DrawCombatRuntime(UBSRuntimeSubsystem SentrySubsystem, int RowIndex) const
	{
		const FBSSentryCombatRuntime& Combat = SentrySubsystem.GetCombatRuntime(RowIndex);

		mm::BeginBorder(SectionColor);
		mm::Padding(10.0f);
		mm::BeginVerticalBox();

			DrawLabeledValue("ShotCooldownRemaining", f"{Combat.ShotCooldownRemaining}");

		mm::EndVerticalBox();
		mm::EndBorder();
	}

	private void DrawPowerRuntime(UBSRuntimeSubsystem SentrySubsystem, int RowIndex) const
	{
		const FBSPowerRuntime& Power = SentrySubsystem.GetPowerRuntime(RowIndex);

		mm::BeginBorder(SectionColor);

		mm::EndBorder();
	}

	private void DrawLabeledValue(const FString& Label, const FString& Value) const
	{
		mm::Text(f"{Label}: {Value}", 14, ValueColor, true);
	}

	private FGameplayTagContainer ResolveCapabilities(TOptional<int> RowIndex) const
	{
		UBSRuntimeSubsystem SentrySubsystem = UBSRuntimeSubsystem::Get();
		if (SentrySubsystem != nullptr && RowIndex.IsSet())
		{
			return SentrySubsystem.Store.Capabilities[RowIndex.Value];
		}

		return FGameplayTagContainer();
	}

	private TOptional<int> FindRowIndex(ABSSentry Sentry) const
	{
		if (Sentry == nullptr)
		{
			return TOptional<int>();
		}

		UBSRuntimeSubsystem SentrySubsystem = UBSRuntimeSubsystem::Get();
		if (SentrySubsystem == nullptr)
		{
			return TOptional<int>();
		}

		return SentrySubsystem.GetRowIndex(Sentry);
	}

	private int GetRuntimeRowCount() const
	{
		UBSRuntimeSubsystem SentrySubsystem = UBSRuntimeSubsystem::Get();
		return SentrySubsystem == nullptr ? 0 : SentrySubsystem.GetRowCount();
	}

	private FString DescribeObject(UObject Object) const
	{
		return Object == nullptr ? "<none>" : Object.GetName().ToString();
	}

	private FString DescribeActor(AActor Actor) const
	{
		return Actor == nullptr ? "<none>" : Actor.GetName().ToString();
	}

	private FString FormatVector(FVector Value) const
	{
		return f"X={Value.X} Y={Value.Y} Z={Value.Z}";
	}

	private FString FormatRotator(FRotator Value) const
	{
		return f"P={Value.Pitch} Y={Value.Yaw} R={Value.Roll}";
	}

	private FString DescribeVisionState(EBSSentryVisionState VisionState) const
	{
		switch (VisionState)
		{
			case EBSSentryVisionState::Probing:
				return "Probing";
			case EBSSentryVisionState::Acquiring:
				return "Acquiring";
			case EBSSentryVisionState::Tracking:
				return "Tracking";
			case EBSSentryVisionState::LostHold:
				return "LostHold";
		}
	}
}
