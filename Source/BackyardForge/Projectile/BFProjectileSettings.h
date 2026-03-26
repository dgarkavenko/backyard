#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "BFProjectileSettings.generated.h"

class UNiagaraDataChannelAsset;

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "BF Projectile"))
class BACKYARDFORGE_API UBFProjectileSettings : public UDeveloperSettings
{
	GENERATED_BODY()

public:

	UPROPERTY(EditAnywhere, Config, BlueprintReadOnly, Category = "DataChannels")
	TSoftObjectPtr<UNiagaraDataChannelAsset> TrailDataChannel;

	UPROPERTY(EditAnywhere, Config, BlueprintReadOnly, Category = "DataChannels")
	TSoftObjectPtr<UNiagaraDataChannelAsset> ImpactDataChannel;

	UPROPERTY(EditAnywhere, Config, BlueprintReadOnly, Category = "DataChannels")
	TSoftObjectPtr<UNiagaraDataChannelAsset> GunshotDataChannel;
};
