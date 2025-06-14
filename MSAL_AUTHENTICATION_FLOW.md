# MSAL Authentication Flow Documentation

## Overview

This document outlines the Microsoft Authentication Library (MSAL) authentication flow implemented in Magentic-UI for Azure AD integration and secure online deployment.

## Authentication Architecture

### High-Level Flow

```mermaid
graph TB
    A[User] --> B[Frontend Login]
    B --> C[Auth Service]
    C --> D[Azure AD]
    D --> E[Authorization Code]
    E --> F[Token Exchange]
    F --> G[JWT Access Token]
    G --> H[Protected API Access]
    
    subgraph "Magentic-UI Application"
        B
        C
        I[API Gateway]
        J[Protected Routes]
        K[User Session]
    end
    
    subgraph "Azure AD Tenant"
        D
        L[App Registration]
        M[User Directory]
    end
    
    H --> I
    I --> J
    G --> K
```

### Detailed Authentication Sequence

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant AuthService
    participant AzureAD
    participant APIGateway
    participant Database
    
    User->>Frontend: Access Application
    Frontend->>AuthService: Request Login URL
    AuthService->>AzureAD: Generate Auth URL
    AzureAD-->>AuthService: Return Auth URL + State
    AuthService-->>Frontend: Auth URL
    Frontend->>User: Redirect to Azure AD
    
    User->>AzureAD: Enter Credentials
    AzureAD->>User: Redirect with Auth Code
    User->>Frontend: Callback with Code
    Frontend->>AuthService: Exchange Code for Token
    AuthService->>AzureAD: POST /token
    AzureAD-->>AuthService: Access Token + ID Token
    
    AuthService->>Database: Store/Update User
    AuthService-->>Frontend: JWT Access Token
    Frontend->>Frontend: Store Token (HTTP-Only Cookie)
    
    Frontend->>APIGateway: API Request + Token
    APIGateway->>APIGateway: Validate JWT
    APIGateway->>Database: Authorized Request
    Database-->>APIGateway: Response
    APIGateway-->>Frontend: Protected Data
```

## Component Architecture

### Authentication Components

```mermaid
graph LR
    subgraph "Frontend (React/Gatsby)"
        A[Login Component]
        B[Auth Context]
        C[HTTP Interceptor]
        D[Route Guards]
    end
    
    subgraph "Backend API"
        E[Auth Router]
        F[MSAL Service]
        G[JWT Service]
        H[Auth Middleware]
        I[User Service]
    end
    
    subgraph "External Services"
        J[Azure AD]
        K[Database]
    end
    
    A --> E
    B --> C
    C --> H
    D --> B
    E --> F
    F --> J
    E --> G
    E --> I
    H --> G
    I --> K
```

### Security Layers

```mermaid
graph TD
    A[User Request] --> B[CORS Middleware]
    B --> C[Rate Limiting]
    C --> D[JWT Validation]
    D --> E[User Authorization]
    E --> F[Route Access Control]
    F --> G[API Endpoint]
    
    D --> H[Token Refresh]
    H --> I[Azure AD Validation]
    I --> D
    
    G --> J[Data Access Layer]
    J --> K[Database]
    
    style A fill:#e1f5fe
    style G fill:#c8e6c9
    style K fill:#fff3e0
```

## Implementation Details

### 1. MSAL Service Configuration

```typescript
// Configuration for Azure AD App Registration
const msalConfig = {
    auth: {
        clientId: process.env.AZURE_CLIENT_ID,
        authority: `https://login.microsoftonline.com/${process.env.AZURE_TENANT_ID}`,
        redirectUri: process.env.AZURE_REDIRECT_URI,
        postLogoutRedirectUri: process.env.AZURE_POST_LOGOUT_URI
    },
    cache: {
        cacheLocation: "sessionStorage",
        storeAuthStateInCookie: false
    }
};
```

### 2. JWT Token Structure

```json
{
    "header": {
        "alg": "RS256",
        "typ": "JWT",
        "kid": "azure-key-id"
    },
    "payload": {
        "iss": "magentic-ui",
        "sub": "user-azure-object-id",
        "aud": "magentic-ui-api",
        "exp": 1640995200,
        "iat": 1640908800,
        "email": "user@company.com",
        "name": "User Name",
        "roles": ["user"],
        "tenant_id": "azure-tenant-id"
    },
    "signature": "..."
}
```

### 3. API Route Protection

```python
from fastapi import Depends, HTTPException
from auth.dependencies import get_current_user

@router.get("/protected-endpoint")
async def protected_route(current_user: dict = Depends(get_current_user)):
    # Only authenticated users can access this endpoint
    return {"data": "protected content", "user": current_user["email"]}
```

## Security Features

### 1. Token Management
- **Access Tokens**: Short-lived (1 hour) for API access
- **Refresh Tokens**: Long-lived (90 days) for token renewal
- **Secure Storage**: HTTP-only cookies for web clients
- **Token Rotation**: Automatic refresh before expiration

### 2. Authorization Controls
- **Role-Based Access Control (RBAC)**: Admin, User, Guest roles
- **Resource-Level Security**: Users can only access their own data
- **API Rate Limiting**: Prevent abuse and DDoS attacks
- **CORS Protection**: Restrict cross-origin requests

### 3. Session Management
- **Secure Session Storage**: Server-side session management
- **Session Timeout**: Automatic logout after inactivity
- **Concurrent Session Control**: Limit active sessions per user
- **Audit Logging**: Track authentication events

## Deployment Configuration

### Environment Variables

```bash
# Azure AD Configuration
AZURE_CLIENT_ID=your-app-registration-client-id
AZURE_CLIENT_SECRET=your-app-registration-secret
AZURE_TENANT_ID=your-azure-tenant-id
AZURE_REDIRECT_URI=https://your-domain.com/auth/callback
AZURE_POST_LOGOUT_URI=https://your-domain.com

# JWT Configuration
JWT_SECRET_KEY=your-secure-random-secret
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=60
JWT_REFRESH_TOKEN_EXPIRE_DAYS=90

# Application Configuration
API_BASE_URL=https://your-domain.com/api
FRONTEND_URL=https://your-domain.com
ALLOWED_ORIGINS=https://your-domain.com,https://your-staging.com

# Database Configuration
DATABASE_URL=postgresql://user:pass@host:port/dbname

# Security Configuration
RATE_LIMIT_PER_MINUTE=100
CORS_ALLOW_CREDENTIALS=true
SECURE_COOKIES=true
```

### Azure App Registration Setup

1. **Create App Registration**:
   - Navigate to Azure Portal > Azure Active Directory > App registrations
   - Click "New registration"
   - Set name: "Magentic-UI"
   - Set redirect URI: `https://your-domain.com/auth/callback`

2. **Configure Authentication**:
   - Add platform: Web
   - Set redirect URIs for all environments
   - Enable ID tokens and access tokens
   - Configure logout URL

3. **Set API Permissions**:
   - Microsoft Graph: `User.Read`
   - Microsoft Graph: `profile`
   - Microsoft Graph: `email`
   - Microsoft Graph: `openid`

4. **Create Client Secret**:
   - Go to Certificates & secrets
   - Create new client secret
   - Copy value to environment variables

## Frontend Integration

### Authentication Context

```typescript
// AuthContext.tsx
import { createContext, useContext, useEffect, useState } from 'react';

interface AuthContextType {
    user: User | null;
    login: () => Promise<void>;
    logout: () => Promise<void>;
    isAuthenticated: boolean;
    isLoading: boolean;
}

export const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
    const context = useContext(AuthContext);
    if (!context) {
        throw new Error('useAuth must be used within AuthProvider');
    }
    return context;
};
```

### Protected Route Component

```typescript
// ProtectedRoute.tsx
import { Navigate } from 'react-router-dom';
import { useAuth } from './AuthContext';

interface ProtectedRouteProps {
    children: React.ReactNode;
    requiredRole?: string;
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ 
    children, 
    requiredRole 
}) => {
    const { isAuthenticated, user, isLoading } = useAuth();

    if (isLoading) {
        return <div>Loading...</div>;
    }

    if (!isAuthenticated) {
        return <Navigate to="/login" replace />;
    }

    if (requiredRole && !user?.roles.includes(requiredRole)) {
        return <Navigate to="/unauthorized" replace />;
    }

    return <>{children}</>;
};
```

## Error Handling

### Authentication Errors

```mermaid
graph TD
    A[Authentication Request] --> B{Token Valid?}
    B -->|Yes| C[Allow Access]
    B -->|No| D{Refresh Token Valid?}
    D -->|Yes| E[Refresh Access Token]
    D -->|No| F[Redirect to Login]
    E --> G{Refresh Successful?}
    G -->|Yes| C
    G -->|No| F
    
    C --> H[API Response]
    F --> I[Login Page]
    
    style F fill:#ffcdd2
    style I fill:#fff3e0
    style C fill:#c8e6c9
```

### Common Error Scenarios

1. **Expired Token**: Automatic refresh attempt
2. **Invalid Token**: Force re-authentication
3. **Network Errors**: Retry with exponential backoff
4. **Azure AD Downtime**: Graceful degradation
5. **Permission Denied**: Clear error messaging

## Monitoring and Logging

### Authentication Metrics

- Login success/failure rates
- Token refresh frequency
- Session duration analytics
- Failed authentication attempts
- Geographic access patterns

### Security Logs

```json
{
    "timestamp": "2024-06-14T10:30:00Z",
    "event": "user_login",
    "user_id": "azure-object-id",
    "email": "user@company.com",
    "ip_address": "192.168.1.100",
    "user_agent": "Mozilla/5.0...",
    "success": true,
    "duration_ms": 1250
}
```

## Troubleshooting Guide

### Common Issues

1. **Token Validation Failures**:
   - Check JWT secret configuration
   - Verify token expiration
   - Validate issuer and audience claims

2. **Azure AD Integration**:
   - Confirm app registration settings
   - Check redirect URI configuration
   - Verify client secret validity

3. **CORS Issues**:
   - Update allowed origins
   - Check preflight request handling
   - Verify credentials configuration

4. **Session Management**:
   - Check cookie security settings
   - Verify session storage configuration
   - Monitor session timeout settings

## Best Practices

### Security
- Use HTTPS in production
- Implement proper CORS policies
- Regular security audits
- Monitor authentication logs
- Implement rate limiting
- Use secure cookie settings

### Performance
- Cache user permissions
- Implement token refresh logic
- Optimize database queries
- Use connection pooling
- Monitor response times

### Maintenance
- Regular dependency updates
- Monitor Azure AD service health
- Backup authentication configurations
- Document deployment procedures
- Test disaster recovery plans
