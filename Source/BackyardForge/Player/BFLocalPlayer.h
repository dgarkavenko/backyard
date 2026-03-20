// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "CommonLocalPlayer.h"
#include "BFLocalPlayer.generated.h"

/**
 *  Project local player — extends CommonLocalPlayer for ForgeryUI integration.
 */
UCLASS()
class BACKYARDFORGE_API UBFLocalPlayer : public UCommonLocalPlayer
{
	GENERATED_BODY()
};
