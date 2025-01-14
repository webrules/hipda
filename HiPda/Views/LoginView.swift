import SwiftUI
import CommonCrypto

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoginActive: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("HiPDA Discovery")
                .font(.largeTitle)
            
            TextField("Username", text: $username)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .disableAutocorrection(true)
                .autocapitalization(.none)
            
            SecureField("Password", text: $password)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            
            Button(action: {
                Task {
                    await submitLogin()
                }
            }) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Logging in...")
                        .foregroundColor(.gray)
                } else {
                    Text("Login")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .cornerRadius(8)
            .disabled(isLoading)
            .onAppear {
                checkCookies()
            }
            
            // Add NavigationLink separately
            NavigationLink(
                destination: TopicListView(),
                isActive: $isLoginActive,
                label: { EmptyView() }
            )
        }
        .padding()
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
private func checkCookies() {
    if let cookies = HTTPCookieStorage.shared.cookies {
        for cookie in cookies {
            // Check for your specific login cookie
            if cookie.domain.contains("4d4y.com") && cookie.name == "cdb_auth" {
                // Check if cookie is still valid
                if let expiresDate = cookie.expiresDate, expiresDate > Date() {
                    DispatchQueue.main.async {
                        self.isLoginActive = true
                    }
                    return
                }
            }
        }
    }
}

private func submitLogin() async {
    // Reset error state
    showError = false
    errorMessage = ""
    isLoading = true
        
    do {
        // Create the request
        let url = URL(string: "https://www.4d4y.com/forum/logging.php?action=login&loginsubmit=yes&inajax=1")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set form data
        //let body = "username=\(username)&password=\(password)&cookietime=2592000"
        // Generate form data
        let formhash = "9f814df3" // This should be dynamically obtained from the login page
        let referer = "https://www.4d4y.com/forum/"
        let loginfield = "username"
        //let username = "webrules"
        let hashedPassword = pwmd5(password) // Hash the password
        //let hashedPassword = pwmd5("123abc!@#")
        let questionid = "0"
        let answer = ""
        let cookietime = "2592000"
        
        let body = """
        formhash=\(formhash)&
        referer=\(referer)&
        loginfield=\(loginfield)&
        username=\(username)&
        password=\(hashedPassword)&
        questionid=\(questionid)&
        answer=\(answer)&
        cookietime=\(cookietime)
        """.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: " ", with: "")

        request.httpBody = body.data(using: .utf8)
        
        // Set headers
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Configure URLSession to handle cookies
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        let session = URLSession(configuration: config)
        
        // Make the request
        let (data, response) = try await session.data(for: request)
        
        // Check response
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                // Check if login was successful by looking for specific text in response
                let gbkEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
                
                if let responseString = String(data: data, encoding: String.Encoding(rawValue: gbkEncoding)),
                   responseString.contains("欢迎您回来") {
                    DispatchQueue.main.async {
                        self.isLoginActive = true
                    }
                    // Successful login
                    isLoginActive = true
                } else {
                    // Handle login failure
                    showError = true
                    errorMessage = "Login failed. Please check your credentials."
                    print(errorMessage)
                }
            } else {
                showError = true
                errorMessage = "Login failed. Please try again."
                print(errorMessage)
            }
        }
    } catch {
        // Handle network errors
        showError = true
        errorMessage = "Network error. Please try again."
        print(errorMessage)
    }
    
    isLoading = false
}

 @State private var pwmd5log: [String: String] = [:]

func pwmd5(_ input: String) -> String {
    // Check if the value is already hashed or if it's not 32 characters long
    if pwmd5log[input] == nil || input.count != 32 {
        let hashedValue = hex_md5(addslashes(input))
        pwmd5log[input] = hashedValue
        return hashedValue
    }
    return pwmd5log[input]!
}

func addslashes(_ string: String) -> String {
    return string
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\u{8}", with: "\\b")
        .replacingOccurrences(of: "\t", with: "\\t")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\u{c}", with: "\\f")
        .replacingOccurrences(of: "\r", with: "\\r")
        .replacingOccurrences(of: "'", with: "\\'")
        .replacingOccurrences(of: "\"", with: "\\\"")
}

  private func hex_md5(_ input: String) -> String {
      let data = Data(input.utf8)
      var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
      _ = data.withUnsafeBytes {
          CC_MD5($0.baseAddress, CC_LONG(data.count), &digest)
      }
      return digest.map { String(format: "%02hhx", $0) }.joined()
  }


}
