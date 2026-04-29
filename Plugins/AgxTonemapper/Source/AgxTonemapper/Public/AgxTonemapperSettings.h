#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "AgxTonemapperSettings.generated.h"

UENUM()
enum class EAgxTonemapperMode : uint8
{
	Stock UMETA(DisplayName = "Stock"),
	Agx UMETA(DisplayName = "AgX"),
	AgxPunchy UMETA(DisplayName = "AgX (Punchy)"),
	Reinhard UMETA(DisplayName = "Reinhard")
};

UCLASS(Config = Engine, DefaultConfig, meta = (DisplayName = "AgX Tonemapper"))
class AGXTONEMAPPER_API UAgxTonemapperSettings : public UDeveloperSettings
{
	GENERATED_BODY()

public:
	UPROPERTY(EditAnywhere, Config, Category = "Tonemapper")
	EAgxTonemapperMode TonemapperMode = EAgxTonemapperMode::Stock;

#if WITH_EDITOR
	virtual FName GetCategoryName() const override
	{
		return TEXT("Plugins");
	}
#endif
};
