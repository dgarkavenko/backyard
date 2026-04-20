enum EBSFloatTweenPreset
{
	Linear,
	InQuad,
	OutQuad,
	SmoothStep,
	SmootherStep
}

struct FBSFloatTweenState
{
	float StartValue = 0.0f;
	float TargetValue = 0.0f;
	float Elapsed = 0.0f;
	float Duration = 0.0f;
	EBSFloatTweenPreset EasePreset = EBSFloatTweenPreset::OutQuad;
	bool bActive = false;
}

namespace Systems
{
	namespace Tween
	{
		void StartFloatTween(FBSFloatTweenState& TweenState,
							 float CurrentValue,
							 float TargetValue,
							 float Duration,
							 EBSFloatTweenPreset EasePreset)
		{
			TweenState.StartValue = CurrentValue;
			TweenState.TargetValue = TargetValue;
			TweenState.Elapsed = 0.0f;
			TweenState.Duration = Duration;
			TweenState.EasePreset = EasePreset;
			TweenState.bActive = Duration > 0.0f && !Math::IsNearlyEqual(CurrentValue, TargetValue, 0.01f);
		}

		float StepFloatTween(FBSFloatTweenState& TweenState, float DeltaSeconds)
		{
			if (!TweenState.bActive)
			{
				return TweenState.TargetValue;
			}

			if (TweenState.Duration <= 0.0f)
			{
				TweenState.bActive = false;
				return TweenState.TargetValue;
			}

			TweenState.Elapsed = Math::Min(TweenState.Elapsed + Math::Max(DeltaSeconds, 0.0f), TweenState.Duration);
			float Alpha = Math::Clamp(TweenState.Elapsed / TweenState.Duration, 0.0f, 1.0f);
			float EasedAlpha = EvaluateEase(TweenState.EasePreset, Alpha);

			if (Alpha >= 1.0f)
			{
				TweenState.bActive = false;
				return TweenState.TargetValue;
			}

			return Math::Lerp(TweenState.StartValue, TweenState.TargetValue, EasedAlpha);
		}

		float EvaluateEase(EBSFloatTweenPreset EasePreset, float Alpha)
		{
			float ClampedAlpha = Math::Clamp(Alpha, 0.0f, 1.0f);

			if (EasePreset == EBSFloatTweenPreset::InQuad)
			{
				return ClampedAlpha * ClampedAlpha;
			}

			if (EasePreset == EBSFloatTweenPreset::OutQuad)
			{
				float OneMinusAlpha = 1.0f - ClampedAlpha;
				return 1.0f - OneMinusAlpha * OneMinusAlpha;
			}

			if (EasePreset == EBSFloatTweenPreset::SmoothStep)
			{
				return ClampedAlpha * ClampedAlpha * (3.0f - 2.0f * ClampedAlpha);
			}

			if (EasePreset == EBSFloatTweenPreset::SmootherStep)
			{
				return ClampedAlpha * ClampedAlpha * ClampedAlpha * (ClampedAlpha * (ClampedAlpha * 6.0f - 15.0f) + 10.0f);
			}

			return ClampedAlpha;
		}
	}
}
