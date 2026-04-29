#pragma once

#include "CoreMinimal.h"
#include "Modules/ModuleInterface.h"

DECLARE_LOG_CATEGORY_EXTERN(LogAgxTonemapper, Log, All);

class FAgxTonemapperModule : public IModuleInterface
{
public:
	virtual void StartupModule() override;
	virtual void ShutdownModule() override;

private:
	class IPlatformFile* PlatformFileOverride = nullptr;

	void InstallShaderOverride();
	void RemoveShaderOverride();
};
