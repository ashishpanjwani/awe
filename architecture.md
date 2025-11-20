# Flow Travel App - Architecture Plan

## Overview
Flow is a modern travel app with a dark theme aesthetic focused on meaningful travel experiences. The app features three main screens: Splash, Welcome/Login, and Home.

## Technical Requirements
- Dark theme with deep blues (#0B1C2E), soft teal gradients, and warm accents
- Modern geometric fonts avoiding Material Design
- Google authentication (mandatory login)
- Weather integration
- Image assets for destinations
- Smooth animations and transitions

## Architecture Components

### 1. Screens Structure
- **SplashScreen**: Dark background with "Flow" branding
- **WelcomeScreen**: Google login with tagline "Travel, but with meaning."
- **HomeScreen**: Main interface with greeting, weather, features, and destinations

### 2. Data Models (`lib/models/`)
- **User**: User profile information from Google Auth
- **WeatherData**: Current weather information
- **Destination**: Popular travel destinations with images and ratings
- **FeatureCard**: App feature cards (Itinerary Builder, QuickTrip, Discover)

### 3. Services (`lib/services/`)
- **AuthService**: Handle Google authentication and user state
- **WeatherService**: Fetch weather data for user location
- **DestinationService**: Manage popular destinations data
- **UserPreferencesService**: Store user preferences and app state

### 4. Widgets (`lib/widgets/`)
- **WeatherCard**: Display current weather information
- **FeatureGrid**: Three-card layout for main features
- **DestinationCard**: Scrollable destination cards
- **AnimatedButton**: Custom button with tap animations

### 5. Screens (`lib/screens/`)
- **splash_screen.dart**: App launch screen
- **welcome_screen.dart**: Authentication screen
- **home_screen.dart**: Main app interface

### 6. Theme Updates
- Custom dark travel theme colors
- Typography with geometric modern fonts
- Gradient definitions for cards and backgrounds

## Implementation Steps

### Phase 1: Theme & Foundation
1. Update theme.dart with Flow's dark travel theme colors
2. Add required dependencies (Google Sign-In, weather API, etc.)
3. Update main.dart with proper routing

### Phase 2: Authentication Flow
1. Implement SplashScreen with brand identity
2. Create WelcomeScreen with Google Sign-In integration
3. Set up AuthService for user management

### Phase 3: Data Layer
1. Create all data models with sample data
2. Implement services for weather and destinations
3. Add local storage for user preferences

### Phase 4: Home Screen UI
1. Build greeting section with user name
2. Create weather card component
3. Implement feature grid with three cards
4. Add popular destinations horizontal scroll

### Phase 5: Assets & Polish
1. Generate travel destination images
2. Add smooth animations and transitions
3. Implement tap feedback for interactive elements
4. Final testing and debugging

## Design Approach
Following a **Brand-Forward** design approach with:
- Deep blue primary (#0B1C2E) 
- Soft teal accents for gradients
- Warm accent colors for interactive elements
- Generous spacing and modern typography
- Card-based layouts with rounded corners
- No heavy shadows, focus on flat design with subtle elevation