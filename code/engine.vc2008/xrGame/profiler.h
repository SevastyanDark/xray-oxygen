#pragma once

struct xrProfiler
{
	void startFunction(xr_string funcName) 
	{
		
	};
	void endFunction() {};
};


#define START_PROFILE(a) Profiler.startFunction(a);
#define STOP_PROFILE	 Profiler.endFunction();
