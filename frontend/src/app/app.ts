import { Component, OnInit } from '@angular/core';
import { DashboardService, IDashboard } from './services/dashboard';
import { AuthService } from './services/auth';
import { SystemService, SystemStats, RecentUpdate, FeaturedDashboard } from './services/system';
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
  showAddModal: boolean = false;
  isAuthenticated: boolean = false;
  isAdmin: boolean = false;
  dashboardToEdit: IDashboard | null = null;
  workshopExpanded: boolean = false;
  hrExpanded: boolean = false;
  llantasExpanded: boolean = false;
  sidebarCollapsed: boolean = false;
  totalDashboards: number = 0;
  activeUsers: number = 0;
  recentUpdates: RecentUpdate[] = [];
  featuredDashboards: FeaturedDashboard[] = [];
  departments: number = 0;
  showRequestModal: boolean = false;
  biTeamExpanded: boolean = false;
  systemOverviewExpanded: boolean = true;
  recentUpdatesExpanded: boolean = true;
  featuredDashboardsExpanded: boolean = true;
  trainingResourcesExpanded: boolean = true;
  quickStartGuideExpanded: boolean = true;
  showProfileDropdown: boolean = false;
  currentUser: any = null;

  // Force Angular recompilation - Updated with Font Awesome
  constructor(
    private dashboardService: DashboardService,
    private authService: AuthService,
    private systemService: SystemService
  ) {}

  ngOnInit() {
    // Load user info on startup if token exists
    this.authService.loadUserInfoOnInit();
    
    this.authService.isAuthenticated().subscribe(isAuth => {
      this.isAuthenticated = isAuth;
      if (isAuth) {
        this.isAdmin = this.authService.isAdmin();
        this.currentUser = this.authService.getCurrentUser();
        this.loadDashboards();
        this.loadSystemData();
      } else {
        this.isAdmin = false;
        this.currentUser = null;
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

  loadSystemData() {
    // Load system statistics
    this.systemService.getSystemStats().subscribe({
      next: stats => {
        this.totalDashboards = stats.total_dashboards;
        this.activeUsers = stats.active_users;
        this.departments = stats.departments;
      },
      error: error => console.error('Error loading system stats:', error)
    });

    // Load recent updates
    this.systemService.getRecentUpdates().subscribe({
      next: updates => {
        this.recentUpdates = updates;
      },
      error: error => console.error('Error loading recent updates:', error)
    });

    // Load featured dashboards
    this.systemService.getFeaturedDashboards().subscribe({
      next: featured => {
        this.featuredDashboards = featured;
      },
      error: error => console.error('Error loading featured dashboards:', error)
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
      this.llantasExpanded = false;
    } else if (filter === 'Human Resources') {
      // Show all HR items (category = Human Resources)
      this.filteredDashboards = this.allDashboards.filter(d => d.categoria === 'Human Resources');
      this.hrExpanded = true;
      this.workshopExpanded = false;
      this.llantasExpanded = false;
    } else if (filter === 'Tires') {
      // Show all Tires items (category = Tires)
      this.filteredDashboards = this.allDashboards.filter(d => d.categoria === 'Tires');
      this.llantasExpanded = true;
      this.workshopExpanded = false;
      this.hrExpanded = false;
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
    } else if (filter === 'Alignments') {
      // Filter by Tires subcategory
      this.filteredDashboards = this.allDashboards.filter(d => 
        d.categoria === 'Tires' && d.subcategoria === filter
      );
    } else {
      // Regular category filtering
      this.filteredDashboards = this.allDashboards.filter(d => d.categoria === filter);
      this.workshopExpanded = false;
      this.hrExpanded = false;
      this.llantasExpanded = false;
    }
  }
  
  onDashboardAdded() {
    this.showAddForm = false;
    this.showAddModal = false;
    this.dashboardToEdit = null;
    this.loadDashboards();
  }

  onDashboardFormCancelled() {
    this.showAddModal = false;
    this.dashboardToEdit = null;
  }

  onEditDashboard(dashboard: IDashboard) {
    this.dashboardToEdit = dashboard;
    this.showAddModal = true;
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

  toggleBiTeam() {
    this.biTeamExpanded = !this.biTeamExpanded;
  }

  toggleSystemOverview() {
    this.systemOverviewExpanded = !this.systemOverviewExpanded;
  }

  toggleRecentUpdates() {
    this.recentUpdatesExpanded = !this.recentUpdatesExpanded;
  }

  toggleFeaturedDashboards() {
    this.featuredDashboardsExpanded = !this.featuredDashboardsExpanded;
  }

  toggleTrainingResources() {
    this.trainingResourcesExpanded = !this.trainingResourcesExpanded;
  }

  toggleQuickStartGuide() {
    this.quickStartGuideExpanded = !this.quickStartGuideExpanded;
  }

  toggleProfileDropdown() {
    this.showProfileDropdown = !this.showProfileDropdown;
  }

  getUserInitials(): string {
    if (!this.currentUser) return 'U';
    
    const firstName = this.currentUser.first_name || '';
    const lastName = this.currentUser.last_name || '';
    
    // If we have first and last name, use those
    if (firstName && lastName) {
      return (firstName.charAt(0) + lastName.charAt(0)).toUpperCase();
    }
    
    // If we have username, use first two characters or first character
    if (this.currentUser.username) {
      const username = this.currentUser.username.toUpperCase();
      return username.length > 1 ? username.substring(0, 2) : username.charAt(0);
    }
    
    return 'U';
  }

  closeProfileDropdown() {
    this.showProfileDropdown = false;
  }

  onModalOverlayClick(event: Event) {
    // Only close modal if clicking directly on the overlay (not on child elements)
    if (event.target === event.currentTarget) {
      this.showAddModal = false;
    }
  }

  onRequestModalOverlayClick(event: Event) {
    // Only close modal if clicking directly on the overlay (not on child elements)
    if (event.target === event.currentTarget) {
      this.showRequestModal = false;
    }
  }

  // New methods for sidebar functionality
  toggleSidebar() {
    this.sidebarCollapsed = !this.sidebarCollapsed;
    // Close submenus when collapsing
    if (this.sidebarCollapsed) {
      this.workshopExpanded = false;
      this.hrExpanded = false;
      this.llantasExpanded = false;
    }
  }

  toggleWorkshopSubmenu() {
    if (!this.sidebarCollapsed) {
      this.workshopExpanded = !this.workshopExpanded;
      // Close other submenus
      this.hrExpanded = false;
      this.llantasExpanded = false;
    } else {
      // If sidebar is collapsed, expand it and show submenu
      this.sidebarCollapsed = false;
      this.workshopExpanded = true;
      this.hrExpanded = false;
      this.llantasExpanded = false;
    }
  }

  toggleHRSubmenu() {
    if (!this.sidebarCollapsed) {
      this.hrExpanded = !this.hrExpanded;
      // Close other submenus
      this.workshopExpanded = false;
      this.llantasExpanded = false;
    } else {
      // If sidebar is collapsed, expand it and show submenu
      this.sidebarCollapsed = false;
      this.hrExpanded = true;
      this.workshopExpanded = false;
      this.llantasExpanded = false;
    }
  }

  toggleLlantasSubmenu() {
    if (!this.sidebarCollapsed) {
      this.llantasExpanded = !this.llantasExpanded;
      // Close other submenus
      this.workshopExpanded = false;
      this.hrExpanded = false;
    } else {
      // If sidebar is collapsed, expand it and show submenu
      this.sidebarCollapsed = false;
      this.llantasExpanded = true;
      this.workshopExpanded = false;
      this.hrExpanded = false;
    }
  }

  // WhatsApp integration methods
  submitDashboardRequest() {
    const formData = this.collectFormData();
    if (this.validateFormData(formData)) {
      const whatsappMessage = this.formatWhatsAppMessage(formData);
      this.sendToWhatsApp(whatsappMessage);
      this.showRequestModal = false;
      this.resetForm();
    }
  }

  private collectFormData() {
    const dashboardName = (document.getElementById('dash-name') as HTMLInputElement)?.value || '';
    const department = (document.getElementById('dept-select') as HTMLSelectElement)?.value || '';
    const requirements = (document.getElementById('requirements-text') as HTMLTextAreaElement)?.value || '';
    const priority = (document.getElementById('priority-level') as HTMLSelectElement)?.value || '';
    
    return {
      dashboardName,
      department,
      requirements,
      priority,
      timestamp: new Date().toLocaleString('es-ES')
    };
  }

  private validateFormData(formData: any): boolean {
    if (!formData.dashboardName.trim()) {
      alert('Por favor, ingresa el nombre del dashboard');
      return false;
    }
    if (!formData.department) {
      alert('Por favor, selecciona un departamento');
      return false;
    }
    if (!formData.requirements.trim()) {
      alert('Por favor, describe los requerimientos del dashboard');
      return false;
    }
    return true;
  }

  private formatWhatsAppMessage(formData: any): string {
    const priorityText = this.getPriorityText(formData.priority);
    
    return `🚀 *NUEVO REQUERIMIENTO DE DASHBOARD*

📋 *Información Básica:*
• Dashboard: ${formData.dashboardName}
• Departamento: ${formData.department}
• Prioridad: ${priorityText}
• Fecha: ${formData.timestamp}

📝 *Requerimientos y Descripción:*
${formData.requirements}

---
💡 Solicitado desde BIDashboard System
👤 Usuario: ${this.currentUser?.username || 'Usuario'}`;
  }

  private getPriorityText(priority: string): string {
    const priorities: { [key: string]: string } = {
      'standard': '🟢 Estándar (2-3 semanas)',
      'high': '🟡 Alta Prioridad (1-2 semanas)',  
      'urgent': '🔴 Urgente (< 1 semana)'
    };
    return priorities[priority] || '🟢 Estándar (2-3 semanas)';
  }

  private sendToWhatsApp(message: string) {
    // Número de WhatsApp de Martin Martinez (formato internacional sin + ni espacios)
    const martinWhatsApp = '5218120729613'; // Martin Martinez +52 1 81 2072 9613
    const encodedMessage = encodeURIComponent(message);
    const whatsappUrl = `https://wa.me/${martinWhatsApp}?text=${encodedMessage}`;
    
    // Abrir WhatsApp en una nueva pestaña
    window.open(whatsappUrl, '_blank');
  }

  private resetForm() {
    (document.getElementById('dash-name') as HTMLInputElement).value = '';
    (document.getElementById('dept-select') as HTMLSelectElement).value = '';
    (document.getElementById('requirements-text') as HTMLTextAreaElement).value = '';
    (document.getElementById('priority-level') as HTMLSelectElement).value = 'standard';
  }

}
