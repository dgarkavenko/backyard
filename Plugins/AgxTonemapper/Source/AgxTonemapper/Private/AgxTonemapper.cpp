#include "AgxTonemapper.h"

#include "AgxTonemapperSettings.h"
#include "HAL/PlatformFileManager.h"
#include "Interfaces/IPluginManager.h"
#include "Misc/CommandLine.h"
#include "Misc/ConfigCacheIni.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "ShaderCore.h"

DEFINE_LOG_CATEGORY(LogAgxTonemapper);

namespace
{
	const TCHAR* const ShaderOverridePlatformFileName = TEXT("AgxShaderOverride");

	class FAgxShaderOverridePlatformFile : public IPlatformFile
	{
	public:
		using IPlatformFile::IterateDirectory;
		using IPlatformFile::IterateDirectoryRecursively;
		using IPlatformFile::IterateDirectoryStat;
		using IPlatformFile::IterateDirectoryStatRecursively;

		FAgxShaderOverridePlatformFile(const FString& InTargetShaderPath, const FString& InOverrideShaderPath)
			: LowerLevel(nullptr)
			, TargetShaderPath(InTargetShaderPath)
			, OverrideShaderPath(InOverrideShaderPath)
		{
		}

		virtual bool Initialize(IPlatformFile* Inner, const TCHAR* CmdLine) override
		{
			LowerLevel = Inner;
			return LowerLevel != nullptr;
		}

		virtual IPlatformFile* GetLowerLevel() override
		{
			return LowerLevel;
		}

		virtual void SetLowerLevel(IPlatformFile* NewLowerLevel) override
		{
			LowerLevel = NewLowerLevel;
		}

		virtual const TCHAR* GetName() const override
		{
			return ShaderOverridePlatformFileName;
		}

		virtual bool FileExists(const TCHAR* Filename) override
		{
			return LowerLevel->FileExists(*ResolveReadPath(Filename));
		}

		virtual int64 FileSize(const TCHAR* Filename) override
		{
			return LowerLevel->FileSize(*ResolveReadPath(Filename));
		}

		virtual bool DeleteFile(const TCHAR* Filename) override
		{
			return LowerLevel->DeleteFile(Filename);
		}

		virtual bool IsReadOnly(const TCHAR* Filename) override
		{
			return LowerLevel->IsReadOnly(*ResolveReadPath(Filename));
		}

		virtual bool MoveFile(const TCHAR* To, const TCHAR* From) override
		{
			return LowerLevel->MoveFile(To, From);
		}

		virtual bool SetReadOnly(const TCHAR* Filename, bool bNewReadOnlyValue) override
		{
			return LowerLevel->SetReadOnly(Filename, bNewReadOnlyValue);
		}

		virtual FDateTime GetTimeStamp(const TCHAR* Filename) override
		{
			return LowerLevel->GetTimeStamp(*ResolveReadPath(Filename));
		}

		virtual void SetTimeStamp(const TCHAR* Filename, FDateTime DateTime) override
		{
			LowerLevel->SetTimeStamp(Filename, DateTime);
		}

		virtual FDateTime GetAccessTimeStamp(const TCHAR* Filename) override
		{
			return LowerLevel->GetAccessTimeStamp(*ResolveReadPath(Filename));
		}

		virtual FString GetFilenameOnDisk(const TCHAR* Filename) override
		{
			return LowerLevel->GetFilenameOnDisk(*ResolveReadPath(Filename));
		}

		virtual IFileHandle* OpenRead(const TCHAR* Filename, bool bAllowWrite) override
		{
			return LowerLevel->OpenRead(*ResolveReadPath(Filename), bAllowWrite);
		}

		virtual IFileHandle* OpenWrite(const TCHAR* Filename, bool bAppend, bool bAllowRead) override
		{
			return LowerLevel->OpenWrite(Filename, bAppend, bAllowRead);
		}

		virtual bool DirectoryExists(const TCHAR* Directory) override
		{
			return LowerLevel->DirectoryExists(Directory);
		}

		virtual bool CreateDirectory(const TCHAR* Directory) override
		{
			return LowerLevel->CreateDirectory(Directory);
		}

		virtual bool DeleteDirectory(const TCHAR* Directory) override
		{
			return LowerLevel->DeleteDirectory(Directory);
		}

		virtual FFileStatData GetStatData(const TCHAR* FilenameOrDirectory) override
		{
			return LowerLevel->GetStatData(*ResolveReadPath(FilenameOrDirectory));
		}

		virtual bool IterateDirectory(const TCHAR* Directory, FDirectoryVisitor& Visitor) override
		{
			return LowerLevel->IterateDirectory(Directory, Visitor);
		}

		virtual bool IterateDirectoryStat(const TCHAR* Directory, FDirectoryStatVisitor& Visitor) override
		{
			return LowerLevel->IterateDirectoryStat(Directory, Visitor);
		}

	private:
		IPlatformFile* LowerLevel;
		FString TargetShaderPath;
		FString OverrideShaderPath;

		FString ResolveReadPath(const TCHAR* Filename) const
		{
			FString NormalizedFilename = FPaths::ConvertRelativePathToFull(Filename);
			FPaths::NormalizeFilename(NormalizedFilename);

			if (FCString::Stricmp(*NormalizedFilename, *TargetShaderPath) == 0)
			{
				return OverrideShaderPath;
			}

			return Filename;
		}
	};

	FString NormalizeFullPath(const FString& InPath)
	{
		FString NormalizedPath = FPaths::ConvertRelativePathToFull(InPath);
		FPaths::NormalizeFilename(NormalizedPath);
		return NormalizedPath;
	}

	FString GetTonemapperModeName(EAgxTonemapperMode Mode)
	{
		switch (Mode)
		{
		case EAgxTonemapperMode::Stock:
			return TEXT("Stock");
		case EAgxTonemapperMode::Agx:
			return TEXT("Agx");
		case EAgxTonemapperMode::AgxPunchy:
			return TEXT("AgxPunchy");
		case EAgxTonemapperMode::Reinhard:
			return TEXT("Reinhard");
		default:
			return TEXT("Stock");
		}
	}

	EAgxTonemapperMode GetConfiguredTonemapperMode()
	{
		FString ConfiguredMode;
		if (GConfig != nullptr && GConfig->GetString(TEXT("/Script/AgxTonemapper.AgxTonemapperSettings"), TEXT("TonemapperMode"), ConfiguredMode, GEngineIni))
		{
			if (ConfiguredMode == TEXT("EAgxTonemapperMode::Agx") || ConfiguredMode == TEXT("Agx"))
			{
				return EAgxTonemapperMode::Agx;
			}
			if (ConfiguredMode == TEXT("EAgxTonemapperMode::AgxPunchy") || ConfiguredMode == TEXT("AgxPunchy"))
			{
				return EAgxTonemapperMode::AgxPunchy;
			}
			if (ConfiguredMode == TEXT("EAgxTonemapperMode::Reinhard") || ConfiguredMode == TEXT("Reinhard"))
			{
				return EAgxTonemapperMode::Reinhard;
			}
		}

		return EAgxTonemapperMode::Stock;
	}

	int32 GetCustomTonemapModeValue(EAgxTonemapperMode Mode)
	{
		switch (Mode)
		{
		case EAgxTonemapperMode::Agx:
		case EAgxTonemapperMode::AgxPunchy:
			return 1;
		case EAgxTonemapperMode::Reinhard:
			return 2;
		case EAgxTonemapperMode::Stock:
		default:
			return 0;
		}
	}

	int32 GetAgxLookValue(EAgxTonemapperMode Mode)
	{
		switch (Mode)
		{
		case EAgxTonemapperMode::Agx:
			return 0;
		case EAgxTonemapperMode::AgxPunchy:
			return 2;
		default:
			return 0;
		}
	}

	bool BuildModeSpecificOverrideShader(const FString& SourceShaderPath, const FString& DestinationShaderPath, EAgxTonemapperMode Mode)
	{
		FString ShaderSource;
		if (!FFileHelper::LoadFileToString(ShaderSource, *SourceShaderPath))
		{
			return false;
		}

		const int32 CustomTonemapMode = GetCustomTonemapModeValue(Mode);
		const int32 AgxLook = GetAgxLookValue(Mode);

		ShaderSource.ReplaceInline(
			TEXT("#define CUSTOM_TONEMAP_MODE 1  // Change this to switch tonemappers"),
			*FString::Printf(TEXT("#define CUSTOM_TONEMAP_MODE %d  // Generated by AgxTonemapper plugin"), CustomTonemapMode),
			ESearchCase::CaseSensitive);

		ShaderSource.ReplaceInline(
			TEXT("#define AGX_LOOK 2"),
			*FString::Printf(TEXT("#define AGX_LOOK %d"), AgxLook),
			ESearchCase::CaseSensitive);

		ShaderSource.ReplaceInline(
			TEXT("#include \"TonemapCommon.ush\""),
			TEXT("#include \"TonemapCommon.ush\"\n#include \"/Plugin/AgxTonemapper/Private/AgxTonemapperCommon.ush\""),
			ESearchCase::CaseSensitive);

		return FFileHelper::SaveStringToFile(ShaderSource, *DestinationShaderPath);
	}
}

void FAgxTonemapperModule::StartupModule()
{
	InstallShaderOverride();
}

void FAgxTonemapperModule::ShutdownModule()
{
	RemoveShaderOverride();
}

void FAgxTonemapperModule::InstallShaderOverride()
{
	const EAgxTonemapperMode Mode = GetConfiguredTonemapperMode();
	if (Mode == EAgxTonemapperMode::Stock)
	{
		UE_LOG(LogAgxTonemapper, Log, TEXT("AgX tonemapper is in Stock mode."));
		return;
	}

	TSharedPtr<IPlugin> Plugin = IPluginManager::Get().FindPlugin(TEXT("AgxTonemapper"));
	if (!Plugin.IsValid())
	{
		UE_LOG(LogAgxTonemapper, Error, TEXT("Failed to locate AgxTonemapper plugin."));
		return;
	}

	const FString PluginBaseDir = Plugin->GetBaseDir();
	const FString ShaderDir = NormalizeFullPath(FPaths::Combine(PluginBaseDir, TEXT("Shaders")));
	const FString HiddenEmpireShaderPath = NormalizeFullPath(FPaths::Combine(ShaderDir, TEXT("HiddenEmpire/PostProcessCombineLUTs_5.7.usf")));
	const FString OverrideShaderPath = NormalizeFullPath(FPaths::Combine(ShaderDir, TEXT("Overrides/PostProcessCombineLUTs.usf")));
	const FString TargetShaderPath = NormalizeFullPath(FPaths::Combine(FPaths::EngineDir(), TEXT("Shaders/Private/PostProcessCombineLUTs.usf")));

	IPlatformFile& PlatformFile = FPlatformFileManager::Get().GetPlatformFile();
	if (!PlatformFile.FileExists(*HiddenEmpireShaderPath))
	{
		UE_LOG(LogAgxTonemapper, Error, TEXT("Missing HiddenEmpire 5.7 shader: %s"), *HiddenEmpireShaderPath);
		return;
	}

	if (!BuildModeSpecificOverrideShader(HiddenEmpireShaderPath, OverrideShaderPath, Mode))
	{
		UE_LOG(LogAgxTonemapper, Error, TEXT("Failed to build generated override shader for mode %s."), *GetTonemapperModeName(Mode));
		return;
	}

	PlatformFileOverride = new FAgxShaderOverridePlatformFile(TargetShaderPath, OverrideShaderPath);
	if (!PlatformFileOverride->Initialize(&PlatformFile, FCommandLine::Get()))
	{
		UE_LOG(LogAgxTonemapper, Error, TEXT("Failed to initialize AgX shader override platform file."));
		delete PlatformFileOverride;
		PlatformFileOverride = nullptr;
		return;
	}

	if (!FPlatformFileManager::Get().InsertPlatformFile(PlatformFileOverride))
	{
		UE_LOG(LogAgxTonemapper, Error, TEXT("Failed to insert AgX shader override platform file."));
		delete PlatformFileOverride;
		PlatformFileOverride = nullptr;
		return;
	}

	AddShaderSourceDirectoryMapping(TEXT("/Plugin/AgxTonemapper"), ShaderDir);

	UE_LOG(LogAgxTonemapper, Log, TEXT("AgX tonemapper override active in mode %s: %s"), *GetTonemapperModeName(Mode), *OverrideShaderPath);
}

void FAgxTonemapperModule::RemoveShaderOverride()
{
	if (PlatformFileOverride == nullptr)
	{
		return;
	}

	FPlatformFileManager::Get().RemovePlatformFile(PlatformFileOverride);
	delete PlatformFileOverride;
	PlatformFileOverride = nullptr;
}

IMPLEMENT_MODULE(FAgxTonemapperModule, AgxTonemapper)
