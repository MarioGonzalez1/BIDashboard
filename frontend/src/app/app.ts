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
  currentFilter: string = 'all';
  showAddForm: boolean = false;
  isAuthenticated: boolean = false;
  dashboardToEdit: IDashboard | null = null;
  workshopExpanded: boolean = false;

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
    
    if (filter === 'all') {
      this.filteredDashboards = this.allDashboards;
    } else if (filter === 'Workshop') {
      // Show all workshop items (category = Workshop)
      this.filteredDashboards = this.allDashboards.filter(d => d.categoria === 'Workshop');
      this.workshopExpanded = true;
    } else if (filter === 'Forza Transportation' || filter === 'Force One Transport') {
      // Filter by subcategory
      this.filteredDashboards = this.allDashboards.filter(d => 
        d.categoria === 'Workshop' && d.subcategoria === filter
      );
    } else {
      // Regular category filtering
      this.filteredDashboards = this.allDashboards.filter(d => d.categoria === filter);
      this.workshopExpanded = false;
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
