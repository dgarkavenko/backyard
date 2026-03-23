#include "BSInputLibrary.h"

#include "BackyardForge.h"
#include "EnhancedInputComponent.h"
#include "InputAction.h"

void UBSInputLibrary::BindSimpleAction(UEnhancedInputComponent* InputComponent, UInputAction* Action, ETriggerEvent TriggerEvent, UObject* Object, FName FunctionName)
{
	if (!InputComponent || !Action || !Object)
	{
		return;
	}

	UFunction* Func = Object->FindFunction(FunctionName);
	if (!Func)
	{
		UE_LOG(LogBackyardForge, Warning, TEXT("BindSimpleAction: Function '%s' not found on %s"), *FunctionName.ToString(), *Object->GetName());
		return;
	}

	InputComponent->BindActionInstanceLambda(Action, TriggerEvent,
		[WeakObj = TWeakObjectPtr<UObject>(Object), FunctionName](const FInputActionInstance&)
		{
			if (UObject* Obj = WeakObj.Get())
			{
				if (UFunction* F = Obj->FindFunction(FunctionName))
				{
					Obj->ProcessEvent(F, nullptr);
				}
			}
		});
}
