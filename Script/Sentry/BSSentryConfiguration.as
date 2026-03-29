namespace Sentry
{
	const FName ChildSocketName = n"s_child_01";
	const FName VisorSocketName = n"s_visor";
	const FName MagazineSocketName = n"s_magazine";
	const FName MuzzleSocketName = n"s_muzzle";
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
