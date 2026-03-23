#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "BSInputLibrary.generated.h"

class UEnhancedInputComponent;
class UInputAction;

UCLASS()
class BACKYARDFORGE_API UBSInputLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintCallable, Category = "Input")
	static void BindSimpleAction(UEnhancedInputComponent* InputComponent, UInputAction* Action, ETriggerEvent TriggerEvent, UObject* Object, FName FunctionName);
};
