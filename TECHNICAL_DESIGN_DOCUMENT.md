# BIDashboard Technical Design Document

## Project Overview
**BIDashboard** - Business Intelligence Portal for Forza Transportation Services
- Multi-company dashboard system for Forza Transportation (US 🇺🇸) and Force One Transport (Mexico 🇲🇽)
- Role-based access control with admin/user permissions
- Full-stack web application with modern UI/UX patterns

## Architecture Overview

### Frontend Architecture
- **Framework**: Angular 20.2.0
- **Architecture Pattern**: Standalone Components
- **Control Flow**: New Angular syntax (@if, @else, @for)
- **Styling**: SCSS with modern CSS techniques
- **State Management**: Service-based with RxJS
- **Authentication**: JWT with HTTP Interceptor

### Backend Architecture
- **Framework**: FastAPI (Python)
- **Database Pattern**: Adapter Pattern for multi-database support
- **Authentication**: JWT with role-based access control
- **API Design**: RESTful with automatic OpenAPI documentation

## Key Technical Patterns

### 1. Database Adapter Pattern
```python
# Multi-database compatibility
class DatabaseAdapter:
    def __init__(self, db_type: str):
        if db_type == "sqlite":
            self.implementation = SQLiteAdapter()
        elif db_type == "sqlserver":
            self.implementation = SQLServerAdapter()
```

**Benefits:**
- Easy database switching
- Consistent API across different databases
- Clean separation of concerns

### 2. Standalone Angular Components
```typescript
@Component({
  selector: 'app-dashboard-card',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './dashboard-card.html',
  styleUrl: './dashboard-card.scss'
})
export class DashboardCardComponent {
  // Component logic
}
```

**Benefits:**
- Reduced bundle size
- Better tree-shaking
- Simplified dependency management

### 3. HTTP Interceptor for Authentication
```typescript
@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  intercept(req: HttpRequest<any>, next: HttpHandler) {
    const token = localStorage.getItem('access_token');
    if (token) {
      req = req.clone({
        setHeaders: { Authorization: `Bearer ${token}` }
      });
    }
    return next.handle(req);
  }
}
```

### 4. Role-Based Access Control (RBAC)
```python
# Backend dependency for admin operations
def get_current_admin_user(current_user: User = Depends(get_current_user)):
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user
```

## UI/UX Design Patterns

### 1. Split-Screen Layout (Login Page)
```scss
.login-container {
  display: flex;
  min-height: 100vh;
}
.image-section {
  flex: 1; // Takes remaining space
}
.form-section {
  flex: 0 0 450px; // Fixed width
}
```

### 2. Responsive Grid Layout
```scss
.dashboard-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 1.5rem;
}
.dashboard-card {
  max-width: 380px;
  justify-self: start;
}
```

**Key Points:**
- `auto-fill` vs `auto-fit` for proper spacing
- Maximum width constraints prevent over-stretching
- `justify-self: start` for proper alignment

### 3. Glassmorphism Design
```scss
.modal-content {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
}
```

### 4. Smart Modal Overlay Handling
```typescript
onModalOverlayClick(event: Event) {
  // Only close if clicking directly on overlay, not child elements
  if (event.target === event.currentTarget) {
    this.closeModal();
  }
}
```

## Component Architecture

### 1. Dashboard Card Component
```typescript
export class DashboardCardComponent {
  @Input() dashboard: IDashboard;
  @Input() isAdmin: boolean;
  @Output() editRequested = new EventEmitter<IDashboard>();
  @Output() deleteRequested = new EventEmitter<number>();
  
  onEdit(event: Event) {
    event.preventDefault();
    event.stopPropagation();
    this.editRequested.emit(this.dashboard);
  }
}
```

### 2. Form Components with Validation
```typescript
export class AddDashboardFormComponent {
  addForm: FormGroup;
  categories = ['Operations', 'Finance', 'Workshop', 'Human Resources', 'Tires', 'Executive & Management'];
  subcategories: { [key: string]: string[] } = {
    'Workshop': ['Forza Transportation 🇺🇸', 'Force One Transport 🇲🇽']
  };
}
```

## Security Implementation

### 1. Frontend Security
- JWT token storage in localStorage
- Automatic token attachment via HTTP interceptor
- Admin-only UI elements with `*ngIf="isAdmin"`
- Proper event handling to prevent unintended actions

### 2. Backend Security
```python
@app.post("/dashboards/")
async def create_dashboard(
    dashboard_data: dict,
    screenshot: UploadFile,
    current_admin: User = Depends(get_current_admin_user)  # Admin required
):
    # Admin-only endpoint
```

### 3. Input Validation
- Frontend: Angular Reactive Forms with validators
- Backend: Pydantic models for request validation
- File upload validation and sanitization

## Performance Optimizations

### 1. Lazy Loading
```typescript
// Route-based lazy loading
const routes: Routes = [
  {
    path: 'admin',
    loadComponent: () => import('./admin/admin.component')
  }
];
```

### 2. OnPush Change Detection
```typescript
@Component({
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class OptimizedComponent {}
```

### 3. Image Optimization
```scss
.dashboard-image {
  background-size: cover;
  background-position: center;
  loading: lazy; // Native lazy loading
}
```

## Responsive Design Strategy

### 1. Mobile-First Approach
```scss
// Base styles for mobile
.component {
  padding: 1rem;
}

// Desktop enhancements
@media (min-width: 768px) {
  .component {
    padding: 2rem;
  }
}
```

### 2. Flexible Grid Systems
```scss
@media (max-width: 768px) {
  .dashboard-grid {
    grid-template-columns: 1fr;
  }
}
```

## File Structure Best Practices

```
frontend/src/app/
├── components/           # Reusable components
│   ├── dashboard-card/
│   ├── add-dashboard-form/
│   └── login/
├── services/            # Business logic
│   ├── auth.service.ts
│   ├── dashboard.service.ts
│   └── http-interceptor.ts
├── models/              # TypeScript interfaces
│   └── dashboard.interface.ts
├── guards/              # Route protection
│   └── admin.guard.ts
└── pipes/               # Custom pipes
    └── safe-url.pipe.ts

backend/
├── main.py             # FastAPI application
├── database_adapter.py # Database abstraction
├── models/             # Pydantic models
├── routers/            # API routes
└── utils/              # Helper functions
```

## Error Handling Patterns

### 1. Global Error Handling
```typescript
@Injectable()
export class GlobalErrorHandler implements ErrorHandler {
  handleError(error: any): void {
    console.error('Global error:', error);
    // Send to logging service
  }
}
```

### 2. HTTP Error Handling
```typescript
this.dashboardService.getDashboards().subscribe({
  next: (dashboards) => this.dashboards = dashboards,
  error: (error) => {
    if (error.status === 401) {
      this.router.navigate(['/login']);
    }
    this.showErrorMessage(error.message);
  }
});
```

## Testing Strategy

### 1. Unit Tests
```typescript
describe('DashboardCardComponent', () => {
  it('should emit edit event when admin clicks edit', () => {
    component.isAdmin = true;
    spyOn(component.editRequested, 'emit');
    component.onEdit(mockEvent);
    expect(component.editRequested.emit).toHaveBeenCalled();
  });
});
```

### 2. Integration Tests
```python
def test_create_dashboard_admin_required():
    response = client.post("/dashboards/", json=dashboard_data)
    assert response.status_code == 401
```

## Deployment Considerations

### 1. Environment Configuration
```typescript
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8000',
  jwtSecret: process.env['JWT_SECRET']
};
```

### 2. Build Optimization
```json
{
  "scripts": {
    "build:prod": "ng build --configuration production",
    "analyze": "ng build --stats-json && npx webpack-bundle-analyzer"
  }
}
```

## Key Lessons Learned

### 1. Layout Issues
- **Problem**: `auto-fit` caused uneven grid distribution
- **Solution**: Use `auto-fill` with proper width constraints
- **Learning**: Understanding CSS Grid behavior is crucial

### 2. Modal UX
- **Problem**: Modal closing on text selection
- **Solution**: Smart event handling with `event.target === event.currentTarget`
- **Learning**: Event propagation requires careful consideration

### 3. Security Implementation
- **Problem**: Non-admin users accessing admin functions
- **Solution**: Both frontend hiding and backend enforcement
- **Learning**: Security must be implemented at all layers

### 4. Database Flexibility
- **Problem**: Tight coupling to specific database
- **Solution**: Adapter pattern for database abstraction
- **Learning**: Plan for future scalability from the start

## Reusable Code Snippets

### 1. Smart Modal Component
```typescript
export class ModalComponent {
  @Output() closed = new EventEmitter<void>();
  
  onOverlayClick(event: Event) {
    if (event.target === event.currentTarget) {
      this.closed.emit();
    }
  }
}
```

### 2. File Upload Handler
```typescript
onFileSelect(event: Event) {
  const input = event.target as HTMLInputElement;
  if (input.files && input.files.length) {
    this.selectedFile = input.files[0];
    // Validate file type and size
  }
}
```

### 3. Responsive Image Background
```scss
.background-image {
  background-size: contain;
  background-position: center;
  background-repeat: no-repeat;
  
  @media (max-width: 768px) {
    background-size: cover;
  }
}
```

## Performance Metrics
- Initial load time: < 3 seconds
- Time to interactive: < 2 seconds
- Bundle size: < 500KB (gzipped)
- Lighthouse score: 90+

## Browser Support
- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## Future Enhancements
- Progressive Web App (PWA) capabilities
- Real-time updates with WebSockets
- Advanced filtering and search
- Dashboard analytics and usage tracking
- Multi-language support (i18n)

---

This technical design document captures the key architectural decisions, patterns, and implementations used in the BIDashboard project. It can serve as a reference for similar projects or as a foundation for scaling this application.