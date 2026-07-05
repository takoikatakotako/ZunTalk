// swiftlint:disable file_length
import Foundation
import SceneKit
import UIKit

/// 用途特化の glb(=VRM) → SceneKit ローダ（フルスクラッチ）。
///
/// 必要なものだけを読む:
/// - メッシュ（POSITION / NORMAL / TEXCOORD_0 / indices）
/// - baseColor テクスチャ
/// - モーフターゲット（blendshape, 名前つき）→ 表情・口パク用
///
/// スキニング（ボーン変形）とアニメは省略する（顔のアップ用途のため rest pose で十分）。
/// VRM の MToon マテリアルは pbrMetallicRoughness.baseColorTexture にフォールバックする。
enum GLBLoader {

    enum LoadError: Error {
        case notGLB
        case noJSONChunk
        case decodeFailed(String)
    }

    /// 読み込み結果（シーン＋モデルのルートノード＋境界ボックス）。
    struct LoadedModel {
        let scene: SCNScene
        let root: SCNNode
        let min: SCNVector3
        let max: SCNVector3
    }

    /// glb を読み込み、シーンと境界を返す。各メッシュノードの morpher には名前つき target が入る。
    /// glTF の構造（mesh/primitive/morph target）をなぞる都合で長く複雑になっている。
    static func loadScene(url: URL) throws -> LoadedModel { // swiftlint:disable:this cyclomatic_complexity function_body_length
        let data = try Data(contentsOf: url)
        let (json, bin) = try splitGLB(data)
        let gltf = try JSONDecoder().decode(GLTF.self, from: json)

        let scene = SCNScene()
        let modelRoot = SCNNode()
        modelRoot.name = "modelRoot"
        let reader = AccessorReader(gltf: gltf, bin: bin)
        let gltfNodes = gltf.nodes ?? []
        let sceneIndex = gltf.scene ?? 0
        let sceneRoots = gltf.scenes.indices.contains(sceneIndex) ? gltf.scenes[sceneIndex].nodes : []
        let sceneNodes = gltfNodes.enumerated().map { index, nodeDef in
            makeNode(index: index, definition: nodeDef)
        }

        struct PendingSkin {
            let node: SCNNode
            let skinIndex: Int
            let jointAccessor: Int
            let weightAccessor: Int
        }
        var pendingSkins: [PendingSkin] = []

        var minV = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxV = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)

        for (nodeIndex, nodeDef) in gltfNodes.enumerated() {
            guard let meshIndex = nodeDef.mesh, gltf.meshes.indices.contains(meshIndex) else { continue }
            let mesh = gltf.meshes[meshIndex]
            let targetNames = mesh.extras?.targetNames ?? []

            for primitive in mesh.primitives {
                guard let posAccessor = primitive.attributes["POSITION"] else { continue }
                let positions = reader.readVec3(gltf.accessors[posAccessor])

                for p in positions {
                    minV.x = Swift.min(minV.x, p.x); minV.y = Swift.min(minV.y, p.y); minV.z = Swift.min(minV.z, p.z)
                    maxV.x = Swift.max(maxV.x, p.x); maxV.y = Swift.max(maxV.y, p.y); maxV.z = Swift.max(maxV.z, p.z)
                }

                var sources: [SCNGeometrySource] = [SCNGeometrySource(vertices: positions)]
                if let n = primitive.attributes["NORMAL"] {
                    sources.append(SCNGeometrySource(normals: reader.readVec3(gltf.accessors[n])))
                }
                if let t = primitive.attributes["TEXCOORD_0"] {
                    sources.append(SCNGeometrySource(textureCoordinates: reader.readUV(gltf.accessors[t])))
                }

                guard let indexAccessor = primitive.indices else { continue }
                let indices = reader.readIndices(gltf.accessors[indexAccessor])
                let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)

                let geometry = SCNGeometry(sources: sources, elements: [element])
                geometry.firstMaterial = material(for: primitive.material, gltf: gltf, reader: reader)

                let node = SCNNode(geometry: geometry)
                node.name = mesh.name

                if let skinIndex = nodeDef.skin,
                   primitive.attributes["JOINTS_0"] != nil,
                   primitive.attributes["WEIGHTS_0"] != nil {
                    pendingSkins.append(PendingSkin(
                        node: node,
                        skinIndex: skinIndex,
                        jointAccessor: primitive.attributes["JOINTS_0"]!,
                        weightAccessor: primitive.attributes["WEIGHTS_0"]!
                    ))
                }

                // モーフターゲット（glTF は POSITION の差分）を SceneKit 用の絶対座標に変換して追加する。
                if let targets = primitive.targets, !targets.isEmpty {
                    let morpher = SCNMorpher()
                    var targetGeometries: [SCNGeometry] = []
                    for (i, target) in targets.enumerated() {
                        guard let tp = target["POSITION"] else { continue }
                        let deltas = reader.readVec3(gltf.accessors[tp])
                        let tname = i < targetNames.count ? targetNames[i] : "target\(i)"
                        guard deltas.count == positions.count else { continue }
                        let morphedPositions = zip(positions, deltas).map { base, delta in
                            SCNVector3(base.x + delta.x, base.y + delta.y, base.z + delta.z)
                        }
                        let tGeo = SCNGeometry(
                            sources: [SCNGeometrySource(vertices: morphedPositions)],
                            elements: [element]
                        )
                        tGeo.name = tname
                        targetGeometries.append(tGeo)
                    }
                    morpher.targets = targetGeometries
                    node.morpher = morpher
                }

                sceneNodes[nodeIndex].addChildNode(node)
            }
        }

        for (index, nodeDef) in gltfNodes.enumerated() {
            for child in nodeDef.children ?? [] where sceneNodes.indices.contains(child) {
                sceneNodes[index].addChildNode(sceneNodes[child])
            }
        }

        for rootIndex in sceneRoots where sceneNodes.indices.contains(rootIndex) {
            modelRoot.addChildNode(sceneNodes[rootIndex])
        }

        for pendingSkin in pendingSkins {
            guard let skins = gltf.skins,
                  skins.indices.contains(pendingSkin.skinIndex),
                  let geometry = pendingSkin.node.geometry else { continue }
            let skin = skins[pendingSkin.skinIndex]
            let bones = skin.joints.compactMap { sceneNodes.indices.contains($0) ? sceneNodes[$0] : nil }
            guard bones.count == skin.joints.count else { continue }
            let inverseBindTransforms = skin.inverseBindMatrices.flatMap { accessorIndex -> [NSValue]? in
                guard gltf.accessors.indices.contains(accessorIndex) else { return nil }
                return reader.readMat4(gltf.accessors[accessorIndex]).map { NSValue(scnMatrix4: $0) }
            } ?? bones.map { _ in NSValue(scnMatrix4: SCNMatrix4Identity) }
            let boneWeights = reader.readVec4GeometrySource(
                gltf.accessors[pendingSkin.weightAccessor],
                semantic: .boneWeights
            )
            let boneIndices = reader.readJointGeometrySource(
                gltf.accessors[pendingSkin.jointAccessor],
                semantic: .boneIndices
            )
            pendingSkin.node.skinner = SCNSkinner(
                baseGeometry: geometry,
                bones: bones,
                boneInverseBindTransforms: inverseBindTransforms,
                boneWeights: boneWeights,
                boneIndices: boneIndices
            )
        }

        scene.rootNode.addChildNode(modelRoot)
        return LoadedModel(scene: scene, root: modelRoot, min: minV, max: maxV)
    }

    private static func makeNode(index: Int, definition: GLTF.Node) -> SCNNode {
        let node = SCNNode()
        node.name = definition.name ?? "node\(index)"

        if let matrix = definition.matrix, matrix.count == 16 {
            node.transform = matrix4(from: matrix)
        } else {
            if let translation = definition.translation, translation.count == 3 {
                node.position = SCNVector3(translation[0], translation[1], translation[2])
            }
            if let rotation = definition.rotation, rotation.count == 4 {
                node.orientation = SCNQuaternion(rotation[0], rotation[1], rotation[2], rotation[3])
            }
            if let scale = definition.scale, scale.count == 3 {
                node.scale = SCNVector3(scale[0], scale[1], scale[2])
            }
        }

        return node
    }

    private static func matrix4(from values: [Float]) -> SCNMatrix4 {
        SCNMatrix4(
            m11: values[0], m12: values[1], m13: values[2], m14: values[3],
            m21: values[4], m22: values[5], m23: values[6], m24: values[7],
            m31: values[8], m32: values[9], m33: values[10], m34: values[11],
            m41: values[12], m42: values[13], m43: values[14], m44: values[15]
        )
    }

    // MARK: - GLB container

    private static func splitGLB(_ data: Data) throws -> (json: Data, bin: Data) {
        guard data.count > 12 else { throw LoadError.notGLB }
        let magic = data.subdata(in: 0..<4)
        guard magic == Data([0x67, 0x6C, 0x54, 0x46]) else { throw LoadError.notGLB } // "glTF"

        var offset = 12
        var json: Data?
        var bin: Data?
        while offset + 8 <= data.count {
            let len = Int(readU32(data, offset))
            let type = readU32(data, offset + 4)
            let start = offset + 8
            let end = start + len
            guard end <= data.count else { break }
            let chunk = data.subdata(in: start..<end)
            if type == 0x4E4F534A { // "JSON"
                json = chunk
            } else if type == 0x004E4942 { // "BIN\0"
                bin = chunk
            }
            offset = end
        }
        guard let j = json else { throw LoadError.noJSONChunk }
        return (j, bin ?? Data())
    }

    // MARK: - Material

    private static func material(for index: Int?, gltf: GLTF, reader: AccessorReader) -> SCNMaterial {
        let mat = SCNMaterial()
        // VRM は本来アンリット（MToon）。陰影で破綻しないようテクスチャそのまま表示する。
        mat.lightingModel = .constant
        mat.isDoubleSided = true

        guard let index = index, let materials = gltf.materials, index < materials.count else {
            mat.diffuse.contents = UIColor.systemGreen
            return mat
        }
        let m = materials[index]
        mat.name = m.name
        if let texInfo = m.pbrMetallicRoughness?.baseColorTexture,
           let image = reader.image(textureIndex: texInfo.index) {
            mat.diffuse.contents = image
            applyTextureSampler(textureIndex: texInfo.index, to: mat.diffuse, gltf: gltf)
        } else if let f = m.pbrMetallicRoughness?.baseColorFactor, f.count >= 3 {
            mat.diffuse.contents = UIColor(red: CGFloat(f[0]), green: CGFloat(f[1]), blue: CGFloat(f[2]), alpha: CGFloat(f.count > 3 ? f[3] : 1))
        } else {
            mat.diffuse.contents = UIColor.systemGreen
        }

        // 眉・口・目のハイライト等は透過テクスチャ。アルファを有効化する。
        if m.alphaMode == "BLEND" || m.alphaMode == "MASK" {
            mat.transparencyMode = .aOne
            mat.blendMode = .alpha
        }
        return mat
    }

    private static func applyTextureSampler(textureIndex: Int, to property: SCNMaterialProperty, gltf: GLTF) {
        guard let textures = gltf.textures,
              textureIndex < textures.count,
              let samplerIndex = textures[textureIndex].sampler,
              let samplers = gltf.samplers,
              samplerIndex < samplers.count else {
            return
        }
        let sampler = samplers[samplerIndex]
        property.wrapS = wrapMode(from: sampler.wrapS)
        property.wrapT = wrapMode(from: sampler.wrapT)
    }

    private static func wrapMode(from gltfValue: Int?) -> SCNWrapMode {
        switch gltfValue ?? 10497 {
        case 33071:
            return .clamp
        case 33648:
            return .mirror
        case 10497:
            return .repeat
        default:
            return .repeat
        }
    }
}

// MARK: - Accessor 読み出し

private final class AccessorReader {
    let gltf: GLTF
    let bin: Data
    private var imageCache: [Int: UIImage] = [:]

    init(gltf: GLTF, bin: Data) {
        self.gltf = gltf
        self.bin = bin
    }

    /// glTF UV(原点 左上)。SceneKit も左上原点なので反転しない。
    private let flipV = false

    func readVec3(_ acc: GLTF.Accessor) -> [SCNVector3] {
        // ベース（密）部分。bufferView が無ければ全て 0（morph 差分の定番）。
        var out: [SCNVector3]
        if let bvIndex = acc.bufferView {
            let bv = gltf.bufferViews[bvIndex]
            let base = (bv.byteOffset ?? 0) + (acc.byteOffset ?? 0)
            let stride = (bv.byteStride ?? 0) == 0 ? 12 : bv.byteStride!
            out = (0..<acc.count).map { i in
                let o = base + i * stride
                return SCNVector3(readF32(bin, o), readF32(bin, o + 4), readF32(bin, o + 8))
            }
        } else {
            out = Array(repeating: SCNVector3(0, 0, 0), count: acc.count)
        }

        // sparse 部分（変化した頂点だけ上書き）。VRM の morph 差分はこれで来る。
        if let sparse = acc.sparse {
            let idxBV = gltf.bufferViews[sparse.indices.bufferView]
            let idxBase = (idxBV.byteOffset ?? 0) + (sparse.indices.byteOffset ?? 0)
            let valBV = gltf.bufferViews[sparse.values.bufferView]
            let valBase = (valBV.byteOffset ?? 0) + (sparse.values.byteOffset ?? 0)
            for k in 0..<sparse.count {
                let vi: Int
                switch sparse.indices.componentType {
                case 5121: vi = Int(bin[bin.startIndex + idxBase + k])
                case 5123: vi = Int(readU16(bin, idxBase + k * 2))
                case 5125: vi = Int(readU32(bin, idxBase + k * 4))
                default: vi = -1
                }
                guard vi >= 0 && vi < out.count else { continue }
                let o = valBase + k * 12
                out[vi] = SCNVector3(readF32(bin, o), readF32(bin, o + 4), readF32(bin, o + 8))
            }
        }
        return out
    }

    func readUV(_ acc: GLTF.Accessor) -> [CGPoint] {
        guard let bvIndex = acc.bufferView else { return [] }
        let bv = gltf.bufferViews[bvIndex]
        let base = (bv.byteOffset ?? 0) + (acc.byteOffset ?? 0)
        let stride = (bv.byteStride ?? 0) == 0 ? 8 : bv.byteStride!
        var out = [CGPoint]()
        out.reserveCapacity(acc.count)
        for i in 0..<acc.count {
            let o = base + i * stride
            let u = readF32(bin, o)
            let v = readF32(bin, o + 4)
            out.append(CGPoint(x: CGFloat(u), y: CGFloat(flipV ? 1 - v : v)))
        }
        return out
    }

    func readMat4(_ acc: GLTF.Accessor) -> [SCNMatrix4] {
        guard let bvIndex = acc.bufferView else { return [] }
        let bv = gltf.bufferViews[bvIndex]
        let base = (bv.byteOffset ?? 0) + (acc.byteOffset ?? 0)
        let stride = (bv.byteStride ?? 0) == 0 ? 64 : bv.byteStride!
        return (0..<acc.count).map { i in
            let o = base + i * stride
            let values = (0..<16).map { readF32(bin, o + $0 * 4) }
            return SCNMatrix4(
                m11: values[0], m12: values[1], m13: values[2], m14: values[3],
                m21: values[4], m22: values[5], m23: values[6], m24: values[7],
                m31: values[8], m32: values[9], m33: values[10], m34: values[11],
                m41: values[12], m42: values[13], m43: values[14], m44: values[15]
            )
        }
    }

    func readVec4GeometrySource(_ acc: GLTF.Accessor, semantic: SCNGeometrySource.Semantic) -> SCNGeometrySource {
        guard let bvIndex = acc.bufferView else {
            return floatGeometrySource(values: Array(repeating: 0, count: acc.count * 4), semantic: semantic)
        }
        let bv = gltf.bufferViews[bvIndex]
        let base = (bv.byteOffset ?? 0) + (acc.byteOffset ?? 0)
        let componentSize = byteSize(for: acc.componentType)
        let stride = (bv.byteStride ?? 0) == 0 ? componentSize * 4 : bv.byteStride!
        var values: [Float] = []
        values.reserveCapacity(acc.count * 4)
        for i in 0..<acc.count {
            let o = base + i * stride
            for component in 0..<4 {
                values.append(readComponentAsFloat(acc.componentType, o + component * componentSize))
            }
        }
        return floatGeometrySource(values: values, semantic: semantic)
    }

    func readJointGeometrySource(_ acc: GLTF.Accessor, semantic: SCNGeometrySource.Semantic) -> SCNGeometrySource {
        guard let bvIndex = acc.bufferView else {
            return jointGeometrySource(values: Array(repeating: 0, count: acc.count * 4), semantic: semantic)
        }
        let bv = gltf.bufferViews[bvIndex]
        let base = (bv.byteOffset ?? 0) + (acc.byteOffset ?? 0)
        let componentSize = byteSize(for: acc.componentType)
        let stride = (bv.byteStride ?? 0) == 0 ? componentSize * 4 : bv.byteStride!
        var values: [UInt16] = []
        values.reserveCapacity(acc.count * 4)
        for i in 0..<acc.count {
            let o = base + i * stride
            for component in 0..<4 {
                values.append(readComponentAsUInt16(acc.componentType, o + component * componentSize))
            }
        }
        return jointGeometrySource(values: values, semantic: semantic)
    }

    func readIndices(_ acc: GLTF.Accessor) -> [Int32] {
        guard let bvIndex = acc.bufferView else { return [] }
        let bv = gltf.bufferViews[bvIndex]
        let base = (bv.byteOffset ?? 0) + (acc.byteOffset ?? 0)
        var out = [Int32]()
        out.reserveCapacity(acc.count)
        switch acc.componentType {
        case 5123: // UNSIGNED_SHORT
            for i in 0..<acc.count { out.append(Int32(readU16(bin, base + i * 2))) }
        case 5125: // UNSIGNED_INT
            for i in 0..<acc.count { out.append(Int32(bitPattern: readU32(bin, base + i * 4))) }
        case 5121: // UNSIGNED_BYTE
            for i in 0..<acc.count { out.append(Int32(bin[bin.startIndex + base + i])) }
        default:
            break
        }
        return out
    }

    func image(textureIndex: Int) -> UIImage? {
        guard let textures = gltf.textures, textureIndex < textures.count,
              let source = textures[textureIndex].source,
              let images = gltf.images, source < images.count else { return nil }
        if let cached = imageCache[source] { return cached }
        let img = images[source]
        guard let bvIndex = img.bufferView else { return nil }
        let bv = gltf.bufferViews[bvIndex]
        let start = bin.startIndex + (bv.byteOffset ?? 0)
        let chunk = bin.subdata(in: start..<(start + bv.byteLength))
        let ui = UIImage(data: chunk)
        if let ui { imageCache[source] = ui }
        return ui
    }

    private func byteSize(for componentType: Int) -> Int {
        switch componentType {
        case 5120, 5121: return 1
        case 5122, 5123: return 2
        case 5125, 5126: return 4
        default: return 4
        }
    }

    private func readComponentAsFloat(_ componentType: Int, _ offset: Int) -> Float {
        switch componentType {
        case 5121: return Float(bin[bin.startIndex + offset]) / 255
        case 5123: return Float(readU16(bin, offset)) / 65535
        case 5126: return readF32(bin, offset)
        default: return 0
        }
    }

    private func readComponentAsUInt16(_ componentType: Int, _ offset: Int) -> UInt16 {
        switch componentType {
        case 5121: return UInt16(bin[bin.startIndex + offset])
        case 5123: return readU16(bin, offset)
        case 5125: return UInt16(clamping: readU32(bin, offset))
        default: return 0
        }
    }

    private func floatGeometrySource(values: [Float], semantic: SCNGeometrySource.Semantic) -> SCNGeometrySource {
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        return SCNGeometrySource(
            data: data,
            semantic: semantic,
            vectorCount: values.count / 4,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 4
        )
    }

    private func jointGeometrySource(values: [UInt16], semantic: SCNGeometrySource.Semantic) -> SCNGeometrySource {
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        return SCNGeometrySource(
            data: data,
            semantic: semantic,
            vectorCount: values.count / 4,
            usesFloatComponents: false,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<UInt16>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<UInt16>.size * 4
        )
    }
}

// MARK: - バイト読み出しヘルパー

private func readU32(_ data: Data, _ offset: Int) -> UInt32 {
    data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: data.startIndex - data.startIndex + offset, as: UInt32.self) }
}
private func readU16(_ data: Data, _ offset: Int) -> UInt16 {
    data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self) }
}
private func readF32(_ data: Data, _ offset: Int) -> Float {
    data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Float32.self) }
}

// MARK: - 最小限の glTF スキーマ

struct GLTF: Decodable {
    let accessors: [Accessor]
    let bufferViews: [BufferView]
    let meshes: [Mesh]
    let nodes: [Node]?
    let skins: [Skin]?
    let scenes: [Scene]
    let scene: Int?
    let materials: [Material]?
    let textures: [Texture]?
    let samplers: [Sampler]?
    let images: [Image]?

    struct Accessor: Decodable {
        let bufferView: Int?
        let byteOffset: Int?
        let componentType: Int
        let count: Int
        let type: String
        let sparse: Sparse?

        struct Sparse: Decodable {
            let count: Int
            let indices: Indices
            let values: Values
            struct Indices: Decodable {
                let bufferView: Int
                let byteOffset: Int?
                let componentType: Int
            }
            struct Values: Decodable {
                let bufferView: Int
                let byteOffset: Int?
            }
        }
    }
    struct BufferView: Decodable {
        let byteOffset: Int?
        let byteLength: Int
        let byteStride: Int?
    }
    struct Mesh: Decodable {
        let name: String?
        let primitives: [Primitive]
        let extras: Extras?
        struct Extras: Decodable { let targetNames: [String]? }
    }
    struct Primitive: Decodable {
        let attributes: [String: Int]
        let indices: Int?
        let material: Int?
        let targets: [[String: Int]]?
    }
    struct Node: Decodable {
        let name: String?
        let mesh: Int?
        let skin: Int?
        let children: [Int]?
        let translation: [Float]?
        let rotation: [Float]?
        let scale: [Float]?
        let matrix: [Float]?
    }
    struct Skin: Decodable {
        let joints: [Int]
        let inverseBindMatrices: Int?
        let skeleton: Int?
    }
    struct Scene: Decodable {
        let nodes: [Int]
    }
    struct Material: Decodable {
        let name: String?
        let pbrMetallicRoughness: PBR?
        let alphaMode: String?
        struct PBR: Decodable {
            let baseColorTexture: TexInfo?
            let baseColorFactor: [Float]?
        }
        struct TexInfo: Decodable { let index: Int }
    }
    struct Texture: Decodable { let sampler: Int?; let source: Int? }
    struct Sampler: Decodable { let wrapS: Int?; let wrapT: Int? }
    struct Image: Decodable { let bufferView: Int?; let mimeType: String? }
}
