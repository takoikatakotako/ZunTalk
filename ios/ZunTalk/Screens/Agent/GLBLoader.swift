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

    /// glb を読み込み、SCNScene を返す。各メッシュノードの morpher には名前つき target が入る。
    static func loadScene(url: URL) throws -> SCNScene {
        let data = try Data(contentsOf: url)
        let (json, bin) = try splitGLB(data)
        let gltf = try JSONDecoder().decode(GLTF.self, from: json)

        let scene = SCNScene()
        let reader = AccessorReader(gltf: gltf, bin: bin)

        for mesh in gltf.meshes {
            let targetNames = mesh.extras?.targetNames ?? []

            for primitive in mesh.primitives {
                guard let posAccessor = primitive.attributes["POSITION"] else { continue }
                let positions = reader.readVec3(gltf.accessors[posAccessor])

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
                    morpher.calculationMode = .additive
                    var targetGeometries: [SCNGeometry] = []
                    for (i, target) in targets.enumerated() {
                        guard let tp = target["POSITION"] else { continue }
                        let deltas = reader.readVec3(gltf.accessors[tp])
                        let tGeo = SCNGeometry(
                            sources: [SCNGeometrySource(vertices: deltas)],
                            elements: [element]
                        )
                        tGeo.name = i < targetNames.count ? targetNames[i] : "target\(i)"
                        targetGeometries.append(tGeo)
                    }
                    morpher.targets = targetGeometries
                    node.morpher = morpher
                }

                scene.rootNode.addChildNode(node)
            }
        }

        return scene
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
        mat.lightingModel = .physicallyBased
        mat.isDoubleSided = true // スパイク中は裏面カリングの事故を避ける

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

    /// glTF UV(原点 左上) → SceneKit 用に V を反転（環境により要調整）。
    private let flipV = true

    func readVec3(_ acc: GLTF.Accessor) -> [SCNVector3] {
        guard let bvIndex = acc.bufferView else { return [] }
        let bv = gltf.bufferViews[bvIndex]
        let base = (bv.byteOffset ?? 0) + (acc.byteOffset ?? 0)
        let stride = (bv.byteStride ?? 0) == 0 ? 12 : bv.byteStride!
        var out = [SCNVector3]()
        out.reserveCapacity(acc.count)
        for i in 0..<acc.count {
            let o = base + i * stride
            out.append(SCNVector3(readF32(bin, o), readF32(bin, o + 4), readF32(bin, o + 8)))
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
        struct PBR: Decodable {
            let baseColorTexture: TexInfo?
            let baseColorFactor: [Float]?
        }
        struct TexInfo: Decodable { let index: Int }
    }
    struct Texture: Decodable { let source: Int? }
    struct Image: Decodable { let bufferView: Int?; let mimeType: String? }
}
