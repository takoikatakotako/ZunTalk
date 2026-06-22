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
    }

    private func loadIfNeeded() {
        guard scene == nil else { return }
        let expr = expression
        let spk = speaking
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

/// SceneView の delegate 兼モーフ駆動リグ。毎フレーム呼ばれる `updateAtTime` で
/// 表情・口パク・まばたき・揺れを反映する（これにより連続描画も保証される）。
final class SceneRig: NSObject, SCNSceneRendererDelegate, ObservableObject {
    // 外から設定される望ましい状態（main から書き、render スレッドで読む）。
    var expression: ZundamonExpression = .idle
    var speaking = false

    private var morpher: SCNMorpher?
    private weak var modelRoot: SCNNode?

    /// 表情に関係するモーフ（毎フレーム一旦 0 に戻す対象）。
    private let expressionMorphs = [
        "Joy", "Angry", "Sorrow", "Fun", "困り眉1", "困り眉2",
        "見開き白目", "ジト目1", "にっこり", "涙", "なごみ目"
    ]

    private var frameCount = 0

    func attach(to scene: SCNScene) {
        scene.rootNode.enumerateChildNodes { node, _ in
            if let m = node.morpher, !m.targets.isEmpty {
                self.morpher = m
            }
        }
        modelRoot = scene.rootNode.childNode(withName: "modelRoot", recursively: false)
        print("🟢 attach morpher=\(morpher != nil) modelRoot=\(modelRoot != nil)")
    }

    // 毎フレーム呼ばれる。
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // DEBUG: 揺れを大きくして「画面が毎フレーム更新されているか」をはっきり確認する。
        modelRoot?.eulerAngles.y = Float(sin(time * 1.2) * 0.3)

        guard let morpher else { return }

        // 表情（まばたき/口パクは一旦止めて、表情だけ確認）
        for name in expressionMorphs { morpher.setWeight(0, forTargetNamed: name) }
        switch expression {
        case .idle, .neutral:
            break
        case .thinking:
            morpher.setWeight(0.6, forTargetNamed: "ジト目1")
        case .happy:
            morpher.setWeight(1.0, forTargetNamed: "Joy")
        case .sad:
            morpher.setWeight(1.0, forTargetNamed: "Sorrow")
            morpher.setWeight(0.6, forTargetNamed: "涙")
        case .surprised:
            morpher.setWeight(1.0, forTargetNamed: "見開き白目")
        case .troubled:
            morpher.setWeight(1.0, forTargetNamed: "困り眉1")
        }
    }
}
