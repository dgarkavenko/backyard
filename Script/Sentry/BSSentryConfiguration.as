namespace Sentry
{
	const FName ChildSocketName = n"s_child_01";
	const FName VisorSocketName = n"s_visor";
	const FName MagazineSocketName = n"s_magazine";
	const FName MuzzleSocketName = n"s_muzzle";
}

class UBSSentryArmConfiguration : UDataAsset
{
	UPROPERTY(EditAnywhere)
	FBSSentrySlot Rotator01;

	UPROPERTY(EditAnywhere)
	FBSSentrySlot Rotator02;

	UPROPERTY(EditAnywhere)
	UStaticMesh Platform;
}

struct FBSLoadoutElement
{
	UPROPERTY(EditAnywhere)
	UStaticMesh Mesh;

	UPROPERTY(EditAnywhere)
	FGameplayTag Tag;

	UPROPERTY(EditAnywhere)
	FName Socket;

	UPROPERTY(EditAnywhere)
	FVector Offset;

	UPROPERTY(EditAnywhere, meta = (ClampMin = "-1"))
	int ParentIndex = -1;
}

class UBSChassisConfiguration : UDataAsset
{
	UPROPERTY(EditAnywhere)
	UStaticMesh BaseMesh;

	UPROPERTY(EditAnywhere)
	UStaticMesh FrameMesh;

	UPROPERTY(EditAnywhere)
	UBSSentryArmConfiguration Arm;
}

class UBSSentryLoadout : UDataAsset
{
	UPROPERTY(EditAnywhere, meta=(ForceInlineRow, TitleProperty = "{ParentIndex}-{Socket}"))
	TArray<FBSLoadoutElement> Elements;
}

struct FBSSentryConstraint
{
	UPROPERTY(EditAnywhere)
	bool bYaw = false;

	UPROPERTY(EditAnywhere)
	bool bPitch = false;

	UPROPERTY(EditAnywhere)
	bool bRoll = false;

	UPROPERTY(EditAnywhere, meta = (ClampMin = "0", ClampMax = "720", Units = "Degrees"))
	float RotationSpeed = 90.0f;

	UPROPERTY(EditAnywhere, meta = (ClampMin = "0", ClampMax = "360", Units = "Degrees"))
	float RotationRange = 180.0f;
}

struct FBSSentrySlot
{
	UPROPERTY(EditAnywhere, Category = "Slot")
	UStaticMesh Mesh;

	UPROPERTY(EditAnywhere, Category = "Slot")
	FBSSentryConstraint Constraint;
}

UCLASS(DefaultToInstanced, EditInlineNew)
class UBSSentryConfiguration : UObject
{
	UPROPERTY(EditAnywhere)
	UBSChassisConfiguration Chassis;

	UPROPERTY(EditAnywhere)
	UBSSentryLoadout Loadout;
}
