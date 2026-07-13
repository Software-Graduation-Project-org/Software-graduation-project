# Medical Lab System - Startup Commands

This file contains all the terminal commands needed to run the Medical Lab System.

## Prerequisites
- Node.js (v16+)
- MongoDB Atlas connection
- Flutter SDK
- Git

## Environment Setup
1. Clone the repository:
```bash
git clone <repository-url>
cd medical-lab-system
```

2. Install backend dependencies:
```bash
cd backend
npm install
```

3. Install frontend dependencies:
```bash
cd ../frontend_flutter
flutter pub get
```

4. Set up environment variables:
```bash
# Copy and configure .env file in backend directory
cp .env.example .env
# Edit .env with your MongoDB URI and JWT secret
```

## Startup Commands

### 1. Start Backend Server (Port 5000)
```bash
# From project root
cd backend
npm start
# or for development with auto-restart
npm run dev
```

### 2. Start HL7 Server (Ports 3003 & 4003)
```bash
# From project root (Windows)
start_hl7.bat

# Alternative: Manual start
cd hl7-server
node server.js
```

### 3. Start Flutter Frontend
```bash
# From project root
cd frontend_flutter

# For Android:
flutter run

# For Web:
flutter run -d chrome

# For iOS (macOS only):
flutter run -d ios
```

### 4. Verify Services are Running
```bash
# Check if ports are listening
netstat -ano | findstr :5000  # Backend
netstat -ano | findstr :3003  # HL7 Server (HL7 protocol)
netstat -ano | findstr :4003  # HL7 Server (HTTP API)
```

## Development Workflow

### Full System Startup (Windows)
```batch
# Start all services in separate terminals/command prompts

# Terminal 1: Backend
cd backend
npm start

# Terminal 2: HL7 Server
start_hl7.bat

# Terminal 3: Flutter App
cd frontend_flutter
flutter run
```

### Testing HL7 Simulation
```bash
# Test backend connectivity
curl http://localhost:5000/api/public/health

# Test HL7 server connectivity
curl http://localhost:4003/health

# Run HL7 simulation (requires valid detail_id)
curl -X POST http://localhost:5000/api/staff/test-run-test \
  -H "Content-Type: application/json" \
  -d '{"detail_id": "your-order-detail-id"}'
```

## Database Setup
The system uses MongoDB Atlas. Ensure your `.env` file contains:
```
MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/medical_lab
JWT_SECRET=your-jwt-secret-key
```

## Troubleshooting

### Backend won't start
```bash
# Check Node.js version
node --version

# Check MongoDB connection
cd backend
node -e "require('mongoose').connect(process.env.MONGO_URI).then(() => console.log('Connected')).catch(console.error)"
```

### HL7 Server won't start
```bash
# Check if ports are available
netstat -ano | findstr :3003
netstat -ano | findstr :4003

# Kill processes using ports (if needed)
# Find PID and use: taskkill /PID <pid> /F
```

### Flutter issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check connected devices
flutter devices
```

## Ports Used
- **5000**: Backend API (Express.js)
- **3003**: HL7 Server (MLLP protocol)
- **4003**: HL7 Server (HTTP API)
- **5173/3000**: Flutter web development server

## Common Issues & Solutions

1. **MongoDB Connection Error**
   - Verify MONGO_URI in .env
   - Check network connectivity
   - Ensure IP whitelist in MongoDB Atlas

2. **HL7 Simulation Not Working**
   - Ensure HL7 server is running on port 4003
   - Check order detail exists and sample is collected
   - Verify staff is assigned to the test

3. **Flutter Build Errors**
   - Run `flutter doctor` to check setup
   - Ensure Android SDK/iOS SDK is properly configured
   - Clear cache: `flutter clean && flutter pub get`

## Production Deployment

For production deployment, consider:
- Using PM2 for Node.js process management
- Setting up reverse proxy (nginx)
- Configuring SSL certificates
- Setting up monitoring and logging
- Database backups and replication</content>
<parameter name="filePath">c:\MEDICAL-LAB-SYSTEM\STARTUP_COMMANDS.md