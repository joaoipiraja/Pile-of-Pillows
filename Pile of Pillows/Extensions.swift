//
//  Extensions.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//

import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation




extension Array where Element == PlaneAnchor {
    func within(meters maxDistance: Float, of transform: matrix_float4x4) -> [PlaneAnchor] {
        let refY = transform.translation.y
        return filter {
            abs($0.originFromAnchorTransform.translation.y - refY) <= maxDistance
        }
    }
    
    func containing(pointToProject transform: matrix_float4x4) -> [PlaneAnchor] {
        var results: [PlaneAnchor] = []
        for anchor in self {
            let anchorInverse = simd_inverse(anchor.originFromAnchorTransform)
            let planeFromPoint = anchorInverse * transform
            let planePoint2D = SIMD2<Float>(planeFromPoint.translation.x, planeFromPoint.translation.z)
            let faces = anchor.geometry.meshFaces
            var inside = false
            for faceIndex in 0..<faces.count {
                let indices = faces[faceIndex]
                let v1 = anchor.geometry.meshVertices[indices[0]]
                let v2 = anchor.geometry.meshVertices[indices[1]]
                let v3 = anchor.geometry.meshVertices[indices[2]]
                inside = planePoint2D.isInsideOf(
                    [v1.0, v1.2],
                    [v2.0, v2.2],
                    [v3.0, v3.2]
                )
                if inside {
                    results.append(anchor)
                    break
                }
            }
        }
        return results
    }
    
    func closestPlane(to transform: matrix_float4x4) -> PlaneAnchor? {
        let refY = transform.translation.y
        var minDist = Float.greatestFiniteMagnitude
        var chosen: PlaneAnchor?
        for anchor in self {
            let planeY = anchor.originFromAnchorTransform.translation.y
            let dist = abs(refY - planeY)
            if dist < minDist {
                minDist = dist
                chosen = anchor
            }
        }
        return chosen
    }
}

extension GeometrySource {
    func asArray<T>(ofType: T.Type) -> [T] {
        assert(MemoryLayout<T>.stride == stride)
        return (0..<count).map {
            buffer.contents().advanced(by: offset + stride * Int($0)).assumingMemoryBound(to: T.self).pointee
        }
    }
    
    func asSIMD3<T>(ofType: T.Type) -> [SIMD3<T>] {
        asArray(ofType: (T, T, T).self).map { .init($0.0, $0.1, $0.2) }
    }
    
    subscript(_ index: Int32) -> (Float, Float, Float) {
        precondition(format == .float3)
        return buffer.contents().advanced(by: offset + (stride * Int(index))).assumingMemoryBound(to: (Float, Float, Float).self).pointee
    }
}

extension GeometryElement {
    subscript(_ index: Int) -> [Int32] {
        precondition(bytesPerIndex == MemoryLayout<Int32>.size)
        var data = [Int32]()
        data.reserveCapacity(primitive.indexCount)
        for idxOffset in 0 ..< primitive.indexCount {
            data.append(buffer.contents()
                .advanced(by: (Int(index) * primitive.indexCount + idxOffset) * MemoryLayout<Int32>.size)
                .assumingMemoryBound(to: Int32.self).pointee)
        }
        return data
    }
    
    func asInt32Array() -> [Int32] {
        var data = [Int32]()
        let total = count * primitive.indexCount
        data.reserveCapacity(total)
        for offset in 0 ..< total {
            data.append(buffer.contents().advanced(by: offset * MemoryLayout<Int32>.size).assumingMemoryBound(to: Int32.self).pointee)
        }
        return data
    }
    
    func asUInt16Array() -> [UInt16] {
        asInt32Array().map { UInt16($0) }
    }
    
    public func asUInt32Array() -> [UInt32] {
        asInt32Array().map { UInt32($0) }
    }
}

extension simd_float4x4 {
    init(translation vector: SIMD3<Float>) {
        self.init(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(vector.x, vector.y, vector.z, 1)
        )
    }
    
    var translation: SIMD3<Float> {
        get { columns.3.xyz }
        set { columns.3 = [newValue.x, newValue.y, newValue.z, 1] }
    }
    
    var rotation: simd_quatf {
        simd_quatf(rotationMatrix)
    }
    
    var xAxis: SIMD3<Float> { columns.0.xyz }
    var yAxis: SIMD3<Float> { columns.1.xyz }
    var zAxis: SIMD3<Float> { columns.2.xyz }
    
    var rotationMatrix: simd_float3x3 {
        matrix_float3x3(xAxis, yAxis, zAxis)
    }
    
    var gravityAligned: simd_float4x4 {
        let projectedZAxis: SIMD3<Float> = [zAxis.x, 0.0, zAxis.z]
        let normalizedZAxis = normalize(projectedZAxis)
        let gravityAlignedYAxis: SIMD3<Float> = [0, 1, 0]
        let resultingXAxis = normalize(cross(gravityAlignedYAxis, normalizedZAxis))
        return simd_matrix(
            SIMD4(resultingXAxis.x, resultingXAxis.y, resultingXAxis.z, 0),
            SIMD4(gravityAlignedYAxis.x, gravityAlignedYAxis.y, gravityAlignedYAxis.z, 0),
            SIMD4(normalizedZAxis.x, normalizedZAxis.y, normalizedZAxis.z, 0),
            columns.3
        )
    }
}

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        self[SIMD3(0, 1, 2)]
    }
}

extension SIMD2<Float> {
    func isInsideOf(_ v1: SIMD2<Float>, _ v2: SIMD2<Float>, _ v3: SIMD2<Float>) -> Bool {
        let coords = barycentricCoordinatesInTriangle(v1, v2, v3)
        return coords.x >= 0 && coords.x <= 1 && coords.y >= 0 && coords.y <= 1 && coords.z >= 0 && coords.z <= 1
    }
    
    func barycentricCoordinatesInTriangle(_ v1: SIMD2<Float>, _ v2: SIMD2<Float>, _ v3: SIMD2<Float>) -> SIMD3<Float> {
        let v2FromV1 = v2 - v1
        let v3FromV1 = v3 - v1
        let selfFromV1 = self - v1
        let areaOverallTriangle = cross(v2FromV1, v3FromV1).z
        let areaU = cross(selfFromV1, v3FromV1).z
        let areaV = cross(v2FromV1, selfFromV1).z
        let u = areaU / areaOverallTriangle
        let v = areaV / areaOverallTriangle
        let w = 1.0 - v - u
        return SIMD3<Float>(u, v, w)
    }
}

extension PlaneAnchor {
    static let horizontalCollisionGroup = CollisionGroup(rawValue: 1 << 31)
    static let verticalCollisionGroup = CollisionGroup(rawValue: 1 << 30)
    static let allPlanesCollisionGroup = CollisionGroup(rawValue: horizontalCollisionGroup.rawValue | verticalCollisionGroup.rawValue)
}

extension MeshResource.Contents {
    init(planeGeometry: PlaneAnchor.Geometry) {
        self.init()
        self.instances = [MeshResource.Instance(id: "main", model: "model")]
        var part = MeshResource.Part(id: "part", materialIndex: 0)
        part.positions = MeshBuffers.Positions(planeGeometry.meshVertices.asSIMD3(ofType: Float.self))
        part.triangleIndices = MeshBuffer(planeGeometry.meshFaces.asUInt32Array())
        self.models = [MeshResource.Model(id: "model", parts: [part])]
    }
}
