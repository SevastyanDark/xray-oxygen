#pragma once
#include <cstdlib>

/// #DARK: rename this.
struct xrProfilerEntry
{
	xr_string functionName;
	std::chrono::steady_clock::time_point beginTime;
	std::vector<xrProfilerEntry> childs;
	std::chrono::steady_clock::time_point endTime;
	std::chrono::nanoseconds elapsedTime;
};

typedef struct
{
private:
	xrProfilerEntry _callstack;
public:
	void beginFunction(xr_string funName, DWORD threadId)
	{
		if (_callstack.childs.empty())
		{
			_callstack.functionName = funName;
			_callstack.beginTime = std::chrono::steady_clock::now();
			return;
		}
		_callstack.childs.push_back({ funName, std::chrono::steady_clock::now() });
	}
	void endFunction()
	{
		if (_callstack.childs.empty())
		{
			_callstack.endTime = std::chrono::steady_clock::now();
			_callstack.elapsedTime = std::chrono::duration_cast<std::chrono::nanoseconds>(_callstack.beginTime - _callstack.endTime);
		}
		_callstack.childs.back().endTime = std::chrono::steady_clock::now();
		_callstack.childs.back().elapsedTime = std::chrono::duration_cast<std::chrono::nanoseconds>(_callstack.childs.back().beginTime - _callstack.childs.back().endTime);
	}

} xrProfiler;

extern xrProfiler Profiler;

// Use this at beginning and end of the function
// you want to profile

#define PROFILER_BEGIN() Profiler.beginFunction(__FUNCTION__, GetCurrentThreadId());
#define PROFILER_BEGIN(x) Profiler.beginFunction(x);

#define PROFLLER_END() Profiler.endFunction();