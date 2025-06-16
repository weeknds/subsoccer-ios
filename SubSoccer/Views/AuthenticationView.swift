import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var otpCode = ""
    @State private var showingOTPView = false
    @State private var isSignUp = false
    @State private var useOTPAuthentication = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var currentNonce: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                if showingOTPView {
                    otpVerificationView
                } else if useOTPAuthentication {
                    emailOTPView
                } else {
                    emailPasswordView
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var emailPasswordView: some View {
        VStack(spacing: AppTheme.largePadding) {
            Spacer()
            
            // App Logo/Icon
            Image(systemName: "sportscourt")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.accentColor)
                .padding(.bottom, AppTheme.largePadding)
            
            Text("SubSoccer")
                .font(AppTheme.headerFont)
                .foregroundColor(AppTheme.primaryText)
                .padding(.bottom, AppTheme.standardPadding)
            
            Text(isSignUp ? "Create your account to sync data" : "Sign in to sync your data across devices")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, AppTheme.largePadding)
            
            // Email Input
            VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                Text("Email Address")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(AppTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disabled(isLoading)
            }
            .padding(.horizontal, AppTheme.largePadding)
            
            // Password Input
            VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                Text("Password")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(AppTextFieldStyle())
                    .disabled(isLoading)
            }
            .padding(.horizontal, AppTheme.largePadding)
            
            // Sign In/Up Button
            Button(action: {
                Task {
                    await signInWithEmailPassword()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryBackground))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isSignUp ? "person.badge.plus" : "person")
                            .font(.title3)
                        
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(AppTheme.subheadFont)
                    }
                }
                .foregroundColor(AppTheme.primaryBackground)
                .frame(maxWidth: .infinity)
                .padding()
                .background((email.isEmpty || password.isEmpty || isLoading) ? AppTheme.secondaryText : AppTheme.accentColor)
                .cornerRadius(AppTheme.cornerRadius)
            }
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .padding(.horizontal, AppTheme.largePadding)
            
            // Apple Sign-In Button
            SignInWithAppleButton(
                onRequest: { request in
                    let nonce = supabaseService.generateNonce()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = supabaseService.sha256(nonce)
                },
                onCompletion: { result in
                    Task {
                        await handleAppleSignIn(result)
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, AppTheme.largePadding)
            .disabled(isLoading)
            
            // Divider
            HStack {
                VStack { Divider() }
                Text("OR")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
                    .padding(.horizontal, 8)
                VStack { Divider() }
            }
            .padding(.horizontal, AppTheme.largePadding)
            
            // Toggle Sign In/Up
            Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                isSignUp.toggle()
                errorMessage = ""
            }
            .font(AppTheme.bodyFont)
            .foregroundColor(AppTheme.accentColor)
            .disabled(isLoading)
            
            // Error Message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(AppTheme.captionFont)
                    .foregroundColor(.red)
                    .padding(.horizontal, AppTheme.largePadding)
            }
            
            Spacer()
            
            // Alternative authentication methods
            VStack(spacing: AppTheme.standardPadding) {
                Button("Use Magic Link Instead") {
                    useOTPAuthentication = true
                    errorMessage = ""
                }
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.secondaryText)
                
                Button("Continue Offline") {
                    // This would dismiss the auth view and continue with local-only mode
                }
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.secondaryText)
            }
            .padding(.bottom, AppTheme.largePadding)
        }
    }
    
    private var emailOTPView: some View {
        VStack(spacing: AppTheme.largePadding) {
            Spacer()
            
            // App Logo/Icon
            Image(systemName: "sportscourt")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.accentColor)
                .padding(.bottom, AppTheme.largePadding)
            
            Text("SubSoccer")
                .font(AppTheme.headerFont)
                .foregroundColor(AppTheme.primaryText)
                .padding(.bottom, AppTheme.standardPadding)
            
            Text("Sign in to sync your data across devices")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, AppTheme.largePadding)
            
            // Email Input
            VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                Text("Email Address")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(AppTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disabled(isLoading)
            }
            .padding(.horizontal, AppTheme.largePadding)
            
            // Sign In Button
            Button(action: {
                Task {
                    await signInWithEmailOTP()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryBackground))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "envelope")
                            .font(.title3)
                        
                        Text("Send Magic Link")
                            .font(AppTheme.subheadFont)
                    }
                }
                .foregroundColor(AppTheme.primaryBackground)
                .frame(maxWidth: .infinity)
                .padding()
                .background(email.isEmpty || isLoading ? AppTheme.secondaryText : AppTheme.accentColor)
                .cornerRadius(AppTheme.cornerRadius)
            }
            .disabled(email.isEmpty || isLoading)
            .padding(.horizontal, AppTheme.largePadding)
            
            // Apple Sign-In Button
            SignInWithAppleButton(
                onRequest: { request in
                    let nonce = supabaseService.generateNonce()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = supabaseService.sha256(nonce)
                },
                onCompletion: { result in
                    Task {
                        await handleAppleSignIn(result)
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, AppTheme.largePadding)
            .disabled(isLoading)
            
            // Divider
            HStack {
                VStack { Divider() }
                Text("OR")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.secondaryText)
                    .padding(.horizontal, 8)
                VStack { Divider() }
            }
            .padding(.horizontal, AppTheme.largePadding)
            
            // Error Message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(AppTheme.captionFont)
                    .foregroundColor(.red)
                    .padding(.horizontal, AppTheme.largePadding)
            }
            
            Spacer()
            
            // Offline Mode Button
            Button("Continue Offline") {
                // This would dismiss the auth view and continue with local-only mode
            }
            .font(AppTheme.bodyFont)
            .foregroundColor(AppTheme.secondaryText)
            .padding(.bottom, AppTheme.largePadding)
        }
    }
    
    private var otpVerificationView: some View {
        VStack(spacing: AppTheme.largePadding) {
            Spacer()
            
            Image(systemName: "envelope.badge")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.accentColor)
                .padding(.bottom, AppTheme.largePadding)
            
            Text("Check Your Email")
                .font(AppTheme.titleFont)
                .foregroundColor(AppTheme.primaryText)
                .padding(.bottom, AppTheme.standardPadding)
            
            Text("We sent a 6-digit code to")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.secondaryText)
            
            Text(email)
                .font(AppTheme.subheadFont)
                .foregroundColor(AppTheme.primaryText)
                .padding(.bottom, AppTheme.largePadding)
            
            // OTP Input
            VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                Text("Verification Code")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                TextField("Enter 6-digit code", text: $otpCode)
                    .textFieldStyle(AppTextFieldStyle())
                    .keyboardType(.numberPad)
                    .disabled(isLoading)
            }
            .padding(.horizontal, AppTheme.largePadding)
            
            // Verify Button
            Button(action: {
                Task {
                    await verifyOTP()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryBackground))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.shield")
                            .font(.title3)
                        
                        Text("Verify Code")
                            .font(AppTheme.subheadFont)
                    }
                }
                .foregroundColor(AppTheme.primaryBackground)
                .frame(maxWidth: .infinity)
                .padding()
                .background(otpCode.isEmpty || isLoading ? AppTheme.secondaryText : AppTheme.accentColor)
                .cornerRadius(AppTheme.cornerRadius)
            }
            .disabled(otpCode.isEmpty || isLoading)
            .padding(.horizontal, AppTheme.largePadding)
            
            // Resend Button
            Button("Resend Code") {
                Task {
                    await signInWithEmailOTP()
                }
            }
            .font(AppTheme.bodyFont)
            .foregroundColor(AppTheme.accentColor)
            .disabled(isLoading)
            
            // Error Message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(AppTheme.captionFont)
                    .foregroundColor(.red)
                    .padding(.horizontal, AppTheme.largePadding)
            }
            
            Spacer()
            
            // Back Button
            Button("← Use Different Email") {
                showingOTPView = false
                otpCode = ""
                errorMessage = ""
            }
            .font(AppTheme.bodyFont)
            .foregroundColor(AppTheme.secondaryText)
            
            Button("← Back to Password Login") {
                useOTPAuthentication = false
                showingOTPView = false
                otpCode = ""
                errorMessage = ""
            }
            .font(AppTheme.bodyFont)
            .foregroundColor(AppTheme.secondaryText)
            .padding(.bottom, AppTheme.largePadding)
        }
    }
    
    private func signInWithEmailPassword() async {
        isLoading = true
        errorMessage = ""
        
        do {
            if isSignUp {
                try await supabaseService.signUpWithEmail(email, password: password)
            } else {
                try await supabaseService.signInWithEmail(email, password: password)
            }
            // Authentication successful - the ObservableObject will update the UI
        } catch {
            errorMessage = isSignUp ? "Failed to create account. Please try again." : "Invalid email or password. Please try again."
        }
        
        isLoading = false
    }
    
    private func signInWithEmailOTP() async {
        isLoading = true
        errorMessage = ""
        
        do {
            try await supabaseService.signInWithEmailOTP(email)
            showingOTPView = true
        } catch {
            errorMessage = "Failed to send magic link. Please try again."
        }
        
        isLoading = false
    }
    
    private func verifyOTP() async {
        isLoading = true
        errorMessage = ""
        
        do {
            try await supabaseService.verifyOTP(email: email, token: otpCode)
            // Authentication successful - the ObservableObject will update the UI
        } catch {
            errorMessage = "Invalid code. Please try again."
        }
        
        isLoading = false
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = ""
        
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let identityToken = appleIDCredential.identityToken,
               let tokenString = String(data: identityToken, encoding: .utf8),
               let nonce = currentNonce {
                
                do {
                    try await supabaseService.signInWithApple(idToken: tokenString, nonce: nonce)
                    // Authentication successful - the ObservableObject will update the UI
                } catch {
                    errorMessage = "Apple Sign-In failed. Please try again."
                }
            } else {
                errorMessage = "Apple Sign-In failed. Please try again."
            }
            
        case .failure(let error):
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    // User canceled, don't show error
                    break
                case .failed:
                    errorMessage = "Apple Sign-In failed. Please try again."
                case .invalidResponse:
                    errorMessage = "Invalid response from Apple. Please try again."
                case .notHandled:
                    errorMessage = "Apple Sign-In not handled. Please try again."
                case .unknown:
                    errorMessage = "Unknown error occurred. Please try again."
                @unknown default:
                    errorMessage = "Apple Sign-In failed. Please try again."
                }
            } else {
                errorMessage = "Apple Sign-In failed. Please try again."
            }
        }
        
        isLoading = false
    }
}

#Preview {
    AuthenticationView()
}