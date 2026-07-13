# Medical Lab System

A comprehensive management system for medical laboratories, featuring user administration, patient management, inventory tracking, invoicing, and direct WhatsApp communication between admins and lab owners.

## Features

- **User Management**: Separate roles for Admins, Owners, Doctors, Staff, and Patients
- **Lab Operations**: Inventory management, test ordering, result processing
- **Financial Management**: Invoice generation and tracking
- **Office Hours Management**: Lab owners can set operating hours for each day of the week
- **Notifications**: In-app and email notifications
- **WhatsApp Integration**: Direct messaging between admins and owners via Twilio
- **Authentication**: JWT-based secure login
- **Real-time Communication**: Webhook-based WhatsApp messaging

## Tech Stack

### Backend
- **Node.js** with Express.js
- **MongoDB** with Mongoose ODM
- **Twilio** for WhatsApp API
- **JWT** for authentication
- **Nodemailer** for email notifications

### Frontend
- **Flutter** (Dart) for cross-platform mobile/web app

### Development Tools
- **ngrok** for local tunneling
- **MongoDB Atlas** for cloud database
- **Postman** for API testing

## Project Structure

```
medical-lab-system/
├── backend/
│   ├── models/          # Database schemas
│   ├── routes/          # API endpoints
│   ├── controllers/     # Business logic
│   ├── middleware/      # Auth, validation, rate limiting
│   ├── utils/           # Helpers (email, SMS, WhatsApp)
│   ├── validators/      # Input validation
│   └── tests/           # Unit tests
├── frontend_flutter/
│   ├── lib/
│   │   ├── models/      # Data models
│   │   ├── providers/   # State management
│   │   ├── screens/     # UI screens
│   │   ├── services/    # API calls
│   │   └── widgets/     # Reusable components
│   └── test/            # Widget tests
└── package.json         # Root dependencies
```

## Key Models

- **Admin**: System administrators
- **Owner**: Lab owners (assigned to admins)
- **Doctor**: Medical professionals
- **Staff**: Lab technicians
- **Patient**: Test recipients
- **Test/TestComponent**: Lab tests and components
- **Result/ResultComponent**: Test results
- **Inventory**: Lab supplies
- **Order/OrderDetails**: Test orders
- **Invoice**: Billing
- **Notification**: System messages

## WhatsApp Integration

- **Sandbox Mode**: For testing with Twilio's free tier
- **Webhook**: Handles incoming messages at `/api/whatsapp/webhook`
- **Routing**: Messages from owners route to assigned admins
- **Opt-in Required**: Phones must join sandbox with "join <keyword>"

## Installation

### Backend
```bash
cd backend
npm install
cp .env.example .env  # Configure environment variables
npm start
```

### Frontend
```bash
cd frontend_flutter
flutter pub get
flutter run
```

### Database
- Set up MongoDB Atlas or local MongoDB
- Update `MONGO_URI` in `.env`

## Usage

1. **Setup Test Data**: Run `node setupTest.js` to create sample users
2. **Update Office Hours**: Run `node updateOfficeHours.js` to add office hours to existing labs
3. **Start Services**: Backend on port 5000, ngrok for tunneling
4. **Configure Twilio**: Set webhook URL in sandbox settings
5. **Test Messaging**: Opt-in phones and send WhatsApp messages

## API Endpoints

- `POST /api/auth/login` - User authentication
- `GET /api/admin/owners` - Admin dashboard
- `POST /api/staff/send-whatsapp` - Send WhatsApp messages
- `POST /api/whatsapp/webhook` - Twilio webhook
- `GET /api/inventory` - Inventory management
- `POST /api/invoices` - Create invoices

## Security

- Password hashing with bcrypt
- JWT tokens for sessions
- Role-based access control
- Input validation and sanitization
- Rate limiting on API endpoints

## Development

- **Testing**: `npm test` in backend
- **Linting**: ESLint configured
- **Environment**: Separate dev/prod configs
- **Logging**: Winston for structured logs

## Future Enhancements

- Production WhatsApp Business API
- Real-time notifications with WebSockets
- Advanced reporting and analytics
- Multi-language support
- Mobile app optimizations

For detailed API documentation, see individual route files in `backend/routes/`.