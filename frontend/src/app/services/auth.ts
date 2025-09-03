import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, BehaviorSubject } from 'rxjs';
import { tap } from 'rxjs/operators';

const API_URL = 'http://127.0.0.1:8000';

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  access_token: string;
  token_type: string;
}

export interface UserInfo {
  username: string;
  is_admin: boolean;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private tokenKey = 'jwt_token';
  private userInfoKey = 'user_info';
  private isAuthenticatedSubject = new BehaviorSubject<boolean>(this.hasToken());
  
  constructor(private http: HttpClient) { }
  
  login(credentials: LoginRequest): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${API_URL}/api/login`, credentials)
      .pipe(
        tap(response => {
          localStorage.setItem(this.tokenKey, response.access_token);
          // Decode JWT to get user info
          const payload = this.decodeJWT(response.access_token);
          const userInfo: UserInfo = {
            username: payload.sub,
            is_admin: payload.sub === 'admin' // Simple check, could be improved
          };
          localStorage.setItem(this.userInfoKey, JSON.stringify(userInfo));
          this.isAuthenticatedSubject.next(true);
        })
      );
  }
  
  register(credentials: LoginRequest): Observable<{message: string}> {
    return this.http.post<{message: string}>(`${API_URL}/api/register`, credentials);
  }
  
  logout(): void {
    localStorage.removeItem(this.tokenKey);
    localStorage.removeItem(this.userInfoKey);
    this.isAuthenticatedSubject.next(false);
  }
  
  getToken(): string | null {
    return localStorage.getItem(this.tokenKey);
  }
  
  hasToken(): boolean {
    return !!this.getToken();
  }
  
  isAuthenticated(): Observable<boolean> {
    return this.isAuthenticatedSubject.asObservable();
  }
  
  getCurrentUser(): UserInfo | null {
    const userInfo = localStorage.getItem(this.userInfoKey);
    return userInfo ? JSON.parse(userInfo) : null;
  }
  
  isAdmin(): boolean {
    const user = this.getCurrentUser();
    return user ? user.is_admin : false;
  }
  
  decodeJWT(token: string): any {
    try {
      const base64Url = token.split('.')[1];
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
      const jsonPayload = decodeURIComponent(atob(base64).split('').map(function(c) {
        return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
      }).join(''));
      return JSON.parse(jsonPayload);
    } catch (error) {
      return {};
    }
  }
}