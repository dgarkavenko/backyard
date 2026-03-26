#pragma once

#include "CoreMinimal.h"
#include "BFProjectileSubsystem.generated.h"

class UNiagaraDataChannelAsset;
class AController;
class UDamageType;

UENUM(BlueprintType)
enum EBFProjectileDrag : uint8
{
	None,
	VeryLow,
	Low,
	Average,
	COUNT UMETA(Hidden),
};

USTRUCT(BlueprintType)
struct FBFProjectileSpawnParams
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FVector Position = FVector::ZeroVector;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FVector Velocity = FVector::ZeroVector;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TEnumAsByte<EBFProjectileDrag> DragType = EBFProjectileDrag::Average;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FVector2D DamageRamp = FVector2D::ZeroVector;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FVector2D DistanceRamp = FVector2D::ZeroVector;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, meta = (ClampMin = 0.1, Units = "s"))
	float Lifetime = 6.0f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TWeakObjectPtr<AController> Instigator;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TWeakObjectPtr<AActor> Causer;
};

USTRUCT(BlueprintType)
struct FBFProjectileImpactInfo
{
	GENERATED_BODY()

	int32 SlotIndex;

	UPROPERTY(BlueprintReadOnly)
	FHitResult HitResult;

	UPROPERTY(BlueprintReadOnly)
	bool bHitType = false;
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FBFProjectileImpactSignature, const FBFProjectileImpactInfo&, Impact);

// Pool-based projectile subsystem. Simulates up to MaxProjectiles with per-frame line traces,
// drag, gravity, distance-based damage ramps, and Niagara data channel integration for trails/impacts.
//
// Debug CVars (editor only, ECVF_Cheat):
//   bf.Projectile.DebugDraw     (int32)  — trajectory lines: green = miss, red = hit
//   bf.Projectile.DebugDuration (float)  — draw duration in seconds (default 0.1)
//   bf.Projectile.DebugIds      (int32)  — show projectile ID labels
//
// Profiling — `stat Projectiles`:
//   Tick, Prep (drag LUT), Solve (physics + traces),
//   Impacts (damage + Niagara), Trails (Niagara), Editor (debug draw)
UCLASS()
class BACKYARDFORGE_API UBFProjectileSubsystem : public UTickableWorldSubsystem
{
	GENERATED_BODY()

public:
	virtual TStatId GetStatId() const override
	{
		RETURN_QUICK_DECLARE_CYCLE_STAT(UBFProjectileSubsystem, STATGROUP_Engine);
	}

protected:
	struct FProjectileSlot
	{
		FVector Position = FVector::ZeroVector;
		FVector Velocity = FVector::ZeroVector;
		float Lifetime = 6.0f;
		float Age = 0.0f;
		EBFProjectileDrag Drag = EBFProjectileDrag::Average;
		int32 Id = INDEX_NONE;
		uint8 bAlive = 0;
	};

	struct FProjectileColdData
	{
		TWeakObjectPtr<AController> Instigator;
		TWeakObjectPtr<AActor> Causer;
		FVector StartLocation;
		FVector2D DamageRamp = FVector2D(0, 0);
		FVector2D DistanceRamp = FVector2D(0, 0);
	};

public:

	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;
	virtual void Tick(float DeltaSeconds) override;
	virtual bool ShouldCreateSubsystem(UObject* Outer) const override;

	UFUNCTION(ScriptCallable)
	int32 SpawnProjectile(const FBFProjectileSpawnParams& SpawnParams);

	UFUNCTION(ScriptCallable)
	bool KillProjectile(int32 ProjectileId);

	UFUNCTION(ScriptCallable)
	void ClearProjectiles();

	UFUNCTION(ScriptCallable)
	void SetTraceChannel(ECollisionChannel InChannel);

	UFUNCTION(ScriptCallable)
	void SetTrailDataChannel(UNiagaraDataChannelAsset* InChannel);

	UFUNCTION(ScriptCallable)
	void SetImpactDataChannel(UNiagaraDataChannelAsset* InChannel);

	UFUNCTION(ScriptCallable)
	void SetMaxProjectiles(int32 InMaxProjectiles);

	UFUNCTION(ScriptCallable)
	void SetDamageType(TSubclassOf<UDamageType> InDamageType);

protected:
	void ProcessPendingImpacts();
	void ReleaseProjectileSlot(int32 SlotIndex);

public:
	UPROPERTY(BlueprintAssignable, Category = "Projectile")
	FBFProjectileImpactSignature OnImpact;

	UPROPERTY(EditAnywhere, ScriptReadWrite, Category = "Projectile")
	FVector Gravity = FVector(0.0f, 0.0f, -980.0f);

	UPROPERTY(EditAnywhere, ScriptReadWrite, Category = "Projectile")
	TEnumAsByte<ECollisionChannel> TraceChannel = ECC_WorldDynamic;

	UPROPERTY(EditAnywhere, ScriptReadWrite, Category = "Projectile")
	UNiagaraDataChannelAsset* TrailDataChannel = nullptr;

	UPROPERTY(EditAnywhere, ScriptReadWrite, Category = "Projectile")
	UNiagaraDataChannelAsset* ImpactDataChannel = nullptr;

	UPROPERTY(EditAnywhere, ScriptReadWrite, Category = "Projectile")
	int32 MaxProjectiles = 1024;

	UPROPERTY(EditAnywhere, ScriptReadWrite, Category = "Projectile")
	TSubclassOf<UDamageType> DamageTypeClass;

private:
	TArray<FProjectileSlot> ProjectilePool;
	TArray<FProjectileColdData> ProjectileColdDataPool;

	TArray<int32> FreeList;
	TMap<int32, int32> IdToSlot;

	TStaticArray<int32, 1024> TrailsCacheId;
	TStaticArray<FVector, 1024> TrailsCachePosition;

	TArray<FBFProjectileImpactInfo> PendingImpacts;

	TArray<FCollisionQueryParams> TraceParamsCache;
	int32 NextProjectileId = 1;
	float DynamicDragLUT[EBFProjectileDrag::COUNT]{1, 0, 0, 0};
};
