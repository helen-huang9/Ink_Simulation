//
//  Transformations.swift
//  Ink_Simulation
//
//  Created by Helen Huang on 4/30/23.
//
//  Based on: https://github.com/amengede/getIntoMetalDev/blob/main/02%20Transformations/Finished/Transformations/LinearAlgebro.swift
//

import simd

class Matrix4x4 {
    static func Identity() -> float4x4 {
        return float4x4 (
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        )
    }
    
    static func Translation(translation: simd_float3) -> float4x4 {
        return float4x4 (
            [1,                 0,              0,              0],
            [0,                 1,              0,              0],
            [0,                 0,              1,              0],
            [translation[0],    translation[1], translation[2], 1]
        )
    }
    
    static func Rotation(eulers: simd_float3) -> float4x4 {
        let gamma: Float = eulers[0] * .pi / 180.0
        let beta: Float = eulers[1] * .pi / 180.0
        let alpha: Float = eulers[2] * .pi / 180.0
        return zRotation(theta: alpha) * yRotation(theta: beta) * xRotation(theta: gamma)
    }
    
    static func LookAt(eye: simd_float3, target: simd_float3, up: simd_float3) -> float4x4 {
        let forwards: simd_float3 = simd.normalize(target - eye)
        let right: simd_float3 = simd.normalize(simd.cross(up, forwards))
        let up2: simd_float3 = simd.normalize(simd.cross(forwards, right))
        
        return float4x4(
            [            right[0],             up2[0],             forwards[0],       0],
            [            right[1],             up2[1],             forwards[1],       0],
            [            right[2],             up2[2],             forwards[2],       0],
            [-simd.dot(right,eye), -simd.dot(up2,eye), -simd.dot(forwards,eye),       1]
        )
    }
    
    static func Perspective(fovy: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let A: Float = aspect * 1 / tan(fovy * .pi / 360)
        let B: Float = 1 / tan(fovy * .pi / 360)
        let C: Float = far / (far - near)
        let D: Float = 1
        let E: Float = -near * far / (far - near)
        
        return float4x4(
            [A, 0, 0, 0],
            [0, B, 0, 0],
            [0, 0, C, D],
            [0, 0, E, 0]
        )
    }
    
    static private func xRotation(theta: Float) -> float4x4 {
        return float4x4(
            [1,           0,          0, 0],
            [0,  cos(theta), sin(theta), 0],
            [0, -sin(theta), cos(theta), 0],
            [0,           0,          0, 1]
        )
    }
    
    static private func yRotation(theta: Float) -> float4x4 {
        return float4x4(
            [cos(theta), 0, -sin(theta), 0],
            [         0, 1,           0, 0],
            [sin(theta), 0,  cos(theta), 0],
            [         0, 0,           0, 1]
        )
    }
    
    static private func zRotation(theta: Float) -> float4x4 {
        return float4x4(
            [ cos(theta), sin(theta), 0, 0],
            [-sin(theta), cos(theta), 0, 0],
            [          0,          0, 1, 0],
            [          0,          0, 0, 1]
        )
    }
}
