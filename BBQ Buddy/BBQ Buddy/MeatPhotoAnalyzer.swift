import Foundation
import UIKit

class MeatPhotoAnalyzer {
    static let shared = MeatPhotoAnalyzer()
    private init() {}
    
    func analyze(photo: UIImage, completion: @escaping (String?) -> Void) {
        // Replace with your cloud endpoint URL
        guard let url = URL(string: "https://your-cloud-endpoint.com/analyze") else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let imageData = photo.jpegData(compressionQuality: 0.8) ?? Data()
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"meat.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, let feedback = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            completion(feedback)
        }.resume()
    }
} 