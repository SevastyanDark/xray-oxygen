//Giperion August 2018
//[EUREKA] 3.6.1
// xrLC Redux, X-Ray Oxygen
// Class modified from Nvidia Buffer<T> (OptiX lib)

#pragma once

#include <vector>
#include "radeon_rays.h"
#include "RadeonRaysGlobalObjects.h"
#include "calc/buffer.h"

enum class DeviceBufferType
{
	CPU,
	OpenCL,
	CUDA
};
//------------------------------------------------------------------------------
//
// A simple abstraction for memory to be passed into Prime via BufferDescs
//
template<typename T>
class DeviceBuffer
{
public:
	DeviceBuffer(size_t count = 0, DeviceBufferType type = DeviceBufferType::CPU)
		: m_ptr(0),
		clBuffer(nullptr)
	{
		alloc(count, type);
	}

	// Allocate without changing type
	void alloc(size_t count)
	{
		alloc(count, m_type);
	}

	void alloc(size_t count, DeviceBufferType type)
	{
		if (m_ptr)
			free();

		m_type = type;
		m_count = count;
		if (m_count > 0)
		{
			if (m_type == DeviceBufferType::CPU)
			{
				m_ptr = new T[m_count];
			}
			else if (m_type == DeviceBufferType::CUDA)
			{
				CHK_CUDA(cudaGetDevice(&m_device));
				CHK_CUDA(cudaMalloc(&m_ptr, sizeInBytes()));
			}
			else if (m_type == DeviceBufferType::OpenCL)
			{
				R_ASSERT(gCalcDevice);
				clBuffer = gCalcDevice->CreateBuffer(sizeInBytes(), 0);
			}
			else
			{
				FATAL("Undefined Buffer::Type for Buffer");
			}
		}
	}

	void free()
	{
		if (m_ptr && m_type == DeviceBufferType::CPU)
		{
			delete[] m_ptr;
		}
		else if (m_type == DeviceBufferType::CUDA)
		{
			int oldDevice;
			CHK_CUDA(cudaGetDevice(&oldDevice));
			CHK_CUDA(cudaSetDevice(m_device));
			CHK_CUDA(cudaFree(m_ptr));
			CHK_CUDA(cudaSetDevice(oldDevice));
		}
		else if (m_type == DeviceBufferType::OpenCL)
		{
			if (clBuffer)
			{
				gCalcDevice->DeleteBuffer(clBuffer);
			}
		}
		else
		{
			FATAL("Undefined Buffer::Type for Buffer");
		}

		m_ptr = 0;
		m_count = 0;
	}

	~DeviceBuffer()
	{
		free();
	}

	size_t count()       const { return m_count; }
	size_t sizeInBytes() const { return m_count * sizeof(T); }
	const T* ptr()       const 
	{ 
		if (m_type == DeviceBufferType::OpenCL)
		{
			return reinterpret_cast<T*> (clBuffer.GetPtr());
		}
		
		return m_ptr;
	}
	T* ptr() 
	{ 
		if (m_type == DeviceBufferType::OpenCL)
		{
			return reinterpret_cast<T*> (clBuffer->GetPtr());
		}

		return m_ptr;
	}
	DeviceBufferType type() const { return m_type; }

	const T* hostPtr()
	{
		if (m_type == DeviceBufferType::CPU)
		{
			return m_ptr;
		}
		else if (m_type == DeviceBufferType::CUDA)
		{
			m_tempHost.resize(m_count);
			CHK_CUDA(cudaMemcpy(&m_tempHost[0], m_ptr, sizeInBytes(), cudaMemcpyDeviceToHost));
			return &m_tempHost[0];
		}
		else if (m_type == DeviceBufferType::OpenCL)
		{
			m_tempHost.resize(m_count);
			gCalcDevice->ReadBuffer(clBuffer, 0, 0, sizeInBytes(), m_tempHost.data(), nullptr);
			return &m_tempHost[0];
		}
		else
		{
			FATAL("Undefined Buffer::Type for Buffer");
		}

		return nullptr;
	}

	// count == elements
	void copyToBuffer(T* InData, size_t count, size_t offset = 0)
	{
		if (m_type == DeviceBufferType::CPU)
		{
			memcpy(m_ptr + offset, InData, count * sizeof(T));
		}
		else if (m_type == DeviceBufferType::CUDA)
		{
			cudaError_t ErrCode = cudaMemcpy(m_ptr + offset, InData, count * sizeof(T), cudaMemcpyHostToDevice);
			R_ASSERT(ErrCode == cudaSuccess);
		}
		else if (m_type == DeviceBufferType::OpenCL)
		{
			gCalcDevice->WriteBuffer(clBuffer, 0, offset, count * sizeof(T), InData, nullptr);
		}
		else
		{
			FATAL("Undefined Buffer::Type for Buffer");
		}
	}

protected:
	DeviceBufferType m_type;
	T* m_ptr;
	int m_device;
	size_t m_count;
	std::vector<T> m_tempHost;
	mutable Calc::Buffer* clBuffer;

private:
	DeviceBuffer<T>(const DeviceBuffer<T>&);            // forbidden
	DeviceBuffer<T>& operator=(const DeviceBuffer<T>&); // forbidden
};

