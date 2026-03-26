#include "BFProjectileSubsystem.h"

#include "BackyardForge.h"
#include "BFProjectileSettings.h"
#include "CollisionQueryParams.h"
#include "DrawDebugHelpers.h"
#include "NiagaraDataChannel.h"
#include "NiagaraDataChannelAccessor.h"
#include "NiagaraDataChannelFunctionLibrary.h"
#include "Engine/World.h"
#include "GameFramework/DamageType.h"
#include "HAL/IConsoleManager.h"
#include "Kismet/GameplayStatics.h"
#include "UObject/WeakObjectPtrTemplates.h"
#include "Stats/Stats.h"

DECLARE_STATS_GROUP(TEXT("Projectiles"), STATGROUP_Projectiles, STATCAT_Advanced);
DECLARE_CYCLE_STAT(TEXT("Subsystem Tick"), STAT_ProjectileSubsystem_Tick, STATGROUP_Projectiles);
DECLARE_CYCLE_STAT(TEXT("Subsystem Prep"), STAT_ProjectileSubsystem_Prep, STATGROUP_Projectiles);
DECLARE_CYCLE_STAT(TEXT("Subsystem Solve"), STAT_ProjectileSubsystem_Solve, STATGROUP_Projectiles);
DECLARE_CYCLE_STAT(TEXT("Subsystem Impacts"), STAT_ProjectileSubsystem_Impacts, STATGROUP_Projectiles);
DECLARE_CYCLE_STAT(TEXT("Subsystem Trails"), STAT_ProjectileSubsystem_Trails, STATGROUP_Projectiles);
DECLARE_CYCLE_STAT(TEXT("Subsystem Editor"), STAT_ProjectileSubsystem_Editor, STATGROUP_Projectiles);

namespace
{
	static TAutoConsoleVariable<int32> CVarBFProjectileDebugDraw(
		TEXT("bf.Projectile.DebugDraw"),
		0,
		TEXT("Enable debug drawing for native projectiles."),
		ECVF_Cheat);

	static TAutoConsoleVariable<float> CVarBFProjectileDebugDuration(
		TEXT("bf.Projectile.DebugDuration"),
		0.1f,
		TEXT("Duration of debug draw for native projectiles."),
		ECVF_Cheat);

	static TAutoConsoleVariable<int32> CVarBFProjectileDebugIds(
		TEXT("bf.Projectile.DebugIds"),
		0,
		TEXT("Show projectile ids when debug drawing projectiles."),
		ECVF_Cheat);
}

const FName PositionParam = FName("Position");
const FName NormalParam = FName("Normal");
const FName VelocityParam = FName("Velocity");
const FName IDParam = FName("ProjectileIndex");
const FName HitTypeParam = FName("HitType");

inline constexpr float DragValues[EBFProjectileDrag::COUNT] { 0.0f, 0.125f, 0.215f, 0.3f};

void UBFProjectileSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);

	ProjectilePool.Reset(MaxProjectiles);
	ProjectilePool.AddDefaulted(MaxProjectiles);

	ProjectileColdDataPool.Reset(MaxProjectiles);
	ProjectileColdDataPool.AddDefaulted(MaxProjectiles);

	TraceParamsCache.Reset(MaxProjectiles);
	TraceParamsCache.AddDefaulted(MaxProjectiles);

	FreeList.Reset(MaxProjectiles);
	for (int32 Index = 0; Index < MaxProjectiles; ++Index)
	{
		FreeList.Add(Index);
	}

	PendingImpacts.Reserve(MaxProjectiles);

	if (const UBFProjectileSettings* Settings = GetDefault<UBFProjectileSettings>())
	{
		SetImpactDataChannel(Settings->ImpactDataChannel.LoadSynchronous());
		SetTrailDataChannel(Settings->TrailDataChannel.LoadSynchronous());
	}
}

void UBFProjectileSubsystem::Deinitialize()
{
	ProjectilePool.Reset();
	FreeList.Reset();
	IdToSlot.Reset();
	PendingImpacts.Reset();
	Super::Deinitialize();
}

void UBFProjectileSubsystem::Tick(float DeltaSeconds)
{
	SCOPE_CYCLE_COUNTER(STAT_ProjectileSubsystem_Tick);
	int32 TrailsWriteCount = 0;

	UWorld* World = GetWorld();
	if (!World)
	{
		return;
	}

	{
		SCOPE_CYCLE_COUNTER(STAT_ProjectileSubsystem_Prep);
		if (ProjectilePool.Num() > 0)
		{
			for (int32 DragIndex = 1; DragIndex < EBFProjectileDrag::COUNT; ++DragIndex)
			{
				DynamicDragLUT[DragIndex] = FMath::Exp(-DragValues[DragIndex] * DeltaSeconds);
			}
		}
	}

	{
		SCOPE_CYCLE_COUNTER(STAT_ProjectileSubsystem_Solve);
		for (int32 Index = 0; Index < ProjectilePool.Num(); ++Index)
		{
			FProjectileSlot& Projectile = ProjectilePool[Index];
			if (!Projectile.bAlive)
			{
				continue;
			}

			Projectile.Age += DeltaSeconds;
			if (Projectile.Age >= Projectile.Lifetime)
			{
				ReleaseProjectileSlot(Index);
				continue;
			}

			const FVector Start = Projectile.Position;
			FVector Velocity = Projectile.Velocity;
			Velocity += Gravity * DeltaSeconds;
			Velocity *= DynamicDragLUT[Projectile.Drag];

			const FVector End = Start + Velocity * DeltaSeconds;

			FHitResult HitResult;
			const bool bHit = World->LineTraceSingleByChannel(HitResult, Start, End, TraceChannel, TraceParamsCache[Index]);

			Projectile.Velocity = Velocity;

#if WITH_EDITOR
			if (CVarBFProjectileDebugDraw.GetValueOnAnyThread() > 0)
			{
				SCOPE_CYCLE_COUNTER(STAT_ProjectileSubsystem_Editor);

				const float DebugDuration = CVarBFProjectileDebugDuration.GetValueOnAnyThread();
				const bool bShowIds = CVarBFProjectileDebugIds.GetValueOnAnyThread() > 0;

				const FColor DebugColor = bHit ? FColor::Red : FColor::Green;
				DrawDebugLine(World, Start, End, DebugColor, false, DebugDuration);
				DrawDebugPoint(World, End, 8.0f, DebugColor, false, DebugDuration);
				if (bShowIds)
				{
					DrawDebugString(World, End, FString::Printf(TEXT("%d"), Projectile.Id), nullptr, DebugColor, DebugDuration);
				}
			}
#endif

			if (bHit)
			{
				FBFProjectileImpactInfo& ImpactInfo = PendingImpacts.AddDefaulted_GetRef();
				ImpactInfo.HitResult = HitResult;
				ImpactInfo.SlotIndex = Index;
				ImpactInfo.bHitType = true;
				ReleaseProjectileSlot(Index);
			}
			else
			{
				Projectile.Position = End;
				if (ensureMsgf(TrailsWriteCount < 1024, TEXT("Trail cache overflow")))
				{
					TrailsCacheId[TrailsWriteCount] = Projectile.Id;
					TrailsCachePosition[TrailsWriteCount] = End;
					++TrailsWriteCount;
				}
			}
		}
	}

	{
		SCOPE_CYCLE_COUNTER(STAT_ProjectileSubsystem_Trails);
		const FNiagaraDataChannelSearchParameters SearchParameters;
		if (UNiagaraDataChannelWriter* Writer = UNiagaraDataChannelLibrary::WriteToNiagaraDataChannel(this, TrailDataChannel, SearchParameters, TrailsWriteCount, false, true, true, TEXT("TrailSnapshots")))
		{
			for (int32 Index = 0; Index < TrailsWriteCount; ++Index)
			{
				Writer->WritePosition(PositionParam, Index, TrailsCachePosition[Index]);
				Writer->WriteInt(IDParam, Index, TrailsCacheId[Index]);
			}
		}
	}

	ProcessPendingImpacts();
}

bool UBFProjectileSubsystem::ShouldCreateSubsystem(UObject* Outer) const
{
	return true;
}

int32 UBFProjectileSubsystem::SpawnProjectile(const FBFProjectileSpawnParams& SpawnParams)
{
	if (FreeList.Num() == 0)
	{
		UE_LOG(LogBackyardForge, Warning, TEXT("UBFNativeProjectileSubsystem: projectile pool exhausted (MaxProjectiles=%d)."), MaxProjectiles);
		return INDEX_NONE;
	}

	const int32 Slot = FreeList.Pop(EAllowShrinking::No);

	FProjectileSlot& Projectile = ProjectilePool[Slot];
	Projectile.Position = SpawnParams.Position;
	Projectile.Velocity = SpawnParams.Velocity;
	Projectile.Drag = SpawnParams.DragType;
	Projectile.Lifetime = SpawnParams.Lifetime;
	Projectile.Age = 0.0f;
	Projectile.Id = NextProjectileId++;
	Projectile.bAlive = 1;

	FProjectileColdData& ColdData = ProjectileColdDataPool[Slot];
	ColdData.Instigator = SpawnParams.Instigator;
	ColdData.Causer = SpawnParams.Causer;
	ColdData.StartLocation = SpawnParams.Position;
	ColdData.DamageRamp = SpawnParams.DamageRamp;
	ColdData.DistanceRamp = SpawnParams.DistanceRamp;

	TraceParamsCache[Slot].ClearIgnoredSourceObjects();
	TraceParamsCache[Slot].AddIgnoredActor(SpawnParams.Causer.Get());

	IdToSlot.Add(Projectile.Id, Slot);

	return Projectile.Id;
}

bool UBFProjectileSubsystem::KillProjectile(const int32 ProjectileId)
{
	if (const int32* SlotPtr = IdToSlot.Find(ProjectileId))
	{
		ReleaseProjectileSlot(*SlotPtr);
		return true;
	}
	return false;
}

void UBFProjectileSubsystem::ClearProjectiles()
{
	for (int32 Index = 0; Index < ProjectilePool.Num(); ++Index)
	{
		if (ProjectilePool[Index].bAlive)
		{
			ReleaseProjectileSlot(Index);
		}
	}
}

void UBFProjectileSubsystem::SetTraceChannel(ECollisionChannel InChannel)
{
	TraceChannel = InChannel;
}

void UBFProjectileSubsystem::SetTrailDataChannel(UNiagaraDataChannelAsset* InChannel)
{
	TrailDataChannel = InChannel;
}

void UBFProjectileSubsystem::SetImpactDataChannel(UNiagaraDataChannelAsset* InChannel)
{
	ImpactDataChannel = InChannel;
}

void UBFProjectileSubsystem::SetMaxProjectiles(int32 InMaxProjectiles)
{
	if (InMaxProjectiles <= 0)
	{
		return;
	}

	MaxProjectiles = InMaxProjectiles;
	ProjectilePool.SetNum(MaxProjectiles);
	ProjectileColdDataPool.SetNum(MaxProjectiles);
	TraceParamsCache.SetNum(MaxProjectiles);
	FreeList.Reset();
	IdToSlot.Reset();
	NextProjectileId = 1;

	FreeList.Reserve(MaxProjectiles);

	FCollisionQueryParams TraceParams(SCENE_QUERY_STAT(BFProjectileTrace), false);
	TraceParams.bTraceComplex = false;
	TraceParams.bReturnPhysicalMaterial = false;

	for (int32 Index = 0; Index < MaxProjectiles; ++Index)
	{
		ProjectilePool[Index] = FProjectileSlot();
		ProjectileColdDataPool[Index] = FProjectileColdData();
		TraceParamsCache[Index] = TraceParams;
		FreeList.Add(Index);
	}

	PendingImpacts.Reset();
	PendingImpacts.Reserve(MaxProjectiles);
}

void UBFProjectileSubsystem::SetDamageType(TSubclassOf<UDamageType> InDamageType)
{
	if (InDamageType)
	{
		DamageTypeClass = InDamageType;
	}
	else
	{
		DamageTypeClass = UDamageType::StaticClass();
	}
}

void UBFProjectileSubsystem::ProcessPendingImpacts()
{
	SCOPE_CYCLE_COUNTER(STAT_ProjectileSubsystem_Impacts)

	UNiagaraDataChannelWriter* Writer = nullptr;

	if (ImpactDataChannel && PendingImpacts.Num() > 0)
	{
		const FNiagaraDataChannelSearchParameters SearchParameters;
		Writer = UNiagaraDataChannelLibrary::WriteToNiagaraDataChannel(this, ImpactDataChannel, SearchParameters, PendingImpacts.Num(), false, true, true, TEXT("ImpactDataChannel"));
	}

	for (int32 Index = 0; Index < PendingImpacts.Num(); ++Index)
	{
		const FBFProjectileImpactInfo& Impact = PendingImpacts[Index];

		auto& Projectile = ProjectilePool[Impact.SlotIndex];
		auto& ColdData = ProjectileColdDataPool[Impact.SlotIndex];

		const float Distance = FVector::DistXY(Projectile.Position, ColdData.StartLocation);
		const float Damage = FMath::GetMappedRangeValueClamped(ColdData.DistanceRamp, ColdData.DamageRamp, Distance);

		if (AActor* HitActor = Impact.HitResult.GetActor())
		{
			UGameplayStatics::ApplyPointDamage(
				HitActor,
				Damage,
				Projectile.Velocity.GetSafeNormal(),
				Impact.HitResult,
				ColdData.Instigator.Get(),
				ColdData.Causer.Get(),
				DamageTypeClass ? DamageTypeClass.Get() : UDamageType::StaticClass());
		}

		OnImpact.Broadcast(Impact);

		if (Writer)
		{
			Writer->WritePosition(PositionParam, Index, Projectile.Position);
			Writer->WriteVector(NormalParam, Index, Impact.HitResult.Normal);
			Writer->WriteInt(HitTypeParam, Index, Impact.bHitType);
		}
	}

	PendingImpacts.Reset();
}

void UBFProjectileSubsystem::ReleaseProjectileSlot(const int32 SlotIndex)
{
	FProjectileSlot& Projectile = ProjectilePool[SlotIndex];
	if (!Projectile.bAlive)
	{
		return;
	}

	Projectile.bAlive = false;
	IdToSlot.Remove(Projectile.Id);
	FreeList.Add(SlotIndex);
}
