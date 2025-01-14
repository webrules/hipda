import SwiftUI
import Foundation

struct PostListView: View {
    let id: String
    let title: String
    @State private var posts: [Post] = []
    @State private var currentPage = 1
    @State private var hasNextPage = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(topic:Topic) {
        self.id = topic.id
        self.title = topic.title
    }

    var body: some View {
        List {
            ForEach(posts) { post in
                    VStack(alignment: .leading) {
                        Text(post.author + ": " + post.content)
                            .font(.headline)
                }
                .onAppear {
                    if post == posts.last && hasNextPage {
                        loadMorePosts()
                    }
                }
            }
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                }
            }
        }
        .navigationTitle(self.title)
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            if posts.isEmpty {
                loadMorePosts()
            }
        }
    }
    
    func innerText(from html: String) -> String {
        // Step 1: Remove HTML tags using regex
        let tagPattern = #"<[^>]+>"#
        do {
            let regex = try NSRegularExpression(pattern: tagPattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: html.utf16.count)
            let textWithoutTags = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "")
            
            // Step 2: Decode HTML entities (e.g., &nbsp;, &amp;, etc.)
            if let data = textWithoutTags.data(using: .utf8) {
                do {
                    let decodedString = try NSAttributedString(
                        data: data,
                        options: [
                            .documentType: NSAttributedString.DocumentType.html,
                            .characterEncoding: String.Encoding.utf8.rawValue
                        ],
                        documentAttributes: nil
                    ).string
                    return decodedString.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch {
                    print("Failed to decode HTML entities: \(error.localizedDescription)")
                    // Fallback: Return the text without tags if decoding fails
                    return textWithoutTags.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch {
            print("Failed to create regex: \(error.localizedDescription)")
        }
        
        // Fallback: Return the original string if something goes wrong
        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func loadMorePosts() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                let url = URL(string: "https://www.4d4y.com/forum/viewthread.php?tid=\(id)&extra=page%3D1&page=\(currentPage)")!
                // Use the same cookie-aware session configuration
                let config = URLSessionConfiguration.default
                config.httpCookieStorage = HTTPCookieStorage.shared
                let session = URLSession(configuration: config)
            
                let (data, _) = try await session.data(from: url)
                
                // Use CFStringConvertEncodingToNSStringEncoding for GBK
                let gbkEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
                if let htmlString = String(data: data, encoding: String.Encoding(rawValue: gbkEncoding)) {
                    let newPosts = try parsePosts(from: htmlString)
                    self.hasNextPage = htmlString.contains("class=\"next\"")
                    self.isLoading = !self.hasNextPage
                    await MainActor.run {
                        self.posts.append(contentsOf: newPosts)
                        if self.hasNextPage {self.currentPage += 1}
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
    
    private func parsePosts(from html: String) throws -> [Post] {
        let pattern = #"(?s)<td class="postauthor".*?<div class="postinfo">.*?<a[^>]*?>(.*?)</a>.*?</div>.*?<td class="t_msgfont" id="postmessage_(\d+)">(.*?)</td>"#
        let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        
        var posts: [Post] = []
        
        for match in matches {
            guard let author = Range(match.range(at: 1), in: html),
                let id = Range(match.range(at: 2), in: html),
                let content = Range(match.range(at: 3), in: html) else {
                continue // Skip invalid matches
            }

            // Ensure we have valid values before creating Topic
            guard !id.isEmpty, !content.isEmpty else {
                continue // Skip invalid matches
            }
            
            let post = Post(
                id: String(html[id]),
                author: innerText(from:String(html[author])),
                content: innerText(from:String(html[content]))
            )
            //print(content)
            posts.append(post)
        }
        
        return posts
    }
}
