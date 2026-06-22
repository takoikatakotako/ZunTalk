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
    static func loadScene(url: URL) throws -> LoadedModel {
        let data = try Data(contentsOf: url)
        let (json, bin) = try splitGLB(data)
        let gltf = try JSONDecoder().decode(GLTF.self, from: json)

        let scene = SCNScene()
        let modelRoot = SCNNode()
        modelRoot.name = "modelRoot"
        let reader = AccessorReader(gltf: gltf, bin: bin)

        var minV = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxV = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)

        for mesh in gltf.meshes {
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

                // モーフターゲット（POSITION の差分）を名前つきで追加する。
                if let targets = primitive.targets, !targets.isEmpty {
                    let morpher = SCNMorpher()
                    // additive: 結果 = base + Σ weight*target。target は glTF の差分(delta)をそのまま渡す。
                    morpher.calculationMode = .additive
                    var targetGeometries: [SCNGeometry] = []
                    for (i, target) in targets.enumerated() {
                        guard let tp = target["POSITION"] else { continue }
                        let deltas = reader.readVec3(gltf.accessors[tp])
                        let tname = i < targetNames.count ? targetNames[i] : "target\(i)"
                        if tname == "Blink" || tname == "Joy" {
                            let mx = deltas.map { Swift.max(abs($0.x), abs($0.y), abs($0.z)) }.max() ?? 0
                            print("📏 morph \(tname) maxDelta=\(mx) count=\(deltas.count)")
                        }
                        let tGeo = SCNGeometry(
                            sources: [SCNGeometrySource(vertices: deltas)],
                            elements: [element]
                        )
                        tGeo.name = tname
                        targetGeometries.append(tGeo)
                    }
                    morpher.targets = targetGeometries
                    node.morpher = morpher
                }

                modelRoot.addChildNode(node)
            }
        }

        scene.rootNode.addChildNode(modelRoot)
        return LoadedModel(scene: scene, root: modelRoot, min: minV, max: maxV)
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
        if let texInfo = m.pbrMetallicRoughness?.baseColorTexture,
           let image = reader.image(textureIndex: texInfo.index) {
            mat.diffuse.contents = image
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
    let materials: [Material]?
    let textures: [Texture]?
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
    struct Material: Decodable {
        let pbrMetallicRoughness: PBR?
        let alphaMode: String?
        struct PBR: Decodable {
            let baseColorTexture: TexInfo?
            let baseColorFactor: [Float]?
        }
        struct TexInfo: Decodable { let index: Int }
    }
    struct Texture: Decodable { let source: Int? }
    struct Image: Decodable { let bufferView: Int?; let mimeType: String? }
}
