import Foundation

enum AppInfoError: Error {
    case networkError(Error)
    case decodingError
    case invalidResponse
}

protocol AppInfoRepositoryProtocol {
    func fetchAppInfo() async throws -> AppInfoResponse
}

class AppInfoRepository: AppInfoRepositoryProtocol {

    func fetchAppInfo() async throws -> AppInfoResponse {
        let url = URL(string: APIConfig.infoEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    print("AppInfo API Error: \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("Error Response: \(errorString)")
                    }
                    throw AppInfoError.invalidResponse
                }
            }

            let appInfo = try JSONDecoder().decode(AppInfoResponse.self, from: data)
            return appInfo
        } catch let error as AppInfoError {
            throw error
        } catch is DecodingError {
            throw AppInfoError.decodingError
        } catch {
            throw AppInfoError.networkError(error)
        }
    }
}
