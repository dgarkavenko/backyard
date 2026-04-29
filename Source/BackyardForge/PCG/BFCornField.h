#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "PCG/BFCornFieldSplineComponent.h"

#include "BFCornField.generated.h"

class UPCGComponent;
class UPCGGraph;
class UPCGStaticMeshSpawnerSettings;
struct FPropertyChangedEvent;
class USceneComponent;
class USplineComponent;
class UStaticMesh;

USTRUCT(BlueprintType)
struct FBCornFieldMeshVariation
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Corn Field")
	TObjectPtr<UStaticMesh> StaticMesh = nullptr;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Corn Field", meta = (ClampMin = "1"))
	int32 Weight = 1;
};

UCLASS(Blueprintable)
class BACKYARDFORGE_API ABFCornField : public AActor
{
	GENERATED_BODY()

public:
	ABFCornField();

	virtual void OnConstruction(const FTransform& Transform) override;
	virtual void PostRegisterAllComponents() override;
	virtual void BeginDestroy() override;

#if WITH_EDITOR
	virtual void PostEditChangeProperty(FPropertyChangedEvent& PropertyChangedEvent) override;
	virtual void PostEditMove(bool bFinished) override;
#endif

	const USplineComponent* GetFieldSpline() const { return FieldSpline; }
	const TArray<FBCornFieldMeshVariation>& GetMeshVariations() const { return MeshVariations; }
	int32 GetCornSeed() const { return Seed; }
	float GetRowSpacing() const { return RowSpacing; }
	float GetPlantSpacing() const { return PlantSpacing; }
	float GetRowJitter() const { return RowJitter; }
	float GetForwardJitter() const { return ForwardJitter; }
	const FVector2D& GetScaleRange() const { return ScaleRange; }
	float GetYawVariation() const { return YawVariation; }
	float GetEdgePadding() const { return EdgePadding; }
	bool ShouldProjectToTerrain() const { return bProjectToTerrain; }
	float GetMaxSlopeDegrees() const { return MaxSlopeDegrees; }

	UFUNCTION(CallInEditor, Category = "Corn Field")
	void RegenerateCornField();

	UFUNCTION(CallInEditor, Category = "Corn Field")
	void CleanupCornField();

	void HandleSplineEdited();

private:
	void ConfigureDefaultSpline();
	void EnsureGraphSetup();
	void SyncPCGComponent();
	void SyncSpawnerSettings();
	UPCGStaticMeshSpawnerSettings* GetSpawnerSettings() const;

	bool ShouldTriggerEditorGeneration() const;
	void RefreshCornField(bool bForceGenerate);

private:
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Corn Field|Components", meta = (AllowPrivateAccess = "true"))
	TObjectPtr<USceneComponent> SceneRoot;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Corn Field|Components", meta = (AllowPrivateAccess = "true"))
	TObjectPtr<UBFCornFieldSplineComponent> FieldSpline;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Corn Field|Components", meta = (AllowPrivateAccess = "true"))
	TObjectPtr<UPCGComponent> PCGComponent;

	UPROPERTY(VisibleAnywhere, Instanced, Category = "Corn Field|PCG")
	TObjectPtr<UPCGGraph> CornGraph;

	UPROPERTY(EditAnywhere, Category = "Corn Field|Meshes")
	TArray<FBCornFieldMeshVariation> MeshVariations;

	UPROPERTY(EditAnywhere, Category = "Corn Field|Layout", meta = (ClampMin = "25.0", Units = "cm"))
	float RowSpacing = 120.0f;

	UPROPERTY(EditAnywhere, Category = "Corn Field|Layout", meta = (ClampMin = "25.0", Units = "cm"))
	float PlantSpacing = 60.0f;

	UPROPERTY(EditAnywhere, Category = "Corn Field|Layout", meta = (ClampMin = "0.0", Units = "cm"))
	float RowJitter = 8.0f;

	UPROPERTY(EditAnywhere, Category = "Corn Field|Layout", meta = (ClampMin = "0.0", Units = "cm"))
	float ForwardJitter = 10.0f;

	UPROPERTY(EditAnywhere, Category = "Corn Field|Layout", meta = (ClampMin = "0.0", Units = "cm"))
	float EdgePadding = 20.0f;

	UPROPERTY(EditAnywhere, Category = "Corn Field|Variation", meta = (ClampMin = "0.1"))
	FVector2D ScaleRange = FVector2D(0.95f, 1.1f);

	UPROPERTY(EditAnywhere, Category = "Corn Field|Variation", meta = (ClampMin = "0.0", ClampMax = "180.0", Units = "Degrees"))
	float YawVariation = 8.0f;

	UPROPERTY(EditAnywhere, Category = "Corn Field|Variation")
	int32 Seed = 1337;

	UPROPERTY(EditAnywhere, Category = "Corn Field|Projection")
	bool bProjectToTerrain = true;

	UPROPERTY(EditAnywhere, Category = "Corn Field|Projection", meta = (ClampMin = "0.0", ClampMax = "89.0", Units = "Degrees"))
	float MaxSlopeDegrees = 30.0f;

	UPROPERTY(EditAnywhere, Category = "Corn Field|Editor")
	bool bLiveUpdateInEditor = true;
};
