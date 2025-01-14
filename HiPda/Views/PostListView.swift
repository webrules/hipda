import SwiftUI
import SwiftSoup
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
                    Text(post.author)
                        .font(.headline)
                    HStack{
                        ForEach(Array(extractContent(from: post.content).enumerated()), id: \.offset) { index, content in
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
            }}
        
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
    
    //     func extractContent(from html: String) -> [Any] {
    //         // This will return an array of either String (text) or URL (image)
    //         var components: [Any] = []
    
    //         let text = innerText(from: String(html))
    //         components.append(text)
    
    //         // Pattern to match both text and images
    //         //let pattern = #"(<img[^>]+src="([^">]+)"[^>]*>)|([^<]+)"#
    //         let pattern = #"<img[^>]+src="([^">]+)"[^>]*>"#
    
    //         do {
    //             let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    //             let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
    
    //             for match in matches {
    //                 // Check if it's an image
    //                 if let imgRange = Range(match.range(at: 2), in: html) {
    //                     let imgUrl = String(html[imgRange])
    //                     if let url = URL(string: imgUrl) {
    //                         components.append(url)
    //                     }
    //                 }
    //                 // Check if it's text
    // //                else if let textRange = Range(match.range(at: 3), in: html) {
    // //                    let text = String(html[textRange])
    // //                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    // //                        if isHTML(text){
    // //                            components.append(innerText(from:text))
    // //                        }
    // //                        else {
    // //                            components.append(text)
    // //                        }
    // //                    }
    // //                }
    //                 //else if let textRange = Range(match.range(at: 3), in: html) {
    // //                    let text = innerText(from: String(html))
    // //                    components.append(text)
    //                 //}
    //             }
    //         } catch {
    //             print("Failed to create regex: \(error.localizedDescription)")
    //         }
    
    //         return components
    //     }
    func extractContent(from html: String) -> [Any] {
        var components: [Any] = []
        let text = innerText(from: html)
        components.append(text)
        
        // Pattern to match images inside anchor elements and capture src value
        let pattern = #"<a[^>]*>.*?<img[^>]+src="([^">]+)"[^>]*>.*?</a>"#
        // let pattern = #"<a[^>]*<img[^>]+src="([^">]+)"[^>]*>"#
        //let pattern = #"<td[^>]*class="t_msgfont"[^>]*>.*?<img[^>]+src="([^">]+)"[^>]*>.*?</td>"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            
            // First, extract all images
            for match in matches {
                if let imgRange = Range(match.range(at: 1), in: html) {
                    let imgUrl = String(html[imgRange])
                    if let url = URL(string: imgUrl) {
                        if url.absoluteString != "https://www.4d4y.com/forum/images/common/back.gif" {
                            components.append(url)}
                    }
                }
            }
            
            // // Then extract text between images
            // let textParts = regex.stringByReplacingMatches(in: html, options: [], range: NSRange(html.startIndex..., in: html), withTemplate: "|SPLIT|")
            // let textComponents = textParts.components(separatedBy: "|SPLIT|")
            
            // for text in textComponents {
            //     let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            //     if !trimmedText.isEmpty {
            //         components.append(innerText(from:trimmedText))
            //     }
            // }
            
        } catch {
            print("Failed to create regex: \(error.localizedDescription)")
        }
        
        return components
    }
    
     func innerText(from html: String) -> String {
         let html = html.replacingOccurrences(of: "&nbsp;", with: " ")
             .replacingOccurrences(of: "&amp;", with: " ")
             .replacingOccurrences(of: "\n", with: "")
             .replacingOccurrences(of: "\r", with: "")
             .replacingOccurrences(of: "D版有你更美丽～", with: "")
             .replacingOccurrences(of: "论坛助手", with: "")
    
         // Step 1: Remove HTML tags using regex
         let tagPattern = #"<[^>]+>"#
         do {
             let regex = try NSRegularExpression(pattern: tagPattern, options: .caseInsensitive)
             let range = NSRange(location: 0, length: html.utf16.count)
             let textWithoutTags = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "")
    
             // Step 2: Only attempt HTML decoding if the text contains HTML entities
             if textWithoutTags.contains("&") {
                 // Convert to data with proper error handling
                 guard let data = textWithoutTags.data(using: .utf8) else {
                     return textWithoutTags.trimmingCharacters(in: .whitespacesAndNewlines)
                 }
    
                 // Add additional validation for HTML content
                 let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                     .documentType: NSAttributedString.DocumentType.html,
                     .characterEncoding: String.Encoding.utf8.rawValue
                 ]
    
                 // Create a safe parsing environment
                 do {
                     let decodedString = try NSAttributedString(
                         data: data,
                         options: options,
                         documentAttributes: nil
                     ).string
    
                     return decodedString.trimmingCharacters(in: .whitespacesAndNewlines)
                 } catch {
                     print("HTML decoding failed: \(error.localizedDescription)")
                     // Fallback to text without tags if decoding fails
                     return textWithoutTags.trimmingCharacters(in: .whitespacesAndNewlines)
                 }
             }
    
             return textWithoutTags.trimmingCharacters(in: .whitespacesAndNewlines)
         } catch {
             print("Failed to create regex: \(error.localizedDescription)")
             return html.trimmingCharacters(in: .whitespacesAndNewlines)
         }
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
                //content: innerText(from:String(html[content]))
                content: String(html[content])
            )
            //print(content)
            posts.append(post)
        }
        
        return posts
    }
}
