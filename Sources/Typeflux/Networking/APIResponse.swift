import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let code: String
    let message: String?
    let data: T?
}
