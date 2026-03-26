#include "BackyardForgeEditor.h"
#include "BFComponentSelectorCustomization.h"
#include "Modules/ModuleManager.h"
#include "PropertyEditorModule.h"

DEFINE_LOG_CATEGORY(LogBackyardForgeEditor);

void FBackyardForgeEditorModule::StartupModule()
{
	FPropertyEditorModule& PropertyEditorModule = FModuleManager::GetModuleChecked<FPropertyEditorModule>("PropertyEditor");

	PropertyEditorModule.RegisterCustomPropertyTypeLayout(
		"BFComponentSelector",
		FOnGetPropertyTypeCustomizationInstance::CreateStatic(&FBFComponentSelectorCustomization::MakeInstance));
}

void FBackyardForgeEditorModule::ShutdownModule()
{
	if (FModuleManager::Get().IsModuleLoaded("PropertyEditor"))
	{
		FPropertyEditorModule& PropertyEditorModule = FModuleManager::GetModuleChecked<FPropertyEditorModule>("PropertyEditor");
		PropertyEditorModule.UnregisterCustomPropertyTypeLayout("BFComponentSelector");
	}
}

IMPLEMENT_MODULE(FBackyardForgeEditorModule, BackyardForgeEditor)
