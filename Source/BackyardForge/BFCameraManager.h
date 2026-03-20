// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "Camera/PlayerCameraManager.h"
#include "BFCameraManager.generated.h"

/**
 *  Basic First Person camera manager.
 *  Limits min/max look pitch.
 */
UCLASS()
class ABFCameraManager : public APlayerCameraManager
{
	GENERATED_BODY()

public:

	/** Constructor */
	ABFCameraManager();
};
