import Foundation

struct Topic: Equatable, Identifiable {
    var id: String
    var title: String
    
    init(id: String, title: String/*, isNew: Bool, url: String, questions: [String] = [], answers: [String] = []*/) {
            self.id = id
            self.title = title
        }
}
