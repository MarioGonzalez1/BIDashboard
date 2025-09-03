import { Component, OnInit } from '@angular/core';
import { DashboardService, IDashboard } from './services/dashboard';
import { AuthService } from './services/auth';
import { DashboardCardComponent } from './components/dashboard-card/dashboard-card';
import { AddDashboardFormComponent } from './components/add-dashboard-form/add-dashboard-form';
import { LoginComponent } from './components/login/login';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-root',
  imports: [CommonModule, DashboardCardComponent, AddDashboardFormComponent, LoginComponent],
  templateUrl: './app.html',
  styleUrl: './app.scss'
})
export class App implements OnInit {
  allDashboards: IDashboard[] = [];
  filteredDashboards: IDashboard[] = [];
  currentFilter: string = 'getting-started';
  showAddForm: boolean = false;
  isAuthenticated: boolean = false;
  dashboardToEdit: IDashboard | null = null;
  workshopExpanded: boolean = false;
  hrExpanded: boolean = false;
  totalDashboards: number = 0;
  activeUsers: number = 127;
  recentUpdates: number = 8;
  showRequestModal: boolean = false;

  constructor(
    private dashboardService: DashboardService,
    private authService: AuthService
  ) {}

  ngOnInit() {
    this.authService.isAuthenticated().subscribe(isAuth => {
      this.isAuthenticated = isAuth;
      if (isAuth) {
        this.loadDashboards();
      }
    });
  }

  loadDashboards() {
    this.dashboardService.getDashboards().subscribe({
      next: data => {
        this.allDashboards = data;
        this.totalDashboards = data.length;
        this.setFilter(this.currentFilter);
      },
      error: error => {
        console.error('Error loading dashboards:', error);
        if (error.status === 401) {
          this.authService.logout();
        }
      }
    });
  }

  setFilter(filter: string) {
    this.currentFilter = filter;
    
    if (filter === 'getting-started') {
      this.filteredDashboards = this.allDashboards;
    } else if (filter === 'Workshop') {
      // Show all workshop items (category = Workshop)
      this.filteredDashboards = this.allDashboards.filter(d => d.categoria === 'Workshop');
      this.workshopExpanded = true;
      this.hrExpanded = false;
    } else if (filter === 'Human Resources') {
      // Show all HR items (category = Human Resources)
      this.filteredDashboards = this.allDashboards.filter(d => d.categoria === 'Human Resources');
      this.hrExpanded = true;
      this.workshopExpanded = false;
    } else if (filter === 'Forza Transportation' || filter === 'Force One Transport') {
      // Filter by workshop subcategory
      this.filteredDashboards = this.allDashboards.filter(d => 
        d.categoria === 'Workshop' && d.subcategoria === filter
      );
    } else if (filter === 'Employee Management' || filter === 'Payroll' || filter === 'Performance Reviews' || filter === 'Recruiting' || filter === 'Training') {
      // Filter by HR subcategory
      this.filteredDashboards = this.allDashboards.filter(d => 
        d.categoria === 'Human Resources' && d.subcategoria === filter
      );
    } else {
      // Regular category filtering
      this.filteredDashboards = this.allDashboards.filter(d => d.categoria === filter);
      this.workshopExpanded = false;
      this.hrExpanded = false;
    }
  }
  
  onDashboardAdded() {
    this.showAddForm = false;
    this.dashboardToEdit = null;
    this.loadDashboards();
  }

  onEditDashboard(dashboard: IDashboard) {
    this.dashboardToEdit = dashboard;
    this.showAddForm = true;
  }

  onDeleteDashboard(dashboardId: number) {
    this.dashboardService.deleteDashboard(dashboardId).subscribe({
      next: () => {
        this.loadDashboards();
      },
      error: (error) => {
        if (error.status === 403) {
          alert('Solo los administradores pueden eliminar dashboards');
        } else {
          alert('Error al eliminar el dashboard');
        }
      }
    });
  }

  logout() {
    this.authService.logout();
  }
}
