import Foundation
import SwiftSoup
import SwiftUI

struct PostListView: View {
    let id: String
    let title: String
    @State private var posts: [Post] = []
    @State private var currentPage = 1
    @State private var hasNextPage = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(topic: Topic) {
//        print (topic.id + " " + topic.title)
        self.id = topic.id
        self.title = topic.title
    }

    var body: some View {
        List {
            ForEach(posts) { post in
                VStack(alignment: .leading) {
                    Text(post.author)
                        .font(.headline)
                    VStack {
                        ForEach(
                            Array(
                                extractContent(from: post.content).enumerated()),
                            id: \.offset
                        ) { index, content in
                            if let text = content as? String {
                                Text(text)
                                    .font(.body)
                            } else if let imageUrl = content as? URL {
                                AsyncImage(url: imageUrl) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                    case .failure:
                                        Image(systemName: "xmark.circle")
                                            .foregroundColor(.red)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
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
        }

        .navigationTitle(self.title)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"), message: Text(errorMessage),
                dismissButton: .default(Text("OK")))
        }
        .onAppear {
            if posts.isEmpty {
                loadMorePosts()
            }
        }
    }

    func extractContent(from html: String) -> [Any] {
        var components: [Any] = []
        let text = innerText(from: html)
        components.append(text)

        let pattern = #"<a[^>]*>.*?<img[^>]+src="([^">]+)"[^>]*>.*?</a>"#

        do {
            let regex = try NSRegularExpression(
                pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(
                in: html, range: NSRange(html.startIndex..., in: html))

            // First, extract all images
            for match in matches {
                if let imgRange = Range(match.range(at: 1), in: html) {
                    let imgUrl = String(html[imgRange])
                    if let url = URL(string: imgUrl) {
                        if url.absoluteString
                            != "https://www.4d4y.com/forum/images/common/back.gif"
                        {
                            components.append(url)
                        }
                    }
                }
            }
        } catch {
            print("Failed to create regex: \(error.localizedDescription)")
        }

        return components
    }

    func innerText(from html: String) -> String {
         let html = html.replacingOccurrences(of: "D版有你更美丽～", with: "")
             .replacingOccurrences(of: "iOS fly ~", with: "")
             .replacingOccurrences(of: "论坛助手", with: "")
             .replacingOccurrences(of: "每日地板", with: "")
             .replacingOccurrences(
                     of: " +", // Matches one or more spaces
                     with: " ",
                     options: .regularExpression
                 )
            .replacingOccurrences(
                    of: "\\n+",
                    with: "\n",
                    options: .regularExpression
                )
            .replacingOccurrences(
                    of: "\\n +",
                    with: "\n",
                    options: .regularExpression
                )

        // Step 1: Remove HTML tags using regex
        let tagPattern = #"<[^>]+>"#
        do {
            //let html = removeUselessText(html)
            //let cleanHtml = decodeHTMLEntities(html)
            let cleanHtml = html
            let regex = try NSRegularExpression(
                pattern: tagPattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: cleanHtml.utf16.count)
            return trim(regex.stringByReplacingMatches(
                in: cleanHtml, options: [], range: range, withTemplate: ""))
            
        } catch {
            print("Failed to create regex: \(error.localizedDescription)")
            return trim(html)
        }
    }
    func decodeHTMLEntities(_ string: String) -> String {
        do {
            let decodedString = try Entities.unescape(string)
            return decodedString
        } catch {
            print("Failed to decode HTML entities: \(error.localizedDescription)")
            return string
        }
    }
    
    private func trim(_ html: String) -> String {
        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func removeUselessText(_ html: String) -> String {
        do {
            let document = try SwiftSoup.parse(html)
            
            // Select and remove unwanted elements
            try document.select("div.t_attach, div.t_smallfont").remove()
            
//            return try document.select("div.postmessage").outerHtml()
            return try document.outerHtml()
        } catch {
            return html
        }
    }
    
    private func loadMorePosts() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            do {
                let url = URL(
                    string:
                        "https://www.4d4y.com/forum/viewthread.php?tid=\(id)&extra=page%3D1&page=\(currentPage)"
                )!
                print(url)
                // Use the same cookie-aware session configuration
                let config = URLSessionConfiguration.default
                config.httpCookieStorage = HTTPCookieStorage.shared
                let session = URLSession(configuration: config)

                let (data, _) = try await session.data(from: url)

                // Use CFStringConvertEncodingToNSStringEncoding for GBK
                let gbkEncoding = CFStringConvertEncodingToNSStringEncoding(
                    CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
                if let htmlString = String(
                    data: data, encoding: String.Encoding(rawValue: gbkEncoding)
                ) {
                    let newPosts = try parsePosts(
//                        from: removeUselessText(decodeHTMLEntities(htmlString)))
                        from: removeUselessText(htmlString))
                    self.hasNextPage = htmlString.contains("class=\"next\"")
                    self.isLoading = !self.hasNextPage
                    await MainActor.run {
                        self.posts.append(contentsOf: newPosts)
                        if self.hasNextPage { self.currentPage += 1 }
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
//        print("html: " + html)
        let pattern =
            #"(?s)<td class="postauthor".*?<div class="postinfo">.*?<a[^>]*?>(.*?)</a>.*?</div>.*?<td class="t_msgfont" id="postmessage_(\d+)">(.*?)</td>"#
        let regex = try NSRegularExpression(
            pattern: pattern, options: .dotMatchesLineSeparators)

        let matches = regex.matches(
            in: html, range: NSRange(html.startIndex..., in: html))

        var posts: [Post] = []

        for match in matches {
            guard let author = Range(match.range(at: 1), in: html),
                let id = Range(match.range(at: 2), in: html),
                let content = Range(match.range(at: 3), in: html)
            else {
                continue  // Skip invalid matches
            }

            // Ensure we have valid values before creating Topic
            guard !id.isEmpty, !content.isEmpty else {
                continue  // Skip invalid matches
            }

            let post = Post(
                id: String(html[id]),
                author: innerText(from: String(html[author])),
                content: innerText(from:decodeHTMLEntities(String(html[content])))
                //content: String(html[content])
            )
            //print(content)
            posts.append(post)
        }

        return posts
    }
}
