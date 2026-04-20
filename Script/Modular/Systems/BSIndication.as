namespace Systems
{
	namespace Indication
	{
		void Tick(FBSRuntimeStore& Store, float DeltaSeconds)
		{
			for (int IndicationIndex = 0; IndicationIndex < Store.IndicationHot.Num(); IndicationIndex++)
			{
				FBSIndicationHotRow& IndicationHot = Store.IndicationHot[IndicationIndex];
				FBSIndicationColdRow& IndicationCold = Store.IndicationCold[IndicationIndex];
				USpotLightComponent IndicatorComponent = IndicationCold.IndicatorComponent;
				if (IndicatorComponent == nullptr)
				{
					continue;
				}

				float ChainInsuficency = 0.0f;
				bool bSupplied = true;
				if (IndicationHot.Links.PowerIndex >= 0)
				{
					ChainInsuficency = 0;
					bSupplied = Store.PowerHot[IndicationHot.Links.PowerIndex].bSupplied;
				}

				if (IndicationHot.Links.DetectionIndex >= 0)
				{
					const FBSDetectionHotRow& DetectionHot = Store.DetectionHot[IndicationHot.Links.DetectionIndex];
					IndicationHot.DesiredColor = DetectionHot.VisionState == EBSSentryVisionState::Probing ? IndicationHot.SweepColor : IndicationHot.ActiveColor;
				}

				if (!bSupplied)
				{
					IndicationHot.DesiredIntensity = 0.0f;
				}
				else if (ChainInsuficency > 0.0f)
				{
					float T = Gameplay::TimeSeconds + IndicationIndex;
					float I = Math::Min(1.0f, Math::Abs(2.0f * Math::Sin(0.3f * T) + Math::Cos(T * 6.0f)));
					IndicationHot.DesiredIntensity = Math::Lerp(IndicationHot.FlickerLowIntensity, IndicationHot.FlickerHighIntensity, I);
				}
				else
				{
					IndicationHot.DesiredIntensity = IndicationHot.NominalIntensity;
				}

				IndicatorComponent.SetIntensity(IndicationHot.DesiredIntensity);
				IndicatorComponent.SetLightColor(IndicationHot.DesiredColor, true);
			}
		}
	}
}