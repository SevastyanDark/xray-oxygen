#pragma once
#include "ScriptCompiler.h"

using namespace System;
using namespace System::Collections::Generic;

// Create and manage DotNet code
public ref class SpectreEngine
{
public:

	SpectreEngine();

	static SpectreEngine^ Instance();
	static void xrCoreInit(String^ appName);
	static void xrEngineInit();
	static void xrRenderInit();
	static void GameLibInit();
	void CompileScripts();
private:

	xrScriptCompiler^ ScriptCompiler;

	List<Object^>^ ModInstances;

	static SpectreEngine^ gInstance;
};