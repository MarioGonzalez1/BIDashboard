import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

const API_URL = 'http://127.0.0.1:8000';

export interface IDashboard {
  id: number;
  titulo: string;
  url_acceso: string;
  categoria: string;
  subcategoria?: string;
  descripcion?: string;
  url_imagen_preview: string;
}

@Injectable({
  providedIn: 'root'
})
export class DashboardService {
  constructor(private http: HttpClient) { }
  
  getDashboards(): Observable<IDashboard[]> {
    return this.http.get<IDashboard[]>(`${API_URL}/api/tableros`);
  }
  
  addDashboard(formData: FormData): Observable<IDashboard> {
    return this.http.post<IDashboard>(`${API_URL}/api/tableros`, formData);
  }
  
  updateDashboard(id: number, formData: FormData): Observable<IDashboard> {
    return this.http.put<IDashboard>(`${API_URL}/api/tableros/${id}`, formData);
  }
  
  deleteDashboard(id: number): Observable<{message: string}> {
    return this.http.delete<{message: string}>(`${API_URL}/api/tableros/${id}`);
  }
}
