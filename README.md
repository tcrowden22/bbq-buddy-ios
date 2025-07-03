# BBQ Buddy iOS App

BBQ Buddy is your intelligent cooking companion that helps you achieve perfect results every time you fire up your smoker or grill. With real-time temperature monitoring, AI-powered cooking assistance, and smart cook planning, you'll never have to guess when your meat is done.

## Features

### 🌡️ Real-Time Temperature Monitoring
- Live temperature tracking with beautiful visualizations
- Temperature trend analysis
- Customizable alerts for target and wrapping temperatures
- Historical temperature data for analysis

### 🤖 AI Cooking Assistant
- Context-aware cooking advice
- Real-time suggestions based on temperature trends
- Answers to common BBQ questions
- Personalized cooking tips

### 📝 Smart Cook Planning
- Customizable cook plans for different meat types
- Estimated completion times
- Automatic wrap and rest time calculations
- Cook notes with timestamps for future reference

### 📊 Cook History
- Detailed session logs
- Temperature graphs
- Cook notes and observations
- AI-generated cook summaries

### 👤 User Profiles
- Save favorite cook plans
- Track cooking history
- Personalized cooking preferences
- Cloud sync with Supabase backend

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Active OpenAI API key
- Supabase account and project

## Installation

1. Clone the repository:
```bash
git clone https://github.com/tcrowden22/bbq-buddy-ios.git
cd bbq-buddy-ios
```

2. Create configuration file:
   - Copy `Config.example.swift` to `Config.swift`
   - Add your API keys and configuration values:
```swift
enum Config {
    static let openAIKey = "your-openai-api-key"
    static let supabaseURL = "your-supabase-project-url"
    static let supabaseAnonKey = "your-supabase-anon-key"
}
```

3. Open the project in Xcode:
```bash
open "BBQ Buddy/BBQ Buddy.xcodeproj"
```

4. Build and run the project (⌘R)

## Project Structure

```
BBQ Buddy/
├── Assets.xcassets/          # App icons and assets
├── Views/
│   ├── SessionView           # Main cooking session view
│   ├── CookPlannerView      # Cook planning interface
│   ├── HistoryView          # Past sessions view
│   ├── ProfileView          # User profile management
│   └── AssistantView        # AI chat interface
├── ViewModels/
│   ├── SessionViewModel     # Session management logic
│   ├── AssistantViewModel   # AI interaction logic
│   └── HistoryViewModel    # History data management
├── Models/
│   ├── CookSession         # Session data structure
│   ├── CookNote           # Timestamped observations
│   └── Message            # Chat message structure
└── Managers/
    ├── AuthManager        # Authentication handling
    ├── ThermometerManager # Temperature monitoring
    ├── SessionStorage     # Data persistence
    └── HapticsManager    # Haptic feedback
```

## Key Components

### Temperature Monitoring
The app uses CoreBluetooth to connect to compatible thermometers for real-time temperature monitoring. Temperature data is processed and analyzed to provide trend information and cooking predictions.

### AI Assistant
The AI assistant uses OpenAI's GPT-4 to provide context-aware cooking advice. It takes into account:
- Current temperature readings
- Temperature trends
- Cook plan details
- User's notes and observations
- Historical cooking data

### Data Storage
Cook sessions, user preferences, and history are stored using Supabase, providing:
- Real-time data sync
- Secure user authentication
- Cloud backup
- Cross-device access

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Security

- Never commit API keys or sensitive credentials
- Use the provided `Config.swift` template for local configuration
- Follow iOS security best practices
- Keep dependencies updated

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- OpenAI for GPT-4 API
- Supabase for backend services
- The SwiftUI community for inspiration and examples
- BBQ enthusiasts for feature suggestions and feedback

## Support

For support, feature requests, or bug reports, please open an issue on GitHub or contact the development team. 