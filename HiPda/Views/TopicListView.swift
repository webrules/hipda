import SwiftUI
import SwiftSoup
import Foundation

struct TopicListView: View {
    @State private var topics: [Topic] = []
    @State private var currentPage = 1
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var newTopicSubject: String = "" // State for the reply textbox
    @State private var newTopicText: String = "" // State for the reply textbox
    @State private var showNewTopicError: Bool = false // State for showing reply errors
    @State private var newTopicErrorMessage: String = "" // State for reply error messages

    var body: some View {
        let content = VStack {
            List {
                topicListContent
                loadingIndicator
            }
            CreateNewTopic
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

    func submitNewTopic() {
        let url = URL(string: "https://www.4d4y.com/forum/post.php?action=newthread&fid=2&extra=&topicsubmit=yes")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7", forHTTPHeaderField: "accept")
        request.setValue("en-US,en;q=0.9,zh-CN;q=0.8,zh-TW;q=0.7,zh;q=0.6", forHTTPHeaderField: "accept-language")
        request.setValue("max-age=0", forHTTPHeaderField: "cache-control")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
        request.setValue("cdb_cookietime=2592000; smile=1D1; cdb_auth=1b72qUwioHPTq3IT6rdA160HFQU06cxk5rJFbbM%2FEUNVnW04%2FgD4e8J%2BR47WhqlKh8l%2FwcXEvQA%2FWP7JxwWfj2DhmFME; discuz_fastpostrefresh=0; cdb_sid=67TAjS; cdb_visitedfid=62D2D7D6", forHTTPHeaderField: "cookie")
        request.setValue("https://www.4d4y.com", forHTTPHeaderField: "origin")
        request.setValue("u=0, i", forHTTPHeaderField: "priority")
        request.setValue("https://www.4d4y.com/forum/post.php?action=newthread&fid=62", forHTTPHeaderField: "referer")
        request.setValue("\"Microsoft Edge\";v=\"131\", \"Chromium\";v=\"131\", \"Not_A Brand\";v=\"24\"", forHTTPHeaderField: "sec-ch-ua")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
        request.setValue("document", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("navigate", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("?1", forHTTPHeaderField: "sec-fetch-user")
        request.setValue("1", forHTTPHeaderField: "upgrade-insecure-requests")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0", forHTTPHeaderField: "user-agent")
        
        guard let gbkData1 = newTopicText.data(using: .gbk) else {
            print("Failed to convert message to GBK")
            return
        }
        let gbkMessage = gbkData1.map { String(format: "%%%02X", $0) }.joined()

        guard let gbkData2 = newTopicSubject.data(using: .gbk) else {
            print("Failed to convert message to GBK")
            return
        }
        let gbkSubject = gbkData2.map { String(format: "%%%02X", $0) }.joined()

        let body = "formhash=05ce06e1&posttime=1737007761&wysiwyg=1&iconid=&subject=\(gbkSubject)&typeid=56&message=\(gbkMessage)&tags=&attention_add=1"
        request.httpBody = body.data(using: .utf8)
        
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        let session = URLSession(configuration: config)

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    newTopicSubject = ""
                    newTopicText = ""
                }
            }
        }
        task.resume()
    }
    private var topicListContent: some View {
        ForEach(topics) { topic in
            NavigationLink(destination: PostListView(topic: topic)) {
                VStack(alignment: .leading) {
                    Text(topic.title)
                        .font(.headline)
//                        .background(Color(.systemBackground)) // Adapts to Dark Mode
                        .foregroundColor(Color(.label)) // Adapts to Dark Mode
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
    
    private var CreateNewTopic: some View {
        VStack {
            TextField("Subject", text: $newTopicSubject)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 16))
                .padding(.horizontal)
                .padding(.top, 8)
                .background(Color(.systemBackground)) // Adapts to Dark Mode
                .foregroundColor(Color(.label)) // Adapts to Dark Mode
            HStack(alignment: .center, spacing: 8) {
                TextEditor(text: $newTopicText)
                    .frame(height: 88) // Set a fixed height for the text editor
                    .padding(4)
                    .background(Color(.systemBackground))
                    .foregroundColor(Color(.label)) // Adapts to Dark Mode
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .font(.system(size: 16)) // Set font size
                    .placeholder(when: newTopicText.isEmpty) {
                        Text("Create new topic...") // Placeholder text with \n
                            .foregroundColor(Color(.placeholderText)) // Adapts to Dark Mode
                            .padding(.leading, 4)
                            .padding(.top, 8)
                    }
                
                // Reply Button (20% width, same height as textbox)
                Button(action: {
                    submitNewTopic()
                }) {
                    Text("发表")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(0)
                }
                .frame(width: UIScreen.main.bounds.width * 0.2, height: 88) // 20% of screen width, fixed height
            }
            .background(Color(.systemBackground)) // Adapts to Dark Mode
            .padding()
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
