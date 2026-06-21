import SwiftUI
import SceneKit

/// ずんだもんの3Dモデル（VRM=glb）を自作 GLBLoader で読み込み SceneKit で表示する。
/// まずはモデル表示と morph(blendshape) 名のログ確認用スパイク。
struct Zundamon3DView: UIViewRepresentable {

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.autoenablesDefaultLighting = true
        scnView.antialiasingMode = .multisampling2X
        // スパイク中はドラッグで回せるようにして、読み込めたか確認しやすくする。
        scnView.allowsCameraControl = true

        loadModel(into: scnView)
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    private func loadModel(into scnView: SCNView) {
        guard let url = Bundle.main.url(forResource: "zundamon", withExtension: "glb") else {
            print("⚠️ zundamon.glb が見つからないのだ")
            return
        }
        do {
            let scene = try GLBLoader.loadScene(url: url)
            scnView.scene = scene

            // どんな morph(blendshape) があるかをログ出力（マッピング確定用）。
            scene.rootNode.enumerateChildNodes { node, _ in
                if let morpher = node.morpher, !morpher.targets.isEmpty {
                    print("🎭 node=\(node.name ?? "?") morphs=\(morpher.targets.compactMap { $0.name })")
                }
            }

            // カメラ（顔まわりを正面から映す。位置は実機で見ながら調整する）。
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.position = SCNVector3(0, 1.35, 1.4)
            scene.rootNode.addChildNode(cameraNode)
            scnView.pointOfView = cameraNode
        } catch {
            print("⚠️ VRM 読み込みエラー: \(error)")
        }
    }
}
