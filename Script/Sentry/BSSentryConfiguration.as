namespace Sentry
{
	const FName ChildSocketName = n"s_child_01";
	const FName VisorSocketName = n"s_visor";
	const FName MagazineSocketName = n"s_magazine";
	const FName MuzzleSocketName = n"s_muzzle";
	const FName AssemblyRoleBaseTag = n"Base";
	const FName AssemblyRoleYawTag = n"Yaw";
	const FName AssemblyRolePitchTag = n"Pitch";
	const FName AssemblyRoleMuzzleTag = n"Muzzle";
	const FLinearColor VisorSweepLightColor = FLinearColor(1.00f, 0.31f, 0.07f);
	const FLinearColor VisorActiveLightColor = FLinearColor(1.0f, 0.0f, 0.0f);
}

struct FBSModuleAssemblyElement
{
	UPROPERTY(EditAnywhere)
	FName ElementId;

	UPROPERTY(EditAnywhere)
	UStaticMesh Mesh;

	UPROPERTY(EditAnywhere)
	TArray<FName> Tags;

	UPROPERTY(EditAnywhere)
	FName Socket;

	UPROPERTY(EditAnywhere)
	FVector Offset;

	UPROPERTY(EditAnywhere)
	FRotator Rotation;

	UPROPERTY(EditAnywhere)
	FName ParentElementId;
}

struct FBSChassisRotatorSpec
{
	UPROPERTY(EditAnywhere)
	FName ElementId;

	UPROPERTY(EditAnywhere)
	FBSSentryConstraint Constraint;
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
