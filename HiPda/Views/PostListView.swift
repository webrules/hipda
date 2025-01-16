import Foundation
import SwiftSoup
import SwiftUI

extension String.Encoding {
    static let gbk: String.Encoding = {
        let cfEncoding = CFStringEncodings.GB_18030_2000
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfEncoding.rawValue))
        return String.Encoding(rawValue: nsEncoding)
    }()
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .topLeading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct PostListView: View {
    let id: String
    let title: String
    @State private var posts: [Post] = []
    @State private var currentPage = 1
    @State private var hasNextPage = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var replyText: String = "" // State for the reply textbox
    @State private var showReplyError: Bool = false // State for showing reply errors
    @State private var replyErrorMessage: String = "" // State for reply error messages

    init(topic: Topic) {
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
        HStack(alignment: .center, spacing: 8) {
            // TextBox (80% width, same height as button)
            TextEditor(text: $replyText)
                .frame(height: 44) // Set a fixed height for the text editor
                .padding(4)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .font(.system(size: 16)) // Set font size
                .placeholder(when: replyText.isEmpty) {
                    Text("Type your reply...") // Placeholder text with \n
                        .foregroundColor(.gray)
                        .padding(.leading, 4)
                        .padding(.top, 8)
                }

            // Reply Button (20% width, same height as textbox)
            Button(action: {
                submitReply()
            }) {
                Text("回复")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(0)
            }
            .frame(width: UIScreen.main.bounds.width * 0.2, height: 44) // 20% of screen width, fixed height
        }
        .padding()
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

    func submitReply() {
        // URL
        let url = URL(string: "https://www.4d4y.com/forum/post.php?action=reply&fid=2&tid=" + self.id + "&extra=page%3D1&replysubmit=yes&infloat=yes&handlekey=fastpost&inajax=1")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7", forHTTPHeaderField: "accept")
        request.setValue("en-US,en;q=0.9,zh-CN;q=0.8,zh-TW;q=0.7,zh;q=0.6", forHTTPHeaderField: "accept-language")
        request.setValue("max-age=0", forHTTPHeaderField: "cache-control")
        request.setValue("cdb_cookietime=2592000; smile=1D1; cdb_auth=1b72qUwioHPTq3IT6rdA160HFQU06cxk5rJFbbM%2FEUNVnW04%2FgD4e8J%2BR47WhqlKh8l%2FwcXEvQA%2FWP7JxwWfj2DhmFME; cdb_fid7=1736992446; discuz_fastpostrefresh=0; cdb_sid=jCeNJ9; cdb_visitedfid=2D7D6; cdb_oldtopics=D3350357D22501D3350420D; cdb_fid2=1736994219", forHTTPHeaderField: "cookie")
        request.setValue("https://www.4d4y.com", forHTTPHeaderField: "origin")
        request.setValue("u=0, i", forHTTPHeaderField: "priority")
        request.setValue("https://www.4d4y.com/forum/viewthread.php?tid=3350357&extra=page%3D1&page=2", forHTTPHeaderField: "referer")
        request.setValue("\"Microsoft Edge\";v=\"131\", \"Chromium\";v=\"131\", \"Not_A Brand\";v=\"24\"", forHTTPHeaderField: "sec-ch-ua")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
        request.setValue("iframe", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("navigate", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("?1", forHTTPHeaderField: "sec-fetch-user")
        request.setValue("1", forHTTPHeaderField: "upgrade-insecure-requests")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0", forHTTPHeaderField: "user-agent")

        guard let gbkData = replyText.data(using: .gbk) else {
            print("Failed to convert message to GBK")
            return
        }
        
        let gbkMessage = gbkData.map { String(format: "%%%02X", $0) }.joined()
        
        let body = "formhash=05ce06e1&subject=&usesig=0&message=\(gbkMessage)"
        request.httpBody = body.data(using: .utf8)

        
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        let session = URLSession(configuration: config)

        // Send the request
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                //print("Status Code: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    DispatchQueue.main.async {
                        hideKeyboard()
                    }
                    replyText = ""
                    loadMorePosts()
                }
            }
        }
        task.resume()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                content: decodeHTMLEntities(String(html[content]))
            )
            posts.append(post)
        }

        return posts
    }
}
