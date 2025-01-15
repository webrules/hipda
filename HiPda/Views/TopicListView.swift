import SwiftUI
import SwiftSoup
import Foundation

struct TopicListView: View {
    @State private var topics: [Topic] = []
    @State private var currentPage = 1
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        let content = List {
            topicListContent
            loadingIndicator
        }
        
        return content
            .navigationTitle("Discovery")
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                if topics.isEmpty {
                    loadMoreTopics()
                }
            }
    }

    private var topicListContent: some View {
        ForEach(topics) { topic in
            NavigationLink(destination: PostListView(topic: topic)) {
                VStack(alignment: .leading) {
                    Text(topic.title)
                        .font(.headline)
                }
            }
            .onAppear {
                //print(topic.title)
                //print(topics.last?.title ?? "nothing")
                if topic == topics.last {
                    loadMoreTopics()
                }
            }
        }
    }

    private var loadingIndicator: some View {
        Group {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                }
            }
        }
    }
    
    private func loadMoreTopics() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                let url = URL(string: "https://www.4d4y.com/forum/forumdisplay.php?fid=2&page=\(currentPage)")!
                // Use the same cookie-aware session configuration
                let config = URLSessionConfiguration.default
                config.httpCookieStorage = HTTPCookieStorage.shared
                let session = URLSession(configuration: config)
            
                let cookies = HTTPCookieStorage.shared.cookies(for: url)
//                for cookie in cookies ?? [] {
//                    print("Cookie Name: \(cookie.name), Value: \(cookie.value)")
//                }
                
//                print("network request started")
                let (data, _) = try await session.data(from: url)
//                print("network request completed")
                
                // Use CFStringConvertEncodingToNSStringEncoding for GBK
                let gbkEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
                if let htmlString = String(data: data, encoding: String.Encoding(rawValue: gbkEncoding)) {
                    let newTopics = try parseTopics(from: htmlString)
                    await MainActor.run {
                        self.topics.append(contentsOf: newTopics)
                        print(self.currentPage)
                        self.currentPage = self.currentPage + 1
                        print(self.currentPage)
                    }
                }
            } catch {
                await MainActor.run {
                    showError = true
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
        }
    }
    
    func decodeHTMLEntities(_ string: String) -> String {
        do {
            let decodedString = try Entities.unescape(string)
//            print("After:" + decodedString)
            return decodedString
        } catch {
            print("Failed to decode HTML entities: \(error.localizedDescription)")
            return string
        }
    }
    
    private func parseTopics(from html: String) throws -> [Topic] {
        let pattern = #"<a href="viewthread\.php\?tid=(\d+)&amp;extra=page%3D\#(currentPage)">(.*?)</a>"#
        //let pattern = #"<a href="viewthread\.php\?tid=(\d+)&amp;(.*?)>(.*?)</a>"#
        let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        
        var topics: [Topic] = []
        
        for match in matches {
            guard let linkRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else {
                continue // Skip invalid matches
            }
            
            let link = String(html[linkRange])
//            print(link)
//            print("before:" + String(html[titleRange]))
            let title = decodeHTMLEntities(String(html[titleRange]))
            
            // Ensure we have valid values before creating Topic
            guard !link.isEmpty, !title.isEmpty else {
                continue // Skip invalid matches
            }
            
            let topic = Topic(
                id: link,
                title: title
            )
            topics.append(topic)
        }
        
        return topics
    }
}
