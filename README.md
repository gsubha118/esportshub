# Esports Tournament Platform

A full-stack esports tournament platform built with React, TypeScript, Node.js, Express, and PostgreSQL. This platform allows users to create, participate in, and manage esports tournaments with features like user authentication, real-time updates, and comprehensive tournament management.

## 🚀 Features

### Frontend
- **React + TypeScript** for type-safe, modern web development
- **Responsive Design** that works on desktop and mobile
- **Real-time Updates** for live tournament data
- **User Authentication** with JWT tokens
- **Tournament Discovery** and participation
- **User Dashboard** with statistics and match history

### Backend
- **Node.js + Express** RESTful API
- **TypeScript** for type safety
- **JWT Authentication** with secure password hashing
- **Tournament Management** with bracket systems
- **User Management** and statistics tracking
- **Input Validation** with Joi

### Database
- **PostgreSQL** with comprehensive schema
- **Migration System** for version control
- **Seed Data** for development
- **Optimized Queries** with proper indexing

## 🏗️ Architecture

```
esports-platform-monorepo/
├── frontend/          # React + TypeScript frontend
├── backend/           # Node.js + Express API
├── database/          # PostgreSQL schema & migrations
└── packages/          # Shared packages (future)
```

## 📋 Prerequisites

- **Node.js** 18.x or higher
- **npm** or **yarn**
- **PostgreSQL** 13.x or higher
- **Git** for version control

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd esports-platform-monorepo
```

### 2. Install Dependencies

```bash
# Install root dependencies
npm install

# Install frontend dependencies
cd frontend && npm install && cd ..

# Install backend dependencies
cd backend && npm install && cd ..
```

### 3. Database Setup

```bash
# Create PostgreSQL database
createdb esports_platform

# Run migrations
cd database
psql -d esports_platform -f schema/esports_platform.sql

# (Optional) Seed with sample data
psql -d esports_platform -f seeds/sample_data.sql
```

### 4. Environment Configuration

#### Backend Configuration

```bash
cd backend
cp .env.example .env
```

Edit `.env` with your configuration:

```env
PORT=5000
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
NODE_ENV=development
DATABASE_URL=postgresql://username:password@localhost:5432/esports_platform
```

#### Frontend Configuration

```bash
cd frontend
cp .env.example .env
```

Edit `.env` with your configuration:

```env
REACT_APP_API_URL=http://localhost:5000/api
```

### 5. Start Development Servers

#### Backend (Terminal 1)

```bash
cd backend
npm run dev
```

#### Frontend (Terminal 2)

```bash
cd frontend
npm start
```

The application will be available at:
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:5000/api

## 🧪 Testing

### Unit Tests

```bash
# Frontend tests
cd frontend && npm test

# Backend tests
cd backend && npm test

# Watch mode
cd backend && npm run test:watch
```

### End-to-End Tests

```bash
# Install Playwright browsers
cd frontend && npx playwright install

# Run E2E tests
cd frontend && npm run test:e2e

# Run E2E tests with UI
cd frontend && npm run test:e2e:ui
```

## 🔧 Development Scripts

### Root Level

```bash
npm run install:all    # Install all dependencies
npm run build          # Build all projects
npm run test           # Run all tests
npm run dev            # Start all dev servers
npm run clean          # Clean all build artifacts
```

### Frontend

```bash
npm start              # Start development server
npm run build          # Build for production
npm test               # Run unit tests
npm run test:e2e       # Run E2E tests
npm run eject          # Eject from Create React App
```

### Backend

```bash
npm run dev            # Start development server with auto-reload
npm run build          # Compile TypeScript to JavaScript
npm run start          # Start production server
npm test               # Run unit tests
npm run test:watch     # Run tests in watch mode
```

## 🚀 Deployment

### Frontend Deployment (Vercel)

1. **Connect to Vercel**:
   ```bash
   npm i -g vercel
   vercel login
   ```

2. **Deploy**:
   ```bash
   cd frontend
   vercel --prod
   ```

3. **Set Environment Variables** in Vercel dashboard:
   - `REACT_APP_API_URL` - Your backend API URL

### Backend Deployment

Deploy to services like:
- **Heroku**
- **DigitalOcean App Platform**
- **AWS Elastic Beanstalk**
- **Railway**

### Database Deployment

Choose one of the following PostgreSQL providers:

#### Option 1: Supabase
1. Create a project at [supabase.com](https://supabase.com)
2. Get your project credentials
3. Run migrations:
   ```bash
   supabase db push
   ```

#### Option 2: Neon
1. Create a database at [neon.tech](https://neon.tech)
2. Get your connection string
3. Run migrations manually or set up automation

#### Option 3: Railway
1. Create a PostgreSQL service
2. Use the provided `DATABASE_URL`

## 🔒 Environment Variables

### Production Backend
```env
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://...
JWT_SECRET=your-production-secret
CORS_ORIGIN=https://yourdomain.com
```

### Production Frontend
```env
REACT_APP_API_URL=https://your-api-domain.com/api
```

## 📁 Project Structure

```
frontend/
├── public/           # Static assets
├── src/
│   ├── components/   # Reusable UI components
│   ├── pages/        # Page components
│   ├── hooks/        # Custom React hooks
│   ├── utils/        # Utility functions
│   ├── services/     # API services
│   └── styles/       # CSS styles
└── tests/           # Test files

backend/
├── src/
│   ├── controllers/  # Route controllers
│   ├── middleware/   # Custom middleware
│   ├── models/       # Database models
│   ├── routes/       # API routes
│   └── utils/        # Utility functions
└── dist/            # Compiled JavaScript

database/
├── schema/          # Database schema files
├── migrations/      # Migration scripts
└── seeds/           # Seed data
```

## 🔧 Available Scripts

### Development
- `npm run dev` - Start all development servers
- `npm start` - Start production build

### Testing
- `npm test` - Run all tests
- `npm run test:watch` - Watch mode for tests

### Building
- `npm run build` - Build all projects for production

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📝 API Documentation

### Authentication Endpoints
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user
- `GET /api/auth/profile` - Get user profile (protected)

### Tournament Endpoints
- `GET /api/tournaments` - Get all tournaments
- `GET /api/tournaments/:id` - Get tournament details
- `POST /api/tournaments` - Create tournament (protected)
- `PUT /api/tournaments/:id` - Update tournament (protected)
- `DELETE /api/tournaments/:id` - Delete tournament (protected)

### User Endpoints
- `GET /api/users` - Get all users (protected)
- `GET /api/users/:id` - Get user details (protected)
- `PUT /api/users/:id` - Update user (protected)

## 🔒 Security Features

- **JWT Authentication** with secure token handling
- **Password Hashing** using bcrypt
- **Input Validation** with Joi schemas
- **CORS Protection** for cross-origin requests
- **Helmet Security** headers
- **Rate Limiting** (can be added)

## 📊 Monitoring & Analytics

- **Error Tracking** with proper logging
- **Performance Monitoring** setup ready
- **Health Check** endpoint at `/api/health`

## 🔄 CI/CD Pipeline

### GitHub Actions Workflows

1. **Test Workflow** (`test.yml`)
   - Runs on every push and PR
   - Tests frontend and backend
   - Uploads coverage reports

2. **Frontend Deployment** (`deploy-frontend.yml`)
   - Deploys to Vercel on main branch
   - Builds production bundle

3. **Database Migrations** (`deploy-db.yml`)
   - Runs migrations on database changes
   - Supports Supabase, Neon, and PostgreSQL

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues or need help:

1. Check the [Issues](../../issues) page
2. Create a new issue with detailed information
3. Contact the development team

## 🔄 Updates

Stay updated with the latest changes:

- **Changelog**: See [CHANGELOG.md](CHANGELOG.md) for version history
- **Releases**: Follow GitHub releases for new versions

---

**Happy coding! 🎮**
