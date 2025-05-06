# EnviroMelody  
<div align="center">
<img src="docs/lp_img/logo.png" width="400" height="400"/>
</div>

**Let your environment play the music.**  

## 🌐 Experience Now
[![Access EnviroMelody's Website](https://img.shields.io/badge/Official_Website-EnviroMelody-%2334C6CD?style=for-the-badge)](https://rorschachwilpeng.github.io/CASA0015_ENVIROMELODY/index.html)

Discover our [Offical Website](https://rorschachwilpeng.github.io/CASA0015_ENVIROMELODY/index.html)，know more how EnviroMelody transform environment into personized music experience.

---

## 🔍 What is EnviroMelody?  
EnviroMelody is a mobile app that turns **real-time environmental data** — like temperature, humidity, and wind — into **custom soundtracks** tailored to your location and mood.  

Whether you're working, relaxing, or exploring, it creates adaptive audio that fits your moment.

---

## 🧠 Why Use It?  

- 📊 **Tired of charts?** Hear your environment instead.  
- 🎵 **Music apps guess your mood.** We read your surroundings.  
- 🖼️ **You remember sights.** We help you remember how a place *sounded*.


<div align="center">
<img src="img/storyboard.png" width="400" height="400"/>
</div>


EnviroMelody bridges the gap between raw data and real emotion.





---

## ✨ Key Experiences  

### 🌇 **City Wanderer Mode**  
> "I walked through Berlin. It turned into synth."  
- Auto-detect location  
- Cultural vibe blending  
- Save and revisit your audio souvenirs  

### 🧘 **Zen Studio Mode**  
> "The weather outside made my room hum with calm piano."  
- Generates ambient tracks from local weather  
- Perfect for meditation, journaling, or deep focus  

### ⚡ **Storm Chaser Mode**  
> "The thunderstorm became a cinematic soundtrack."  
- Turns extreme weather into layered, dramatic scores  
- Great for creative work or storytelling  

---

## 🔉 Who's Using It?  
<div align="center">
<img src="img/target_users.png" width="400" height="400"/>
</div>



---

## 🔗 What Makes It Different?  
- 🎼 Environment-based sound generation  
- 🧭 Location + weather = personalized music  
- 💾 Music saved with metadata (place, time, vibe)  
- 📍 Map your memories with music  

---

Ready to hear your world?  
> 🌦️ Open the map, select a place, and create your personal music.  

EnviroMelody — where every moment has a soundtrack.

---
## 🔧 Features

### 🗺️ Interactive Map
- Auto-locate or manually select any location  
- Place markers to generate music tied to specific places  
- Save and revisit favorite spots with associated soundscapes  

### 🌦️ Real-Time Environmental Data
- Fetch temperature, humidity, wind, and weather conditions  
- Live updates for current or selected location  
- Visual display of environmental metrics  

### 🎵 AI-Powered Music Generation
- Generate music based on environmental data  
- Customize mood and genre (e.g. Lofi, Jazz, Ambient)  
- Playback controls: loop, shuffle, queue  

### 📚 Music Library
- Save and manage generated tracks  
- Each track stores timestamp, location, and environment data  

---

## Tech Stack

### 💭 Workflow
![Workflow](img/CAS0015_Workflow.png)

### 📱 Frontend / App Development
- **Flutter**: Cross-platform framework for building consistent UI on iOS and Android  
- **Dart**: Primary programming language supporting the Flutter framework  
- **Provider**: Lightweight state management solution for reactive data handling  
- **just_audio**: Audio playback plugin with support for loop, queue, and background play  
- **flutter_map**: Map rendering and interaction using OpenStreetMap tiles  

### ☁️ Backend & Data Storage
- **Firebase**: Backend-as-a-Service for real-time data and cloud functions  
  - **Firestore**: Stores user data, music metadata, and environment logs  
  - **Firebase Storage**: Hosts generated audio files  
  - **Firebase Authentication**: Manages user sign-in and account access  
  - **Cloud Functions**: Executes backend logic as serverless functions  

### 📊 APIs & External Services
- **OpenWeatherMap API**: Provides real-time weather data (temp, humidity, wind)  
- **DeepSeek API**: Generates high-quality prompt structures for music creation  
- **Stability Audio API**: Main engine for generative ambient music  
- **Geocoding API**: Enables location search and coordinate transformation  

---
## 🎨 Design System & UI Philosophy

### Visual Style
EnviroMelody adopts a **pixel art-inspired** design, combining retro aesthetics with modern clarity for a unique, recognizable interface.

- **Color Palette**: Inspired by [Litverse Design Template](https://dribbble.com/shots/24962649-Litverse-Mobile-App-Design) — warm tones and soft contrasts for a calm, ambient mood.
- **Pixel Elements**:
  - Pixelated icons with modern readability
  - Grid-aligned layouts for visual consistency
  - Clean, simplified shapes and minimal gradients


----

## 🚀 **Join the Sound Revolution**  
[![Presale](https://img.shields.io/badge/Join_Waitlist-Early_Access-%23FF6B6B?style=flat-square)](https://example.com/waitlist)  
**First 100 users get:**  
- Birthday weather song NFT  
- Soundmap co-creation access  

---

## 🌐 **Connect**  
[![Community](https://img.shields.io/badge/-Sound_Explorers-%2344cc77?style=flat-square)](https://example.com/community)  
[![Gallery](https://img.shields.io/badge/-Hear_Examples-%2300acee?style=flat-square)](https://example.com/gallery)  

--- 

**Transform your surroundings into a living soundtrack.**  
**#HearTheUnheard**  

--- 
## 🔧 Development and Deployment Guide

### Configuration File Setup

EnviroMelody requires specific API keys to access various services. For security reasons, these keys are not included in the code repository. If you want to run or modify this project, please follow these steps:

1. **Create a configuration file**:
   - Find the `config.template.dart` file in the `lib/utils` directory
   - Copy and rename it to `config.dart`
   - Replace the placeholders in the file with your own API keys

2. **Obtain necessary API keys**:
   - **Stability AI**: For audio generation, register at the [Stability AI platform](https://stability.ai/)
   - **DeepSeek API**: For high-quality prompt structure generation, register at the [DeepSeek platform](https://deepseek.com/)
   - **OpenWeatherMap API**: For weather data, register at [OpenWeatherMap](https://openweathermap.org/)

3. **Keep your configuration file secure**:
   - Ensure the `config.dart` file is added to `.gitignore`
   - Never commit a configuration file containing real API keys to a public code repository

> **Note**: If you are a project reviewer or teacher, please contact the project author to obtain a configuration file for testing purposes.

### Local Development

```bash
#Open Simulator (Development Environment Simulator: iPhone SE (3rd generation) - iOS 18.2)
open -a Simulator

# Get dependencies
flutter pub get

# Run the app (make sure config.dart is set up)
flutter run
```

### GitHub Actions Build Notes

Our GitHub Actions workflow creates a `config.dart` file with placeholder values in the CI/CD environment. Since these are placeholder values, applications built through CI/CD will not fully function without valid API keys. This is only used to validate the build process.