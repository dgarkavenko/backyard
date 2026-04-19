class UBSSentryScreen : UBSMMScreen
{
	UPROPERTY(EditAnywhere, Category = "Sentry")
	ABSSentry OwningSentry;

	default PanelColor = FLinearColor(0.02f, 0.02f, 0.02f, 0.9f);

	bool bShowDetectionRuntime = false;
	bool bShowAimRuntime = false;
	bool bShowFireRuntime = false;
	bool bShowPowerRuntime = false;

	const FLinearColor HeaderColor = FLinearColor(0.6f, 0.6f, 0.6f);
	const FLinearColor ValueColor = FLinearColor(1.0f, 1.0f, 1.0f);
	const FLinearColor MutedColor = FLinearColor(0.55f, 0.55f, 0.55f);
	const FLinearColor SectionColor = FLinearColor(0.08f, 0.08f, 0.08f, 0.9f);

	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float InDeltaTime)
	{
		Super::Tick(MyGeometry, InDeltaTime);

		ABSSentry Sentry = OwningSentry;
		UBSModularView RuntimeView = Sentry != nullptr ? Sentry.ModularView : nullptr;

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
					DrawLabeledValue("BaseIndex", RuntimeView != nullptr ? DescribeIndex(RuntimeView.RuntimeBaseIndex) : "<missing>");
					DrawLabeledValue("DetectionIndex", RuntimeView != nullptr ? DescribeIndex(RuntimeView.RuntimeDetectionIndex) : "<missing>");
					DrawLabeledValue("AimIndex", RuntimeView != nullptr ? DescribeIndex(RuntimeView.RuntimeAimIndex) : "<missing>");
					DrawLabeledValue("FireIndex", RuntimeView != nullptr ? DescribeIndex(RuntimeView.RuntimeFireIndex) : "<missing>");
					DrawLabeledValue("PowerIndex", RuntimeView != nullptr ? DescribeIndex(RuntimeView.RuntimePowerIndex) : "<missing>");
					mm::Spacer(12.0f);

					DrawCapabilities(RuntimeView);
					mm::Spacer(12.0f);

					UBSRuntimeSubsystem Runtime = UBSRuntimeSubsystem::Get();
					if (Runtime != nullptr && RuntimeView != nullptr && RuntimeView.RuntimeBaseIndex >= 0)
					{
						DrawRuntimeHeader("DETECTION", bShowDetectionRuntime);
						if (bShowDetectionRuntime && RuntimeView.RuntimeDetectionIndex >= 0)
						{
							DrawDetectionRuntime(Runtime, RuntimeView.RuntimeDetectionIndex);
						}

						mm::Spacer(8.0f);
						DrawRuntimeHeader("AIM", bShowAimRuntime);
						if (bShowAimRuntime && RuntimeView.RuntimeAimIndex >= 0)
						{
							DrawAimRuntime(Runtime, RuntimeView.RuntimeAimIndex);
						}

						mm::Spacer(8.0f);
						DrawRuntimeHeader("FIRE", bShowFireRuntime);
						if (bShowFireRuntime && RuntimeView.RuntimeFireIndex >= 0)
						{
							DrawFireRuntime(Runtime, RuntimeView.RuntimeFireIndex);
						}

						mm::Spacer(8.0f);
						DrawRuntimeHeader("POWER", bShowPowerRuntime);
						if (bShowPowerRuntime && RuntimeView.RuntimePowerIndex >= 0)
						{
							DrawPowerRuntime(Runtime, RuntimeView.RuntimePowerIndex);
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

	private void DrawCapabilities(UBSModularView RuntimeView) const
	{
		mm::Text("CAPABILITIES", 20, HeaderColor);
		mm::Spacer(5.0f);

		FGameplayTagContainer CapabilityTags = ResolveCapabilities(RuntimeView);
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

	private void DrawDetectionRuntime(UBSRuntimeSubsystem Runtime, int DetectionIndex) const
	{
		const FBSDetectionHotRow& Detection = Runtime.GetDetectionRuntime(DetectionIndex);
		const FBSDetectionColdRow& DetectionCold = Runtime.GetDetectionCold(DetectionIndex);

		mm::BeginBorder(SectionColor);
		mm::Padding(10.0f);
		mm::BeginVerticalBox();

			DrawLabeledValue("Detector", DescribeObject(DetectionCold.Detector));
			DrawLabeledValue("State", DescribeVisionState(Detection.VisionState));
			DrawLabeledValue("CurrentTarget", DescribeActor(Detection.CurrentTarget));
			DrawLabeledValue("CurrentTargetLocation", FormatVector(Detection.CurrentTargetLocation));
			DrawLabeledValue("DetectionCooldownRemaining", f"{Detection.DetectionCooldownRemaining}");
			DrawLabeledValue("ProbeDirection", f"{Detection.ProbeDirection}");
			DrawLabeledValue("ProbeTargetYaw", f"{Detection.ProbeTargetYaw}");
			DrawLabeledValue("Contacts", f"{Detection.Contacts.Num()}");
			DrawLabeledValue("Memories", f"{Detection.ContactMemory.Num()}");

			for (int ContactIndex = 0; ContactIndex < Detection.Contacts.Num(); ContactIndex++)
			{
				const FBSSensedContact& Contact = Detection.Contacts[ContactIndex];
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

	private void DrawAimRuntime(UBSRuntimeSubsystem Runtime, int AimIndex) const
	{
		const FBSAimHotRow& Aim = Runtime.GetAimRuntime(AimIndex);

		mm::BeginBorder(SectionColor);
		mm::Padding(10.0f);
		mm::BeginVerticalBox();

			DrawLabeledValue("HasAimTarget", FormatBool(Aim.bHasAimTarget));
			DrawLabeledValue("UseProbe", FormatBool(Aim.bUseProbe));
			DrawLabeledValue("AimTargetLocation", FormatVector(Aim.AimTargetLocation));
			DrawLabeledValue("ProbeYawTarget", f"{Aim.ProbeYawTarget}");
			DrawLabeledValue("AppliedRotator0Local", FormatRotator(Aim.AppliedRotator0Local));
			DrawLabeledValue("AppliedRotator1Local", FormatRotator(Aim.AppliedRotator1Local));
			DrawLabeledValue("MuzzleWorldLocation", FormatVector(Aim.MuzzleWorldLocation));
			DrawLabeledValue("MuzzleWorldRotation", FormatRotator(Aim.MuzzleWorldRotation));
			DrawLabeledValue("DistanceToTarget", f"{Aim.DistanceToTarget}");
			DrawLabeledValue("MuzzleError", FormatRotator(Aim.MuzzleError));

		mm::EndVerticalBox();
		mm::EndBorder();
	}

	private void DrawFireRuntime(UBSRuntimeSubsystem Runtime, int FireIndex) const
	{
		const FBSFireHotRow& Fire = Runtime.GetFireRuntime(FireIndex);

		mm::BeginBorder(SectionColor);
		mm::Padding(10.0f);
		mm::BeginVerticalBox();

			DrawLabeledValue("ShotCooldownRemaining", f"{Fire.ShotCooldownRemaining}");
			DrawLabeledValue("RPM", f"{Fire.RPM}");
			DrawLabeledValue("MaxDistance", f"{Fire.MaxDistance}");
			DrawLabeledValue("MaxAngleDegrees", f"{Fire.MaxAngleDegrees}");

		mm::EndVerticalBox();
		mm::EndBorder();
	}

	private void DrawPowerRuntime(UBSRuntimeSubsystem Runtime, int PowerIndex) const
	{
		const FBSPowerHotRow& Power = Runtime.GetPowerRuntime(PowerIndex);
		const FBSPowerChildrenRow& PowerChildren = Runtime.GetPowerChildren(PowerIndex);

		mm::BeginBorder(SectionColor);
		mm::Padding(10.0f);
		mm::BeginVerticalBox();

			mm::Text("Root", 14, HeaderColor);
			DrawPowerRuntimeValues(Power);
			DrawLabeledValue("Batteries", f"{PowerChildren.Batteries.Num()}");

			for (int BatteryIndex = 0; BatteryIndex < PowerChildren.Batteries.Num(); BatteryIndex++)
			{
				const FBSPowerChildRuntime& Battery = PowerChildren.Batteries[BatteryIndex];
				mm::Spacer(6.0f);
				mm::Text(f"Battery[{BatteryIndex}]", 14, HeaderColor);
				DrawLabeledValue("Reserve", f"{Battery.Reserve}");
				DrawLabeledValue("Output", f"{Battery.Output}");
				DrawLabeledValue("Capacity", f"{Battery.Capacity}");
			}

		mm::EndVerticalBox();
		mm::EndBorder();
	}

	private void DrawPowerRuntimeValues(const FBSPowerHotRow& Power) const
	{
		DrawLabeledValue("TapSourceBaseIndex", DescribeIndex(Power.TapSourcePowerIndex));
		DrawLabeledValue("ChildrenReserve", f"{Power.ChildrenReserve}");
		DrawLabeledValue("Reserve", f"{Power.Reserve}");
		DrawLabeledValue("AccumulatedDecrease", f"{Power.AccumulatedDecrease}");
		DrawLabeledValue("AccumulatedTransfer", f"{Power.AccumulatedTransfer}");
		DrawLabeledValue("Insufficency", f"{Power.Insufficency}");
		DrawLabeledValue("Output", f"{Power.Output}");
		DrawLabeledValue("Capacity", f"{Power.Capacity}");
		DrawLabeledValue("Supplied", FormatBool(Power.bSupplied));
	}

	private void DrawLabeledValue(const FString& Label, const FString& Value) const
	{
		mm::Text(f"{Label}: {Value}", 14, ValueColor, true);
	}

	private FGameplayTagContainer ResolveCapabilities(UBSModularView RuntimeView) const
	{
		UBSRuntimeSubsystem Runtime = UBSRuntimeSubsystem::Get();
		if (Runtime != nullptr && RuntimeView != nullptr && RuntimeView.RuntimeBaseIndex >= 0)
		{
			return Runtime.GetBaseRow(RuntimeView.RuntimeBaseIndex).Capabilities;
		}

		return FGameplayTagContainer();
	}

	private FString DescribeObject(UObject Object) const
	{
		return Object == nullptr ? "<none>" : Object.GetName().ToString();
	}

	private FString DescribeActor(AActor Actor) const
	{
		return Actor == nullptr ? "<none>" : Actor.GetName().ToString();
	}

	private FString DescribeIndex(int32 Index) const
	{
		return Index >= 0 ? f"{Index}" : "<none>";
	}

	private FString FormatVector(FVector Value) const
	{
		return f"X={Value.X} Y={Value.Y} Z={Value.Z}";
	}

	private FString FormatRotator(FRotator Value) const
	{
		return f"P={Value.Pitch} Y={Value.Yaw} R={Value.Roll}";
	}

	private FString FormatBool(bool bValue) const
	{
		return bValue ? "true" : "false";
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
