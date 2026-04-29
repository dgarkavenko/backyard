#pragma once

#include "CoreMinimal.h"
#include "PCGSettings.h"

#include "BFCornFieldGenerator.generated.h"

UCLASS(BlueprintType, ClassGroup = (Procedural))
class BACKYARDFORGE_API UBFCornFieldGeneratorSettings : public UPCGSettings
{
	GENERATED_BODY()

public:
#if WITH_EDITOR
	virtual FName GetDefaultNodeName() const override { return FName(TEXT("BFCornFieldGenerator")); }
	virtual FText GetDefaultNodeTitle() const override { return NSLOCTEXT("BFCornFieldGenerator", "NodeTitle", "Corn Field Generator"); }
	virtual FText GetNodeTooltipText() const override { return NSLOCTEXT("BFCornFieldGenerator", "NodeTooltip", "Generate straight corn rows from a closed spline field boundary."); }
	virtual EPCGSettingsType GetType() const override { return EPCGSettingsType::Spatial; }
#endif

	virtual bool UseSeed() const override { return true; }

protected:
	virtual TArray<FPCGPinProperties> InputPinProperties() const override;
	virtual TArray<FPCGPinProperties> OutputPinProperties() const override;
	virtual FPCGElementPtr CreateElement() const override;
};

class FBFCornFieldGeneratorElement : public IPCGElement
{
public:
	virtual bool CanExecuteOnlyOnMainThread(FPCGContext* Context) const override { return true; }
	virtual bool IsCacheable(const UPCGSettings* InSettings) const override { return false; }

protected:
	virtual bool ExecuteInternal(FPCGContext* Context) const override;
};
