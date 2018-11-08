#pragma once
/***************************************************************************
 *   Copyright (C) 2018 - ForserX & Oxydev
 *
 *   Permission is hereby granted, free of charge, to any person obtaining
 *   a copy of this software and associated documentation files (the
 *   "Software"), to deal in the Software without restriction, including
 *   without limitation the rights to use, copy, modify, merge, publish,
 *   distribute, sublicense, and/or sell copies of the Software, and to
 *   permit persons to whom the Software is furnished to do so, subject to
 *   the following conditions:
 *
 *   The above copyright notice and this permission notice shall be
 *   included in all copies or substantial portions of the Software.
 *
 *   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 *   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 *   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 *   IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 *   OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 *   ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 *   OTHER DEALINGS IN THE SOFTWARE.
 ***************************************************************************/

/// <summary>Generate new cam direction </summary>
inline void BuildCamDir(const Fvector &vFrom, const Fvector &vView, const Fvector &vWorldUp, DirectX::XMMATRIX &Matrics)
{
	// Get the dot product, and calculate the projection of the z basis
	// vector3 onto the up vector3. The projection is the y basis vector3.
	float fDotProduct = vWorldUp.dotproduct(vView);

	Fvector vUp;
	vUp.mul(vView, -fDotProduct).add(vWorldUp).normalize();

	// The x basis vector3 is found simply with the cross product of the y
	// and z basis vectors
	Fvector vRight;
	vRight.crossproduct(vUp, vView);

	// Start building the Device.mView. The first three rows contains the basis
	// vectors used to rotate the view to point at the lookat point
	Matrics = DirectX::XMMATRIX(
		vRight.x, vUp.x, vView.x, 0.0f,
		vRight.y, vUp.y, vView.y, 0.0f,
		vRight.z, vUp.z, vView.z, 0.0f,
		-vFrom.dotproduct(vRight), -vFrom.dotproduct(vUp), -vFrom.dotproduct(vView), 1.f);
}

/// <summary>Half fov <-> angle <-> tangent</summary>
inline void build_projection_HAT(float HAT, float fAspect, float fNearPlane, float fFarPlane, DirectX::XMMATRIX &Matrics)
{
	float cot = 1.f / HAT;
	float w = fAspect * cot;
	float h = 1.f * cot;
	float Q = fFarPlane / (fFarPlane - fNearPlane);

	Matrics = DirectX::XMMATRIX(
		w, 0, 0, 0,
		0, h, 0, 0,
		0, 0, Q, 1.f,
		0, 0, -Q * fNearPlane, 0);
}

/// <summary>Generate new a Matrix Projection</summary>
inline void BuildProj(float fFOV, float fAspect, float fNearPlane, float fFarPlane, DirectX::XMMATRIX &Matrics)
{
	return build_projection_HAT(tanf(fFOV / 2.f), fAspect, fNearPlane, fFarPlane, Matrics);
}

/// <summary>Generate new ortho projection to matrix </summary>
inline void BuildProjOrtho(float w, float h, float zn, float zf, DirectX::XMMATRIX &Matrics)
{
	Matrics = DirectX::XMMATRIX(
		2.f / w, 0, 0, 0,
		0, 2.f / h, 0, 0,
		0, 0, 1.f / (zf - zn), 0,
		0, 0, zn / (zn - zf), 1.f);
}

/// <summary>Convert DirectX::XMMATRIX to Fmatrix</summary>
inline Fmatrix CastToGSCMatrix(const DirectX::XMMATRIX &m)
{
	return
	{
		m.r[0].m128_f32[0], m.r[0].m128_f32[1], m.r[0].m128_f32[2], m.r[0].m128_f32[3],
		m.r[1].m128_f32[0], m.r[1].m128_f32[1], m.r[1].m128_f32[2], m.r[1].m128_f32[3],
		m.r[2].m128_f32[0], m.r[2].m128_f32[1], m.r[2].m128_f32[2], m.r[2].m128_f32[3],
		m.r[3].m128_f32[0], m.r[3].m128_f32[1], m.r[3].m128_f32[2], m.r[3].m128_f32[3]
	};
}

/// <summary>Convert Fmatrix to DirectX::XMMATRIX</summary>
inline DirectX::XMMATRIX CastToDXMatrix(Fmatrix &m)
{
	DirectX::XMMATRIX newMatrix;

	newMatrix.r[0].m128_f32[0] = m._11; newMatrix.r[0].m128_f32[1] = m._12; newMatrix.r[0].m128_f32[2] = m._13; newMatrix.r[0].m128_f32[3] = m._14;
	newMatrix.r[1].m128_f32[0] = m._21; newMatrix.r[1].m128_f32[1] = m._22; newMatrix.r[1].m128_f32[2] = m._23; newMatrix.r[1].m128_f32[3] = m._24;
	newMatrix.r[2].m128_f32[0] = m._31; newMatrix.r[2].m128_f32[1] = m._32; newMatrix.r[2].m128_f32[2] = m._33; newMatrix.r[2].m128_f32[3] = m._34;
	newMatrix.r[3].m128_f32[0] = m._41; newMatrix.r[3].m128_f32[1] = m._42; newMatrix.r[3].m128_f32[2] = m._43; newMatrix.r[3].m128_f32[3] = m._44;

	return newMatrix;
}

/// <summary>Call Fbox::xform for DirectX::XMMATRIX</summary>
inline void BuildXForm(Fbox &B, DirectX::XMMATRIX &m)
{
	Fmatrix GSCMatrix = CastToGSCMatrix(m);

	B.xform(GSCMatrix);
}

/// <summary>GSC Transform func for DirectX::XMMATRIX</summary>
inline void TransformVectorsByMatrix(const DirectX::XMMATRIX &m, Fvector &dest, const Fvector &v)
{
	float iw = 1.f / (v.x*m.r[0].m128_f32[3] + v.y*m.r[1].m128_f32[3] + v.z*m.r[2].m128_f32[3] + m.r[3].m128_f32[3]);

	dest.x = (v.x* m.r[0].m128_f32[0] + v.y* m.r[1].m128_f32[0] + v.z* m.r[2].m128_f32[0] + m.r[3].m128_f32[0])*iw;
	dest.y = (v.x* m.r[0].m128_f32[1] + v.y* m.r[1].m128_f32[1] + v.z* m.r[2].m128_f32[1] + m.r[3].m128_f32[1])*iw;
	dest.z = (v.x* m.r[0].m128_f32[2] + v.y* m.r[1].m128_f32[2] + v.z* m.r[2].m128_f32[2] + m.r[3].m128_f32[2])*iw;
}
