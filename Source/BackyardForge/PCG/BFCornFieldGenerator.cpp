#include "PCG/BFCornFieldGenerator.h"

#include "BackyardForge.h"
#include "PCG/BFCornField.h"

#include "Algo/Reverse.h"
#include "Components/SplineComponent.h"
#include "Data/PCGPointData.h"
#include "Helpers/PCGHelpers.h"
#include "PCGComponent.h"
#include "PCGContext.h"

namespace
{
	constexpr float DefaultProjectionTraceHalfHeight = 10000.0f;

	float SignedPolygonArea2D(const TArray<FVector2D>& Polygon)
	{
		double Area = 0.0;

		for (int32 Index = 0; Index < Polygon.Num(); ++Index)
		{
			const FVector2D& Current = Polygon[Index];
			const FVector2D& Next = Polygon[(Index + 1) % Polygon.Num()];
			Area += static_cast<double>(Current.X) * static_cast<double>(Next.Y) - static_cast<double>(Next.X) * static_cast<double>(Current.Y);
		}

		return static_cast<float>(Area * 0.5);
	}

	bool IsPointInsidePolygon2D(const FVector2D& Point, const TArray<FVector2D>& Polygon)
	{
		bool bInside = false;

		for (int32 Index = 0, PreviousIndex = Polygon.Num() - 1; Index < Polygon.Num(); PreviousIndex = Index++)
		{
			const FVector2D& Current = Polygon[Index];
			const FVector2D& Previous = Polygon[PreviousIndex];

			bool bIntersect = false;
			if ((Current.Y > Point.Y) != (Previous.Y > Point.Y))
			{
				const double Denominator = static_cast<double>(Previous.Y) - static_cast<double>(Current.Y);
				if (!FMath::IsNearlyZero(Denominator))
				{
					const double Alpha = (static_cast<double>(Point.Y) - static_cast<double>(Current.Y)) / Denominator;
					const double IntersectionX = FMath::Lerp(static_cast<double>(Current.X), static_cast<double>(Previous.X), Alpha);
					bIntersect = static_cast<double>(Point.X) < IntersectionX;
				}
			}

			if (bIntersect)
			{
				bInside = !bInside;
			}
		}

		return bInside;
	}

	float DistanceSquaredPointToSegment2D(const FVector2D& Point, const FVector2D& SegmentStart, const FVector2D& SegmentEnd)
	{
		const FVector2D Segment = SegmentEnd - SegmentStart;
		const float SegmentLengthSquared = Segment.SizeSquared();

		if (SegmentLengthSquared <= UE_KINDA_SMALL_NUMBER)
		{
			return FVector2D::DistSquared(Point, SegmentStart);
		}

		const float Alpha = FMath::Clamp(FVector2D::DotProduct(Point - SegmentStart, Segment) / SegmentLengthSquared, 0.0f, 1.0f);
		const FVector2D ClosestPoint = SegmentStart + Alpha * Segment;
		return FVector2D::DistSquared(Point, ClosestPoint);
	}

	float GetDistanceToPolygonEdges2D(const FVector2D& Point, const TArray<FVector2D>& Polygon)
	{
		float MinDistanceSquared = TNumericLimits<float>::Max();

		for (int32 Index = 0; Index < Polygon.Num(); ++Index)
		{
			const FVector2D& SegmentStart = Polygon[Index];
			const FVector2D& SegmentEnd = Polygon[(Index + 1) % Polygon.Num()];
			MinDistanceSquared = FMath::Min(MinDistanceSquared, DistanceSquaredPointToSegment2D(Point, SegmentStart, SegmentEnd));
		}

		return FMath::Sqrt(MinDistanceSquared);
	}

	TArray<FVector2D> BuildFieldPolygon(const ABFCornField& CornField)
	{
		TArray<FVector2D> Polygon;

		const USplineComponent* Spline = CornField.GetFieldSpline();
		if (!Spline || Spline->GetNumberOfSplinePoints() < 3)
		{
			return Polygon;
		}

		const float SampleStep = FMath::Clamp(FMath::Min(CornField.GetRowSpacing(), CornField.GetPlantSpacing()) * 0.5f, 25.0f, 200.0f);
		const float SplineLength = FMath::Max(Spline->GetSplineLength(), 1.0f);
		const int32 SampleCount = FMath::Max(Spline->GetNumberOfSplinePoints(), FMath::CeilToInt(SplineLength / SampleStep));
		const FTransform ActorTransform = CornField.GetActorTransform();

		Polygon.Reserve(SampleCount);

		for (int32 SampleIndex = 0; SampleIndex < SampleCount; ++SampleIndex)
		{
			const float Distance = (SplineLength * static_cast<float>(SampleIndex)) / static_cast<float>(SampleCount);
			const FVector WorldLocation = Spline->GetLocationAtDistanceAlongSpline(Distance, ESplineCoordinateSpace::World);
			const FVector LocalLocation = ActorTransform.InverseTransformPosition(WorldLocation);
			const FVector2D LocalPoint(LocalLocation.X, LocalLocation.Y);

			if (Polygon.IsEmpty() || !LocalPoint.Equals(Polygon.Last(), 0.1f))
			{
				Polygon.Add(LocalPoint);
			}
		}

		if (Polygon.Num() >= 2 && Polygon[0].Equals(Polygon.Last(), 0.1f))
		{
			Polygon.Pop();
		}

		if (Polygon.Num() >= 3 && SignedPolygonArea2D(Polygon) < 0.0f)
		{
			Algo::Reverse(Polygon);
		}

		return Polygon;
	}

	bool ProjectPointToTerrain(UWorld& World, const AActor& CornFieldActor, const FVector& InOutReferenceLocation, float MaxSlopeDegrees, FVector& OutProjectedLocation)
	{
		const FVector TraceStart = InOutReferenceLocation + FVector::UpVector * DefaultProjectionTraceHalfHeight;
		const FVector TraceEnd = InOutReferenceLocation - FVector::UpVector * DefaultProjectionTraceHalfHeight;

		FHitResult HitResult;
		FCollisionQueryParams QueryParams(SCENE_QUERY_STAT(BFCornFieldProjection), false, &CornFieldActor);

		if (!World.LineTraceSingleByChannel(HitResult, TraceStart, TraceEnd, ECC_WorldStatic, QueryParams))
		{
			return false;
		}

		const float CosSlope = FVector::DotProduct(HitResult.ImpactNormal.GetSafeNormal(), FVector::UpVector);
		const float SlopeDegrees = FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(CosSlope, -1.0f, 1.0f)));
		if (SlopeDegrees > MaxSlopeDegrees)
		{
			return false;
		}

		OutProjectedLocation = HitResult.ImpactPoint;
		return true;
	}
}

TArray<FPCGPinProperties> UBFCornFieldGeneratorSettings::InputPinProperties() const
{
	return TArray<FPCGPinProperties>();
}

TArray<FPCGPinProperties> UBFCornFieldGeneratorSettings::OutputPinProperties() const
{
	return DefaultPointOutputPinProperties();
}

FPCGElementPtr UBFCornFieldGeneratorSettings::CreateElement() const
{
	return MakeShared<FBFCornFieldGeneratorElement>();
}

bool FBFCornFieldGeneratorElement::ExecuteInternal(FPCGContext* Context) const
{
	TRACE_CPUPROFILER_EVENT_SCOPE(FBFCornFieldGeneratorElement::Execute);
	check(Context);

	UPCGComponent* SourceComponent = Cast<UPCGComponent>(Context->ExecutionSource.Get());
	ABFCornField* CornField = SourceComponent ? Cast<ABFCornField>(SourceComponent->GetOwner()) : nullptr;
	if (!CornField || !CornField->GetFieldSpline())
	{
		UE_LOG(LogBackyardForge, Warning, TEXT("[BF][CornField] Unable to resolve corn field actor or spline for PCG generation."));
		return true;
	}

	if (CornField->GetRowSpacing() <= UE_KINDA_SMALL_NUMBER || CornField->GetPlantSpacing() <= UE_KINDA_SMALL_NUMBER)
	{
		UE_LOG(LogBackyardForge, Warning, TEXT("[BF][CornField] Corn row spacing and plant spacing must be positive."));
		return true;
	}

	TArray<FVector2D> Polygon = BuildFieldPolygon(*CornField);
	if (Polygon.Num() < 3)
	{
		return true;
	}

	FVector2D BoundsMin(TNumericLimits<float>::Max(), TNumericLimits<float>::Max());
	FVector2D BoundsMax(TNumericLimits<float>::Lowest(), TNumericLimits<float>::Lowest());

	for (const FVector2D& Vertex : Polygon)
	{
		BoundsMin.X = FMath::Min(BoundsMin.X, Vertex.X);
		BoundsMin.Y = FMath::Min(BoundsMin.Y, Vertex.Y);
		BoundsMax.X = FMath::Max(BoundsMax.X, Vertex.X);
		BoundsMax.Y = FMath::Max(BoundsMax.Y, Vertex.Y);
	}

	const int32 MinColumn = FMath::FloorToInt(BoundsMin.X / CornField->GetPlantSpacing()) - 1;
	const int32 MaxColumn = FMath::CeilToInt(BoundsMax.X / CornField->GetPlantSpacing()) + 1;
	const int32 MinRow = FMath::FloorToInt(BoundsMin.Y / CornField->GetRowSpacing()) - 1;
	const int32 MaxRow = FMath::CeilToInt(BoundsMax.Y / CornField->GetRowSpacing()) + 1;

	const FVector2D ScaleRange = CornField->GetScaleRange();
	const float MinScale = FMath::Min(ScaleRange.X, ScaleRange.Y);
	const float MaxScale = FMath::Max(ScaleRange.X, ScaleRange.Y);
	const FRotator BaseRotation(0.0f, CornField->GetActorRotation().Yaw, 0.0f);
	const FTransform ActorTransform = CornField->GetActorTransform();

	TArray<FPCGPoint> Points;
	Points.Reserve(FMath::Max((MaxColumn - MinColumn + 1) * (MaxRow - MinRow + 1), 0));

	for (int32 RowIndex = MinRow; RowIndex <= MaxRow; ++RowIndex)
	{
		for (int32 ColumnIndex = MinColumn; ColumnIndex <= MaxColumn; ++ColumnIndex)
		{
			const int32 CellSeed = HashCombineFast(Context->GetSeed(), GetTypeHash(FIntPoint(ColumnIndex, RowIndex)));
			FRandomStream RandomStream(CellSeed);

			const float BaseX = static_cast<float>(ColumnIndex) * CornField->GetPlantSpacing();
			const float BaseY = static_cast<float>(RowIndex) * CornField->GetRowSpacing();

			const FVector2D CandidateLocal2D(
				BaseX + RandomStream.FRandRange(-CornField->GetForwardJitter(), CornField->GetForwardJitter()),
				BaseY + RandomStream.FRandRange(-CornField->GetRowJitter(), CornField->GetRowJitter()));

			if (!IsPointInsidePolygon2D(CandidateLocal2D, Polygon))
			{
				continue;
			}

			if (CornField->GetEdgePadding() > 0.0f && GetDistanceToPolygonEdges2D(CandidateLocal2D, Polygon) < CornField->GetEdgePadding())
			{
				continue;
			}

			FVector WorldLocation = ActorTransform.TransformPosition(FVector(CandidateLocal2D.X, CandidateLocal2D.Y, 0.0f));

			if (CornField->ShouldProjectToTerrain())
			{
				UWorld* World = CornField->GetWorld();
				FVector ProjectedLocation = WorldLocation;

				if (!World || !ProjectPointToTerrain(*World, *CornField, WorldLocation, CornField->GetMaxSlopeDegrees(), ProjectedLocation))
				{
					continue;
				}

				WorldLocation = ProjectedLocation;
			}

			const float Scale = RandomStream.FRandRange(MinScale, MaxScale);
			const float YawOffset = RandomStream.FRandRange(-CornField->GetYawVariation(), CornField->GetYawVariation());
			const FRotator PointRotation = BaseRotation + FRotator(0.0f, YawOffset, 0.0f);

			FPCGPoint Point(FTransform(PointRotation, WorldLocation, FVector(Scale)), 1.0f, CellSeed);
			Point.BoundsMin = FVector(-CornField->GetPlantSpacing() * 0.25f, -CornField->GetRowSpacing() * 0.25f, 0.0f);
			Point.BoundsMax = FVector(CornField->GetPlantSpacing() * 0.25f, CornField->GetRowSpacing() * 0.25f, 200.0f * Scale);
			Point.Steepness = 1.0f;
			Point.Seed = PCGHelpers::ComputeSeedFromPosition(WorldLocation) ^ CellSeed;

			Points.Add(Point);
		}
	}

	if (Points.IsEmpty())
	{
		return true;
	}

	UPCGBasePointData* PointData = FPCGContext::NewPointData_AnyThread(Context);
	if (!PointData)
	{
		return true;
	}

	PointData->SetNumPoints(Points.Num());
	FPCGPointValueRanges PointRanges(PointData);

	for (int32 PointIndex = 0; PointIndex < Points.Num(); ++PointIndex)
	{
		PointRanges.SetFromPoint(PointIndex, Points[PointIndex]);
	}

	FPCGTaggedData& Output = Context->OutputData.TaggedData.Emplace_GetRef();
	Output.Data = PointData;
	Output.Pin = PCGPinConstants::DefaultOutputLabel;

	return true;
}
