import Foundation

struct Post: Equatable, Identifiable {
    var id: String
    var author: String
    var content: String
    
    init(id: String, author: String, content: String) {
            self.id = id
            self.author = author
            self.content = content
        }
}
