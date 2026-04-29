#include "PCG/BFCornField.h"

#include "BackyardForge.h"
#include "PCG/BFCornFieldGenerator.h"
#include "PCG/BFCornFieldSplineComponent.h"

#include "Components/HierarchicalInstancedStaticMeshComponent.h"
#include "Components/SceneComponent.h"
#include "Engine/CollisionProfile.h"
#include "PCGCommon.h"
#include "PCGComponent.h"
#include "PCGGraph.h"
#include "PCGModule.h"
#include "PCGNode.h"
#include "Elements/PCGStaticMeshSpawner.h"
#include "MeshSelectors/PCGMeshSelectorWeighted.h"

ABFCornField::ABFCornField()
{
	PrimaryActorTick.bCanEverTick = false;

	SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
	SetRootComponent(SceneRoot);

	FieldSpline = CreateDefaultSubobject<UBFCornFieldSplineComponent>(TEXT("FieldSpline"));
	FieldSpline->SetupAttachment(SceneRoot);
	FieldSpline->SetClosedLoop(true);
	FieldSpline->bEditableWhenInherited = true;

	PCGComponent = CreateDefaultSubobject<UPCGComponent>(TEXT("PCGComponent"));

	CornGraph = CreateDefaultSubobject<UPCGGraph>(TEXT("CornGraph"));

	ConfigureDefaultSpline();
}

void ABFCornField::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);

	EnsureGraphSetup();
	SyncPCGComponent();
	SyncSpawnerSettings();
	RefreshCornField(bLiveUpdateInEditor);
}

void ABFCornField::PostRegisterAllComponents()
{
	Super::PostRegisterAllComponents();

	EnsureGraphSetup();
	SyncPCGComponent();
	SyncSpawnerSettings();
}

void ABFCornField::BeginDestroy()
{
	Super::BeginDestroy();
}

#if WITH_EDITOR
void ABFCornField::PostEditChangeProperty(FPropertyChangedEvent& PropertyChangedEvent)
{
	Super::PostEditChangeProperty(PropertyChangedEvent);

	RefreshCornField(bLiveUpdateInEditor);
}

void ABFCornField::PostEditMove(bool bFinished)
{
	Super::PostEditMove(bFinished);

	if (bFinished)
	{
		RefreshCornField(bLiveUpdateInEditor);
	}
}
#endif

void ABFCornField::RegenerateCornField()
{
	RefreshCornField(true);
}

void ABFCornField::CleanupCornField()
{
	if (PCGComponent)
	{
		PCGComponent->CleanupLocal(true);
	}
}

void ABFCornField::HandleSplineEdited()
{
	RefreshCornField(bLiveUpdateInEditor);
}

void ABFCornField::ConfigureDefaultSpline()
{
	if (!FieldSpline || FieldSpline->GetNumberOfSplinePoints() > 2)
	{
		return;
	}

	FieldSpline->ClearSplinePoints(false);
	FieldSpline->AddSplinePoint(FVector(-600.0f, -400.0f, 0.0f), ESplineCoordinateSpace::Local, false);
	FieldSpline->AddSplinePoint(FVector(600.0f, -400.0f, 0.0f), ESplineCoordinateSpace::Local, false);
	FieldSpline->AddSplinePoint(FVector(600.0f, 400.0f, 0.0f), ESplineCoordinateSpace::Local, false);
	FieldSpline->AddSplinePoint(FVector(-600.0f, 400.0f, 0.0f), ESplineCoordinateSpace::Local, false);

	for (int32 PointIndex = 0; PointIndex < FieldSpline->GetNumberOfSplinePoints(); ++PointIndex)
	{
		FieldSpline->SetSplinePointType(PointIndex, ESplinePointType::Linear, false);
	}

	FieldSpline->SetClosedLoop(true, false);
	FieldSpline->UpdateSpline();
}

void ABFCornField::EnsureGraphSetup()
{
	if (!CornGraph || !PCGComponent || HasAnyFlags(RF_ClassDefaultObject) || !FPCGModule::IsPCGModuleLoaded())
	{
		return;
	}

	if (PCGComponent->GetGraph() != CornGraph)
	{
		PCGComponent->SetGraphLocal(CornGraph);
	}

	UPCGNode* GeneratorNode = nullptr;
	UPCGNode* SpawnerNode = nullptr;
	UPCGStaticMeshSpawnerSettings* SpawnerSettings = nullptr;

	for (UPCGNode* Node : CornGraph->GetNodes())
	{
		if (!Node)
		{
			continue;
		}

		if (Node->GetSettings() && Node->GetSettings()->IsA<UBFCornFieldGeneratorSettings>())
		{
			GeneratorNode = Node;
		}
		else if (UPCGStaticMeshSpawnerSettings* CandidateSpawnerSettings = Cast<UPCGStaticMeshSpawnerSettings>(Node->GetSettings()))
		{
			SpawnerNode = Node;
			SpawnerSettings = CandidateSpawnerSettings;
		}
	}

	if (!GeneratorNode)
	{
		UPCGSettings* GeneratorSettings = nullptr;
		GeneratorNode = CornGraph->AddNodeOfType(UBFCornFieldGeneratorSettings::StaticClass(), GeneratorSettings);
	}

	if (!SpawnerNode)
	{
		UPCGSettings* NewSpawnerSettings = nullptr;
		SpawnerNode = CornGraph->AddNodeOfType(UPCGStaticMeshSpawnerSettings::StaticClass(), NewSpawnerSettings);
		SpawnerSettings = Cast<UPCGStaticMeshSpawnerSettings>(NewSpawnerSettings);
	}

	if (GeneratorNode && SpawnerNode)
	{
		CornGraph->AddEdge(GeneratorNode, PCGPinConstants::DefaultOutputLabel, SpawnerNode, PCGPinConstants::DefaultInputLabel);
		CornGraph->AddEdge(SpawnerNode, PCGPinConstants::DefaultOutputLabel, CornGraph->GetOutputNode(), PCGPinConstants::DefaultInputLabel);
	}

	if (SpawnerSettings)
	{
		SpawnerSettings->SetMeshSelectorType(UPCGMeshSelectorWeighted::StaticClass());
		SpawnerSettings->bApplyMeshBoundsToPoints = false;

		if (!HasAnyFlags(RF_ClassDefaultObject))
		{
			SpawnerSettings->TargetActor = this;
		}
	}
}

void ABFCornField::SyncPCGComponent()
{
	if (!PCGComponent || !CornGraph || HasAnyFlags(RF_ClassDefaultObject) || !FPCGModule::IsPCGModuleLoaded())
	{
		return;
	}

	PCGComponent->SetGraphLocal(CornGraph);
	PCGComponent->Seed = Seed;
	PCGComponent->bActivated = true;
	PCGComponent->bIsComponentPartitioned = false;
	PCGComponent->GenerationTrigger = EPCGComponentGenerationTrigger::GenerateOnLoad;
	PCGComponent->bGenerateOnDropWhenTriggerOnDemand = false;

#if WITH_EDITORONLY_DATA
	PCGComponent->bOnlyTrackItself = true;
	PCGComponent->bRegenerateInEditor = true;
#endif
}

void ABFCornField::SyncSpawnerSettings()
{
	if (HasAnyFlags(RF_ClassDefaultObject) || !FPCGModule::IsPCGModuleLoaded())
	{
		return;
	}

	UPCGStaticMeshSpawnerSettings* SpawnerSettings = GetSpawnerSettings();
	if (!SpawnerSettings)
	{
		return;
	}

	SpawnerSettings->SetMeshSelectorType(UPCGMeshSelectorWeighted::StaticClass());
	SpawnerSettings->bApplyMeshBoundsToPoints = false;
	SpawnerSettings->bAllowMergeDifferentDataInSameInstancedComponents = true;
	SpawnerSettings->bWarnOnIdenticalSpawn = false;

	if (!HasAnyFlags(RF_ClassDefaultObject))
	{
		SpawnerSettings->TargetActor = this;
	}

	UPCGMeshSelectorWeighted* WeightedSelector = Cast<UPCGMeshSelectorWeighted>(SpawnerSettings->MeshSelectorParameters);
	if (!WeightedSelector)
	{
		return;
	}

	WeightedSelector->MeshEntries.Reset();
	WeightedSelector->MeshEntries.Reserve(MeshVariations.Num());

	for (const FBCornFieldMeshVariation& Variation : MeshVariations)
	{
		if (!Variation.StaticMesh)
		{
			continue;
		}

		FPCGMeshSelectorWeightedEntry& Entry = WeightedSelector->MeshEntries.Emplace_GetRef();
		Entry.Descriptor.ComponentClass = UHierarchicalInstancedStaticMeshComponent::StaticClass();
		Entry.Descriptor.StaticMesh = Variation.StaticMesh;
		Entry.Descriptor.Mobility = EComponentMobility::Static;
		Entry.Descriptor.bUseDefaultCollision = false;
		Entry.Descriptor.bGenerateOverlapEvents = false;
		Entry.Descriptor.bCanEverAffectNavigation = false;
		Entry.Descriptor.BodyInstance.SetCollisionProfileName(UCollisionProfile::NoCollision_ProfileName);
		Entry.Weight = FMath::Max(1, Variation.Weight);
	}

#if WITH_EDITOR
	WeightedSelector->RefreshDisplayNames();
#endif
}

UPCGStaticMeshSpawnerSettings* ABFCornField::GetSpawnerSettings() const
{
	if (!CornGraph)
	{
		return nullptr;
	}

	for (UPCGNode* Node : CornGraph->GetNodes())
	{
		if (Node)
		{
			if (UPCGStaticMeshSpawnerSettings* SpawnerSettings = Cast<UPCGStaticMeshSpawnerSettings>(Node->GetSettings()))
			{
				return SpawnerSettings;
			}
		}
	}

	return nullptr;
}

bool ABFCornField::ShouldTriggerEditorGeneration() const
{
#if WITH_EDITOR
	return GIsEditor
		&& !HasAnyFlags(RF_ClassDefaultObject)
		&& GetWorld()
		&& !GetWorld()->IsGameWorld()
		&& PCGComponent;
#else
	return false;
#endif
}

void ABFCornField::RefreshCornField(bool bForceGenerate)
{
	if (HasAnyFlags(RF_ClassDefaultObject) || !FPCGModule::IsPCGModuleLoaded())
	{
		return;
	}

	EnsureGraphSetup();
	SyncPCGComponent();
	SyncSpawnerSettings();

	if (bForceGenerate && ShouldTriggerEditorGeneration())
	{
		const FPCGTaskId CleanupTaskId = PCGComponent->CleanupLocal(true, TArray<FPCGTaskId>());
		TArray<FPCGTaskId> Dependencies;

		if (CleanupTaskId != InvalidPCGTaskId)
		{
			Dependencies.Add(CleanupTaskId);
		}

		PCGComponent->GenerateLocal(EPCGComponentGenerationTrigger::GenerateOnDemand, true, EPCGHiGenGrid::Uninitialized, Dependencies);
	}
}
