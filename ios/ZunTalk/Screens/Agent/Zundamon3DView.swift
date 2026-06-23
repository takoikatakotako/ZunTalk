import SwiftUI
import SceneKit

/// 3Dモデルの読み込み状態。
enum ZundamonModelStatus {
    case loading
    case loaded
    case failed
}

/// ずんだもんの3Dモデル（VRM=glb）を SwiftUI の `SceneView` で表示する。
///
/// 描画ループを確実に回すため、SceneView に delegate（SceneRig）を渡し、
/// その毎フレームコールバックで表情・口パク・まばたき・揺れのモーフを駆動する。
struct Zundamon3DView: View {
    var expression: ZundamonExpression
    var speaking: Bool
    var appliesExpressionMorphs = true
    var manualMorphWeights: [String: CGFloat] = [:]
    var manualMorphScale: CGFloat = 1
    var eyeDebugMode: ZundamonEyeDebugMode = .normal
    var eyeDepthOffset: CGFloat = 0
    @Binding var status: ZundamonModelStatus

    @State private var scene: SCNScene?
    @State private var pov: SCNNode?
    @StateObject private var rig = SceneRig()

    var body: some View {
        Group {
            if let scene, let pov {
                SceneView(
                    scene: scene,
                    pointOfView: pov,
                    options: [.rendersContinuously],
                    delegate: rig
                )
            } else {
                Color.clear
            }
        }
        .onAppear(perform: loadIfNeeded)
        .onChange(of: expression) { _, newValue in rig.expression = newValue }
        .onChange(of: speaking) { _, newValue in rig.speaking = newValue }
        .onChange(of: appliesExpressionMorphs) { _, newValue in rig.appliesExpressionMorphs = newValue }
        .onChange(of: manualMorphWeights) { _, newValue in rig.manualMorphWeights = newValue }
        .onChange(of: manualMorphScale) { _, newValue in rig.manualMorphScale = newValue }
        .onChange(of: eyeDebugMode) { _, newValue in rig.eyeDebugMode = newValue }
        .onChange(of: eyeDepthOffset) { _, newValue in rig.eyeDepthOffset = newValue }
    }

    private func loadIfNeeded() {
        guard scene == nil else { return }
        let expr = expression
        let spk = speaking
        let appliesExpressionMorphs = appliesExpressionMorphs
        let morphWeights = manualMorphWeights
        let morphScale = manualMorphScale
        let eyeDebugMode = eyeDebugMode
        let eyeDepthOffset = eyeDepthOffset
        DispatchQueue.global(qos: .userInitiated).async {
            guard let url = Bundle.main.url(forResource: "zundamon", withExtension: "glb") else {
                print("⚠️ zundamon.glb が見つからないのだ")
                DispatchQueue.main.async { status = .failed }
                return
            }
            do {
                let model = try GLBLoader.loadScene(url: url)
                DispatchQueue.main.async {
                    let cam = Self.makeCamera(model)
                    model.scene.rootNode.addChildNode(cam)
                    rig.attach(to: model.scene)
                    rig.expression = expr
                    rig.speaking = spk
                    rig.appliesExpressionMorphs = appliesExpressionMorphs
                    rig.manualMorphWeights = morphWeights
                    rig.manualMorphScale = morphScale
                    rig.eyeDebugMode = eyeDebugMode
                    rig.eyeDepthOffset = eyeDepthOffset
                    scene = model.scene
                    pov = cam
                    status = .loaded
                }
            } catch {
                print("⚠️ VRM 読み込みエラー: \(error)")
                DispatchQueue.main.async { status = .failed }
            }
        }
    }

    private static func makeCamera(_ model: GLBLoader.LoadedModel) -> SCNNode {
        let lo = model.min, hi = model.max
        let height = max(hi.y - lo.y, 0.01)
        let cx = (lo.x + hi.x) / 2
        let faceY = hi.y - height * 0.08 // 顔（目〜額）あたり。少し上を見て頭・耳まで入れる。

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 35
        camera.zNear = 0.01
        camera.zFar = 100
        cameraNode.camera = camera
        // 正面は -Z 側。前面(min z)からさらに前へ置き、向きを 180°回して +Z（モデル方向）を見る。
        let distance = height * 0.72
        cameraNode.position = SCNVector3(cx, faceY, lo.z - distance)
        cameraNode.eulerAngles = SCNVector3(0, Float.pi, 0)
        return cameraNode
    }
}

enum ZundamonEyeDebugMode: String, CaseIterable, Identifiable {
    case normal = "通常"
    case highlighted = "赤表示"
    case hidden = "非表示"

    var id: String { rawValue }
}

/// SceneView の delegate 兼モーフ駆動リグ。毎フレーム呼ばれる `updateAtTime` で
/// 表情・口パク・まばたき・揺れを反映する（これにより連続描画も保証される）。
final class SceneRig: NSObject, SCNSceneRendererDelegate, ObservableObject {
    // 外から設定される望ましい状態（main から書き、render スレッドで読む）。
    var expression: ZundamonExpression = .idle
    var speaking = false
    var appliesExpressionMorphs = true
    var manualMorphWeights: [String: CGFloat] = [:]
    var manualMorphScale: CGFloat = 1
    var eyeDebugMode: ZundamonEyeDebugMode = .normal
    var eyeDepthOffset: CGFloat = 0

    private struct NamedMorpher {
        let morpher: SCNMorpher
        let targetIndexByName: [String: Int]
    }

    private struct EyeNodeState {
        weak var node: SCNNode?
        let baseZ: Float
        let material: SCNMaterial
        let diffuseContents: Any?
        let emissionContents: Any?
        let transparency: CGFloat
    }

    private var morphers: [NamedMorpher] = []
    private var eyeNodeStates: [EyeNodeState] = []
    private weak var modelRoot: SCNNode?

    /// 毎フレーム一旦 0 に戻すモーフ。idle の見た目がモデル初期値に引きずられないよう広めに含める。
    private let resetMorphs = [
        "Joy", "Angry", "Sorrow", "Fun",
        "怒り眉", "上がり眉", "困り眉1", "困り眉2",
        "普通目2", "普通目3", "ジト目1", "ジト目2", "ジト白目", "見開き白目",
        "なごみ目", "にっこり", "にっこり2", "まばたき", "キャッチライト", "〇〇", "UU", "＞＜",
        "涙", "汗", "汗2", "ほっぺ", "ほっぺ赤め", "青ざめ", "かげり",
        "A", "I", "U", "E", "O", "Blink", "Blink_L", "Blink_R",
        "むー", "お", "んー", "んへー", "んあー", "△", "むふ", "ほー", "ほあ", "ほあー"
    ]

    func attach(to scene: SCNScene) {
        morphers.removeAll()
        eyeNodeStates.removeAll()
        scene.rootNode.enumerateChildNodes { node, _ in
            if let m = node.morpher, !m.targets.isEmpty {
                let targetIndexByName = Dictionary(
                    uniqueKeysWithValues: m.targets.enumerated().compactMap { index, target in
                        target.name.map { ($0, index) }
                    }
                )
                self.morphers.append(NamedMorpher(
                    morpher: m,
                    targetIndexByName: targetIndexByName
                ))
            }
            if let material = node.geometry?.firstMaterial, material.name == "Eye" {
                self.eyeNodeStates.append(EyeNodeState(
                    node: node,
                    baseZ: node.position.z,
                    material: material,
                    diffuseContents: material.diffuse.contents,
                    emissionContents: material.emission.contents,
                    transparency: material.transparency
                ))
            }
        }
        resetAllMorphs()
        modelRoot = scene.rootNode.childNode(withName: "modelRoot", recursively: false)
    }

    // 毎フレーム呼ばれる。
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // アイドルの軽い揺れ
        modelRoot?.eulerAngles.y = Float(sin(time * 0.8) * 0.08)
        applyEyeDebug()

        guard !morphers.isEmpty else { return }

        // 表情
        resetAllMorphs()
        if appliesExpressionMorphs {
            for (name, weight) in expression.morphWeights {
                setWeight(weight, forTargetNamed: name)
            }
        }

        for (name, weight) in manualMorphWeights where weight > 0 {
            setWeight(weight * manualMorphScale, forTargetNamed: name)
        }

        // 口パク（喋り中だけ A を開閉）
        if speaking {
            let open = CGFloat(sin(time * 18) * 0.5 + 0.5) * 0.6
            setWeight(open, forTargetNamed: "A")
        }
    }

    private func resetAllMorphs() {
        for name in resetMorphs {
            setWeight(0, forTargetNamed: name)
        }
    }

    private func setWeight(_ weight: CGFloat, forTargetNamed name: String) {
        for namedMorpher in morphers {
            guard let index = namedMorpher.targetIndexByName[name] else { continue }
            namedMorpher.morpher.setWeight(weight, forTargetAt: index)
        }
    }

    private func applyEyeDebug() {
        for state in eyeNodeStates {
            state.node?.position.z = state.baseZ + Float(eyeDepthOffset)
            switch eyeDebugMode {
            case .normal:
                state.material.diffuse.contents = state.diffuseContents
                state.material.emission.contents = state.emissionContents
                state.material.transparency = state.transparency
            case .highlighted:
                state.material.diffuse.contents = UIColor.systemRed
                state.material.emission.contents = UIColor.systemRed
                state.material.transparency = 1
            case .hidden:
                state.material.diffuse.contents = state.diffuseContents
                state.material.emission.contents = state.emissionContents
                state.material.transparency = 0
            }
        }
    }
}
