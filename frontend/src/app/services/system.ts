import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

const API_URL = 'http://127.0.0.1:8000';

export interface SystemStats {
  total_dashboards: number;
  active_users: number;
  departments: number;
  category_counts: { [key: string]: number };
}

export interface RecentUpdate {
  titulo: string;
  categoria: string;
  created_date: string;
}

export interface FeaturedDashboard {
  id: number;
  titulo: string;
  descripcion: string;
  categoria: string;
}

@Injectable({
  providedIn: 'root'
})
export class SystemService {
  
  constructor(private http: HttpClient) { }
  
  getSystemStats(): Observable<SystemStats> {
    return this.http.get<SystemStats>(`${API_URL}/api/system/stats`);
  }
  
  getRecentUpdates(): Observable<RecentUpdate[]> {
    return this.http.get<RecentUpdate[]>(`${API_URL}/api/system/recent-updates`);
  }
  
  getFeaturedDashboards(): Observable<FeaturedDashboard[]> {
    return this.http.get<FeaturedDashboard[]>(`${API_URL}/api/system/featured-dashboards`);
  }
}