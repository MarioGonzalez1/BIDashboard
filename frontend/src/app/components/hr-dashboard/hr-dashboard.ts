import { Component, OnInit } from '@angular/core';
import { HRService, IEmployee } from '../../services/hr';
import { AuthService } from '../../services/auth';
import { EmployeeCardComponent } from '../employee-card/employee-card';
import { AddEmployeeFormComponent } from '../add-employee-form/add-employee-form';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-hr-dashboard',
  imports: [CommonModule, EmployeeCardComponent, AddEmployeeFormComponent],
  templateUrl: './hr-dashboard.html',
  styleUrl: './hr-dashboard.scss'
})
export class HRDashboardComponent implements OnInit {
  allEmployees: IEmployee[] = [];
  filteredEmployees: IEmployee[] = [];
  currentFilter: string = 'all';
  showAddForm: boolean = false;
  employeeToEdit: IEmployee | null = null;
  departments: string[] = [];

  constructor(
    private hrService: HRService,
    private authService: AuthService
  ) {}

  ngOnInit() {
    this.loadEmployees();
  }

  loadEmployees() {
    this.hrService.getEmployees().subscribe({
      next: data => {
        this.allEmployees = data;
        this.departments = [...new Set(data.map(emp => emp.department))];
        this.setFilter(this.currentFilter);
      },
      error: error => {
        console.error('Error loading employees:', error);
        if (error.status === 401) {
          this.authService.logout();
        }
      }
    });
  }

  setFilter(filter: string) {
    this.currentFilter = filter;
    
    if (filter === 'all') {
      this.filteredEmployees = this.allEmployees;
    } else if (filter === 'active') {
      this.filteredEmployees = this.allEmployees.filter(emp => emp.status === 'active');
    } else if (filter === 'inactive') {
      this.filteredEmployees = this.allEmployees.filter(emp => emp.status === 'inactive');
    } else {
      this.filteredEmployees = this.allEmployees.filter(emp => emp.department === filter);
    }
  }

  onEmployeeAdded() {
    this.showAddForm = false;
    this.employeeToEdit = null;
    this.loadEmployees();
  }

  onEditEmployee(employee: IEmployee) {
    this.employeeToEdit = employee;
    this.showAddForm = true;
  }

  onDeleteEmployee(employeeId: number) {
    this.hrService.deleteEmployee(employeeId).subscribe({
      next: () => {
        this.loadEmployees();
      },
      error: (error) => {
        if (error.status === 403) {
          alert('Solo los administradores pueden eliminar empleados');
        } else {
          alert('Error al eliminar el empleado');
        }
      }
    });
  }

  getFilterButtonClass(filter: string): string {
    return this.currentFilter === filter ? 'filter-active' : 'filter-inactive';
  }

  getEmployeeCount(): number {
    return this.filteredEmployees.length;
  }

  getActiveEmployeesCount(): number {
    return this.allEmployees.filter(emp => emp.status === 'active').length;
  }

  getTotalSalaries(): number {
    return this.allEmployees
      .filter(emp => emp.status === 'active')
      .reduce((total, emp) => total + emp.salary, 0);
  }

  getInactiveEmployeesCount(): number {
    return this.allEmployees.filter(emp => emp.status === 'inactive').length;
  }

  getEmployeeCountByDepartment(department: string): number {
    return this.allEmployees.filter(emp => emp.department === department).length;
  }
}