import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable, BehaviorSubject } from 'rxjs';

export interface IEmployee {
  id: number;
  firstName: string;
  lastName: string;
  email: string;
  position: string;
  department: string;
  hireDate: string;
  salary: number;
  status: 'active' | 'inactive';
  phone?: string;
  address?: string;
}

@Injectable({
  providedIn: 'root'
})
export class HRService {
  private apiUrl = 'http://127.0.0.1:8000/api';
  private employeesSubject = new BehaviorSubject<IEmployee[]>([]);
  public employees$ = this.employeesSubject.asObservable();

  constructor(private http: HttpClient) {}

  private getAuthHeaders(): HttpHeaders {
    const token = localStorage.getItem('token');
    return new HttpHeaders({
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    });
  }

  getEmployees(): Observable<IEmployee[]> {
    return this.http.get<IEmployee[]>(`${this.apiUrl}/employees`, {
      headers: this.getAuthHeaders()
    });
  }

  getEmployee(id: number): Observable<IEmployee> {
    return this.http.get<IEmployee>(`${this.apiUrl}/employees/${id}`, {
      headers: this.getAuthHeaders()
    });
  }

  addEmployee(employee: Omit<IEmployee, 'id'>): Observable<IEmployee> {
    return this.http.post<IEmployee>(`${this.apiUrl}/employees`, employee, {
      headers: this.getAuthHeaders()
    });
  }

  updateEmployee(id: number, employee: Partial<IEmployee>): Observable<IEmployee> {
    return this.http.put<IEmployee>(`${this.apiUrl}/employees/${id}`, employee, {
      headers: this.getAuthHeaders()
    });
  }

  deleteEmployee(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/employees/${id}`, {
      headers: this.getAuthHeaders()
    });
  }

  getEmployeesByDepartment(department: string): Observable<IEmployee[]> {
    return this.http.get<IEmployee[]>(`${this.apiUrl}/employees/department/${department}`, {
      headers: this.getAuthHeaders()
    });
  }
}